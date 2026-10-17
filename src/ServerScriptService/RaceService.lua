-- Studio location: ServerScriptService.RaceService (ModuleScript)
-- RaceService  (Milestone 031, D21 Royale Race)
-- Stand on the pad -> run the Spell Run course (034; LAPS = 1: rune gates in order, then the finish arch) -> a capsule
-- opens -> an Ember Academy creature. Falling below the course is never death: anyone inside the course's FallZone
-- is popped back (a racer to the last rune gate they passed, anyone else to PadSpot), whether the race is on or not.
--
-- Rounds: the first race is open as soon as the course is built (032); after that, once RaceConfig.INTERVAL has
-- passed since the last start, the next eligible player who stands on the pad starts a JOIN_WINDOW countdown
-- ("Join the race!" on the sign, big numbers for the last COUNTDOWN s). Eligible players on the pad are frozen
-- (no walking or jumping) for those last COUNTDOWN s and let go at GO; whoever is on the pad at GO races
-- (eligible = data loaded, Zone 6 unlocked, not carrying, room for one more worker). A player on the pad who
-- can't race gets the reason on the "RaceBlock" attribute (RaceClient shows it). Racers run at a fixed speed,
-- don't collide with each other (collision group) and are kept on the track by invisible walls only they
-- collide with (RaceConfig.WALL_GROUP). The server checks every racer's position against invisible gates (Gates.CP1..N in
-- order, then Gates.Finish = one lap); a skipped checkpoint means the lap never counts. Nothing about
-- progress comes from the client: there is no "finish" message to fake or re-send.
--
-- Rewards: every finisher gets one capsule (Gold for the top RaceConfig.goldPlaces(racers), Silver for the
-- rest), rolled from the Zone 6 pool and given straight to a free pad or storage (WorkerInventory.grant).
-- One capsule per player per race: the save's `hub.race` = { id, cap, uid, place } is written in the same
-- step as the worker (no yield between the check and both writes), keyed by the race id (server GUID +
-- counter), and a save is started right away. Leaving mid-race gives nothing; a rejoined player is not a
-- racer; a rejoin after finishing finds hub.race.id already set.
--
-- World: nothing is added unless the race is on (RaceConfig flag / Studio attribute StudioRace). The course
-- (ServerStorage.<RaceConfig.TEMPLATE>) is cloned into Workspace.World.<RaceConfig.WORLD>.RaceCourse, whose attributes
-- the clients read: State (Waiting|Countdown|Racing|Podium), Ready (server time the next race may start),
-- GoAt, EndsAt, Laps, Racers; its Route folder holds the gate positions (CFrameValues, attribute Order) for the
-- client's next-checkpoint arch. A racer can leave mid-race (RaceAction "Leave", the HUD button): no reward.
-- Player attributes while racing: Racing = true, RaceLap = 1..LAPS, RaceNext = the
-- next gate's Order (1..N, 0 = the line); RaceFrozen = true while frozen on the pad.

local HttpService = game:GetService("HttpService")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local LaunchFlag = require(game:GetService("ReplicatedStorage"):WaitForChild("LaunchFlag"))
local RaceConfig = require(ReplicatedStorage:WaitForChild("RaceConfig"))
local WorkerCatalogue = require(ReplicatedStorage:WaitForChild("WorkerCatalogue"))
local ZoneConfig = require(ReplicatedStorage:WaitForChild("ZoneConfig"))
local ParadeService = require(script.Parent:WaitForChild("ParadeService"))
local PlayerData = require(script.Parent:WaitForChild("PlayerData"))
local WorkerInventory = require(script.Parent:WaitForChild("WorkerInventory"))
local WorkerService = require(script.Parent:WaitForChild("WorkerService"))
local ZoneProgress = require(script.Parent:WaitForChild("ZoneProgress"))

local RaceService = {}

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

