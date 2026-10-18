-- Studio location: ReplicatedStorage.BossWarnings (ModuleScript)
-- BossWarnings  (Hub 2b, client only): the in-world warnings of a boss chaser's attacks, shared by the Boss Heist
-- (HeistClient) and the zone guardians (GuardianClient). Moved out of HeistClient unchanged.
--   Searchlight: a yellow circle follows the target, turns red when it locks, fills up, a beam from the boss's lens.
--   Laser: a red strip on the ground fills up, then a red wall sweeps along it.
--   Stomp: a red area + ring shows the reach, then a white wave rolls out (jump it).
-- Each user makes its own set: BossWarnings.new(fxFolder, lens, exclude?) where lens(info) is where the searchlight
-- beam starts (nil = no beam) and exclude() lists models the ground ray ignores (the boss). start(info) on the server's "Attack", lock(id, spot) on "Lock", finish(id) on "Cancel",
-- step(t) every frame. `aim` is where the searchlight looks right now (the old robot turns its lamp to it).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FxKit = require(ReplicatedStorage:WaitForChild("FxKit"))

local RED = Color3.fromRGB(255, 70, 90)
local YELLOW = Color3.fromRGB(255, 225, 90)
local SEGMENTS = 28

type Warning = { kind: string, info: any, parts: { BasePart }, spot: Vector3?, done: boolean }
export type Set = {
	folder: Instance,
	lens: (info: any) -> Vector3?,
	exclude: (() -> { Instance })?,
	warnings: { [number]: Warning },
	aim: Vector3?,
	start: (self: Set, info: any) -> (),
	lock: (self: Set, id: number, spot: Vector3) -> (),
	finish: (self: Set, id: number) -> (),
	step: (self: Set, t: number) -> (),
	clear: (self: Set) -> (),
}

local BossWarnings = {}
BossWarnings.__index = BossWarnings

function BossWarnings.new(folder: Instance, lens: (info: any) -> Vector3?, exclude: (() -> { Instance })?): Set
	return setmetatable({ folder = folder, lens = lens, exclude = exclude, warnings = {}, aim = nil }, BossWarnings) :: any
end

local function fxPart(self: Set, props: { [string]: any }): BasePart
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	for k, v in props do
		(p :: any)[k] = v
	end
	p.Parent = self.folder
	return p
end

local function ringParts(self: Set, colour: Color3): { BasePart }
	local list = {}
	for i = 1, SEGMENTS do
		list[i] = fxPart(self, { Name = "Ring" .. i, Size = Vector3.new(0.5, 0.35, 1), Color = colour, Transparency = 0.15 })
	end
	return list
end

local function placeRing(list: { BasePart }, centre: Vector3, radius: number, from: number?)
	local seg = 2 * math.pi * radius / SEGMENTS
	for i = from or 1, (from or 1) + SEGMENTS - 1 do
		local p = list[i]
		local a = (i - (from or 1)) / SEGMENTS * 2 * math.pi
		local pos = centre + Vector3.new(math.cos(a) * radius, 0.25, math.sin(a) * radius)
		p.Size = Vector3.new(0.6, 0.35, math.max(0.4, seg * 1.05))
		p.CFrame = CFrame.lookAt(pos, pos + Vector3.new(-math.sin(a), 0, math.cos(a)))
	end
end

local function disc(self: Set, colour: Color3, radius: number, transparency: number): BasePart
	return fxPart(self, { Name = "Disc", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.12, radius * 2, radius * 2), Color = colour, Transparency = transparency })
end

local function flatDisc(p: BasePart, centre: Vector3, radius: number, lift: number)
	p.Size = Vector3.new(0.12, radius * 2, radius * 2)
	p.CFrame = CFrame.new(centre + Vector3.new(0, lift, 0)) * CFrame.Angles(0, 0, math.rad(90))
end

local function targetRoot(userId: number): BasePart?
	local target = Players:GetPlayerByUserId(userId)
	local character = target and target.Character
	local r = character and character:FindFirstChild("HumanoidRootPart")
	return if r and r:IsA("BasePart") then r else nil
end

local function groundBelow(self: Set, pos: Vector3): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = { self.folder }
	local extra = self.exclude
	if extra then
		for _, i in extra() do
			table.insert(exclude, i)
		end
	end
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(exclude, p.Character)
		end
	end
	params.FilterDescendantsInstances = exclude
	local r = workspace:Raycast(pos, Vector3.new(0, -20, 0), params)
	return if r then r.Position else pos - Vector3.new(0, 3, 0)
end

