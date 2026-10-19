-- Studio location: ServerScriptService.GuardianService (ModuleScript)
-- GuardianService  (Hub 2b): each of our zones has its boss as a guardian (numbers and rules: GuardianConfig).
--   Knight's Keep (MainStreet) = Sir Malgrave, Sunken Kingdom = Aquaris, Ember Academy (BillionaireHills) = the Vault Wizard.
-- The guardian stands at Workspace.Zones.<zone>.GuardianPost (fallback: the ZoneBoundary's centre). It wakes when a
-- player carries a creature THEY caught in its zone (their own record, loc "carried", record.zone = this zone; a
-- stolen creature never counts), chases only that carrier and attacks with the Boss Heist's three telegraphed attacks
-- (BossChase: shared with HeistService, same warnings on the clients through BossWarnings). It never walks further
-- than LEASH studs outside its ZoneBoundary, and gives up when the carrier is GIVE_UP_MARGIN studs outside it, stops
-- carrying, dies or leaves; then it walks back to its post.
-- A hit = real Humanoid damage (ATTACKS[kind].damage; a ForceField blocks it; HIT_GRACE s between hits). A hit that
-- would take the carrier to 0: the carried creature goes back into the zone as a wanderer (the same creature: its
-- record leaves the player's data, ZoneSpawner.dropBack spawns it again), then the player is knocked out and
-- respawns at their base. Coins and every other creature/save field are untouched.
-- World: Workspace.Guardians (only while on) holds one model per zone, named the zone id; its attributes are what
-- the clients read: GPos (feet position), GYaw, GMode (Post|Wake|Chase|Attack|Return), GTarget (UserId), RootLift,
-- BossHeist (zone id for the boss entry) + the rig's VW_* clip attributes. GuardianClient moves and animates it.
-- Remote GuardianEvent (s -> c): Attack / Lock / Cancel (as the heist's), Wake, Hit, GiveUp, KO.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local LaunchFlag = require(ReplicatedStorage:WaitForChild("LaunchFlag"))
local BossHeist = require(ReplicatedStorage:WaitForChild("BossHeist"))
local GuardianConfig = require(ReplicatedStorage:WaitForChild("GuardianConfig"))
local BossChase = require(script.Parent:WaitForChild("BossChase"))
local CustomWorkerRigs = require(script.Parent:WaitForChild("CustomWorkerRigs"))
local NPCCarry = require(script.Parent:WaitForChild("NPCCarry"))
local PlotService = require(script.Parent:WaitForChild("PlotService"))
local WorkerInventory = require(script.Parent:WaitForChild("WorkerInventory"))
local ZoneSpawner = require(script.Parent:WaitForChild("ZoneSpawner"))

local GuardianService = {}

local TICK = 0.1
local FOLDER = "Guardians"
local flat = BossChase.flat
local livingRoot = BossChase.livingRoot

function GuardianService.enabled(): boolean
	return LaunchFlag(GuardianConfig.ENABLED, GuardianConfig.STUDIO_ATTRIBUTE)
end

local function serverNow(): number
	return workspace:GetServerTimeNow()
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
local clientEvent = getRemote("GuardianEvent")

type Guardian = {
	zone: string,
	entry: BossHeist.Boss,
	model: Model,
	boundary: BasePart,
	post: CFrame,
	pos: Vector3,
	yaw: number,
	mode: string,
	target: Player?,
	attack: BossChase.Attack?,
	cooldown: number,
	wakeAt: number,
	moving: boolean,
	moveAt: number,
	base: string,
}

local guardians: { [string]: Guardian } = {}
local live: Folder? = nil
local attackCount = 0
local rng = Random.new()
local airAt: { [Player]: number } = {}
local graceUntil: { [Player]: number } = {}
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

GuardianService.stats = { wakes = 0, attacks = 0, hits = 0, knockouts = 0, giveUps = 0, dropped = 0 }
GuardianService.attackLog = {} :: { any }

-- Zone geometry --------------------------------------------------------------------------------------------------
-- Flat distance from `p` to the ZoneBoundary box (0 inside).
local function outside(boundary: BasePart, p: Vector3): number
	local l = boundary.CFrame:PointToObjectSpace(p)
	local half = boundary.Size / 2
	local dx = math.max(math.abs(l.X) - half.X, 0)
	local dz = math.max(math.abs(l.Z) - half.Z, 0)
	return math.sqrt(dx * dx + dz * dz)
end

-- `p` pulled back inside the box grown by `margin` (flat).
local function leash(boundary: BasePart, p: Vector3, margin: number): Vector3
	local l = boundary.CFrame:PointToObjectSpace(p)
	local half = boundary.Size / 2
	local c = boundary.CFrame:PointToWorldSpace(Vector3.new(math.clamp(l.X, -half.X - margin, half.X + margin), l.Y, math.clamp(l.Z, -half.Z - margin, half.Z + margin)))
	return Vector3.new(c.X, p.Y, c.Z)
end

local function refreshRays()
	local exclude: { Instance } = {}
	if live then
		table.insert(exclude, live)
	end
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(exclude, p.Character)
		end
	end
	local claimed = workspace:FindFirstChild("ClaimedNPCs")
	if claimed then
		table.insert(exclude, claimed)
	end
	rayParams.FilterDescendantsInstances = exclude
end

-- The creature this player carries if they caught it in `zone` themselves (not a stolen one), else nil.
local function carriedFrom(player: Player, zone: string): (Model?, any)
	if player:GetAttribute("CarryingStolen") == true then
		return nil, nil
	end
	local npc = NPCCarry.getCarried(player)
	local uid = npc and npc:GetAttribute("WorkerUid")
	local record = if type(uid) == "string" then WorkerInventory.getRecord(player, uid) else nil
	if npc and record and record.loc == "carried" and record.zone == zone then
		return npc, record
	end
	return nil, nil
end

local function isTarget(g: Guardian, player: Player): boolean
	local root = livingRoot(player)
	return root ~= nil and player.Parent ~= nil and carriedFrom(player, g.zone) ~= nil and outside(g.boundary, root.Position) <= GuardianConfig.GIVE_UP_MARGIN
end

-- Moving ----------------------------------------------------------------------------------------------------------
local function face(g: Guardian, towards: Vector3)
	local d = flat(towards - g.pos)
	if d.Magnitude > 0.1 then
		g.yaw = math.atan2(-d.X, -d.Z)
	end
end

-- Walks toward `goal` (flat) at `speed`, stopping `stop` studs short, never past its leash; true when there.
local function walk(g: Guardian, goal: Vector3, dt: number, stop: number, speed: number): boolean
	local d = flat(goal - g.pos)
	local dist = d.Magnitude
	if dist <= stop + 0.05 then
		return true
	end
	face(g, goal)
	local step = math.min(speed * dt, dist - stop)
	local nextPos = leash(g.boundary, g.pos + d.Unit * step, GuardianConfig.LEASH)
	if (flat(nextPos - g.pos)).Magnitude < 0.01 then
		return true -- at its leash: can't get closer
	end
	g.moving = true
	local y = BossChase.groundAt(nextPos, g.pos.Y, rayParams)
	g.pos = Vector3.new(nextPos.X, y or g.pos.Y, nextPos.Z)
	return false
end

local function publish(g: Guardian, now: number)
	local m = g.model
	m:SetAttribute("GPos", g.pos)
	m:SetAttribute("GYaw", g.yaw)
	m:SetAttribute("GMode", g.mode)
	m:SetAttribute("GTarget", if g.target then g.target.UserId else nil)
	m:SetAttribute("GAt", now)
	if g.moving then
		g.moveAt = now
	end
	local want = if now - g.moveAt < 0.3 then "Walk" else "Idle"
	if want ~= g.base then
		g.base = want
		m:SetAttribute("VW_Base", want)
		m:SetAttribute("VW_BaseT0", now)
	end
end

-- Hits and knock-outs ---------------------------------------------------------------------------------------------
-- The carried creature runs back into its zone (a wanderer again), then the carrier is knocked out (respawns at base).
local function knockOut(g: Guardian, player: Player, humanoid: Humanoid)
	local npc, record = carriedFrom(player, g.zone)
	if npc and record then
		local workerId = record.id
		local model = NPCCarry.detach(player) -- ends the carry without the "back to your inventory" drop
		if model then
			model:Destroy()
		end
		WorkerInventory.take(player, record.uid)
		local template = CustomWorkerRigs.getTemplate(workerId)
		if template and ZoneSpawner.dropBack(g.zone, template, workerId) then
			GuardianService.stats.dropped += 1
		end
	end
	GuardianService.stats.knockouts += 1
	player:SetAttribute("GuardianKO", g.zone)
	clientEvent:FireAllClients("KO", { userId = player.UserId, zone = g.zone })
	humanoid.Health = 0
	print(("[GuardianService] %s knocked out %s (%s)"):format(g.zone, player.Name, if record then record.id else "no creature"))
end

local function hitPlayer(g: Guardian, player: Player, kind: string, now: number): boolean
	if (graceUntil[player] or 0) > now then
		return false
	end
	local root, humanoid = livingRoot(player)
	local character = player.Character
	if not (root and humanoid and character) or character:FindFirstChildOfClass("ForceField") then
		return false
	end
	graceUntil[player] = now + GuardianConfig.HIT_GRACE
	GuardianService.stats.hits += 1
	local damage = GuardianConfig.ATTACKS[kind].damage
	local ko = humanoid.Health - damage <= 0
	clientEvent:FireAllClients("Hit", { userId = player.UserId, zone = g.zone, damage = damage, kind = kind, ko = ko })
	if ko then
		knockOut(g, player, humanoid)
	else
		humanoid:TakeDamage(damage)
	end
	return true
end

-- Attacks (BossChase) ---------------------------------------------------------------------------------------------
local function startAttack(g: Guardian, kind: string, target: Player, targetRoot: BasePart, now: number)
	attackCount += 1
	local a, info, faceAt = BossChase.plan(kind, GuardianConfig.ATTACKS[kind] :: any, attackCount, g.pos, target, targetRoot, now, rayParams)
	face(g, faceAt)
	info.zone = g.zone
	a.log = { id = a.id, zone = g.zone, kind = kind, startAt = now, warnAt = a.warnAt, hitAt = a.hitAt, hits = {}, target = target.UserId }
	table.insert(GuardianService.attackLog, a.log)
	if #GuardianService.attackLog > 200 then
		table.remove(GuardianService.attackLog, 1)
	end
	GuardianService.stats.attacks += 1
	g.attack = a
	g.mode = "Attack"
	-- where this attack lands, for the boss's own hit effects (BossRigs Vfx): the effect sits on the warning shape the
	-- hit is tested against (presentation only; the searchlight's spot is set when it locks)
	if g.model then
		g.model:SetAttribute("VW_HitSpot", if kind == "Searchlight" then nil else a.centre)
		g.model:SetAttribute("VW_HitAcross", if kind == "Laser" then a.across else nil)
		g.model:SetAttribute("VW_HitLength", if kind == "Laser" then (GuardianConfig.ATTACKS[kind] :: any).length else nil)
	end
	BossChase.playClip(g.model, g.entry, kind, a.hitAt)
	clientEvent:FireAllClients("Attack", info)
end

local function hooks(g: Guardian, a: BossChase.Attack, now: number): BossChase.Hooks
	return {
		candidates = function()
			return if g.target then { g.target :: Player } else {}
		end,
		stillTarget = function(player)
			return if g.target == player and isTarget(g, player) then livingRoot(player) else nil
		end,
		lastAir = function(player)
			return airAt[player] or -math.huge
		end,
		face = function(p)
			face(g, p)
		end,
		lock = function(attack)
			attack.log.spot = attack.spot
			if g.model then
				g.model:SetAttribute("VW_HitSpot", attack.spot)
			end
			clientEvent:FireAllClients("Lock", { id = attack.id, spot = attack.spot, hitAt = attack.hitAt, zone = g.zone })
		end,
		cancel = function(attack)
			clientEvent:FireAllClients("Cancel", { id = attack.id, zone = g.zone })
		end,
		hit = function(player, detail)
			if hitPlayer(g, player, a.kind, now) then
				table.insert(a.log.hits, { userId = player.UserId, at = now, detail = detail })
				return true
			end
			return false
		end,
	}
end

local function cancelAttack(g: Guardian)
	local a = g.attack
	if a then
		g.attack = nil
		clientEvent:FireAllClients("Cancel", { id = a.id, zone = g.zone })
	end
end

-- One guardian, one tick ------------------------------------------------------------------------------------------
local function nearestTarget(g: Guardian): Player?
	local best, bestD = nil, math.huge
	for _, player in Players:GetPlayers() do
		if isTarget(g, player) then
			local root = livingRoot(player) :: BasePart
			local d = (flat(root.Position) - flat(g.pos)).Magnitude
			if d < bestD then
				best, bestD = player, d
			end
		end
	end
	return best
end

local function step(g: Guardian, dt: number, now: number)
	g.moving = false
	local target = g.target
	if target and not isTarget(g, target) then
		local gaveUp = target.Parent ~= nil and livingRoot(target) ~= nil
		g.target = nil
		cancelAttack(g)
		if gaveUp then
			GuardianService.stats.giveUps += 1
			clientEvent:FireAllClients("GiveUp", { userId = target.UserId, zone = g.zone })
		end
		target = nil
	end
	if not target then
		target = nearestTarget(g)
		if target then
			g.target = target
			g.wakeAt = now + GuardianConfig.WAKE_DELAY
			g.cooldown = math.max(g.cooldown, g.wakeAt)
			g.mode = "Wake"
			GuardianService.stats.wakes += 1
			BossChase.playClip(g.model, g.entry, "Basic", now + g.entry.attacks.Basic.impact) -- the wake-up flourish
			clientEvent:FireAllClients("Wake", { userId = target.UserId, zone = g.zone })
		end
	end
	local a = g.attack
	if a then
		BossChase.step(a, GuardianConfig.ATTACKS[a.kind] :: any, now, hooks(g, a, now), rayParams)
		if now >= a.endAt then
			g.attack = nil
			g.cooldown = now + GuardianConfig.ATTACK_GAP
			g.mode = if g.target then "Chase" else "Return"
		end
		return
	end
	if target then
		local root = livingRoot(target) :: BasePart
		if BossChase.airborne(target, rayParams) then
			airAt[target] = now
		end
		if now < g.wakeAt then
			face(g, root.Position)
			return
		end
		g.mode = "Chase"
		local distance = (flat(root.Position) - flat(g.pos)).Magnitude
		if now >= g.cooldown then
			local kind = BossChase.choose(distance, GuardianConfig.ATTACKS :: any, rng)
			if kind then
				startAttack(g, kind, target, root, now)
				return
			end
		end
		walk(g, root.Position, dt, GuardianConfig.STOP_SHORT, GuardianConfig.CHASE_SPEED)
	else
		local home = walk(g, g.post.Position, dt, 0.3, GuardianConfig.RETURN_SPEED)
		g.mode = if home then "Post" else "Return"
		if home then
			face(g, g.post.Position + g.post.LookVector * 10)
		end
	end
end

-- Build / teardown ------------------------------------------------------------------------------------------------
local function build(): boolean
	local zones = workspace:FindFirstChild("Zones")
	if not zones then
		return false
	end
	local folder = Instance.new("Folder")
	folder.Name = FOLDER
	live = folder
	refreshRays()
	for _, zone in GuardianConfig.ZONES do
		local zf = zones:FindFirstChild(zone)
		local boundary = zf and zf:FindFirstChild("ZoneBoundary")
		local entry = BossHeist.BOSSES[zone]
		if not (boundary and boundary:IsA("BasePart") and entry) then
			warn("[GuardianService] no ZoneBoundary or boss for", zone)
			continue
		end
		local model, lift = BossChase.buildModel(entry, GuardianConfig.BOSS_SCALE)
		if not model then
			warn("[GuardianService] boss model for", zone, "is not available")
			continue
		end
		local postPart = zf:FindFirstChild("GuardianPost")
		local post = if postPart and postPart:IsA("BasePart") then postPart.CFrame else boundary.CFrame
		local y = BossChase.groundAt(post.Position, post.Position.Y + 10, rayParams) or post.Position.Y
		local pos = Vector3.new(post.Position.X, y, post.Position.Z)
		model.Name = zone
		model:SetAttribute("BossHeist", zone)
		model:SetAttribute("RootLift", lift)
		model:SetAttribute("Guardian", true)
		model:PivotTo(CFrame.new(pos + Vector3.new(0, lift, 0)) * post.Rotation)
		model.Parent = folder
		local g: Guardian = {
			zone = zone,
			entry = entry,
			model = model,
			boundary = boundary,
			post = CFrame.new(pos) * post.Rotation,
			pos = pos,
			yaw = 0,
			mode = "Post",
			target = nil,
			attack = nil,
			cooldown = 0,
			wakeAt = 0,
			moving = false,
			moveAt = -math.huge,
			base = "",
		}
		face(g, pos + post.LookVector * 10)
		guardians[zone] = g
		publish(g, serverNow())
	end
	folder.Parent = workspace
	return next(guardians) ~= nil
end

local function teardown()
	for _, g in guardians do
		cancelAttack(g)
	end
	table.clear(guardians)
	if live then
		live:Destroy()
	end
	live = nil
end

-- Respawn at base after a guardian knock-out.
local function onCharacter(player: Player, character: Model)
	if player:GetAttribute("GuardianKO") == nil then
		return
	end
	player:SetAttribute("GuardianKO", nil)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	task.wait(0.2)
	local home = PlotService.homeCFrame(player)
	if root and home and character.Parent then
		character:PivotTo(home)
	end
end

GuardianService._test = {
	guardians = function()
		return guardians
	end,
	-- Studio only: start this attack on this guardian's current target now.
	attack = function(zone: string, kind: string): boolean
		local g = guardians[zone]
		local target = g and g.target
		local root = target and livingRoot(target)
		if not (g and target and root) or g.attack then
			return false
		end
		startAttack(g, kind, target, root, serverNow())
		return true
	end,
	place = function(zone: string, pos: Vector3)
		local g = guardians[zone]
		if g then
			g.pos = pos
		end
	end,
}

local started = false
function GuardianService.start()
	if started then
		return
	end
	started = true
	local function track(player: Player)
		player.CharacterAdded:Connect(function(character)
			onCharacter(player, character)
		end)
	end
	Players.PlayerAdded:Connect(track)
	for _, player in Players:GetPlayers() do
		track(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		airAt[player], graceUntil[player] = nil, nil
	end)
	task.spawn(function()
		local running = false
		local last = os.clock()
		local rayAt = 0
		while true do
			local dt = math.min(os.clock() - last, 0.5)
			last = os.clock()
			local on = GuardianService.enabled()
			if on and not running then
				running = build()
				if not running then
					teardown()
				end
			elseif not on and running then
				running = false
				teardown()
			end
			ReplicatedStorage:SetAttribute(GuardianConfig.PUBLISHED, if running then true else nil)
			if running then
				if os.clock() - rayAt > 1 then
					rayAt = os.clock()
					refreshRays()
				end
				local now = serverNow()
				for _, g in guardians do
					local ok, err = pcall(step, g, dt, now)
					if not ok then
						warn("[GuardianService]", g.zone, err)
					end
					publish(g, now)
				end
			end
			task.wait(TICK)
		end
	end)
	if RunService:IsStudio() then
		print("[GuardianService] started; switch:", GuardianService.enabled(), "(ServerStorage." .. GuardianConfig.STUDIO_ATTRIBUTE .. " overrides in Studio)")
	end
end

return GuardianService
