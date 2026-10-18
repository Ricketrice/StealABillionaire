-- Studio location: ServerScriptService.ZoneProgress (ModuleScript)
-- ZoneProgress
-- Server-authoritative district unlocking (ZoneConfig) and per-player district access.
--
-- Buying: a client asks through the ZoneUnlock RemoteFunction; every rule is checked here. The
-- checks, the cash deduction (CashService.trySpend) and recording the unlock all run without
-- yielding, so they form one transaction: no other request can run in between, a player is never
-- charged without being granted the district, and a second purchase of the same district is
-- refused as already owned. Saving happens afterwards (PlayerData.saveZones).
--
-- Access: unlocked players' clients switch off their gate's collision locally (ZoneGates), which
-- only affects their own character. That is never trusted on its own: several times a second the
-- server checks every character, walking, carrying, freshly respawned or teleported, and returns
-- anyone inside a gated district they haven't unlocked to the plaza side of its gate.
--
-- Unlocked districts are shown to clients on the player's "UnlockedZones" attribute (comma
-- separated ids, server-written only).
--
-- Studio only (032): with ServerStorage.StudioDevTools on, our gated zones also count as unlocked for the developer
-- (StudioDevTools.unlocksZone); they are added to the attribute but never to the save.
--
-- 034: a teammate zone that isn't ready (ZoneConfig.READY) counts as locked for everyone, even with an old unlock in
-- the save (kept there, shown again once the zone is ready).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CashFormat = require(ReplicatedStorage:WaitForChild("CashFormat"))
local ZoneConfig = require(ReplicatedStorage:WaitForChild("ZoneConfig"))
local CashService = require(script.Parent:WaitForChild("CashService"))
local PlayerData = require(script.Parent:WaitForChild("PlayerData"))
local StudioDevTools = require(script.Parent:WaitForChild("StudioDevTools"))

local ZoneProgress = {}

local UNLOCKED_ATTRIBUTE = "UnlockedZones"
local REQUEST_COOLDOWN = 0.3 -- seconds between purchase requests per player
local CHECK_INTERVAL = 0.2 -- seconds between boundary checks
local BOUNDARY_MARGIN = 1.5 -- studs past the gate line before a character counts as inside
local RETURN_DISTANCE = 8 -- studs in front of the gate (plaza side) where turned-back players land
local MIN_CHECK_HEIGHT = -20 -- characters below this are falling into the sea and respawn anyway
local NOTICE_COOLDOWN = 3

type Region = { id: string?, position: Vector3 }

local lastRequest: { [Player]: number } = {}
local lastNotice: { [Player]: number } = {}
local noticeEvent: RemoteEvent? = nil

