-- Studio location: ServerScriptService.BossChase (ModuleScript)
-- BossChase  (Hub 2b): the boss-chaser mechanics shared by the Boss Heist (HeistService) and the zone guardians
-- (GuardianService). Moved out of HeistService unchanged; each user keeps its own chaser state, its targets and
-- what a hit does (the heist pops a shield, a guardian deals damage).
--   buildModel  the big boss model (a BossRigs rig, or the creature's own model for Aquaris) at `scale`
--   playClip    starts an attack clip so its impact lands at a given server time
--   plan        the three telegraphed attacks: where the danger zone is and when it hits (+ the client info)
--   step        while an attack runs: searchlight tracking/lock, and who it hits (jumps clear the stomp wave)
--   choose      picks an attack the target is in range of
-- Attack kinds (numbers in HeistConfig.ATTACKS / GuardianConfig.ATTACKS):
--   Searchlight: a circle follows the target, locks (fixed spot, red) and zaps that spot `warning` s later.
--   Laser: a red line across the way ahead of the target; `warning` s later it sweeps along it.
--   Stomp: a ring shows the reach; `warning` s later a shockwave rolls out along the ground (jump over it).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BossHeist = require(ReplicatedStorage:WaitForChild("BossHeist"))

local BossChase = {}

-- Off the ground: feet above JUMP_FEET, or the Humanoid jumping / falling (the owner's client replicates it).
local JUMP_FEET = 1.2
BossChase.AIR_GRACE = 0.35 -- a jump counts this long after the server last saw it
-- The server sees each player ~0.1-0.2 s after they moved: the wave is judged where it was WAVE_LAG s ago, so a jump
-- timed right on the player's screen counts.
BossChase.WAVE_LAG = 0.15

export type Def = { warning: number, range: number, radius: number?, length: number?, width: number?, waveSpeed: number?, band: number? }
export type Attack = {
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
	fired: boolean,
	log: any,
}
export type Hooks = {
	candidates: () -> { Player }, -- who this attack can hit
	stillTarget: (Player) -> BasePart?, -- the searchlight's target, or nil when it got away (no lock, nothing happens)
	lastAir: (Player) -> number, -- last time this player was seen off the ground
	face: (Vector3) -> (),
	lock: (Attack) -> (), -- the searchlight locked: tell the clients
	cancel: (Attack) -> (),
	hit: (Player, string?) -> boolean, -- the attack hits this player (once per attack); true = it counted
}

function BossChase.flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end
local flat = BossChase.flat

function BossChase.livingRoot(player: Player): (BasePart?, Humanoid?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return root, humanoid
	end
	return nil, nil
end
local livingRoot = BossChase.livingRoot

function BossChase.groundAt(p: Vector3, fromY: number, params: RaycastParams): number?
	local result = workspace:Raycast(Vector3.new(p.X, fromY + 8, p.Z), Vector3.new(0, -30, 0), params)
	return result and result.Position.Y
end
local groundAt = BossChase.groundAt

function BossChase.feetHeight(player: Player, params: RaycastParams): number?
	local root, humanoid = livingRoot(player)
	if not (root and humanoid) then
		return nil
	end
	local result = workspace:Raycast(root.Position, Vector3.new(0, -40, 0), params)
	if not result then
		return math.huge
	end
	return root.Position.Y - root.Size.Y / 2 - humanoid.HipHeight - result.Position.Y
end

function BossChase.airborne(player: Player, params: RaycastParams): boolean
	local _, humanoid = livingRoot(player)
	if not humanoid then
		return false
	end
	local state = humanoid:GetState()
	if state == Enum.HumanoidStateType.Jumping or state == Enum.HumanoidStateType.Freefall then
		return true
	end
	local feet = BossChase.feetHeight(player, params)
	return feet ~= nil and feet > JUMP_FEET
end

-- Model ----------------------------------------------------------------------------------------------------------
local function lowestVisibleY(model: Model): number
	local low = math.huge
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 1 then
			local half = d.Size / 2
			for _, sx in { -1, 1 } do
				for _, sy in { -1, 1 } do
					for _, sz in { -1, 1 } do
						low = math.min(low, d.CFrame:PointToWorldSpace(Vector3.new(half.X * sx, half.Y * sy, half.Z * sz)).Y)
					end
				end
			end
		end
	end
	return low
end

-- The chaser is a big boss: `scale` x the collectible's size (the Secret collectible itself stays at normal creature size). Attribute BossScale tells the rig's client driver
-- and effects (BossRigs.Shared.Driver / FxKit) to scale clip translations and effects with the model. Presentation only: ranges, radii and hits stay in the config.
-- Returns the model (root anchored, PrimaryPart = the root) and its RootLift (root height above the feet), or nil when the boss isn't available.
function BossChase.buildModel(entry: BossHeist.Boss, scale: number): (Model?, number)
	local model: Model? = nil
	local lift = 0
	if entry.rig then
		local char = ServerStorage:FindFirstChild("BossRigs") and ServerStorage.BossRigs:FindFirstChild(entry.rig)
		local template = char and char:FindFirstChild("Template")
		if template and template:IsA("Model") and template.PrimaryPart then
			local rig = template:Clone()
			rig:SetAttribute("BossScale", scale)
			rig:ScaleTo(scale)
			lift = (require(rig.Runtime.Data :: ModuleScript) :: any).hrpHeight * scale
			model = rig
		end
	else -- the creature's own model (Aquaris): no Humanoid or scripts, the root stays put and the clients move it
		local creatures = ReplicatedStorage:FindFirstChild("CreatureModels")
		local source = creatures and creatures:FindFirstChild(entry.creature)
		if source and source:IsA("Model") then
			local clone = source:Clone()
			for _, d in clone:GetDescendants() do
				if d:IsA("Humanoid") or d:IsA("Script") or d:IsA("LocalScript") then
					d:Destroy()
				end
			end
			clone:ScaleTo(clone:GetScale() * scale)
			clone:SetAttribute("CreatureScale", (clone:GetAttribute("CreatureScale") or 1) * scale) -- (AquarisChaser / CreatureAnim read the scale from here)
			clone:SetAttribute("CreatureBuiltScale", clone:GetAttribute("CreatureScale")) -- (CreatureScaler would otherwise shrink it to scale 1)
			CollectionService:RemoveTag(clone, "Creature") -- (the client's AquarisChaser animates it, not CreatureClient: both would write the same welds)
			local cloneRoot = clone:FindFirstChild("HumanoidRootPart") :: BasePart
			cloneRoot.PivotOffset = CFrame.identity -- (the creature's pivot sits below the root: PivotTo must place the root itself)
			clone.PrimaryPart = cloneRoot
			lift = cloneRoot.Position.Y - lowestVisibleY(clone)
			model = clone
		end
	end
	if model then
		((model :: Model).PrimaryPart :: BasePart).Anchored = true
	end
	return model, lift
end

-- Plays one of the boss's attack clips so that its impact lands at `impactAt` (server time). The attributes are written shortly before the clip starts: the clients read
-- the start time and the rig's driver fades the pose in.
function BossChase.playClip(model: Model?, entry: BossHeist.Boss?, kind: string, impactAt: number)
	local attack = entry and (entry.attacks :: any)[kind]
	if not (attack and model) then
		return
	end
	local startAt = impactAt - attack.impact
	task.delay(math.max(0, startAt - workspace:GetServerTimeNow() - 0.1), function()
		if model.Parent then
			model:SetAttribute("VW_Clip", attack.clip)
			model:SetAttribute("VW_ClipT0", math.max(startAt, workspace:GetServerTimeNow()))
		end
	end)
end

-- Attacks --------------------------------------------------------------------------------------------------------
-- A random attack the target is in range of, or nil.
function BossChase.choose(distance: number, defs: { [string]: Def }, rng: Random): string?
	local options = {}
	for kind, def in defs do
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

-- A new attack by a boss standing at `from` on `target`. Returns the attack, the info every client gets (event "Attack") and the
-- point the boss should face.
function BossChase.plan(
	kind: string,
	def: Def,
	id: number,
	from: Vector3,
	target: Player,
	targetRoot: BasePart,
	now: number,
	params: RaycastParams
): (Attack, { [string]: any }, Vector3)
	local a: Attack = {
		id = id,
		kind = kind,
		target = target,
		startAt = now,
		warnAt = now,
		hitAt = now + def.warning,
		endAt = now + def.warning + 0.6,
		hitPlayers = {},
		fired = false,
		log = nil,
	}
	local info: { [string]: any } = { id = id, kind = kind, targetId = target.UserId, startAt = now, robot = from }
	local faceAt = targetRoot.Position
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
		local towards = flat(centre - from)
		local across = if towards.Magnitude > 0.1 then Vector3.new(-towards.Unit.Z, 0, towards.Unit.X) else Vector3.new(1, 0, 0)
		local y = groundAt(centre, targetRoot.Position.Y, params) or (targetRoot.Position.Y - 3)
		a.centre = Vector3.new(centre.X, y, centre.Z)
		a.across = across
		info.centre, info.across, info.length, info.width, info.hitAt = a.centre, across, def.length, def.width, a.hitAt
		faceAt = centre
	else -- Stomp
		local y = groundAt(from, from.Y, params) or from.Y
		a.centre = Vector3.new(from.X, y, from.Z)
		a.endAt = a.hitAt + BossChase.WAVE_LAG + ((def.radius :: number) + (def.band :: number)) / (def.waveSpeed :: number) + 0.2
		info.centre, info.hitAt, info.radius, info.waveSpeed, info.band = a.centre, a.hitAt, def.radius, def.waveSpeed, def.band
	end
	return a, info, faceAt
end

local function tryHit(a: Attack, hooks: Hooks, player: Player, detail: string?)
	if a.hitPlayers[player] then
		return
	end
	if hooks.hit(player, detail) then
		a.hitPlayers[player] = true
	end
end

-- One tick of a running attack.
function BossChase.step(a: Attack, def: Def, now: number, hooks: Hooks, params: RaycastParams)
	if a.kind == "Searchlight" then
		if not a.spot then
			local root = hooks.stillTarget(a.target)
			if not root then
				a.endAt = now -- the target got away / home: no lock, nothing happens
				hooks.cancel(a)
				return
			end
			hooks.face(root.Position)
			if now >= a.warnAt then
				local y = groundAt(root.Position, root.Position.Y, params) or (root.Position.Y - 3)
				a.spot = Vector3.new(root.Position.X, y, root.Position.Z)
				hooks.lock(a)
			end
			return
		end
		if now >= a.hitAt and not a.fired then
			a.fired = true
			local spot = a.spot :: Vector3
			for _, player in hooks.candidates() do
				local root = livingRoot(player)
				if root and (flat(root.Position) - flat(spot)).Magnitude <= (def.radius :: number) and math.abs(root.Position.Y - spot.Y) < 8 then
					tryHit(a, hooks, player)
				end
			end
		end
	elseif a.kind == "Laser" then
		if now >= a.hitAt and not a.fired then
			a.fired = true
			local centre, across = a.centre :: Vector3, a.across :: Vector3
			local along = Vector3.new(across.Z, 0, -across.X) -- (across the line's width)
			for _, player in hooks.candidates() do
				local root = livingRoot(player)
				if root then
					local rel = flat(root.Position - centre)
					if
						math.abs(rel:Dot(across)) <= (def.length :: number) / 2
						and math.abs(rel:Dot(along)) <= (def.width :: number) / 2
						and math.abs(root.Position.Y - centre.Y) < 8
					then
						tryHit(a, hooks, player)
					end
				end
			end
		end
	else -- Stomp: the wave front at radius waveSpeed * (now - hitAt); grounded players inside its band are hit
		if now >= a.hitAt + BossChase.WAVE_LAG then
			local r = (def.waveSpeed :: number) * (now - BossChase.WAVE_LAG - a.hitAt)
			if r <= (def.radius :: number) + (def.band :: number) then
				local centre = a.centre :: Vector3
				for _, player in hooks.candidates() do
					local root, humanoid = livingRoot(player)
					if root and math.abs(root.Position.Y - centre.Y) < 8 then
						local d = (flat(root.Position) - flat(centre)).Magnitude
						-- (lag-forgiving: a jump the server saw within AIR_GRACE s clears the wave)
						local lastAir = hooks.lastAir(player)
						if math.abs(d - r) <= (def.band :: number) and not BossChase.airborne(player, params) and now - lastAir > BossChase.AIR_GRACE then
							tryHit(
								a,
								hooks,
								player,
								("d %.1f r %.1f feet %.2f state %s lastAir %.2f s ago, %.2f s after hitAt"):format(
									d,
									r,
									BossChase.feetHeight(player, params) or -1,
									if humanoid then humanoid:GetState().Name else "?",
									now - lastAir,
									now - a.hitAt
								)
							)
						end
					end
				end
			end
		end
	end
end

return BossChase
