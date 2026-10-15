-- Studio location: ServerScriptService.LaneService (ModuleScript)
-- LaneService  (Milestone 030): Home and zone teleports, and the lane's portals. Everything is decided here:
-- a client only names a destination ("Home" or a zone id). Refused while carrying a worker (caught or
-- stolen), in a fight, dead, inside the cooldown, or for a zone the player may not enter. Destinations are
-- read from the map: Home = the player's own plot; Knight's Keep = the part tagged LaneStart; gated zones (Sunken
-- Kingdom, Ember Academy, teammate zones) = the spot in front of their gate (ZoneProgress.entryPoint), which still
-- enforces the unlock. Teammate zones that aren't ready (ZoneConfig.READY) are "coming soon".

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LaneConfig = require(ReplicatedStorage:WaitForChild("LaneConfig"))
local ZoneConfig = require(ReplicatedStorage:WaitForChild("ZoneConfig"))
local PlotService = require(script.Parent:WaitForChild("PlotService"))
local ZoneProgress = require(script.Parent:WaitForChild("ZoneProgress"))

local LaneService = {}

local lastTravel: { [Player]: number } = {}
local lastHurt: { [Player]: number } = {}
local busy: { [Player]: boolean } = {}
local noticeEvent: RemoteEvent? = nil

local function notice(player: Player, ok: boolean, title: string, message: string)
	if noticeEvent then
		noticeEvent:FireClient(player, ok, title, message)
	end
end

-- Why this player can't teleport right now (kid-friendly text), or nil if they can.
function LaneService.blocked(player: Player, recheck: boolean?): string?
	if not LaneConfig.ENABLED then
		return "Teleports are off right now."
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (humanoid and root and humanoid.Health > 0) then
		return "Wait until you're back on your feet."
	end
	if player:GetAttribute("CarryingNPC") == true or player:GetAttribute("CarryingStolen") == true then
		return "You're carrying a creature! Run it home first."
	end
	if player:GetAttribute("HeistCarrying") == true then
		return "You're carrying a Boss Capsule! Run it home first."
	end
	local hurt = lastHurt[player]
	if (hurt and os.clock() - hurt < LaneConfig.COMBAT_SECONDS) or player:GetAttribute("BatCharging") == true then
		return "No teleporting during a fight. Wait a few seconds."
	end
	if recheck then
		return nil -- (the travel in progress is this one: busy and cooldown don't apply to it)
	end
	if busy[player] then
		return "Hold on, you're already on your way!"
	end
	local last = lastTravel[player]
	if last and os.clock() - last < LaneConfig.COOLDOWN then
		return "Hold on a moment, then try again."
	end
	return nil
end

-- Where this destination is for this player: (CFrame, name) or (nil, why not).
function LaneService.destination(player: Player, target: string, zoneId: string?): (CFrame?, string)
	if target == "Home" then
		local cf = PlotService.homeCFrame(player)
		if cf then
			return cf, "your base"
		end
		return nil, "Your base isn't ready yet."
	end
	local zone = if target == "Zone" and zoneId then ZoneConfig.get(zoneId) else nil
	if not zone then
		return nil, "That place doesn't exist."
	end
	if not LaneConfig.OURS[zone.id] then
		if not zone.gate or not ZoneConfig.isReady(zone.id) then
			return nil, zone.name .. " is coming soon!"
		end
		if not ZoneProgress.isUnlocked(player, zone.id) then
			return nil, ("Unlock %s at its gate first."):format(zone.name)
		end
		local entry = ZoneProgress.entryPoint(zone.id)
		if entry then
			return entry, zone.name
		end
		return nil, zone.name .. " isn't ready yet."
	end
	for _, mark in CollectionService:GetTagged(LaneConfig.START_TAG) do
		if mark:GetAttribute("ZoneId") == zone.id and mark:IsA("BasePart") then
			return mark.CFrame, zone.name
		end
	end
	return nil, zone.name .. " isn't ready yet."
end

-- Teleports the player if every rule allows it. Returns (ok, message).
function LaneService.travel(player: Player, target: string, zoneId: string?): (boolean, string)
	local why = LaneService.blocked(player)
	if why then
		return false, why
	end
	local cf, name = LaneService.destination(player, target, zoneId)
	if not cf then
		return false, name
	end
	busy[player] = true
	lastTravel[player] = os.clock()
	pcall(player.RequestStreamAroundAsync, player, cf.Position) -- the floor exists on their screen before they land
	busy[player] = nil
	local again = LaneService.blocked(player, true) -- (a worker may have been grabbed while streaming)
	if again then
		return false, again
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not (character and root) then
		return false, "Wait until you're back on your feet."
	end
	character:PivotTo(cf)
	root.AssemblyLinearVelocity = Vector3.zero
	return true, "Off to " .. name .. "!"
end

local function watchHealth(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then
		return
	end
	local last = humanoid.Health
	humanoid.HealthChanged:Connect(function(health)
		if health < last then
			lastHurt[player] = os.clock()
		end
		last = health
	end)
end

local function request(player: Player, kind: any, id: any)
	if kind ~= "Home" and kind ~= "Zone" then
		return
	end
	if kind == "Zone" and (type(id) ~= "string" or #id > 32) then
		return
	end
	local ok, message = LaneService.travel(player, kind, id)
	notice(player, ok, if ok then "Whoosh!" else "Can't go yet", message)
end

local function hookPortal(trigger: Instance)
	local zoneId = trigger:GetAttribute("ZoneId")
	local prompt = trigger:FindFirstChildOfClass("ProximityPrompt")
	if type(zoneId) ~= "string" or not prompt then
		return
	end
	prompt.Triggered:Connect(function(player)
		request(player, "Zone", zoneId)
	end)
end

function LaneService.start()
	local request_ = Instance.new("RemoteEvent")
	request_.Name = LaneConfig.REQUEST
	request_.Parent = ReplicatedStorage
	local notice_ = Instance.new("RemoteEvent")
	notice_.Name = LaneConfig.NOTICE
	notice_.Parent = ReplicatedStorage
	noticeEvent = notice_
	request_.OnServerEvent:Connect(request)

	local function track(player: Player)
		player.CharacterAdded:Connect(function(character)
			watchHealth(player, character)
		end)
		if player.Character then
			task.spawn(watchHealth, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(track)
	for _, player in Players:GetPlayers() do
		track(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastTravel[player], lastHurt[player], busy[player] = nil, nil, nil
	end)

	CollectionService:GetInstanceAddedSignal(LaneConfig.PORTAL_TAG):Connect(hookPortal)
	for _, trigger in CollectionService:GetTagged(LaneConfig.PORTAL_TAG) do
		hookPortal(trigger)
	end
end

return LaneService
