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

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CashFormat = require(ReplicatedStorage:WaitForChild("CashFormat"))
local ZoneConfig = require(ReplicatedStorage:WaitForChild("ZoneConfig"))
local CashService = require(script.Parent:WaitForChild("CashService"))
local PlayerData = require(script.Parent:WaitForChild("PlayerData"))

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
	gateRadius = math.huge
	table.insert(anchors, { id = nil, position = (workspace:WaitForChild("Hub"):WaitForChild("Floor") :: BasePart).Position })
	for _, zone in ZoneConfig.ZONES do
		local folder = zone.folder and futureZones:FindFirstChild(zone.folder)
		if not folder then
			continue
		end
		local area = folder:FindFirstChild("FutureNPCArea")
		if area and area:IsA("BasePart") then
			table.insert(anchors, { id = zone.id, position = area.Position })
		end
		local gate = folder:FindFirstChild("Gate")
		local barrier = gate and gate:FindFirstChild("Barrier")
		if barrier and barrier:IsA("BasePart") then
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
	local data = PlayerData.get(player)
	return data ~= nil and table.find(data.zones, zoneId) ~= nil
end

local function publish(player: Player)
	local data = PlayerData.get(player)
	if data then
		player:SetAttribute(UNLOCKED_ATTRIBUTE, table.concat(data.zones, ","))
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
	if not zone.purchasable then
		return false, "unavailable", zone.name .. " can't be unlocked yet."
	end
	local previous = ZoneConfig.previous(zone.id)
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