function RaceService.enabled(): boolean
	return LaunchFlag(RaceConfig.ENABLED, RaceConfig.STUDIO_ATTRIBUTE)
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
local clientEvent = getRemote("RaceEvent") -- server -> client: (kind, info)
local actionEvent = getRemote("RaceAction") -- client -> server: ("State")
local revealEvent = getRemote("WorkerRevealed") -- the existing reveal card (WorkerReveal creates it too)

-- Course ------------------------------------------------------------------------------------------------
type Gate = { cf: CFrame, half: Vector3, order: number }
local course: Folder? = nil -- the live copy in the world
local gates: { [number]: Gate } = {} -- order -> gate; 0 = finish
local checkpointCount = 0
local pad: BasePart? = nil
local nameTags: { TextLabel } = {}

local function inBox(cf: CFrame, half: Vector3, position: Vector3): boolean
	local p = cf:PointToObjectSpace(position)
	return math.abs(p.X) <= half.X and math.abs(p.Y) <= half.Y and math.abs(p.Z) <= half.Z
end

local function livingRoot(player: Player): (BasePart?, Humanoid?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return root, humanoid
	end
	return nil, nil
end

function RaceService.onPad(player: Player): boolean
	local root = livingRoot(player)
	local p = pad
	if not (root and p) then
		return false
	end
	local height = p:GetAttribute("PadHeight") or 8
	local half = Vector3.new(p.Size.X / 2, height / 2, p.Size.Z / 2)
	return inBox(p.CFrame * CFrame.new(0, height / 2 - 1, 0), half, root.Position)
end

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

local GOLD_TEXT, SILVER_TEXT, WHITE = Color3.fromRGB(255, 214, 92), Color3.fromRGB(220, 226, 236), Color3.new(1, 1, 1)

local function faces(part: BasePart): { SurfaceGui }
	local list = {}
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Name = "Sign" .. face.Name
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		gui.LightInfluence = 0
		gui.Parent = part
		table.insert(list, gui)
	end
	return list
end

-- The pad sign (both faces): title, one huge status line (filled in by each client: "Join the race! 12",
-- "Next race in 2:41", ...) and one rule line. The odds are on the OddsBoard.
local function dressSign(sign: BasePart)
	for _, gui in faces(sign) do
		label(gui, "Title", RaceConfig.TITLE, 0.04, 0.2, GOLD_TEXT, Enum.Font.FredokaOne)
		label(gui, "Status", "Stand on the pad to race!", 0.27, 0.44, WHITE, Enum.Font.GothamBlack)
		local rule = if RaceConfig.LAPS > 1 then ("%d laps"):format(RaceConfig.LAPS) else ("%d rune gates"):format(checkpointCount)
		label(gui, "Rule", rule .. " · every finisher wins a capsule", 0.76, 0.17, WHITE, Enum.Font.GothamBold)
	end
end

-- The odds board beside the pad (both faces): who gets which capsule, each with its odds.
local function dressOdds(board: BasePart)
	for _, gui in faces(board) do
		local goldRule = ("GOLD: top %d (1st only if under %d racers)"):format(RaceConfig.GOLD_PLACES, RaceConfig.SMALL_RACE_MIN)
		label(gui, "GoldTitle", goldRule, 0.04, 0.17, GOLD_TEXT, Enum.Font.GothamBlack)
		label(gui, "Gold", RaceConfig.oddsText("Gold"), 0.22, 0.24, GOLD_TEXT, Enum.Font.GothamBold).TextWrapped = true
		label(gui, "SilverTitle", "SILVER: everyone else who finishes", 0.52, 0.17, SILVER_TEXT, Enum.Font.GothamBlack)
		label(gui, "Silver", RaceConfig.oddsText("Silver"), 0.7, 0.24, SILVER_TEXT, Enum.Font.GothamBold).TextWrapped = true
	end
end

-- Walls collide with racers only: switched off against every other collision group (also ones registered
-- after the race started, so this runs at each build).
local function wallGroups()
	for _, group in PhysicsService:GetRegisteredCollisionGroups() do
		if group.name ~= RaceConfig.COLLISION_GROUP then
			PhysicsService:CollisionGroupSetCollidable(RaceConfig.WALL_GROUP, group.name, false)
		end
	end
	PhysicsService:CollisionGroupSetCollidable(RaceConfig.WALL_GROUP, RaceConfig.COLLISION_GROUP, true)
end

local function dressNames()
	table.clear(nameTags)
	if not course then
		return
	end
	for i = 1, 3 do
		local anchor = course:FindFirstChild("Name" .. i)
		if anchor then
			local gui = Instance.new("BillboardGui")
			gui.Name = "PodiumName"
			gui.Size = UDim2.fromScale(10, 1.6)
			gui.StudsOffset = Vector3.new(0, 0, 0)
			gui.MaxDistance = 150
			gui.LightInfluence = 0
			gui.Enabled = false
			gui.Parent = anchor
			local text = label(gui, "Name", "", 0, 1, if i == 1 then Color3.fromRGB(255, 214, 92) else Color3.new(1, 1, 1), Enum.Font.FredokaOne)
			text.Position, text.Size = UDim2.new(), UDim2.fromScale(1, 1)
			nameTags[i] = text
		end
	end
end

local function showPodium(rows: { { name: string, place: number } }?)
	for i, tag in nameTags do
		local row = rows and rows[i]
		tag.Text = if row then ({ "1st", "2nd", "3rd" })[i] .. "  " .. row.name else ""
		local gui = tag.Parent :: BillboardGui
		gui.Enabled = row ~= nil
	end
end

local function buildCourse(): boolean
	local template = ServerStorage:FindFirstChild(RaceConfig.TEMPLATE)
	local world = workspace:FindFirstChild("World")
	local royale = world and world:FindFirstChild(RaceConfig.WORLD)
	if not (template and royale) then
		warn("[RaceService] ServerStorage." .. RaceConfig.TEMPLATE .. " or World." .. RaceConfig.WORLD .. " is missing; no race")
		return false
	end
	table.clear(gates)
	checkpointCount = 0
	for _, g in template.Gates:GetChildren() do
		if g:IsA("BasePart") and type(g:GetAttribute("Order")) == "number" then
			local order = g:GetAttribute("Order")
			gates[order] = { cf = g.CFrame, half = g.Size / 2, order = order }
			checkpointCount = math.max(checkpointCount, order)
		end
	end
	assert(gates[0] and checkpointCount > 0, "race course needs Gates.Finish and checkpoints")
	local folder = Instance.new("Folder")
	folder.Name = RaceConfig.FOLDER
	for _, child in template:GetChildren() do
		if child:IsA("BasePart") then
			child:Clone().Parent = folder
		end
	end
	pad = folder:FindFirstChild("StartPad") :: BasePart
	local sign = folder:FindFirstChild("Sign")
	if sign and sign:IsA("BasePart") then
		dressSign(sign)
	end
	local odds = folder:FindFirstChild("OddsBoard")
	if odds and odds:IsA("BasePart") then
		dressOdds(odds)
	end
	local walls = template:FindFirstChild("Walls")
	if walls then
		wallGroups()
		local copy = walls:Clone()
		for _, wall in copy:GetChildren() do
			if wall:IsA("BasePart") then
				wall.CollisionGroup = RaceConfig.WALL_GROUP
			end
		end
		copy.Parent = folder
	end
	-- gate positions for the client's next-checkpoint arch (progress is still only counted here)
	local route = Instance.new("Folder")
	route.Name = "Route"
	for order, g in gates do
		local value = Instance.new("CFrameValue")
		value.Name = if order == 0 then "Finish" else "CP" .. order
		value.Value = g.cf
		value:SetAttribute("Order", order)
		value:SetAttribute("Size", g.half * 2)
		value.Parent = route
	end
	route.Parent = folder
	folder:SetAttribute("Laps", RaceConfig.LAPS)
	folder:SetAttribute("Checkpoints", checkpointCount)
	folder:SetAttribute("State", "Waiting")
	folder.Parent = royale
	course = folder
	dressNames()
	return true
end

-- Sets the round state, then `set` attributes, then clears the `clear` ones.
local function setState(state: string, set: { [string]: any }?, clear: { string }?)
	local folder = course
	if not folder then
		return
	end
	folder:SetAttribute("State", state)
	if set then
		for k, v in set do
			folder:SetAttribute(k, v)
		end
	end
	if clear then
		for _, k in clear do
			folder:SetAttribute(k, nil)
		end
	end
end

-- Racers ------------------------------------------------------------------------------------------------
type Racer = {
	player: Player,
	character: Model,
	nextCp: number, -- 1..checkpointCount, then checkpointCount + 1 = the finish line is next
	lap: number,
	last: Vector3,
	warps: number,
	groups: { [BasePart]: string },
	speed: number?, -- WalkSpeed before the race
	conn: RBXScriptConnection?,
}
type Race = {
	id: string,
	goAt: number,
	endsAt: number,
	started: number, -- racers at GO (decides the Gold places)
	racers: { [Player]: Racer },
	finishers: { { name: string, userId: number, place: number, capsule: string, time: number } },
}

local serverId = HttpService:GenerateGUID(false)
local raceCount = 0
local race: Race? = nil
RaceService.stats = { races = 0, finished = 0, capsules = 0, out = 0, duplicate = 0, left = 0, pops = 0 }

-- Can this player race right now? (ok, message for the player)
function RaceService.eligible(player: Player): (boolean, string?)
	if not PlayerData.isLoaded(player) then
		return false, "Loading your data, one moment"
	end
	if not ZoneProgress.isUnlocked(player, RaceConfig.ZONE) then
		return false, ("Unlock %s to race"):format((ZoneConfig.get(RaceConfig.ZONE) :: any).name)
	end
	if player:GetAttribute("CarryingNPC") == true or player:GetAttribute("CarryingStolen") == true or player:GetAttribute("HeistCarrying") == true then
		return false, "Drop your creature first"
	end
	if not WorkerInventory.hasRoom(player) then
		return false, "Your base is full"
	end
	return true, nil
end

local function setGroup(racer: Racer, part: Instance)
	if part:IsA("BasePart") and racer.groups[part] == nil then
		racer.groups[part] = part.CollisionGroup
		part.CollisionGroup = RaceConfig.COLLISION_GROUP
	end
end

local function join(r: Race, player: Player)
	local root, humanoid = livingRoot(player)
	if not (root and humanoid) then
		return
	end
	local character = player.Character :: Model
	local racer: Racer = {
		player = player,
		character = character,
		nextCp = 1,
		lap = 1,
		last = root.Position,
		warps = 0,
		groups = {},
		speed = humanoid.WalkSpeed,
		conn = nil,
	}
	for _, part in character:GetDescendants() do
		setGroup(racer, part)
	end
	racer.conn = character.DescendantAdded:Connect(function(part)
		setGroup(racer, part)
	end)
	humanoid.WalkSpeed = RaceConfig.WALK_SPEED
	r.racers[player] = racer
	player:SetAttribute("Racing", true)
	player:SetAttribute("RaceLap", 1)
	player:SetAttribute("RaceNext", 1)
end

-- Takes a racer out of the race (finished, out or race over): collision group, speed, attributes back.
local function release(r: Race, racer: Racer)
	r.racers[racer.player] = nil
	if racer.conn then
		racer.conn:Disconnect()
	end
	for part, group in racer.groups do
		if part.Parent and part.CollisionGroup == RaceConfig.COLLISION_GROUP then
			part.CollisionGroup = group
		end
	end
	local humanoid = racer.character:FindFirstChildOfClass("Humanoid")
	if humanoid and racer.speed and humanoid.WalkSpeed == RaceConfig.WALK_SPEED then
		humanoid.WalkSpeed = racer.speed
	end
	if racer.player.Parent then
		racer.player:SetAttribute("Racing", nil)
		racer.player:SetAttribute("RaceLap", nil)
		racer.player:SetAttribute("RaceNext", nil)
	end
end

local function out(r: Race, racer: Racer, reason: string)
	release(r, racer)
	RaceService.stats.out += 1
	if racer.player.Parent then
		clientEvent:FireClient(racer.player, "Out", { reason = reason })
	end
end

-- The capsule. Decided and written once per player per race; returns (worker id, worker uid, where it went),
-- or nil if this player already has this race's capsule (or the data isn't loaded).
function RaceService.grant(player: Player, raceId: string, place: number, capsule: string): (string?, string?, string?)
	local data = PlayerData.get(player) :: any
	if not data then
		return nil, nil, nil
	end
	if type(data.hub) ~= "table" then
		data.hub = {}
	end
	local hub = data.hub
	if type(hub.race) == "table" and hub.race.id == raceId then
		RaceService.stats.duplicate += 1
		return nil, nil, nil
	end
	local workerId = WorkerService.rollWorkerId(RaceConfig.ZONE, RaceConfig.PER_MILLE[capsule])
	local identity = WorkerService.newIdentity(workerId, RaceConfig.ZONE)
	-- No yield from the check above to here: the marker and the worker go into the data together.
	hub.race = { id = raceId, cap = capsule, uid = identity.uid, place = place }
	local where = WorkerInventory.grant(player, {
		uid = identity.uid,
		id = identity.workerId,
		zone = identity.zoneId,
		level = identity.level,
		tier = identity.tier,
		loc = "carried",
	})
	RaceService.stats.capsules += 1
	task.spawn(PlayerData.save, player)
	return workerId, identity.uid, where
