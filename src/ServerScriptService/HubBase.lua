-- Studio location: ServerScriptService.HubBase (ModuleScript)
-- HubBase  (Milestone 026)
-- Shared server state for the hub gameplay (arena, shops, guide, quests): the four feature flags,
-- the hub remotes (rate-limited), each player's saved hub data and what their client is told.
-- Everything is decided on the server; clients only ask (HubAction) and are shown the result
-- (HubState = their hub data and quests, HubEvent = things that happen).
--
-- Saved per player, in the save's `hub` field (schema 3): trophies, owned = { [itemId] = true },
-- skin, trail, decor = { [spot] = itemId }, upgrades = { storage, training = { [workerUid] = level } },
-- tutorial, quests = { day, ids, progress, claimed }.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local LaunchFlag = require(game:GetService("ReplicatedStorage"):WaitForChild("LaunchFlag"))
local HubConfig = require(ReplicatedStorage:WaitForChild("HubConfig"))
local CashService = require(script.Parent:WaitForChild("CashService"))
local NPCClaim = require(script.Parent:WaitForChild("NPCClaim"))
local PlayerData = require(script.Parent:WaitForChild("PlayerData"))

local HubBase = {}

local FLAGS = { "ARENA_ENABLED", "SHOPS_ENABLED", "NPC_QUESTS_ENABLED", "UPGRADES_ENABLED" }
local PUBLISHED = { ARENA_ENABLED = "HubArena", SHOPS_ENABLED = "HubShops", NPC_QUESTS_ENABLED = "HubNpcQuests", UPGRADES_ENABLED = "HubUpgrades" }

local function getRemote(name: string): RemoteEvent
	local remote = ReplicatedStorage:FindFirstChild(name)
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = ReplicatedStorage
	end
	return remote :: RemoteEvent
end
local actionEvent = getRemote("HubAction") -- client -> server: (action: string, ...)
local clientEvent = getRemote("HubEvent") -- server -> client: (kind: string, info: table?)
local stateEvent = getRemote("HubState") -- server -> client: the player's hub data, quests and flags

local flagsChanged = Instance.new("BindableEvent")
HubBase.FlagsChanged = flagsChanged.Event
HubBase.stats = { dropped = 0, handled = 0 }

function HubBase.flag(name: string): boolean
	return LaunchFlag(HubConfig[name], HubConfig.STUDIO_ATTRIBUTES[name])
end
function HubBase.anyFlag(): boolean
	for _, name in FLAGS do
		if HubBase.flag(name) then
			return true
		end
	end
	return false
end

function HubBase.notify(player: Player, success: boolean, message: string, title: string?)
	if player.Parent then
		NPCClaim.notify(player, success, message, title or "City")
	end
end
function HubBase.event(player: Player, kind: string, info: any?)
	if player.Parent then
		clientEvent:FireClient(player, kind, info)
	end
end
function HubBase.broadcast(kind: string, info: any?)
	clientEvent:FireAllClients(kind, info)
end

-- The player's saved hub data, with its sections in place. nil while their data isn't loaded.
function HubBase.data(player: Player): any?
	local data = PlayerData.get(player) :: any
	if not data then
		return nil
	end
	local hub = data.hub
	if type(hub) ~= "table" then
		hub = {}
		data.hub = hub
	end
	hub.trophies = if type(hub.trophies) == "number" then hub.trophies else 0
	for _, section in { "owned", "decor", "upgrades", "quests" } do
		if type(hub[section]) ~= "table" then
			hub[section] = {}
		end
	end
	if type(hub.upgrades.training) ~= "table" then
		hub.upgrades.training = {}
	end
	return hub
end

