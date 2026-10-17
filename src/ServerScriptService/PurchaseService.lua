-- Studio location: ServerScriptService.PurchaseService (ModuleScript)
-- PurchaseService  (Milestone 033, D13/D19/D20): Robux purchases, decided here. Items + perks in
-- ReplicatedStorage.ProductConfig; switch PURCHASES_ENABLED (Studio StudioPurchases, published PurchasesOn).
-- Off = no receipt is handled (Roblox keeps them and asks again later), no pass perks, every card "Coming soon".
--
-- Developer products (ProcessReceipt): a receipt is granted ONCE. Its PurchaseId is written into hub.receipts
-- (last RECEIPTS_KEPT) together with what it gave, and PurchaseGranted is only returned once that save has landed.
-- A failed save returns NotProcessedYet; Roblox sends the receipt again and, seeing the id already there, we only
-- save again (never grant twice). A player who isn't here (or whose data isn't loaded) gets NotProcessedYet.
-- Gamepasses: owned = UserOwnsGamePassAsync (asked once per join, cached, retried) or a purchase seen this
-- session (PromptGamePassPurchaseFinished); the result is cached in hub.passes so perks are there from the
-- first second of the next visit. Player attributes Pass_x2cash / Pass_slots / Pass_vip and IsVIP.
-- Perks: 2x Cash and VIP multiply income (PassiveIncome), Extra Slots = +storage (WorkerInventory) and +2 pads
-- (BaseService reads Pass_slots). VIP's tag: RankServer (gold "VIP · RANK"), chat tag: PurchaseClient.
-- Starter Pack: one per player (hub.starter), shown for STARTER_DAYS after the first visit (hub.born).
-- Remote PurchaseRequest (RemoteFunction): "State" -> info | "Buy" key -> ok, message (prompts the purchase).
-- Studio only (tests, never live): ServerStorage attribute StudioOwnPasses = "x2cash,slots,vip" counts as owned.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local ProductConfig = require(ReplicatedStorage:WaitForChild("ProductConfig"))
local Analytics = require(script.Parent:WaitForChild("Analytics"))
local CashService = require(script.Parent:WaitForChild("CashService"))
local PassiveIncome = require(script.Parent:WaitForChild("PassiveIncome"))
local PlayerData = require(script.Parent:WaitForChild("PlayerData"))
local SpeedService = require(script.Parent:WaitForChild("SpeedService"))
local WorkerInventory = require(script.Parent:WaitForChild("WorkerInventory"))

local PurchaseService = {}

local OWNERSHIP_TRIES = 3
local REQUEST_GAP = 0.5 -- seconds between a player's Buy requests

local request = ReplicatedStorage:FindFirstChild("PurchaseRequest") :: RemoteFunction?
if not request then
	local r = Instance.new("RemoteFunction")
	r.Name = "PurchaseRequest"
	r.Parent = ReplicatedStorage
	request = r
end

PurchaseService.stats = { granted = 0, repeats = 0, notYet = 0, passes = 0 }

local on = ProductConfig.on
PurchaseService.on = on

local PASSES: { any } = ProductConfig.ITEMS.passes
local byProductId: { [number]: any } = {}
local byPassId: { [number]: any } = {}
local function index()
	table.clear(byProductId)
	table.clear(byPassId)
	for _, item in ProductConfig.BY_KEY do
		if ProductConfig.available(item) then
			if item.kind == "pass" then
				byPassId[item.id] = item
			else
				byProductId[item.id] = item
			end
		end
	end
end
index()

local function hub(player: Player): any?
	local data = PlayerData.get(player) :: any
	if not data then
		return nil
	end
	if type(data.hub) ~= "table" then
		data.hub = {}
	end
	return data.hub
end

-- Passes ---------------------------------------------------------------------------------------------------------------
local checked: { [Player]: { [string]: boolean } } = setmetatable({}, { __mode = "k" }) :: any -- live answers this session