end

local function finish(r: Race, racer: Racer)
	local player = racer.player
	local place = #r.finishers + 1
	local capsule = if place <= RaceConfig.goldPlaces(r.started) then "Gold" else "Silver"
	release(r, racer)
	table.insert(r.finishers, { name = player.DisplayName, userId = player.UserId, place = place, capsule = capsule, time = serverNow() - r.goAt })
	RaceService.stats.finished += 1
	local workerId, uid, where = RaceService.grant(player, r.id, place, capsule)
	if not (workerId and uid) then
		return
	end
	clientEvent:FireClient(player, "Finish", { place = place, capsule = capsule, where = where, racers = r.started })
	task.delay(RaceConfig.REVEAL_DELAY, function()
		if player.Parent then
			revealEvent:FireClient(player, workerId, uid)
			ParadeService.announce(player, workerId, capsule == "Gold")
		end
	end)
	local worker = WorkerCatalogue.get(workerId)
	print(
		("[RaceService] %s finished #%d of %d -> %s capsule: %s (%s), %s"):format(
			player.Name,
			place,
			r.started,
			capsule,
			workerId,
			worker and worker.rarity or "?",
			tostring(where)
		)
	)
end

-- One server tick of a racer: still valid? any gate passed?
local function step(r: Race, racer: Racer, dt: number)
	local player = racer.player
	if not player.Parent then
		release(r, racer)
		return
	end
	local root = livingRoot(player)
	if not root or player.Character ~= racer.character then
		out(r, racer, "You fell out of the race!")
		return
	end
	if player:GetAttribute("CarryingNPC") == true or player:GetAttribute("CarryingStolen") == true then
		out(r, racer, "Racers can't carry creatures.")
		return
	end
	local humanoid = racer.character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.WalkSpeed ~= RaceConfig.WALK_SPEED then
		humanoid.WalkSpeed = RaceConfig.WALK_SPEED -- no speed changes in the race
	end
	local position = root.Position
	local moved = ((position - racer.last) * Vector3.new(1, 0, 1)).Magnitude
	racer.last = position
	if moved > math.max(RaceConfig.WARP_STUDS, RaceConfig.WALK_SPEED * dt * 2.5) then
		racer.warps += 1
		if racer.warps >= RaceConfig.WARP_LIMIT then
			out(r, racer, "Out of the race: no shortcuts!")
		end
		return -- a jump this big counts no gate
	end
	local target = if racer.nextCp > checkpointCount then gates[0] else gates[racer.nextCp]
	if not inBox(target.cf, target.half, position) then
		return
	end
	if racer.nextCp <= checkpointCount then
		racer.nextCp += 1
		player:SetAttribute("RaceNext", if racer.nextCp > checkpointCount then 0 else racer.nextCp)
		return
	end
	-- crossed the line after every checkpoint: a lap
	if racer.lap >= RaceConfig.LAPS then
		finish(r, racer)
		return
	end
	racer.lap += 1
	racer.nextCp = 1
	player:SetAttribute("RaceLap", racer.lap)
	player:SetAttribute("RaceNext", 1)
	clientEvent:FireClient(player, "Lap", { lap = racer.lap, laps = RaceConfig.LAPS })
