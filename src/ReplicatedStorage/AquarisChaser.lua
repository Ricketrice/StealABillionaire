-- Studio location: ReplicatedStorage.AquarisChaser (ModuleScript)
-- AquarisChaser  (036 boss pass, step 3): client-side animation of Aquaris as the Boss Heist chaser. Runs the idle (CreatureAnim, as for any creature) and lays the clips of
-- AquarisAttacks on top: the server writes VW_Base ("Idle" | "Walk") + VW_BaseT0 and VW_Clip + VW_ClipT0 on the chaser model (the same attributes the rigged bosses use), this module
-- reads them. Local only: it moves the welds of this client's copy; nothing replicates.
--   local chaser = AquarisChaser.new(model)
--   local offset = chaser:step(serverNow, base)   -- every frame; `base` = where the root stands; returns the extra root CFrame (rearing, dashing) to apply: root.CFrame = base * offset

local Players = game:GetService("Players")

local AquarisAttacks = require(script.Parent:WaitForChild("AquarisAttacks"))
local CreatureAnim = require(script.Parent:WaitForChild("CreatureAnim"))
local FxKit = require(script.Parent:WaitForChild("FxKit"))

local AquarisChaser = {}
AquarisChaser.__index = AquarisChaser

local WATER = Color3.fromRGB(150, 230, 255)
local BLEND = 0.2 -- seconds the walk fades out / back in around a one-shot clip
local ZERO = { 0, 0, 0, 0, 0, 0 }

local function pieceOf(part: BasePart): string
	return string.match(part.Name, "^([^_]+)_") or part.Name
end

local function smooth(u: number): number
	u = math.clamp(u, 0, 1)
	return u * u * (3 - 2 * u)
end

function AquarisChaser.new(model: Model)
	local self = setmetatable({}, AquarisChaser)
	self.model = model
	self.count = -1
	self.nextCheck = 0
	self.clip = nil :: string?
	self.clipT0 = 0
	self.fired = {} :: { [string]: number } -- fx key -> how many times it has fired for the current clip
	self.items = {} :: { [string]: { CreatureAnim.Item } }
	self.pivot = {} :: { [string]: CFrame }
	return self
end

-- (Re)collects the animated parts; the model streams in piece by piece, so this runs again whenever the part count changes.
function AquarisChaser:_bind()
	local model = self.model
	self.state = CreatureAnim.bind(model)
	table.clear(self.items)
	table.clear(self.pivot)
	for _, it in self.state.items do
		local piece = pieceOf(it.part)
		self.items[piece] = self.items[piece] or {}
		table.insert(self.items[piece], it)
		if it.kind == "swing" and not self.pivot[piece] then
			self.pivot[piece] = it.pivot
		end
	end
	local low = Players.LocalPlayer:GetAttribute("LowEffects") == true
	CreatureAnim.setAura(self.state, not low, if low then nil else "World")
	CreatureAnim.setFx(self.state, if low then nil else "World")
end

local function partNamed(model: Model, piece: string): BasePart?
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and string.match(d.Name, "^" .. piece .. "_") then
			return d
		end
	end
	return nil
end

function AquarisChaser:_fire(entry: any, k: number, base: CFrame)
	local model = self.model
	local lift = model:GetAttribute("RootLift") or 0
	local ground = base.Position - Vector3.new(0, lift, 0)
	local forward = base.LookVector
	local kind = entry.kind
	if kind == "tail" then
		local tip = partNamed(model, "TailC")
		FxKit.burst(if tip then tip.Position else ground + Vector3.new(0, 3, 0), "puff", WATER, 18)
	elseif kind == "stream" then
		local head = partNamed(model, "Head")
		local from = if head then head.Position else base.Position
		FxKit.burst(from + forward * (4 + 4 * k) - Vector3.new(0, 1 + k * 0.3, 0), "puff", WATER, 12)
	elseif kind == "trail" then
		FxKit.burst(ground + Vector3.new(0, 1.5, 0), "puff", WATER, 10)
	elseif kind == "splash" then
		FxKit.burst(ground + Vector3.new(0, 1.5, 0), "puff", WATER, 24)
		FxKit.burst(ground + Vector3.new(0, 2, 0), "glow", WATER, 10)
	elseif kind == "ring" then
		for i = 0, 11 do
			local a = i / 12 * 2 * math.pi
			FxKit.burst(ground + Vector3.new(math.cos(a) * 7, 0.6, math.sin(a) * 7), "puff", WATER, 8)
		end
		FxKit.burst(ground + Vector3.new(0, 1, 0), "glow", WATER, 14)
		local cam = workspace.CurrentCamera
		if cam and (cam.CFrame.Position - ground).Magnitude < 60 and not FxKit.low() then
			FxKit.shake(0.5, 0.35)
		end
	end