local function studioOwned(key: string): boolean
	if not RunService:IsStudio() then
		return false
	end
	local list = ServerStorage:GetAttribute("StudioOwnPasses")
	return type(list) == "string" and table.find(string.split(list, ","), key) ~= nil
end

function PurchaseService.owns(player: Player, key: string): boolean
	if not on() then
		return false
	end
	if studioOwned(key) then
		return true
	end
	local live = checked[player]
	if live and live[key] ~= nil then
		return live[key]
	end
	local h = hub(player)
	return h ~= nil and type(h.passes) == "table" and h.passes[key] == true
end

local function publish(player: Player)
	if not player.Parent then
		return
	end
	for _, item in PASSES do
		local owned = PurchaseService.owns(player, item.key)
		player:SetAttribute("Pass_" .. item.key, owned or nil)
	end
	player:SetAttribute("IsVIP", PurchaseService.owns(player, "vip") or nil)
	PassiveIncome.refresh(player)
end

local function setOwned(player: Player, key: string, owned: boolean)
	checked[player] = checked[player] or {}
	checked[player][key] = owned
	local h = hub(player)
	if h then
		if type(h.passes) ~= "table" then
			h.passes = {}
		end
		h.passes[key] = if owned then true else nil
	end
end

-- Asks Roblox which passes the player owns (passes without an id are skipped). Yields.
local function checkPasses(player: Player)
	for _, item in PASSES do
		if not ProductConfig.available(item) then
			continue
		end
		for attempt = 1, OWNERSHIP_TRIES do
			local ok, owned = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, item.id)
			if ok then
				setOwned(player, item.key, owned == true)
				break
			elseif attempt < OWNERSHIP_TRIES then
				task.wait(2 * attempt)
			end -- (still unknown: the saved cache in hub.passes is used)
		end
	end
	publish(player)
end

-- Products -------------------------------------------------------------------------------------------------------------
local function receiptsOf(h: any): { string }
	if type(h.receipts) ~= "table" then
		h.receipts = {}
	end
	return h.receipts
end

-- Gives what a product gives. Returns the cash given.
local function give(player: Player, h: any, item: any): number
	local cash = ProductConfig.cashFor(item, PassiveIncome.getIncome(player))
	CashService.add(player, cash)
	if item.oneTime then
		h.starter = true
		player:SetAttribute("StarterOwned", true)
	end
	if item.trail then
		SpeedService.grant(player, item.trail)
	end
	return cash
end

-- The receipt handler (also called directly by Studio tests with a made-up receipt).
function PurchaseService.processReceipt(info: any): Enum.ProductPurchaseDecision
	if not on() then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local player = Players:GetPlayerByUserId(info.PlayerId)
	local item = byProductId[info.ProductId]
	if not (player and item and PlayerData.isLoaded(player)) then
		PurchaseService.stats.notYet += 1
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local h = hub(player)
	if not h then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local receipts = receiptsOf(h)
	local id = tostring(info.PurchaseId)
	if table.find(receipts, id) then
		PurchaseService.stats.repeats += 1 -- granted before: only make sure it is saved
	else
		give(player, h, item)
		table.insert(receipts, id)
		while #receipts > ProductConfig.RECEIPTS_KEPT do
			table.remove(receipts, 1)
		end
		PurchaseService.stats.granted += 1
	end
	if PlayerData.save(player) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	PurchaseService.stats.notYet += 1
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

-- State + requests -----------------------------------------------------------------------------------------------------
local function starterShown(player: Player): boolean
	local h = hub(player)
	if not h or h.starter == true then
		return false
	end
	local born = tonumber(h.born)
	return born ~= nil and os.time() - born < ProductConfig.STARTER_DAYS * 86400
end

local function state(player: Player): any
	local owned = {}
	for _, item in PASSES do
		owned[item.key] = PurchaseService.owns(player, item.key)
	end
	local h = hub(player)
	return { on = on(), passes = owned, starterOwned = h ~= nil and h.starter == true, starterShown = starterShown(player) }