end

-- Falls (034): anyone inside the course's FallZone (below the floating course) is put back, never killed: a racer at
-- the last rune gate they passed (the pad if none yet), anyone else at PadSpot. Runs whether the race is on or not.
local function catchFalls()
	local world = workspace:FindFirstChild("World")
	local home = world and world:FindFirstChild(RaceConfig.WORLD)
	local geometry = home and home:FindFirstChild(RaceConfig.COURSE)
	local zone = geometry and geometry:FindFirstChild("FallZone")
	local spot = geometry and geometry:FindFirstChild("PadSpot")
	if not (zone and spot and zone:IsA("BasePart") and spot:IsA("BasePart")) then
		return
	end
	for _, player in Players:GetPlayers() do
		local root = livingRoot(player)
		if root and inBox(zone.CFrame, zone.Size / 2, root.Position) then
			local target = spot.CFrame
			local racer = race and race.racers[player]
			if racer then
				local passed = math.min(racer.nextCp - 1, checkpointCount)
				local gate = gates[passed]
				if passed >= 1 and gate then
					target = gate.cf * CFrame.new(0, -1, 0)
				end
			end
			(player.Character :: Model):PivotTo(target)
			root.AssemblyLinearVelocity = Vector3.zero
			if racer then
				racer.last = target.Position
			end
			RaceService.stats.pops += 1
			clientEvent:FireClient(player, "Pop", { racing = racer ~= nil })
		end
	end
