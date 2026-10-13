-- Studio location: ServerScriptService.HeistService (ModuleScript)
-- HeistService  (Milestone 032, D22/D24 Boss Heist)
-- The vault opens -> grab a Boss Capsule -> the security robot chases you -> reach the SAFE ZONE -> reveal.
--
-- Vault: opens every HeistConfig.INTERVAL s for WINDOW s (first opening FIRST_OPEN s after start). While it is
-- open, each player may grab ONE capsule per opening (prompt at the door; checked here: data loaded, hands
-- free, not racing, room for a worker, not already grabbed this opening - also after a rejoin).
-- Carry: the capsule rides above the head (welded); the player walks at carry speed (SpeedService) with the
-- player attributes HeistCarrying = true, HeistHits = 0/1, HeistDeadline. Crossing the safe line (the lane's
-- SafeLineWide, south of it and at its height) delivers it: a worker rolled from HEIST odds goes straight to a
-- free pad or storage (WorkerInventory.grant), then the reveal card. Only a walked crossing counts: the tick
-- that crosses the line must be a normal step (a jump of more than WARP_STUDS in one tick never delivers, and
-- WARP_LIMIT of them send the capsule back). Taking more than CARRY_LIMIT s, dying, respawning or leaving sends
-- the capsule back to the vault: nothing gained, nothing lost.
-- One capsule per player per opening: in memory per server (grabbed[userId] = opening id) and in the save:
-- `hub.heist` = { id, cap, uid } is written in the same step as the worker (no yield between the check and both
-- writes), keyed by the opening id (server GUID + counter); a save starts right away.
--
-- Robot: wakes when the vault opens; only carriers are targets (the nearest one). It walks at ROBOT_SPEED inside
-- the RobotArea boxes (apron, street, ramp; never into the safe zone) and stops for slow, telegraphed attacks:
--   Searchlight: a circle follows the target, locks (fixed spot, red) and zaps that spot `warning` s later.
--   Laser: a red line across the lane ahead of the target; `warning` s later the laser sweeps along it.
--   Stomp: a ring shows the reach; `warning` s later a shockwave rolls out along the ground (jump over it).
-- Every attack is announced to all clients (HeistEvent "Attack") at least MIN_WARNING s before anyone can be
-- hit by it; hits are decided here only. Hit 1 pops the shield bubble (HeistHits = 1), hit 2 sends the capsule
-- back. HIT_GRACE s of safety after each hit. No damage, no death, no cash lost.
--
-- World: nothing is added unless the heist is on (HeistConfig flag / Studio attribute StudioHeist). The template
-- ServerStorage.HeistVault032 (tools/build032/B1_Vault.lua) is cloned into Workspace.World.SkyCity.Heist, whose
-- attributes the clients read: State (Closed|Open), OpensAt, ClosesAt, OpeningId, Robot* (RobotPos, RobotYaw,
-- RobotMode, RobotAt); the robot model there is moved by the clients only.
-- Studio: ServerStorage attribute StudioHeistNow = true (or HeistService.forceOpen()) opens the vault now.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local HeistConfig = require(ReplicatedStorage:WaitForChild("HeistConfig"))
local WorkerCatalogue = require(ReplicatedStorage:WaitForChild("WorkerCatalogue"))
local NPCCarry = require(script.Parent:WaitForChild("NPCCarry"))
local NPCClaim = require(script.Parent:WaitForChild("NPCClaim"))
local ParadeService = require(script.Parent:WaitForChild("ParadeService"))
local PlayerData = require(script.Parent:WaitForChild("PlayerData"))
local WorkerInventory = require(script.Parent:WaitForChild("WorkerInventory"))
local WorkerService = require(script.Parent:WaitForChild("WorkerService"))

local HeistService = {}

local TEMPLATE, FOLDER = "HeistVault032", "Heist"
local TICK = 0.1
local REVEAL_DELAY = 1.2
local WARP_STUDS, WARP_LIMIT = 10, 3 -- (the same rule as the race)

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

function HeistService.enabled(): boolean
	return HeistConfig.ENABLED == true or (RunService:IsStudio() and ServerStorage:GetAttribute(HeistConfig.STUDIO_ATTRIBUTE) == true)
end

local function getRemote(name: string): RemoteEvent
	local remote = ReplicatedStorage:FindFirstChild(name)
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = ReplicatedStorage
	end
	return remote :: RemoteEvent