end

-- Adds a joint pose (scaled by w) into the accumulated pose table.
local function addPose(into: { [string]: { number } }, pose: { [string]: { number } }, w: number)
	for piece, p in pose do
		local acc = into[piece] or { 0, 0, 0, 0, 0, 0 }
		for i = 1, 6 do
			acc[i] += p[i] * w
		end
		into[piece] = acc
	end
end

function AquarisChaser:step(now: number, base: CFrame): CFrame
	local model = self.model
	-- re-collect the parts when the model has streamed in more (checked twice a second)
	if os.clock() >= self.nextCheck then
		self.nextCheck = os.clock() + 0.5
		local n = 0
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				n += 1
			end
		end
		if n ~= self.count then
			self.count = n
			self:_bind()
		end
	end
	local state = self.state
	if not state then
		return CFrame.identity
	end
	local s = state.scale
	CreatureAnim.step(state, os.clock()) -- the idle, as for any creature

	-- which clips: the looping base (Walk) and a one-shot started by the server
	local baseName, baseT0 = model:GetAttribute("VW_Base"), model:GetAttribute("VW_BaseT0")
	local clipName, clipT0 = model:GetAttribute("VW_Clip"), model:GetAttribute("VW_ClipT0")
	local pose: { [string]: { number } } = {}
	local shot: string? = nil
	local el = 0
	if typeof(clipName) == "string" and typeof(clipT0) == "number" then
		local c = AquarisAttacks.CLIPS[clipName]
		el = now - clipT0
		if c and el >= 0 and el <= c.length then
			shot = clipName
		end
	end
	if shot ~= self.clip or (shot and clipT0 ~= self.clipT0) then
		self.clip, self.clipT0 = shot, clipT0 :: number
		table.clear(self.fired)
	end
	local baseWeight = 1
	if shot then
		local c = AquarisAttacks.CLIPS[shot]
		baseWeight = 1 - math.min(smooth(el / BLEND), smooth((c.length - el) / BLEND))
		local p = AquarisAttacks.sample(shot, el)
		if p then
			addPose(pose, p, 1)
		end
		-- fx on the clip's cue (each repeats `count` times, `every` seconds apart)
		for i, entry in c.fx do
			local key = tostring(i)
			local done = self.fired[key] or 0
			local total = entry.count or 1
			while done < total and el >= entry.at + done * (entry.every or 0) do
				self:_fire(entry, done + 1, base)
				done += 1
			end
			self.fired[key] = done
		end
	end
	if baseName == "Walk" and typeof(baseT0) == "number" and baseWeight > 0 then
		local p = AquarisAttacks.sample("Walk", now - baseT0)
		if p then
			addPose(pose, p, baseWeight)
		end
	end

	-- compose each piece: its parent's pose first, then its own, each about its own pivot (the idle's weld.C0 is already set; the pose is laid on top of it)
	local total: { [string]: CFrame } = {}
	local function of(piece: string): CFrame
		local cached = total[piece]
		if cached then
			return cached
		end
		local parent = AquarisAttacks.PARENT[piece]
		local mine = CFrame.identity
		local p = pose[piece]
		local pv = self.pivot[piece]
		if p and pv then
			local joint = CFrame.Angles(math.rad(p[1]), math.rad(p[2]), math.rad(p[3])) * CFrame.new(p[4] * s, p[5] * s, p[6] * s)
			mine = pv * joint * pv:Inverse()
		end
		local result = if parent then of(parent) * mine else mine
		total[piece] = result
		return result
	end
	for piece, list in self.items do
		if pose[piece] or AquarisAttacks.PARENT[piece] then
			local a = of(piece)
			for _, it in list do
				it.weld.C0 = a * it.weld.C0
			end
		end
	end

	local r = pose.Root or ZERO
	return CFrame.new(r[4] * s, r[5] * s, r[6] * s) * CFrame.Angles(math.rad(r[1]), math.rad(r[2]), math.rad(r[3]))
end

return AquarisChaser