end

-- Rounds ------------------------------------------------------------------------------------------------
local function setBlock(player: Player, text: string?)
	if player:GetAttribute("RaceBlock") ~= text then
		player:SetAttribute("RaceBlock", text)
	end
end

-- Eligible players on the pad (not already racing). Everyone on the pad who can't race gets the reason on
-- their RaceBlock attribute (cleared off the pad); RaceClient shows it on screen and above the pad.
local function eligibleOnPad(): { Player }
	local list = {}
	for _, player in Players:GetPlayers() do
		local block = nil
		if RaceService.onPad(player) and not (race and race.racers[player]) then
			local ok, message = RaceService.eligible(player)
			if ok then
				table.insert(list, player)
			else
				block = message
			end
		end
		setBlock(player, block)
	end
	return list
end

-- Freezing on the pad for the last COUNTDOWN seconds: walk speed and jump off, given back at GO (or as soon
-- as the player is no longer an eligible player on the pad: teleported, died, left, became ineligible).
type Frozen = { humanoid: Humanoid, speed: number, jumpPower: number, jumpHeight: number }
local frozen: { [Player]: Frozen } = {}

local function freeze(player: Player)
	if frozen[player] then
		return
	end
	local _, humanoid = livingRoot(player)
	if not humanoid then
		return
	end
	frozen[player] = { humanoid = humanoid, speed = humanoid.WalkSpeed, jumpPower = humanoid.JumpPower, jumpHeight = humanoid.JumpHeight }
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0
	player:SetAttribute("RaceFrozen", true)
