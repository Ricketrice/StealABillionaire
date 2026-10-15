-- Studio location: ServerScriptService.BaseService (ModuleScript)
-- BaseService  (Milestone 033, D25/D28): worker levels 1-10 and base pads 7-12, all decided here. Numbers in
-- ReplicatedStorage.BaseConfig; switches LEVELS_ENABLED / PADS_ENABLED / LIVING_ENABLED (Studio StudioLevels /
-- StudioPads / StudioLiving), published as LevelsOn / PadsOn / LivingOn. All off = nothing here changes the game.
-- Started by HubServer BEFORE WorkerInventory, so bought pads exist before saved workers are stood on them.
--
-- Levels: the worker record's `level` (already saved, schema 3). Level up = cash (BaseConfig.levelCost of the
-- worker's catalogue income), from the card (BaseRequest "LevelUp" uid) or the "Level up" prompt on its pad. Only
-- income rises (WorkerCatalogue.getStats). A stolen worker keeps its level (the record travels with it).
-- Pads: while PADS_ENABLED the lot's own six pads move to the inner columns (BaseConfig.PAD_SPOTS) and bought pads go
-- up in the outer ones, on the owner's lot only (taken down when they leave). hub.pads = pads bought (0..6). The
-- next pad shows as a glowing "Unlock $X" pad once the player's pads are all full (and from then on).
-- Extra Slots gamepass (033, player attribute Pass_slots): +PASS_PADS pads, numbered after the bought ones.
-- Feature reveal (D28): level-up appears once REVEAL_LEVELS_AT workers are on pads; both get one NEW! hint
-- (hub.intro.levels / hub.intro.pads, BaseEvent "Intro").
-- Remotes: BaseRequest (RemoteFunction) "State" | "LevelUp" uid | "UnlockPad"  -> ok, message, info
--          BaseEvent (s->c) "Intro" what | "Levelled" { uid, level } | "PadUnlocked" index
-- Player attributes: LevelsShown, PadsBought, PadsTotal, PadNextPrice (nil when none), PadUnlockShown.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local BaseConfig = require(ReplicatedStorage:WaitForChild("BaseConfig"))
local CashFormat = require(ReplicatedStorage:WaitForChild("CashFormat"))
local WorkerCatalogue = require(ReplicatedStorage:WaitForChild("WorkerCatalogue"))
local CashService = require(script.Parent:WaitForChild("CashService"))
local NPCClaim = require(script.Parent:WaitForChild("NPCClaim"))
local NPCPlacement = require(script.Parent:WaitForChild("NPCPlacement"))
local PassiveIncome = require(script.Parent:WaitForChild("PassiveIncome"))
local PlayerData = require(script.Parent:WaitForChild("PlayerData"))
local PlotService = require(script.Parent:WaitForChild("PlotService"))
local PurchaseService = require(script.Parent:WaitForChild("PurchaseService"))
local WorkerInventory = require(script.Parent:WaitForChild("WorkerInventory"))

local BaseService = {}

local TITLE = "Base"
local LEVEL_PROMPT = "LevelPrompt"
local UNLOCK_NAME = "PadUnlock"
local REQUEST_RATE = 6 -- requests per second per player
local REACH = 12 -- studs from a pad (prompt distance 8 + latency)

local function remote(name: string, class: string): any
	local r = ReplicatedStorage:FindFirstChild(name)
	if not r then
		r = Instance.new(class)
		r.Name = name
		r.Parent = ReplicatedStorage
	end
	return r
end
local request = remote("BaseRequest", "RemoteFunction") :: RemoteFunction
local event = remote("BaseEvent", "RemoteEvent") :: RemoteEvent

BaseService.stats = { levels = 0, pads = 0, refused = 0 }

local function on(key: string): boolean
	return BaseConfig.on(key)
end
BaseService.on = on

local function notify(player: Player, ok: boolean, message: string)
	NPCClaim.notify(player, ok, message, TITLE)
end

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

local function saveSoon(player: Player)
	task.spawn(function()
		if player.Parent and PlayerData.isLoaded(player) then
			PlayerData.save(player)
		end
	end)
end

-- Pads ----------------------------------------------------------------------------------------------------------------
local plotsFolder: Instance = workspace:WaitForChild("Hub"):WaitForChild("Plots")