-- Extra sections of the state sent to clients (e.g. today's quests): name -> (player) -> any.
local views: { [string]: (Player) -> any } = {}
function HubBase.addView(name: string, view: (Player) -> any)
	views[name] = view
end
function HubBase.push(player: Player)
	if not (player.Parent and HubBase.anyFlag()) then
		return -- (and with every flag off nothing is ever added to a player's saved data)
	end
	local hub = HubBase.data(player)
	if not hub then
		return
	end
	local state = { hub = HttpService:JSONDecode(HttpService:JSONEncode(hub)) }
	for name, view in views do
		state[name] = view(player)
	end
	stateEvent:FireClient(player, state)
end
-- After a change to a player's hub data: tell their client and save soon.
local saving: { [Player]: boolean } = setmetatable({}, { __mode = "k" }) :: any
function HubBase.changed(player: Player)
	HubBase.push(player)
	if not saving[player] then
		saving[player] = true
		task.delay(1, function()
			saving[player] = nil
			if player.Parent then
				PlayerData.save(player)
			end
		end)
	end
end

-- Cash paid out by the hub (rewards). Tracked so the "collect cash" quest doesn't count it.
local granted: { [Player]: number } = setmetatable({}, { __mode = "k" }) :: any
function HubBase.giveCash(player: Player, amount: number)
	granted[player] = (granted[player] or 0) + amount
	CashService.add(player, amount)
end
-- Takes hub-paid cash out of an observed cash increase; returns what is left of it.
function HubBase.takeGranted(player: Player, increase: number): number
	local pending = granted[player] or 0
	local used = math.min(pending, increase)
	granted[player] = pending - used
	return increase - used
end

-- Height of the ground an avatar model is standing on: the soles of its feet. (Not its bounding
-- box: clothing accessories can hang below the feet.)
function HubBase.feetY(model: Model): number
	local low = math.huge
	for _, name in { "LeftFoot", "RightFoot", "Left Leg", "Right Leg" } do
		local part = model:FindFirstChild(name, true)
		if part and part:IsA("BasePart") then
			low = math.min(low, part.Position.Y - part.Size.Y / 2)
		end
	end
	if low == math.huge then
		local box, size = model:GetBoundingBox()
		low = box.Position.Y - size.Y / 2
	end
	return low
end
-- Stands an avatar model at `cf` (facing its -Z) with its feet at height `floorY`.
function HubBase.stand(model: Model, cf: CFrame, floorY: number)
	model:PivotTo(cf)
	model:PivotTo(model:GetPivot() + Vector3.new(0, floorY - HubBase.feetY(model), 0))
end

-- Requests: one entry point, so a spamming client is cut off in one place.
local handlers: { [string]: (Player, ...any) -> () } = {}
local budget: { [Player]: { tokens: number, at: number } } = setmetatable({}, { __mode = "k" }) :: any
function HubBase.onAction(name: string, handler: (Player, ...any) -> ())
	handlers[name] = handler
end
function HubBase.handleAction(player: Player, name: any, ...: any)
	local rate, t = HubConfig.ACTION_RATE, os.clock()
	local b = budget[player]
	if not b then
		b = { tokens = rate, at = t }
		budget[player] = b
	end
	b.tokens = math.min(rate, b.tokens + (t - b.at) * rate)
	b.at = t
	if b.tokens < 1 then
		HubBase.stats.dropped += 1
		return
	end
	b.tokens -= 1
	local handler = if type(name) == "string" then handlers[name] else nil
	if handler and HubBase.anyFlag() and PlayerData.isLoaded(player) then
		HubBase.stats.handled += 1
		handler(player, ...)
	end
end
actionEvent.OnServerEvent:Connect(HubBase.handleAction)

local started = false
function HubBase.start()
	if started then
		return
	end
	started = true
	local function publish()
		for _, name in FLAGS do
			local on = HubBase.flag(name)
			ReplicatedStorage:SetAttribute(PUBLISHED[name], if on then true else nil)
		end
	end
	publish()
	for _, name in FLAGS do
		ServerStorage:GetAttributeChangedSignal(HubConfig.STUDIO_ATTRIBUTES[name]):Connect(function()
			publish()
			flagsChanged:Fire()
			for _, player in Players:GetPlayers() do
				HubBase.push(player)
			end
		end)
	end
	PlayerData.onLoaded(function(player)
		task.wait(1)
		HubBase.push(player)
	end)
	HubBase.onAction("Refresh", function(player)
		HubBase.push(player)
	end)
end

return HubBase