end

local function unfreeze(player: Player)
	local f = frozen[player]
	if not f then
		return
	end
	frozen[player] = nil
	if f.humanoid.Parent then
		f.humanoid.WalkSpeed = f.speed
		f.humanoid.JumpPower = f.jumpPower
		f.humanoid.JumpHeight = f.jumpHeight
	end
	if player.Parent then
		player:SetAttribute("RaceFrozen", nil)
	end
end

local function unfreezeAll(except: { Player }?)
	local list = {}
	for player in frozen do
		if not (except and table.find(except, player)) then
			table.insert(list, player)
		end
	end
	for _, player in list do
		unfreeze(player)
	end
end

local function startRace(goAt: number, players: { Player })
	raceCount += 1
	local r: Race = {
		id = serverId .. "-" .. raceCount,
		goAt = goAt,
		endsAt = goAt + RaceConfig.TIME_LIMIT,
		started = 0,
		racers = {},
		finishers = {},
	}
	race = r
	unfreezeAll() -- GO: walking and jumping back before the race speed is set
	for _, player in players do
		join(r, player)
	end
	for _ in r.racers do
		r.started += 1
	end
	RaceService.stats.races += 1
	setState("Racing", { GoAt = goAt, EndsAt = r.endsAt, Racers = r.started, Ready = goAt + RaceConfig.INTERVAL, RaceId = r.id })
	for player in r.racers do
		clientEvent:FireClient(player, "Go", { endsAt = r.endsAt, laps = RaceConfig.LAPS, racers = r.started })
	end
	print(("[RaceService] race %s: GO with %d racer(s)"):format(r.id, r.started))