-- District space: a character is in a district once it is farther from the plaza centre than the
-- gate ring, and that district's NPC area is the nearest anchor (the home hub is an anchor too).
local plazaCentre: Vector3? = nil
local gateRadius = math.huge
local anchors: { Region } = {}
local returnPoints: { [string]: CFrame } = {}
-- Gates that are not on the plaza ring but on the Rising Lane (030, Gate attribute LaneGate): the district is
-- everything north of the barrier (smaller Z) within LANE_GATE_HALF_WIDTH of it, up to the next lane gate (034:
-- Sunken Kingdom, then Ember Academy; the northmost gate a position is past wins).
local LANE_GATE_HALF_WIDTH = 110
-- Hub 2b: a lane gate may face any way. Barrier attributes: Inward (Vector3, flat, from the gate into the zone;
-- default north = (0, 0, -1)) and HalfWidth (studs either side of the gate's line; default LANE_GATE_HALF_WIDTH).
-- Several gates match: the one later in ZoneConfig.ZONES wins (= the northmost on the old straight lane).
type LaneGate = { part: BasePart, inward: Vector3, half: number, order: number }
local laneGates: { [string]: LaneGate } = {}

local function gateInward(barrier: BasePart): Vector3
	local v = barrier:GetAttribute("Inward")
	if typeof(v) == "Vector3" and Vector3.new(v.X, 0, v.Z).Magnitude > 0.01 then
		return Vector3.new(v.X, 0, v.Z).Unit
	end
	return Vector3.new(0, 0, -1)
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

function ZoneProgress.buildRegions()
	local world = workspace:WaitForChild("World")
	local futureZones = world:WaitForChild("FutureZones")
	local plaza = futureZones:WaitForChild("BillionairePlaza"):WaitForChild("ArenaFloor") :: BasePart
	plazaCentre = plaza.Position
	table.clear(anchors)
	table.clear(returnPoints)
	table.clear(laneGates)
	gateRadius = math.huge
	table.insert(anchors, { id = nil, position = (workspace:WaitForChild("Hub"):WaitForChild("Floor") :: BasePart).Position })
	for order, zone in ZoneConfig.ZONES do
		local folder = zone.folder and futureZones:FindFirstChild(zone.folder)
		if not folder then
			continue
		end
		local gate = folder:FindFirstChild("Gate")
		local barrier = gate and gate:FindFirstChild("Barrier")
		local onLane = gate ~= nil and gate:GetAttribute("LaneGate") == true
		local area = folder:FindFirstChild("FutureNPCArea")
		if area and area:IsA("BasePart") and not onLane then
			table.insert(anchors, { id = zone.id, position = area.Position })
		end
		if onLane and barrier and barrier:IsA("BasePart") then
			local inward = gateInward(barrier)
			local half = barrier:GetAttribute("HalfWidth")
			laneGates[zone.id] = {
				part = barrier,
				inward = inward,
				half = if type(half) == "number" and half > 0 then half else LANE_GATE_HALF_WIDTH,
				order = order,
			}
			-- where a turned-back player lands: just in front (outside) of the barrier, on the landing
			local front = barrier.Position - inward * RETURN_DISTANCE
			local hit = workspace:Raycast(front + Vector3.new(0, 12, 0), Vector3.new(0, -40, 0))
			local standAt = Vector3.new(front.X, (if hit then hit.Position.Y else barrier.Position.Y - 5) + 3, front.Z)
			returnPoints[zone.id] = CFrame.lookAt(standAt, standAt - inward)
		elseif barrier and barrier:IsA("BasePart") then
			local offset = flat(barrier.Position - plaza.Position)
			gateRadius = math.min(gateRadius, offset.Magnitude)
			local outward = offset.Unit
			local spot = barrier.Position - outward * RETURN_DISTANCE
			-- ArenaFloor is a flat cylinder: its height is Size.X.
			local standAt = Vector3.new(spot.X, plaza.Position.Y + plaza.Size.X / 2 + 3, spot.Z)
			returnPoints[zone.id] = CFrame.lookAt(standAt, standAt - outward)
		end
	end
	for _, zone in ZoneConfig.ZONES do
		if zone.gate then
			assert(returnPoints[zone.id], zone.id .. " is gated but its gate barrier wasn't found")
		end
	end
end

-- The district a world position is in, or nil (home island, Main Street, bridges home, plaza).
function ZoneProgress.zoneAt(position: Vector3): string?
	local laneZone, laneOrder = nil, -math.huge
	for id, gate in laneGates do
		local b, inward = gate.part.Position, gate.inward
		local dx, dz = position.X - b.X, position.Z - b.Z
		local along = dx * inward.X + dz * inward.Z
		local across = math.abs(dx * inward.Z - dz * inward.X)
		if along > BOUNDARY_MARGIN and across < gate.half and position.Y > b.Y - 30 and gate.order > laneOrder then
			laneZone, laneOrder = id, gate.order
		end
	end
	if laneZone then
		return laneZone
	end
	if not plazaCentre or (flat(position) - flat(plazaCentre)).Magnitude < gateRadius + BOUNDARY_MARGIN then
		return nil
	end
	local best, bestDistance = nil, math.huge
	for _, anchor in anchors do
		local distance = (flat(position) - flat(anchor.position)).Magnitude
		if distance < bestDistance then
			best, bestDistance = anchor, distance
		end
	end
	return best and best.id
end

-- The spot just inside the plaza in front of a district's gate (where a turned-back player lands), if known.
function ZoneProgress.entryPoint(zoneId: string): CFrame?
	return returnPoints[zoneId]
end

function ZoneProgress.isUnlocked(player: Player, zoneId: string): boolean
	if zoneId == ZoneConfig.FREE_ZONE then
		return true
	end
	if not ZoneConfig.isReady(zoneId) then
		return false
	end
	local data = PlayerData.get(player)
	if data ~= nil and StudioDevTools.unlocksZone(player, zoneId) then
		return true
	end
	return data ~= nil and table.find(data.zones, zoneId) ~= nil
end

local function publish(player: Player)
	local data = PlayerData.get(player)
	if data then
		local shown = {}
		for _, id in data.zones do
			if ZoneConfig.isReady(id) then
				table.insert(shown, id)
			end
		end
		for _, zone in ZoneConfig.ZONES do
			if not table.find(shown, zone.id) and StudioDevTools.unlocksZone(player, zone.id) then
				table.insert(shown, zone.id)
			end
		end
		player:SetAttribute(UNLOCKED_ATTRIBUTE, table.concat(shown, ","))
	end
end

-- Buys a district for the player. Returns (success, code, message); code is one of
-- "unlocked", "invalid", "loading", "unavailable", "owned", "prerequisite", "funds".
function ZoneProgress.purchase(player: Player, zoneId: any): (boolean, string, string)
	-- Everything from here to the grant runs without yielding: one indivisible transaction.
	local zone = type(zoneId) == "string" and ZoneConfig.get(zoneId)
	if not zone then
		return false, "invalid", "That district doesn't exist."
	end
	local data = PlayerData.get(player)
	if not data then
		return false, "loading", "Your data is still loading. Try again in a moment."
	end
	if ZoneProgress.isUnlocked(player, zone.id) then
		return false, "owned", zone.name .. " is already unlocked."
	end
	if not ZoneConfig.forSale(zone) then
		return false, "unavailable", zone.name .. " is coming soon!"
	end
	local previous = ZoneConfig.prerequisite(zone.id)
	if previous and not ZoneProgress.isUnlocked(player, previous.id) then
		return false, "prerequisite", ("Unlock %s first. Districts open in order."):format(previous.name)
	end
	if not CashService.trySpend(player, zone.price) then
		local short = zone.price - CashService.get(player)
		return false, "funds", ("You need %s more to unlock %s."):format(CashFormat.format(short), zone.name)
	end
	table.insert(data.zones, zone.id)
	publish(player)
	-- Granted. Persist outside the transaction (this yields).
	task.spawn(function()
		if not PlayerData.saveZones(player) then
			warn("[ZoneProgress] unlock of", zone.id, "for", player.Name, "isn't fully saved yet; the next save retries")
		end
	end)
	print(("[ZoneProgress] %s unlocked %s for %s"):format(player.Name, zone.id, CashFormat.format(zone.price)))
	return true, "unlocked", zone.name .. " unlocked! Walk through the gate to enter."
end

local function notify(player: Player, title: string, message: string)
	local now = os.clock()
	if noticeEvent and now - (lastNotice[player] or -math.huge) >= NOTICE_COOLDOWN then
		lastNotice[player] = now
		noticeEvent:FireClient(player, "error", title, message)
	end
end

-- Returns characters that are inside a gated district they haven't unlocked to its gate.
local function enforce()
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not (root and root:IsA("BasePart")) or root.Position.Y < MIN_CHECK_HEIGHT then
			continue
		end
		local zoneId = ZoneProgress.zoneAt(root.Position)
		local zone = zoneId and ZoneConfig.get(zoneId)
		if zone and zone.gate and not ZoneProgress.isUnlocked(player, zone.id) then
			(character :: Model):PivotTo(returnPoints[zone.id])
			root.AssemblyLinearVelocity = Vector3.zero
			notify(player, zone.name, ("Unlock %s at its gate to enter."):format(zone.name))
		end
	end
end

local function getRemote(className: string, name: string): Instance
	local remote = ReplicatedStorage:FindFirstChild(name)
	if not remote then
		remote = Instance.new(className)
		remote.Name = name
		remote.Parent = ReplicatedStorage
	end
	return remote
end

function ZoneProgress.start()
	ZoneProgress.buildRegions()
	noticeEvent = getRemote("RemoteEvent", "ZoneNotice") :: RemoteEvent
	local unlockRemote = getRemote("RemoteFunction", "ZoneUnlock") :: RemoteFunction
	unlockRemote.OnServerInvoke = function(player: Player, zoneId: any)
		local now = os.clock()
		if now - (lastRequest[player] or -math.huge) < REQUEST_COOLDOWN then
			return false, "busy", "Please wait a moment."
		end
		lastRequest[player] = now
		return ZoneProgress.purchase(player, zoneId)
	end
	PlayerData.onLoaded(function(player)
		publish(player)
	end)
	StudioDevTools.onChanged(function()
		for _, player in Players:GetPlayers() do
			publish(player)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
		lastNotice[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(CHECK_INTERVAL)
			enforce()
		end
	end)
end

ZoneProgress._test = { enforce = enforce, publish = publish }

return ZoneProgress