local function padsBought(player: Player): number
	local h = hub(player)
	if not h then
		return 0
	end
	local n = tonumber(h.pads) or 0
	-- (Studio saves from the 026 Upgrade Office's Extra Station count as bought pads)
	local old = type(h.upgrades) == "table" and tonumber(h.upgrades.stations) or 0
	n = math.max(n, old)
	return if n == n then math.clamp(math.floor(n), 0, #BaseConfig.PAD_PRICES) else 0
end

local function passPads(player: Player): number
	return if PurchaseService.owns(player, "slots") then BaseConfig.PASS_PADS else 0 -- (reads the saved cache too)
end

-- Extra stations beyond the first six (WorkerInventory station bonus "pads").
local function extraPads(player: Player): number
	if not on("PADS_ENABLED") then
		return 0
	end
	return padsBought(player) + passPads(player)
end

local function spotCFrame(plot: Model, index: number, template: BasePart): CFrame?
	local spot = BaseConfig.PAD_SPOTS[index]
	local floor = plot.PrimaryPart
	if not (spot and floor) then
		return nil
	end
	local at = floor.CFrame * CFrame.new(spot[1], 0, spot[2])
	return CFrame.new(at.Position.X, template.Position.Y, at.Position.Z) * template.CFrame.Rotation
end

local function stationsOf(plot: Model): { [number]: BasePart }
	local list = {}
	local folder = plot:FindFirstChild("Stations")
	for _, station in (if folder then folder:GetChildren() else {}) do
		local index = station:GetAttribute("StationIndex")
		if station:IsA("BasePart") and type(index) == "number" then
			list[index] = station
		end
	end
	return list
end

-- Moves a pad (with its ring and the worker standing on it) so its centre is at `cf`.
local function movePad(plot: Model, pad: BasePart, cf: CFrame)
	local delta = cf * pad.CFrame:Inverse()
	local placed = plot:FindFirstChild("PlacedNPCs")
	for _, npc in (if placed then placed:GetChildren() else {}) do
		if npc:IsA("Model") and npc:GetAttribute("StationIndex") == pad:GetAttribute("StationIndex") then
			npc:PivotTo(delta * npc:GetPivot())
		end
	end
	local pieces = {}
	for _, piece in pad:GetDescendants() do
		if piece:IsA("BasePart") then
			pieces[piece] = delta * piece.CFrame
		end
	end
	pad.CFrame = cf
	for piece, target in pieces do
		piece.CFrame = target
	end
end

-- The lot's own six pads: in the new layout while PADS_ENABLED, back where they were built otherwise.
local layoutOn: boolean? = nil
local function layout()
	local want = on("PADS_ENABLED")
	if layoutOn == want then
		return
	end
	layoutOn = want
	for _, plot in plotsFolder:GetChildren() do
		if not plot:IsA("Model") then
			continue
		end
		for index, pad in stationsOf(plot) do
			if index > BaseConfig.FIRST_PADS then
				continue
			end
			local home = pad:GetAttribute("BuiltCFrame")
			if typeof(home) ~= "CFrame" then
				pad:SetAttribute("BuiltCFrame", pad.CFrame)
				home = pad.CFrame
			end
			local target = if want then spotCFrame(plot, index, pad) else home
			if target and (target.Position - pad.Position).Magnitude > 0.01 then
				movePad(plot, pad, target)
			end
		end
	end
end

local function template(plot: Model): BasePart?
	return stationsOf(plot)[1]
end

local function stripPad(pad: BasePart)
	for _, child in pad:GetChildren() do
		if not child:IsA("BasePart") then
			child:Destroy()
		end
	end
end

-- The glowing "Unlock $X" pad for the next pad, on the owner's lot.
local function setUnlockPad(player: Player, plot: Model, index: number?, price: number?)
	local old = plot:FindFirstChild(UNLOCK_NAME)
	if not (index and price) then
		if old then
			old:Destroy()
		end
		return
	end
	if old and old:GetAttribute("PadIndex") == index and old:GetAttribute("Price") == price then
		return
	end
	if old then
		old:Destroy()
	end
	local base = template(plot)
	local cf = base and spotCFrame(plot, index, base)
	if not (base and cf) then
		return
	end
	local pad = base:Clone()
	stripPad(pad)
	pad.Name = UNLOCK_NAME
	for _, attribute in { "StationIndex", "Occupied", "BuiltCFrame" } do
		pad:SetAttribute(attribute, nil)
	end
	pad:SetAttribute("PadIndex", index)
	pad:SetAttribute("Price", price)
	pad:SetAttribute("OwnerUserId", player.UserId)
	pad.CFrame = cf
	pad.Material = Enum.Material.Neon
	pad.Color = Color3.fromRGB(255, 200, 60)
	pad.Transparency = 0.45
	pad.CanCollide, pad.CanTouch = false, false
	for _, ring in pad:GetChildren() do
		if ring:IsA("BasePart") then
			ring.CFrame = cf * CFrame.new(-0.02, 0, 0)
			ring.Material = Enum.Material.Neon
			ring.Color = Color3.fromRGB(255, 240, 160)
			ring.Transparency = 0.6
			ring.CanCollide, ring.CanTouch = false, false
		end
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromOffset(180, 64)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 3.5, 0)
	gui.MaxDistance = 70
	gui.LightInfluence = 0
	gui.Parent = pad
	local function line(name: string, text: string, y: number, h: number, colour: Color3)
		local label = Instance.new("TextLabel")
		label.Name = name
		label.BackgroundTransparency = 1
		label.Position = UDim2.fromScale(0, y)
		label.Size = UDim2.fromScale(1, h)
		label.Font = Enum.Font.GothamBlack
		label.TextScaled = true
		label.Text = text
		label.TextColor3 = colour
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.Color = Color3.fromRGB(30, 24, 40)
		stroke.Parent = label
		label.Parent = gui
	end
	line("Title", "NEW PAD " .. index, 0, 0.4, Color3.new(1, 1, 1))
	line("Price", "Unlock " .. CashFormat.format(price), 0.42, 0.58, Color3.fromRGB(255, 214, 92))
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "UnlockPrompt"
	prompt.ActionText = "Unlock " .. CashFormat.format(price)
	prompt.ObjectText = "New pad"
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.Enabled = false -- BaseClient shows it to the owner only
	prompt.Parent = pad
	prompt.Triggered:Connect(function(who)
		if who == player then
			local ok, message = BaseService.unlockPad(who)
			if message then
				notify(who, ok, message)
			end
		end
	end)
	pad.Parent = plot
end

-- Level-up prompt on every occupied pad of an owner who has levels (attribute Want); BaseClient enables only the
-- owner's nearest one while they are not carrying (all prompts share the E key, see PlotPrompts).
local function levelText(npc: Model?): (string?, number?)
	if not npc then
		return nil, nil
	end
	local id, level = npc:GetAttribute("WorkerId"), npc:GetAttribute("Level")
	local worker = type(id) == "string" and WorkerCatalogue.get(id)
	if not (worker and type(level) == "number") then
		return nil, nil
	end
	local cost = BaseConfig.levelCost(worker.income, level)
	return if cost then ("Level up %s"):format(CashFormat.format(cost)) else "MAX LEVEL", cost
end

local function placedOn(plot: Model, index: number): Model?
	local placed = plot:FindFirstChild("PlacedNPCs")
	for _, npc in (if placed then placed:GetChildren() else {}) do
		if npc:IsA("Model") and npc:GetAttribute("StationIndex") == index then
			return npc
		end
	end
	return nil
end

local function refreshPrompt(plot: Model, pad: BasePart)
	local prompt = pad:FindFirstChild(LEVEL_PROMPT) :: ProximityPrompt?
	local index = pad:GetAttribute("StationIndex") :: number
	local owner = Players:GetPlayerByUserId(plot:GetAttribute("OwnerUserId") or 0)
	local npc = placedOn(plot, index)
	local text, cost = levelText(npc)
	local want = on("LEVELS_ENABLED") and owner ~= nil and owner:GetAttribute("LevelsShown") == true and text ~= nil
	if not want then
		if prompt then
			prompt:SetAttribute("Want", false)
		end
		return
	end
	if not prompt then
		local p = Instance.new("ProximityPrompt")
		p.Name = LEVEL_PROMPT
		p.HoldDuration = 0
		p.MaxActivationDistance = 8
		p.RequiresLineOfSight = false
		p.KeyboardKeyCode = Enum.KeyCode.E
		p.GamepadKeyCode = Enum.KeyCode.ButtonX
		p.UIOffset = Vector2.new(0, 36)
		p.Enabled = false -- BaseClient enables the owner's nearest one (attribute Want = the server allows it)
		p.Parent = pad
		p.Triggered:Connect(function(who)
			local worker = placedOn(plot, index)
			local uid = worker and worker:GetAttribute("WorkerUid")
			if PlotService.getPlot(who) ~= plot or type(uid) ~= "string" then
				return
			end
			local ok, message = BaseService.levelUp(who, uid, pad)
			if message then
				notify(who, ok, message)
			end
		end)
		prompt = p
	end
	local p = prompt :: ProximityPrompt
	p.ActionText = text :: string
	local worker = npc and WorkerCatalogue.get(npc:GetAttribute("WorkerId"))
	p.ObjectText = ("%s · Lv %d"):format(if worker then worker.name else "Worker", (npc and npc:GetAttribute("Level")) or 1)
	p:SetAttribute("Want", cost ~= nil)
end

local function refreshPrompts(plot: Model)
	for _, pad in stationsOf(plot) do
		refreshPrompt(plot, pad)
	end
end

-- Builds (or takes down) the owner's extra pads and the unlock pad. Does not yield.
local function buildPads(player: Player, plot: Model?)
	plot = plot or PlotService.getPlot(player)
	if not plot then
		return
	end
	local p = plot :: Model
	local stations = p:FindFirstChild("Stations")
	local base = template(p)
	if not (stations and base) then
		return
	end
	local want, added = BaseConfig.FIRST_PADS + extraPads(player), false
	for index = BaseConfig.FIRST_PADS + 1, #BaseConfig.PAD_SPOTS do
		local pad = stations:FindFirstChild("Station" .. index)
		local mine = pad and pad:GetAttribute("BasePad") == true
		if index <= want and not pad then
			local cf = spotCFrame(p, index, base)
			if cf then
				local copy = base:Clone()
				stripPad(copy)
				copy:SetAttribute("BuiltCFrame", nil)
				local delta = cf * base.CFrame:Inverse()
				for _, piece in copy:GetDescendants() do
					if piece:IsA("BasePart") then
						piece.CFrame = delta * piece.CFrame
					end
				end
				copy.CFrame = cf
				copy.Name = "Station" .. index
				copy:SetAttribute("StationIndex", index)
				copy:SetAttribute("Occupied", false)
				copy:SetAttribute("BasePad", true)
				copy.Parent = stations
				added = true
			end
		elseif index > want and mine then
			-- (only when the switch goes off: a bought pad is never taken back) its worker goes to storage first
			local npc = placedOn(p, index)
			local uid = npc and npc:GetAttribute("WorkerUid")
			if type(uid) == "string" then
				local record = WorkerInventory.take(player, uid)
				if record then
					record.loc, record.station = "carried", nil
					WorkerInventory.give(player, record, true)
					WorkerInventory.putAway(player, uid)
				end
			end
			pad:Destroy()
		end
	end
	if added and p.Parent then
		NPCPlacement.start(p.Parent) -- Place prompts on the new pads
	end
	refreshPrompts(p)
end
BaseService.buildPads = buildPads

local function clearPads(plot: Model)
	local stations = plot:FindFirstChild("Stations")
	for _, pad in (if stations then stations:GetChildren() else {}) do
		if pad:GetAttribute("BasePad") == true then
			pad:Destroy()
		end
	end
	local unlock = plot:FindFirstChild(UNLOCK_NAME)
	if unlock then
		unlock:Destroy()
	end
	for _, pad in stationsOf(plot) do
		local prompt = pad:FindFirstChild(LEVEL_PROMPT)
		if prompt then
			prompt:Destroy()
		end
	end
end

-- Publishes the player's base state, runs the feature reveal, and puts up / takes down the unlock pad.
local function update(player: Player)
	local h = hub(player)
	local plot = PlotService.getPlot(player)
	if not (h and plot and WorkerInventory.isReady(player)) then
		return
	end
	local _, onPads = WorkerInventory.count(player)
	local _, stations = WorkerInventory.capacity(player)
	if type(h.intro) ~= "table" then
		h.intro = {}
	end
	-- Levels (D28): shown once enough workers are working.
	local levelsOn = on("LEVELS_ENABLED")
	if levelsOn and h.intro.levels ~= true and onPads >= BaseConfig.REVEAL_LEVELS_AT then
		h.intro.levels = true
		event:FireClient(player, "Intro", "levels")
	end
	local shown = levelsOn and h.intro.levels == true
	if player:GetAttribute("LevelsShown") ~= shown then
		player:SetAttribute("LevelsShown", shown)
		refreshPrompts(plot)
	end
	-- Pads: the next one shows when every pad is full, and from then on.
	local padsOn = on("PADS_ENABLED")
	local bought = padsBought(player)
	local price = if padsOn then BaseConfig.padPrice(bought) else nil
	if padsOn and price and h.intro.pads ~= true and onPads >= stations then
		h.intro.pads = true
		event:FireClient(player, "Intro", "pads")
	end
	local unlockShown = padsOn and price ~= nil and h.intro.pads == true
	player:SetAttribute("PadsBought", if padsOn then bought else nil)
	player:SetAttribute("PadsTotal", if padsOn then stations else nil)
	player:SetAttribute("PadNextPrice", price)
	player:SetAttribute("PadUnlockShown", unlockShown)
	setUnlockPad(player, plot, if unlockShown then stations + 1 else nil, if unlockShown then price else nil)
end
BaseService.update = update

-- Unlocks the next pad for cash. The pad must be showing (D28) and the player must afford it.
function BaseService.unlockPad(player: Player): (boolean, string?)
	if not on("PADS_ENABLED") then
		return false, nil
	end
	local h = hub(player)
	local plot = PlotService.getPlot(player)
	if not (h and plot and WorkerInventory.isReady(player)) then
		return false, "Your base is still loading."
	end
	update(player)
	if player:GetAttribute("PadUnlockShown") ~= true then
		return false, "Fill all your pads first."
	end
	local bought = padsBought(player)
	local price = BaseConfig.padPrice(bought)
	if not price then
		return false, "Your base has every pad."
	end
	local unlock = plot:FindFirstChild(UNLOCK_NAME) :: BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not (unlock and root and (root.Position - unlock.Position).Magnitude <= REACH) then
		return false, "Walk onto the glowing pad to unlock it."
	end
	if not CashService.trySpend(player, price) then
		return false, ("You need %s for this pad."):format(CashFormat.format(price))
	end
	h.pads = bought + 1
	if type(h.upgrades) == "table" and h.upgrades.stations then
		h.upgrades.stations = nil -- (folded into hub.pads above)
	end
	BaseService.stats.pads += 1
	buildPads(player, plot)
	WorkerInventory.refresh(player)
	update(player)
	local _, stations = WorkerInventory.capacity(player)
	event:FireClient(player, "PadUnlocked", stations)
	saveSoon(player)
	return true, ("New pad unlocked! You now have %d pads."):format(stations)
end

-- Levels --------------------------------------------------------------------------------------------------------------
-- Raises one of the player's workers by one level for cash. `pad` = the pad they pressed (checked for reach).
function BaseService.levelUp(player: Player, uid: any, pad: BasePart?): (boolean, string?, any?)
	if not on("LEVELS_ENABLED") then
		return false, nil
	end
	if player:GetAttribute("LevelsShown") ~= true then
		return false, nil
	end
	local record = type(uid) == "string" and WorkerInventory.getRecord(player, uid) :: any
	if not record then
		return false, nil
	end
	local worker = WorkerCatalogue.get(record.id)
	if not worker then
		return false, "That creature can't level up."
	end
	if record.loc == "carried" then
		return false, "Put your creature down first."
	end
	local busy = WorkerInventory.busyReason(player, record)
	if busy then
		return false, busy
	end
	local level = math.max(1, math.floor(tonumber(record.level) or 1))
	local cost = BaseConfig.levelCost(worker.income, level)
	if not cost then
		return false, worker.name .. " is already at the top level."
	end
	if pad then
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not (root and (root.Position - pad.Position).Magnitude <= REACH) then
			return false, "Get closer to the pad."
		end
	end
	if not CashService.trySpend(player, cost) then
		return false, ("You need %s to level up %s."):format(CashFormat.format(cost), worker.name)
	end
	level += 1
	record.level = level
	local model = WorkerInventory.placedModel(player, uid)
	if model then
		model:SetAttribute("Level", level)
		model:SetAttribute("Income", (WorkerCatalogue.getStats(record.id, level, record.tier or WorkerCatalogue.TIER)))
		local plot = PlotService.getPlot(player)
		local station = model:GetAttribute("StationIndex")
		local p = plot and type(station) == "number" and stationsOf(plot)[station]
		if plot and p then
			refreshPrompt(plot, p)
		end
	end
	BaseService.stats.levels += 1
	PassiveIncome.refresh(player)
	WorkerInventory.refresh(player)
	event:FireClient(player, "Levelled", { uid = uid, level = level })
	saveSoon(player)
	return true, ("%s is now Level %d!"):format(worker.name, level), { level = level }
end

-- Requests ------------------------------------------------------------------------------------------------------------
local buckets: { [Player]: { tokens: number, at: number } } = {}
local function allow(player: Player): boolean
	local now = os.clock()
	local b = buckets[player]
	if not b then
		b = { tokens = REQUEST_RATE, at = now }
		buckets[player] = b
	end
	b.tokens = math.min(REQUEST_RATE, b.tokens + (now - b.at) * REQUEST_RATE)
	b.at = now
	if b.tokens < 1 then
		return false
	end
	b.tokens -= 1
	return true
end

local function state(player: Player): any
	return {
		levels = on("LEVELS_ENABLED"),
		pads = on("PADS_ENABLED"),
		living = on("LIVING_ENABLED"),
		levelsShown = player:GetAttribute("LevelsShown") == true,
		padsBought = player:GetAttribute("PadsBought"),
		padNextPrice = player:GetAttribute("PadNextPrice"),
	}
end

request.OnServerInvoke = function(player: Player, action: any, arg: any)
	if not allow(player) then
		return false, "Slow down a little."
	end
	local ok, message, info
	if action == "State" then
		return true, nil, state(player)
	elseif action == "LevelUp" then
		ok, message, info = BaseService.levelUp(player, arg)
	elseif action == "UnlockPad" then
		ok, message = BaseService.unlockPad(player)
	else
		return false, nil
	end
	if not ok then
		BaseService.stats.refused += 1
	end
	if message then
		notify(player, ok, message)
	end
	return ok, message, info
end

-- Start ---------------------------------------------------------------------------------------------------------------
local function publish()
	for key, flag in BaseConfig.FLAGS do
		ReplicatedStorage:SetAttribute(flag.published, on(key))
	end
end

local function refreshAll()
	publish()
	layout()
	for _, player in Players:GetPlayers() do
		if PlayerData.isLoaded(player) then
			buildPads(player)
			WorkerInventory.refresh(player)
			update(player)
		end
	end
	for _, plot in plotsFolder:GetChildren() do
		if plot:IsA("Model") then
			refreshPrompts(plot)
		end
	end
end

local started = false
function BaseService.start()
	if started then
		return
	end
	started = true
	publish()
	layout()
	WorkerInventory.setStationBonus(extraPads, buildPads, "pads")
	PlayerData.onLoaded(function(player)
		local waited = 0
		while not (PlotService.getPlot(player) and WorkerInventory.isReady(player)) and player.Parent and waited < 15 do
			waited += task.wait(0.25)
		end
		if player.Parent then
			buildPads(player) -- (already done if the lot was there when the workers were rebuilt)
			WorkerInventory.refresh(player)
			update(player)
		end
	end)
	-- Pads fill / empty: reveal, unlock pad and level prompts follow.
	for _, plot in plotsFolder:GetChildren() do
		if not plot:IsA("Model") then
			continue
		end
		local placed = plot:WaitForChild("PlacedNPCs", 10)
		if placed then
			local function changed(child: Instance)
				local owner = Players:GetPlayerByUserId(plot:GetAttribute("OwnerUserId") or 0)
				if owner then
					task.defer(update, owner) -- after the inventory has recorded it
				end
				local index = child:GetAttribute("StationIndex")
				local pad = type(index) == "number" and stationsOf(plot)[index]
				if pad then
					task.defer(refreshPrompt, plot, pad)
				end
			end
			placed.ChildAdded:Connect(changed)
			placed.ChildRemoved:Connect(changed)
		end
		plot:GetAttributeChangedSignal("OwnerUserId"):Connect(function()
			if plot:GetAttribute("OwnerUserId") == nil then
				clearPads(plot)
			end
		end)
	end
	local function watchPass(player: Player)
		player:GetAttributeChangedSignal("Pass_slots"):Connect(function()
			if PlayerData.isLoaded(player) then
				buildPads(player)
				WorkerInventory.refresh(player)
				update(player)
			end
		end)
	end
	Players.PlayerAdded:Connect(watchPass)
	for _, player in Players:GetPlayers() do
		watchPass(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		buckets[player] = nil
	end)
	if RunService:IsStudio() then
		for _, flag in BaseConfig.FLAGS do
			ServerStorage:GetAttributeChangedSignal(flag.studio):Connect(refreshAll)
		end
	end
end

-- Studio tests only.
BaseService._test = {
	padsBought = padsBought,
	layoutOn = function()
		return layoutOn
	end,
}

return BaseService