end

local function endRace(r: Race, reason: string)
	for _, racer in r.racers do
		local late = if RaceConfig.LAPS > 1 then ("Time's up! Finish all %d laps next time."):format(RaceConfig.LAPS) else "Time's up! Reach the finish arch next time."
		out(r, racer, if reason == "time" then late else "The race was stopped.")
	end
	race = nil
	RaceService.lastRace = { id = r.id, started = r.started, finishers = r.finishers, reason = reason }
	local rows = {}
	for i = 1, math.min(3, #r.finishers) do
		table.insert(rows, { name = r.finishers[i].name, place = i })
	end
	showPodium(rows)
	setState("Podium", { PodiumUntil = serverNow() + RaceConfig.PODIUM_SECONDS }, { "GoAt", "EndsAt", "Racers" })
	clientEvent:FireAllClients("End", { podium = rows, raceId = r.id })
	print(("[RaceService] race %s over (%s): %d finisher(s)"):format(r.id, reason, #r.finishers))
end

RaceService._test = {
	race = function()
		return race
	end,
	gates = gates,
	-- Studio only: what happens when a racer's Player leaves the game (PlayerRemoving) mid-race.
	drop = function(player: Player)
		local r = race
		if r and r.racers[player] then
			release(r, r.racers[player])
		end
	end,
	frozen = function(player: Player): boolean
		return frozen[player] ~= nil
	end,
	-- Studio only: the next race may start now (skips the 3-minute wait).
	readyNow = function()
		if course then
			course:SetAttribute("Ready", serverNow())
		end
	end,
}

local started = false
function RaceService.start()
	if started then
		return
	end
	started = true
	if not PhysicsService:IsCollisionGroupRegistered(RaceConfig.COLLISION_GROUP) then
		PhysicsService:RegisterCollisionGroup(RaceConfig.COLLISION_GROUP)
	end
	PhysicsService:CollisionGroupSetCollidable(RaceConfig.COLLISION_GROUP, RaceConfig.COLLISION_GROUP, false)
	if not PhysicsService:IsCollisionGroupRegistered(RaceConfig.WALL_GROUP) then
		PhysicsService:RegisterCollisionGroup(RaceConfig.WALL_GROUP)
	end
	Players.PlayerRemoving:Connect(function(player)
		frozen[player] = nil
	end)

	local lastState: { [Player]: number } = setmetatable({}, { __mode = "k" }) :: any
	actionEvent.OnServerEvent:Connect(function(player, action)
		-- "Leave" (032, the HUD's Leave race button): out of the race now, no reward; the walls stop applying to
		-- them (their collision group is put back) and the race goes on for the others. Only a current racer can
		-- leave, and only themselves.
		if action == "Leave" then
			local r = race
			local racer = r and r.racers[player]
			if r and racer then
				RaceService.stats.left += 1
				out(r, racer, "You left the race. Join the next one any time!")
			end
			return
		end
		-- Otherwise the only request: the current round, for a client that just joined or opened the HUD.
		local t = os.clock()
		if action == "State" and course and (not lastState[player] or t - lastState[player] > 1) then
			lastState[player] = t
			local r = race
			clientEvent:FireClient(player, "State", {
				racing = r ~= nil and r.racers[player] ~= nil,
				lap = player:GetAttribute("RaceLap"),
				endsAt = r and r.endsAt,
			})
		end
	end)
	if RunService:IsStudio() then -- Studio test hook: ServerStorage StudioRaceNow = true -> next race may start now
		ServerStorage:GetAttributeChangedSignal("StudioRaceNow"):Connect(function()
			if ServerStorage:GetAttribute("StudioRaceNow") == true then
				ServerStorage:SetAttribute("StudioRaceNow", nil)
				RaceService._test.readyNow()
			end
		end)
	end

	task.spawn(function()
		local running = false
		local last = os.clock()
		while true do
			local dt = os.clock() - last
			last = os.clock()
			local on = RaceService.enabled()
			if on and not running then
				running = buildCourse()
				if running then
					setState("Waiting", { Ready = serverNow() }) -- the first race is open right away
				else
					on = false
				end
			elseif not on and running then
				running = false
				if race then
					endRace(race, "stopped")
				end
				unfreezeAll()
				for _, player in Players:GetPlayers() do
					setBlock(player, nil)
				end
				if course then
					course:Destroy()
				end
				course, pad = nil, nil
				table.clear(nameTags)
			end
			ReplicatedStorage:SetAttribute(RaceConfig.PUBLISHED, if running then true else nil)
			catchFalls()
			local folder = course
			if running and folder then
				local now = serverNow()
				local state = folder:GetAttribute("State")
				local onPad = eligibleOnPad()
				if state == "Waiting" and now >= (folder:GetAttribute("Ready") or math.huge) then
					if #onPad > 0 then
						setState("Countdown", { GoAt = now + RaceConfig.JOIN_WINDOW })
						clientEvent:FireAllClients("Countdown", { goAt = now + RaceConfig.JOIN_WINDOW })
					end
				elseif state == "Countdown" then
					local goAt = folder:GetAttribute("GoAt") or 0
					if now >= goAt then
						if #onPad > 0 then
							startRace(goAt, onPad)
						else
							unfreezeAll()
							setState("Waiting", nil, { "GoAt" }) -- everyone stepped off: the next one on the pad starts it
						end
					else
						if goAt - now <= RaceConfig.COUNTDOWN then
							for _, player in onPad do
								freeze(player)
							end
						end
						unfreezeAll(onPad)
					end
				elseif state == "Racing" and race then
					local r = race :: Race
					for _, racer in r.racers do
						step(r, racer, dt)
					end
					if next(r.racers) == nil then
						endRace(r, "done")
					elseif now >= r.endsAt then
						endRace(r, "time")
					end
				elseif state == "Podium" and now >= (folder:GetAttribute("PodiumUntil") or 0) then
					showPodium(nil)
					setState("Waiting", nil, { "PodiumUntil" })
				end
			end
			task.wait(RaceConfig.TICK)
		end
	end)
end

return RaceService