function BossWarnings.start(self: Set, info: any)
	local w: Warning = { kind = info.kind, info = info, parts = {}, spot = nil, done = false }
	if info.kind == "Searchlight" then
		local fill = disc(self, YELLOW, 0.1, 0.35)
		local area = disc(self, YELLOW, info.radius, 0.6)
		local beam = fxPart(self, { Name = "Beam", Size = Vector3.new(2.4, 2.4, 1), Color = YELLOW, Transparency = 0.7 })
		w.parts = { area, fill, beam }
	elseif info.kind == "Laser" then
		local strip = fxPart(self, { Name = "Strip", Size = Vector3.new(info.length, 0.2, info.width), Color = RED, Transparency = 0.45 })
		local fill = fxPart(self, { Name = "Fill", Size = Vector3.new(0.1, 0.25, info.width * 0.6), Color = Color3.new(1, 1, 1), Transparency = 0.2 })
		local wall = fxPart(self, { Name = "Laser", Size = Vector3.new(1.2, 10, info.width), Color = RED, Transparency = 1 })
		local cf = CFrame.lookAt(info.centre, info.centre + Vector3.new(info.across.Z, 0, -info.across.X))
		strip.CFrame = cf * CFrame.new(0, 0.12, 0) -- (local X = along the line, Z = its width)
		w.parts = { strip, fill, wall }
		w.spot = info.centre
	else -- Stomp
		local area = disc(self, RED, info.radius, 0.82)
		flatDisc(area, info.centre, info.radius, 0.08)
		local ring = ringParts(self, RED)
		placeRing(ring, info.centre, info.radius)
		local wave = ringParts(self, Color3.new(1, 1, 1))
		for _, p in wave do
			p.Transparency = 1
		end
		w.parts = { area }
		for _, p in ring do
			table.insert(w.parts, p)
		end
		for _, p in wave do
			table.insert(w.parts, p)
		end
		w.spot = info.centre
	end
	self.warnings[info.id] = w
	FxKit.sound("deny")
end

function BossWarnings.lock(self: Set, id: number, spot: Vector3)
	local w = self.warnings[id]
	if w then
		w.spot = spot
	end
end

function BossWarnings.finish(self: Set, id: number)
	local w = self.warnings[id]
	if w then
		self.warnings[id] = nil
		for _, p in w.parts do
			p:Destroy()
		end
		if w.kind == "Searchlight" then
			self.aim = nil
		end
	end
end

function BossWarnings.clear(self: Set)
	for id in self.warnings do
		BossWarnings.finish(self, id)
	end
	self.aim = nil
end

function BossWarnings.step(self: Set, t: number)
	for id, w in self.warnings do
		local info = w.info
		if w.kind == "Searchlight" then
			local area, fill, beam = w.parts[1], w.parts[2], w.parts[3]
			local centre = w.spot
			if not centre then
				local r = targetRoot(info.targetId)
				centre = if r then groundBelow(self, r.Position) else nil
			end
			if centre then
				local locked = w.spot ~= nil
				local colour = if locked then RED else YELLOW
				area.Color, fill.Color, beam.Color = colour, colour, colour
				flatDisc(area, centre, info.radius, 0.1)
				local k = if locked then math.clamp((t - info.lockAt) / (info.hitAt - info.lockAt), 0, 1) else 0
				flatDisc(fill, centre, math.max(0.1, info.radius * k), 0.14)
				area.Transparency = if locked then 0.45 + 0.2 * math.sin(t * 18) else 0.6
				self.aim = centre
				local lens = self.lens(info)
				if lens then
					local len = (centre - lens).Magnitude
					beam.Size = Vector3.new(if locked then 1.6 else 2.4, if locked then 1.6 else 2.4, len)
					beam.CFrame = CFrame.lookAt((lens + centre) / 2, centre)
				end
			end
			if t >= info.hitAt + 0.35 then
				if centre and not w.done then
					w.done = true
					FxKit.burst(centre + Vector3.new(0, 1, 0), "glow", RED, if FxKit.low() then 6 else 14)
				end
				BossWarnings.finish(self, id)
			end
		elseif w.kind == "Laser" then
			local strip, fill, wall = w.parts[1], w.parts[2], w.parts[3]
			local k = math.clamp((t - info.startAt) / (info.hitAt - info.startAt), 0, 1)
			local cf = strip.CFrame
			fill.Size = Vector3.new(math.max(0.1, info.length * k), 0.26, info.width * 0.6)
			fill.CFrame = cf * CFrame.new(-info.length / 2 + info.length * k / 2, 0.02, 0)
			strip.Transparency = 0.35 + 0.2 * math.sin(t * 16)
			if t >= info.hitAt then
				local s = math.clamp((t - info.hitAt) / 0.45, 0, 1)
				wall.Transparency = 0.25
				wall.CFrame = cf * CFrame.new(-info.length / 2 + info.length * s, 5, 0)
				if not w.done then
					w.done = true
					FxKit.sound("steal")
				end
				if s >= 1 then
					BossWarnings.finish(self, id)
				end
			end
		else -- Stomp
			local wave = {}
			for i = 2 + SEGMENTS, 1 + 2 * SEGMENTS do
				table.insert(wave, w.parts[i])
			end
			if t >= info.hitAt then
				if not w.done then
					w.done = true
					FxKit.burst(info.centre + Vector3.new(0, 1, 0), "puff", Color3.new(1, 1, 1), if FxKit.low() then 6 else 16)
					local cam = workspace.CurrentCamera
					if cam and (cam.CFrame.Position - info.centre).Magnitude < 60 and not FxKit.low() then
						FxKit.shake(0.5, 0.35)
					end
				end
				local r = info.waveSpeed * (t - info.hitAt)
				for _, p in wave do
					p.Transparency = 0.1
					p.Color = Color3.new(1, 1, 1)
				end
				placeRing(wave, info.centre, math.max(0.5, r))
				if r > info.radius + info.band then
					BossWarnings.finish(self, id)
				end
			end
		end
	end
end

return BossWarnings