end

local lastBuy: { [Player]: number } = setmetatable({}, { __mode = "k" }) :: any
function PurchaseService.buy(player: Player, key: any): (boolean, string?)
	if not on() then
		return false, "The Store isn't open yet."
	end
	local item = type(key) == "string" and ProductConfig.BY_KEY[key]
	if not (item and ProductConfig.available(item)) then
		return false, "Coming soon."
	end
	local t = os.clock()
	if lastBuy[player] and t - lastBuy[player] < REQUEST_GAP then
		return false, nil
	end
	lastBuy[player] = t
	if item.kind == "pass" then
		if PurchaseService.owns(player, item.key) then
			return false, "You already have this pass."
		end
		Analytics.step(player, "FirstPurchasePrompt")
		MarketplaceService:PromptGamePassPurchase(player, item.id)
	else
		if item.oneTime and player:GetAttribute("StarterOwned") == true then
			return false, "You already have the Starter Pack."
		end
		if item.oneTime and not starterShown(player) then
			return false, "The Starter Pack is for new players."
		end
		Analytics.step(player, "FirstPurchasePrompt")
		MarketplaceService:PromptProductPurchase(player, item.id)
	end
	return true, nil
end

-- Perks, registered as soon as this module loads (BaseService requires it before any save loads, so a pass's
-- storage and pads are there when saved workers are put back).
for _, item in PASSES do
	if item.income then
		PassiveIncome.setMultiplier(function(player: Player): number
			return if PurchaseService.owns(player, item.key) then item.income else 1
		end, item.key)
	end
	if item.storage then
		WorkerInventory.setSlotBonus(function(player: Player): number
			return if PurchaseService.owns(player, item.key) then item.storage else 0
		end, item.key)
	end
end

local started = false
function PurchaseService.start()
	if started then
		return
	end
	started = true
	ReplicatedStorage:SetAttribute(ProductConfig.PUBLISHED, on())
	MarketplaceService.ProcessReceipt = PurchaseService.processReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		local item = byPassId[passId]
		if purchased and item and on() then
			setOwned(player, item.key, true)
			PurchaseService.stats.passes += 1
			publish(player)
			task.spawn(PlayerData.save, player)
		end
	end)
	local remote = request :: RemoteFunction
	remote.OnServerInvoke = function(player, action, key)
		if action == "State" then
			return true, nil, state(player)
		elseif action == "Buy" then
			return PurchaseService.buy(player, key)
		end
		return false, nil
	end
	PlayerData.onLoaded(function(player)
		local h = hub(player)
		if h and type(h.born) ~= "number" then
			h.born = os.time() -- first visit since 033 (the Starter Pack window starts now)
		end
		player:SetAttribute("StarterOwned", h ~= nil and h.starter == true or nil)
		publish(player) -- cached passes first, then the live answer
		if on() then
			checkPasses(player)
			WorkerInventory.refresh(player) -- storage from Extra Slots
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		checked[player] = nil
	end)
	if RunService:IsStudio() then
		local function refresh()
			ReplicatedStorage:SetAttribute(ProductConfig.PUBLISHED, on())
			index()
			for _, player in Players:GetPlayers() do
				publish(player)
				if PlayerData.isLoaded(player) then
					WorkerInventory.refresh(player)
				end
			end
		end
		ServerStorage:GetAttributeChangedSignal(ProductConfig.STUDIO_ATTRIBUTE):Connect(refresh)
		ServerStorage:GetAttributeChangedSignal("StudioOwnPasses"):Connect(refresh)
	end
end

-- Studio tests only: what a product with this key gives / set ids for a test run.
PurchaseService._test = {
	setId = function(key: string, id: number)
		if RunService:IsStudio() then
			ProductConfig.BY_KEY[key].id = id
			index()
		end
	end,
	state = state,
	starterShown = starterShown,
}

return PurchaseService