end
local clientEvent = getRemote("HeistEvent") -- server -> client: (kind, info)
local actionEvent = getRemote("HeistAction") -- client -> server: ("State")
local revealEvent = getRemote("WorkerRevealed") -- the existing reveal card

local function livingRoot(player: Player): (BasePart?, Humanoid?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return root, humanoid
	end
	return nil, nil
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function clock(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	return ("%d:%02d"):format(seconds // 60, seconds % 60)
end

-- World ----------------------------------------------------------------------------------------------------
local live: Folder? = nil
local prompt: ProximityPrompt? = nil
local capsuleMaster: Model? = nil
local areas: { { cf: CFrame, half: Vector3 } } = {}
local dockCF, guardCF = CFrame.new(), CFrame.new()
local safeZ, safeY = math.huge, 0
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local GOLD_TEXT, WHITE = Color3.fromRGB(255, 214, 92), Color3.new(1, 1, 1)

local function label(parent: Instance, name: string, text: string, y: number, h: number, color: Color3, font: Enum.Font): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Position = UDim2.fromScale(0.04, y)
	l.Size = UDim2.fromScale(0.92, h)
	l.Font = font
	l.Text = text
	l.TextScaled = true
	l.TextColor3 = color
	l.TextStrokeTransparency = 0.2
	l.Parent = parent
	return l
end

local function surface(part: BasePart): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Name = "SignFront"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Parent = part
	return gui
end

-- Signs: title, a status line the clients fill in ("Opens in 3:20" / "OPEN! 0:42"), the odds.
local function dressSigns(folder: Folder)
	local vault = folder:FindFirstChild("Vault")
	local sign = vault and vault:FindFirstChild("Sign")
	if sign and sign:IsA("BasePart") then
		local gui = surface(sign)
		label(gui, "Title", "BOSS VAULT", 0.04, 0.24, GOLD_TEXT, Enum.Font.FredokaOne)
		label(gui, "Status", "", 0.3, 0.32, WHITE, Enum.Font.GothamBlack)
		label(gui, "Odds", "Boss Capsule: " .. HeistConfig.oddsText(), 0.66, 0.14, GOLD_TEXT, Enum.Font.GothamBold)
		label(gui, "Rule", "Grab one, run it to the SAFE ZONE!", 0.82, 0.13, WHITE, Enum.Font.GothamBold)
	end
	local doorSign = vault and vault:FindFirstChild("DoorSign")
	if doorSign and doorSign:IsA("BasePart") then
		local gui = surface(doorSign)
		label(gui, "Status", "", 0.06, 0.5, WHITE, Enum.Font.GothamBlack)
		label(gui, "Odds", HeistConfig.oddsText(), 0.6, 0.32, GOLD_TEXT, Enum.Font.GothamBold)
	end
	local bay = folder:FindFirstChild("Bay")
	local baySign = bay and bay:FindFirstChild("BaySign")
	if baySign and baySign:IsA("BasePart") then
		label(surface(baySign), "Title", "SECURITY BOT", 0.05, 0.9, GOLD_TEXT, Enum.Font.FredokaOne)
	end
end

local function build(): boolean
	local template = ServerStorage:FindFirstChild(TEMPLATE)
	local world = workspace:FindFirstChild("World")
	local city = world and world:FindFirstChild("SkyCity")
	local lane = city and city:FindFirstChild("Lane")
	local line = lane and lane:FindFirstChild("SafeLineWide")
	if not (template and city and line and line:IsA("BasePart")) then
		warn("[HeistService] ServerStorage." .. TEMPLATE .. " or the lane's SafeLineWide is missing; no heist")
		return false
	end
	safeZ, safeY = line.Position.Z, line.Position.Y
	table.clear(areas)
	for _, box in template.RobotArea:GetChildren() do
		if box:IsA("BasePart") then
			table.insert(areas, { cf = box.CFrame, half = box.Size / 2 })
		end
	end
	dockCF = (template:FindFirstChild("DockSpot") :: BasePart).CFrame
	guardCF = (template:FindFirstChild("GuardSpot") :: BasePart).CFrame
	capsuleMaster = template:FindFirstChild("CapsuleMaster") :: Model
	local folder = Instance.new("Folder")
	folder.Name = FOLDER
	for _, name in { "Vault", "Bay", "Robot", "GrabSpot" } do
		local child = template:FindFirstChild(name)
		if child then
			child:Clone().Parent = folder
		end
	end
	dressSigns(folder)
	local spot = folder:FindFirstChild("GrabSpot") :: BasePart
	local p = Instance.new("ProximityPrompt")
	p.Name = "GrabPrompt"
	p.ActionText = "Grab Boss Capsule"
	p.ObjectText = "Boss Vault"
	p.HoldDuration = 0.4
	p.MaxActivationDistance = 12
	p.RequiresLineOfSight = false
	p.Enabled = false
	p.Parent = spot
	prompt = p
	folder:SetAttribute("State", "Closed")
	folder:SetAttribute("RobotPos", dockCF.Position)
	folder:SetAttribute("RobotYaw", 0)
	folder:SetAttribute("RobotMode", "Dock")
	folder.Parent = city
	live = folder
	rayParams.FilterDescendantsInstances = { folder }
	return true
end

-- Opening ----------------------------------------------------------------------------------------------------
local serverId = HttpService:GenerateGUID(false)
local openingCount = 0
local opening: { id: string, opensAt: number, closesAt: number }? = nil -- the current (or last) opening
local nextOpen = math.huge
local grabbed: { [number]: string } = {} -- userId -> opening id they grabbed in (this server)

HeistService.stats = { openings = 0, grabs = 0, safe = 0, lost = 0, hits = 0, refused = 0, duplicate = 0, attacks = 0 }
HeistService.attackLog = {} :: { any } -- every attack: kind, startAt, warnAt (fixed warning shown), hitAt, hits

local function isOpen(): boolean
	return live ~= nil and live:GetAttribute("State") == "Open"
end

local function openVault(now: number)
	openingCount += 1
	local o = { id = serverId .. "-" .. openingCount, opensAt = now, closesAt = now + HeistConfig.WINDOW }
	opening = o
	nextOpen = now + HeistConfig.INTERVAL
	HeistService.stats.openings += 1
	local folder = live :: Folder
	folder:SetAttribute("State", "Open")
	folder:SetAttribute("OpeningId", o.id)
	folder:SetAttribute("OpensAt", o.opensAt)
	folder:SetAttribute("ClosesAt", o.closesAt)
	if prompt then
		prompt.Enabled = true
	end
	clientEvent:FireAllClients("Open", { id = o.id, closesAt = o.closesAt })
	print(("[HeistService] vault open (%s) until +%ds"):format(o.id, HeistConfig.WINDOW))
end

local function closeVault()
	local folder = live :: Folder
	folder:SetAttribute("State", "Closed")
	folder:SetAttribute("OpensAt", nextOpen)
	folder:SetAttribute("ClosesAt", nil)
	if prompt then
		prompt.Enabled = false
	end
	clientEvent:FireAllClients("Close", { opensAt = nextOpen })
end

-- Studio / trailer kit: open the vault on the next tick (no-op if it is open or the heist is off).
function HeistService.forceOpen(): boolean
	if not RunService:IsStudio() or not live or isOpen() then
		return false
	end
	nextOpen = serverNow()
	return true
end

-- Carriers ---------------------------------------------------------------------------------------------------
type Carrier = {
	player: Player,
	openingId: string,
	at: number,
	hits: number,
	grace: number,
	capsule: Model?,
	conns: { RBXScriptConnection },
	last: Vector3?, -- position at the last tick
	warps: number,
}
local carriers: { [Player]: Carrier } = {}

local function message(player: Player, text: string)
	clientEvent:FireClient(player, "Msg", { text = text })
end

local function attachCapsule(player: Player): Model?
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	local master = capsuleMaster
	if not (head and head:IsA("BasePart") and master) then
		return nil
	end
	local capsule = master:Clone()
	capsule.Name = "BossCapsule"
	local base = capsule.PrimaryPart :: BasePart
	for _, part in capsule:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.Massless = true
			part.CanCollide, part.CanQuery, part.CanTouch = false, false, false
			if part ~= base then
				local weld = Instance.new("WeldConstraint")
				weld.Part0, weld.Part1 = base, part
				weld.Parent = part
			end
		end
	end
	capsule:PivotTo(head.CFrame * CFrame.new(0, head.Size.Y / 2 + 2, 0))
	local weld = Instance.new("Weld")
	weld.Name = "CapsuleWeld"
	weld.Part0, weld.Part1 = head, base
	weld.C0 = CFrame.new(0, head.Size.Y / 2 + 2, 0)
	weld.Parent = base
	capsule.Parent = character
	return capsule
end

local function clearCarrier(c: Carrier)
	carriers[c.player] = nil
	for _, conn in c.conns do
		conn:Disconnect()
	end
	if c.capsule then
		c.capsule:Destroy()
	end
	if c.player.Parent then
		c.player:SetAttribute("HeistCarrying", nil)
		c.player:SetAttribute("HeistHits", nil)
		c.player:SetAttribute("HeistDeadline", nil)
	end
end

-- The capsule goes back to the vault: nothing gained, nothing lost (the grab for this opening stays used).
local function lose(c: Carrier, reason: string)
	local root = livingRoot(c.player)
	local from = if root then root.Position else nil
	clearCarrier(c)
	HeistService.stats.lost += 1
	if c.player.Parent then
		clientEvent:FireAllClients("Lost", { userId = c.player.UserId, reason = reason, from = from })
	end
	print(("[HeistService] %s lost the capsule (%s)"):format(c.player.Name, reason))
end

-- The capsule's worker. Decided and written once per player per opening; returns (worker id, uid, where it
-- went), or nil if this player already has this opening's capsule (or the data isn't loaded).
function HeistService.grant(player: Player, openingId: string): (string?, string?, string?)
	local data = PlayerData.get(player) :: any
	if not data then
		return nil, nil, nil
	end
	if type(data.hub) ~= "table" then
		data.hub = {}
	end
	local hub = data.hub
	if type(hub.heist) == "table" and hub.heist.id == openingId then
		HeistService.stats.duplicate += 1
		return nil, nil, nil
	end
	local workerId = WorkerService.rollWorkerId(HeistConfig.ZONE, HeistConfig.PER_MILLE)
	local identity = WorkerService.newIdentity(workerId, HeistConfig.ZONE)
	-- No yield from the check above to here: the marker and the worker go into the data together.
	hub.heist = { id = openingId, cap = "Boss", uid = identity.uid }
	local where = WorkerInventory.grant(player, {
		uid = identity.uid,
		id = identity.workerId,
		zone = identity.zoneId,
		level = identity.level,
		tier = identity.tier,
		loc = "carried",
	})
	task.spawn(PlayerData.save, player)
	return workerId, identity.uid, where
end

local function deliver(c: Carrier)
	local player = c.player
	clearCarrier(c)
	local workerId, uid, where = HeistService.grant(player, c.openingId)
	if not (workerId and uid) then
		return
	end
	HeistService.stats.safe += 1
	local worker = WorkerCatalogue.get(workerId)
	clientEvent:FireAllClients("Safe", { userId = player.UserId, where = where, rarity = worker and worker.rarity })
	task.delay(REVEAL_DELAY, function()
		if player.Parent then
			revealEvent:FireClient(player, workerId, uid)
			ParadeService.announce(player, workerId, true)
		end
	end)
	print(("[HeistService] %s got the Boss Capsule home: %s (%s), %s"):format(player.Name, workerId, worker and worker.rarity or "?", tostring(where)))
end

-- Can this player grab now? (ok, message)
function HeistService.canGrab(player: Player): (boolean, string?)
	local o = opening
	if not (isOpen() and o) then
		return false, ("The vault is closed. It opens in %s."):format(clock(nextOpen - serverNow()))
	end
	if not PlayerData.isLoaded(player) then
		return false, "Loading your data, one moment"
	end
	local data = PlayerData.get(player) :: any
	local marker = data and type(data.hub) == "table" and data.hub.heist
	if carriers[player] then
		return false, "You already have a Boss Capsule!"
	end
	if grabbed[player.UserId] == o.id or (type(marker) == "table" and marker.id == o.id) then
		return false, ("One capsule per opening! Next one in %s."):format(clock(nextOpen - serverNow()))
	end
	if NPCCarry.getCarried(player) or NPCClaim.getReservation(player) or player:GetAttribute("CarryingNPC") == true or player:GetAttribute("CarryingStolen") == true then
		return false, "Drop your worker first"
	end
	if player:GetAttribute("Racing") == true then
		return false, "Finish your race first"
	end
	if not livingRoot(player) then
		return false, nil
	end
	if not WorkerInventory.hasRoom(player) then
		return false, "Your base is full"
	end
	return true, nil
end

function HeistService.grab(player: Player): boolean
	local ok, why = HeistService.canGrab(player)
	if not ok then
		HeistService.stats.refused += 1
		if why then
			message(player, why)
		end
		return false
	end
	local o = opening :: { id: string, opensAt: number, closesAt: number }
	local now = serverNow()
	grabbed[player.UserId] = o.id
	local startRoot = livingRoot(player)
	local c: Carrier = { player = player, openingId = o.id, at = now, hits = 0, grace = 0, capsule = nil, conns = {}, last = startRoot and startRoot.Position, warps = 0 }
	carriers[player] = c
	c.capsule = attachCapsule(player)
	local _, humanoid = livingRoot(player)
	if humanoid then
		table.insert(
			c.conns,
			humanoid.Died:Connect(function()
				if carriers[player] == c then
					lose(c, "fell")
				end
			end)
		)
	end
	table.insert(
		c.conns,
		player.CharacterRemoving:Connect(function()
			if carriers[player] == c then
				lose(c, "fell")
			end
		end)
	)
	player:SetAttribute("HeistHits", 0)
	player:SetAttribute("HeistDeadline", now + HeistConfig.CARRY_LIMIT)
	player:SetAttribute("HeistCarrying", true)
	player:SetAttribute("HeistGrabbed", o.id)
	HeistService.stats.grabs += 1
	clientEvent:FireAllClients("Grab", { userId = player.UserId, deadline = now + HeistConfig.CARRY_LIMIT })
	print(("[HeistService] %s grabbed a Boss Capsule (%s)"):format(player.Name, o.id))
	return true
end

local function hit(c: Carrier, kind: string, now: number): boolean
	if now < c.grace or carriers[c.player] ~= c then
		return false
	end
	c.hits += 1
	c.grace = now + HeistConfig.HIT_GRACE
	HeistService.stats.hits += 1
	if c.hits >= HeistConfig.HITS then
		lose(c, "caught")
	else
		c.player:SetAttribute("HeistHits", c.hits)
		clientEvent:FireAllClients("Hit", { userId = c.player.UserId, hits = c.hits, kind = kind })
	end
	return true
end

-- Robot ------------------------------------------------------------------------------------------------------
type Attack = {
	id: number,
	kind: string,
	target: Player,
	startAt: number,
	warnAt: number, -- from here the danger zone is fixed and shown
	hitAt: number, -- first moment anyone can be hit
	endAt: number,
	spot: Vector3?, -- searchlight (set when it locks)
	centre: Vector3?, -- laser line centre / stomp centre
	across: Vector3?, -- laser line direction (unit, flat)
	hitPlayers: { [Player]: boolean },
	log: any,
}
local robot = { pos = Vector3.zero, yaw = 0, mode = "Dock", target = nil :: Player?, attack = nil :: Attack?, cooldown = 0 }
local attackCount = 0
local rng = Random.new()

local function inArea(p: Vector3): boolean
	for _, a in areas do
		local l = a.cf:PointToObjectSpace(p)
		if math.abs(l.X) <= a.half.X and math.abs(l.Z) <= a.half.Z then
			return true
		end
	end
	return false
end

-- Nearest point (flat) inside the robot's area.
local function clampToArea(p: Vector3): Vector3
	if inArea(p) then
		return p
	end
	local best, bestD = p, math.huge
	for _, a in areas do
		local l = a.cf:PointToObjectSpace(p)
		local c = a.cf:PointToWorldSpace(Vector3.new(math.clamp(l.X, -a.half.X, a.half.X), l.Y, math.clamp(l.Z, -a.half.Z, a.half.Z)))
		local d = (flat(c) - flat(p)).Magnitude
		if d < bestD then
			best, bestD = Vector3.new(c.X, p.Y, c.Z), d
		end
	end
	return best
end

local function groundAt(p: Vector3, fromY: number): number?
	local result = workspace:Raycast(Vector3.new(p.X, fromY + 8, p.Z), Vector3.new(0, -30, 0), rayParams)
	return result and result.Position.Y
end

local function feetHeight(player: Player): number?
	local root, humanoid = livingRoot(player)
	if not (root and humanoid) then
		return nil
	end
	local result = workspace:Raycast(root.Position, Vector3.new(0, -40, 0), rayParams)
	if not result then
		return math.huge
	end
	return root.Position.Y - root.Size.Y / 2 - humanoid.HipHeight - result.Position.Y
end

local function nearestCarrier(from: Vector3): (Player?, number)
	local best, bestD = nil, math.huge
	for player in carriers do
		local root = livingRoot(player)
		if root then
			local d = (flat(root.Position) - flat(from)).Magnitude
			if d < bestD then
				best, bestD = player, d
			end
		end
	end
	return best, bestD
end

local function face(towards: Vector3)
	local d = flat(towards - robot.pos)
	if d.Magnitude > 0.1 then
		robot.yaw = math.atan2(-d.X, -d.Z)
	end
end

-- Walks toward `goal` (flat), stopping `stop` studs short; returns true when there.
local function walk(goal: Vector3, dt: number, stop: number): boolean
	local d = flat(goal - robot.pos)
	local dist = d.Magnitude
	if dist <= stop + 0.05 then
		return true
	end
	face(goal)
	local step = math.min(HeistConfig.ROBOT_SPEED * dt, dist - stop)
	local nextPos = clampToArea(robot.pos + d.Unit * step)
	local y = groundAt(nextPos, robot.pos.Y)
	robot.pos = Vector3.new(nextPos.X, y or robot.pos.Y, nextPos.Z)
	return false
end

local function publishRobot(now: number)
	local folder = live
	if not folder then
		return
	end
	folder:SetAttribute("RobotPos", robot.pos)
	folder:SetAttribute("RobotYaw", robot.yaw)
	folder:SetAttribute("RobotMode", robot.mode)
	folder:SetAttribute("RobotAt", now)
	folder:SetAttribute("RobotTarget", if robot.target then robot.target.UserId else nil)
end

local function startAttack(kind: string, target: Player, targetRoot: BasePart, now: number)
	attackCount += 1
	local def = HeistConfig.ATTACKS[kind]
	local a: Attack = {
		id = attackCount,
		kind = kind,
		target = target,
		startAt = now,
		warnAt = now,
		hitAt = now + def.warning,
		endAt = now + def.warning + 0.6,
		hitPlayers = {},
		log = nil,
	}
	local info: { [string]: any } = { id = a.id, kind = kind, targetId = target.UserId, startAt = now, robot = robot.pos }
	if kind == "Searchlight" then
		-- follows the target for TRACK s, then locks: the fixed red circle is shown `warning` s before the zap
		local track = 0.6
		a.warnAt = now + track
		a.hitAt = a.warnAt + def.warning
		a.endAt = a.hitAt + 0.5
		info.lockAt, info.hitAt, info.radius = a.warnAt, a.hitAt, def.radius
	elseif kind == "Laser" then
		local v = flat(targetRoot.AssemblyLinearVelocity)
		local lead = v * (def.warning * 0.6)
		if lead.Magnitude > 12 then
			lead = lead.Unit * 12
		end
		local centre = targetRoot.Position + lead
		local towards = flat(centre - robot.pos)
		local across = if towards.Magnitude > 0.1 then Vector3.new(-towards.Unit.Z, 0, towards.Unit.X) else Vector3.new(1, 0, 0)
		local y = groundAt(centre, targetRoot.Position.Y) or (targetRoot.Position.Y - 3)
		a.centre = Vector3.new(centre.X, y, centre.Z)
		a.across = across
		info.centre, info.across, info.length, info.width, info.hitAt = a.centre, across, def.length, def.width, a.hitAt
		face(centre)
	else -- Stomp
		local y = groundAt(robot.pos, robot.pos.Y) or robot.pos.Y
		a.centre = Vector3.new(robot.pos.X, y, robot.pos.Z)
		a.endAt = a.hitAt + def.radius / def.waveSpeed + 0.3
		info.centre, info.hitAt, info.radius, info.waveSpeed, info.band = a.centre, a.hitAt, def.radius, def.waveSpeed, def.band
		face(targetRoot.Position)
	end
	a.log = { id = a.id, kind = kind, startAt = now, warnAt = a.warnAt, hitAt = a.hitAt, hits = {}, target = target.UserId }
	table.insert(HeistService.attackLog, a.log)
	if #HeistService.attackLog > 200 then
		table.remove(HeistService.attackLog, 1)
	end
	HeistService.stats.attacks += 1
	robot.attack = a
	robot.mode = "Attack"
	clientEvent:FireAllClients("Attack", info)
end

local function tryHit(a: Attack, c: Carrier, now: number)
	if a.hitPlayers[c.player] then
		return
	end
	if hit(c, a.kind, now) then
		a.hitPlayers[c.player] = true
		table.insert(a.log.hits, { userId = c.player.UserId, at = now })
	end
end

local function stepAttack(a: Attack, now: number)
	local def = HeistConfig.ATTACKS[a.kind]
	if a.kind == "Searchlight" then
		if not a.spot then
			local root = livingRoot(a.target)
			if not (root and carriers[a.target]) then
				a.endAt = now -- the target got away / home: no lock, nothing happens
				clientEvent:FireAllClients("Cancel", { id = a.id })
				return
			end
			face(root.Position)
			if now >= a.warnAt then
				local y = groundAt(root.Position, root.Position.Y) or (root.Position.Y - 3)
				a.spot = Vector3.new(root.Position.X, y, root.Position.Z)
				a.log.spot = a.spot
				clientEvent:FireAllClients("Lock", { id = a.id, spot = a.spot, hitAt = a.hitAt })
			end
			return
		end
		if now >= a.hitAt and not a.log.fired then
			a.log.fired = true
			for _, c in carriers do
				local root = livingRoot(c.player)
				local spot = a.spot :: Vector3
				if root and (flat(root.Position) - flat(spot)).Magnitude <= def.radius and math.abs(root.Position.Y - spot.Y) < 8 then
					tryHit(a, c, now)
				end
			end
		end
	elseif a.kind == "Laser" then
		if now >= a.hitAt and not a.log.fired then
			a.log.fired = true
			local centre, across = a.centre :: Vector3, a.across :: Vector3
			local along = Vector3.new(across.Z, 0, -across.X) -- (across the line's width)
			for _, c in carriers do
				local root = livingRoot(c.player)
				if root then
					local rel = flat(root.Position - centre)
					if math.abs(rel:Dot(across)) <= def.length / 2 and math.abs(rel:Dot(along)) <= def.width / 2 and math.abs(root.Position.Y - centre.Y) < 8 then
						tryHit(a, c, now)
					end
				end
			end
		end
	else -- Stomp: the wave front at radius waveSpeed * (now - hitAt); grounded players inside its band are hit
		if now >= a.hitAt then
			local r = def.waveSpeed * (now - a.hitAt)
			if r <= def.radius + def.band then
				local centre = a.centre :: Vector3
				for _, c in carriers do
					local root = livingRoot(c.player)
					if root and math.abs(root.Position.Y - centre.Y) < 8 then
						local d = (flat(root.Position) - flat(centre)).Magnitude
						if math.abs(d - r) <= def.band then
							local feet = feetHeight(c.player)
							if feet and feet <= def.jumpClear then
								tryHit(a, c, now)
							end
						end
					end
				end
			end
		end
	end
end

local function chooseAttack(distance: number): string?
	local options = {}
	for kind, def in HeistConfig.ATTACKS do
		if distance <= def.range then
			table.insert(options, kind)
		end
	end
	if #options == 0 then
		return nil
	end
	table.sort(options)
	return options[rng:NextInteger(1, #options)]
end

local function stepRobot(dt: number, now: number)
	local a = robot.attack
	if a then
		stepAttack(a, now)
		if now >= a.endAt then
			robot.attack = nil
			robot.cooldown = now + HeistConfig.ATTACK_GAP
		end
		return
	end
	local target, distance = nearestCarrier(robot.pos)
	robot.target = target
	if target then
		robot.mode = "Chase"
		local root = livingRoot(target) :: BasePart
		if now >= robot.cooldown then
			local kind = chooseAttack(distance)
			if kind then
				startAttack(kind, target, root, now)
				return
			end
		end
		walk(root.Position, dt, 7)
	elseif isOpen() then
		robot.mode = if walk(guardCF.Position, dt, 0.5) then "Guard" else "Walk"
		if robot.mode == "Guard" then
			face(guardCF.Position + guardCF.LookVector * 10)
		end
	else
		local home = walk(dockCF.Position, dt, 0.3)
		robot.mode = if home then "Dock" else "Walk"
		if home then
			robot.pos = dockCF.Position
			face(dockCF.Position + dockCF.LookVector * 10)
		end
	end
end

-- Carriers each tick: time limit, safe line.
local function stepCarriers(now: number)
	local list = {}
	for _, c in carriers do
		table.insert(list, c)
	end
	for _, c in list do
		if carriers[c.player] ~= c then
			continue
		end
		if not c.player.Parent then
			clearCarrier(c)
			HeistService.stats.lost += 1
			continue
		end
		local root = livingRoot(c.player)
		if not root then
			lose(c, "fell")
			continue
		end
		local pos = root.Position
		local last = c.last or pos
		c.last = pos
		local warped = ((pos - last) * Vector3.new(1, 0, 1)).Magnitude > WARP_STUDS
		if warped then
			c.warps += 1
		end
		if now - c.at > HeistConfig.CARRY_LIMIT then
			lose(c, "time")
		elseif c.warps >= WARP_LIMIT then
			lose(c, "shortcut")
		elseif not warped and last.Z < safeZ and pos.Z >= safeZ and pos.Y <= safeY + 12 then
			deliver(c)
		end
	end
end

HeistService._test = {
	carriers = function()
		return carriers
	end,
	robot = robot,
	opening = function()
		return opening
	end,
	grabbed = grabbed,
	safeLine = function()
		return safeZ, safeY
	end,
	-- Studio only: the robot stands here now (positions the chase for a test; it keeps chasing from there).
	placeRobot = function(pos: Vector3)
		robot.pos = clampToArea(pos)
	end,
	-- Studio only: start this attack on this target now (skips the cooldown and range choice).
	attack = function(kind: string, target: Player): boolean
		local root = livingRoot(target)
		if not (root and live) or robot.attack then
			return false
		end
		startAttack(kind, target, root, serverNow())
		return true
	end,
	-- Studio only: no attacks before this time (lets a test walk someone home untouched).
	holdAttacks = function(untilTime: number)
		robot.cooldown = untilTime
	end,
	close = function()
		if isOpen() then
			closeVault()
		end
	end,
	-- Studio only: what PlayerRemoving does for a carrier.
	drop = function(player: Player)
		local c = carriers[player]
		if c then
			clearCarrier(c)
			HeistService.stats.lost += 1
		end
	end,
}

local started = false
function HeistService.start()
	if started then
		return
	end
	started = true
	Players.PlayerRemoving:Connect(function(player)
		local c = carriers[player]
		if c then
			clearCarrier(c) -- back to the vault; the grab for this opening stays used (grabbed[] keeps the id)
			HeistService.stats.lost += 1
		end
	end)
	local lastState: { [Player]: number } = setmetatable({}, { __mode = "k" }) :: any
	actionEvent.OnServerEvent:Connect(function(player, action)
		local t = os.clock()
		if action == "State" and live and (not lastState[player] or t - lastState[player] > 1) then
			lastState[player] = t
			local c = carriers[player]
			clientEvent:FireClient(player, "State", { carrying = c ~= nil, hits = c and c.hits, deadline = c and (c.at + HeistConfig.CARRY_LIMIT) })
		end
	end)
	if RunService:IsStudio() then -- Studio hook: ServerStorage StudioHeistNow = true -> the vault opens now
		ServerStorage:GetAttributeChangedSignal("StudioHeistNow"):Connect(function()
			if ServerStorage:GetAttribute("StudioHeistNow") == true then
				ServerStorage:SetAttribute("StudioHeistNow", nil)
				HeistService.forceOpen()
			end
		end)
	end

	task.spawn(function()
		local running = false
		local last = os.clock()
		while true do
			local dt = math.min(os.clock() - last, 0.5)
			last = os.clock()
			local on = HeistService.enabled()
			if on and not running then
				running = build()
				if running then
					nextOpen = serverNow() + HeistConfig.FIRST_OPEN
					local folder = live :: Folder
					folder:SetAttribute("OpensAt", nextOpen)
					robot.pos, robot.mode, robot.attack, robot.target = dockCF.Position, "Dock", nil, nil
					face(dockCF.Position + dockCF.LookVector * 10)
					local p = prompt :: ProximityPrompt
					p.Triggered:Connect(function(player)
						HeistService.grab(player)
					end)
				else
					on = false
				end
			elseif not on and running then
				running = false
				for _, c in carriers do
					clearCarrier(c)
				end
				if live then
					live:Destroy()
				end
				live, prompt, opening = nil, nil, nil
				robot.attack = nil
			end
			ReplicatedStorage:SetAttribute(HeistConfig.PUBLISHED, if running then true else nil)
			if running and live then
				local now = serverNow()
				if not isOpen() and now >= nextOpen then
					openVault(now)
				elseif isOpen() and opening and now >= opening.closesAt then
					closeVault()
				end
				stepCarriers(now)
				stepRobot(dt, now)
				publishRobot(now)
			end
			task.wait(TICK)
		end
	end)
end

return HeistService
