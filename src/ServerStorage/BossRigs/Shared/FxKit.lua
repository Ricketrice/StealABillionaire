-- Studio location: ServerStorage.BossRigs.Shared.FxKit (ModuleScript)
-- FxKit: shared helpers for the boss rigs' Roblox-native effects (emitters, rings, bursts, timed one-shots, registered temporaries, cleanup).
-- A character's Vfx module makes its class with setmetatable({}, { __index = FxKit.Base }), calls FxKit.init(self, model, data, assets, opts, colors) in new(), and defines
-- one method per clip named _clip_<ClipName>(self, token, elapsed) plus an optional step(now, dt) and onCleanup(). Cosmetic only. Every one-shot object is registered in self.temps and
-- destroyed by Debris; cleanup() removes whatever is left.

local Debris = game:GetService("Debris")
local UserInputService = game:GetService("UserInputService")

local FxKit = {}

FxKit.SPARK = "rbxasset://textures/particles/sparkles_main.dds"
FxKit.WHITE = Color3.fromRGB(255, 255, 255)
FxKit.PREFIX = "VWFX_"
local PREFIX = FxKit.PREFIX
local SPARK = FxKit.SPARK

function FxKit.ns(keys: { { number } }): NumberSequence
	local k = {}
	for _, p in keys do
		table.insert(k, NumberSequenceKeypoint.new(p[1], p[2], p[3] or 0))
	end
	return NumberSequence.new(k)
end

function FxKit.cs(keys: { { any } }): ColorSequence
	local k = {}
	for _, p in keys do
		table.insert(k, ColorSequenceKeypoint.new(p[1], p[2]))
	end
	return ColorSequence.new(k)
end
local ns, cs = FxKit.ns, FxKit.cs

function FxKit.newEmitter(parent: Instance, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = PREFIX .. (props.name or "Emitter")
	e.Texture = SPARK
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Rate = 0
	e.Lifetime = NumberRange.new(1)
	e.Speed = NumberRange.new(0)
	e.Size = NumberSequence.new(0.4)
	e.Transparency = ns({ { 0, 1 }, { 0.15, 0.2 }, { 1, 1 } })
	e.ZOffset = 0
	e.Enabled = false
	for k, v in props do
		if k ~= "name" then
			(e :: any)[k] = v
		end
	end
	e.Parent = parent
	return e
end
local newEmitter = FxKit.newEmitter

-- Time the authored FX node is "on": first key before its scale rises above 2%, and the key after it falls back.
function FxKit.ramp(fx: any, clip: string): (number, number, { { number } })
	local sc = fx.clips[clip].scale
	local start, stop
	for i, k in sc do
		if k[2] > 0.02 and not start then
			start = if i > 1 then sc[i - 1][1] else k[1]
		end
		if start and k[2] <= 0.02 and not stop then
			stop = k[1]
		end
	end
	return start or 0, stop or sc[#sc][1], sc
end

function FxKit.scaleAt(sc: { { number } }, t: number): number
	if t <= sc[1][1] then
		return sc[1][2]
	end
	for i = 1, #sc - 1 do
		local a, b = sc[i], sc[i + 1]
		if t >= a[1] and t <= b[1] then
			return a[2] + (b[2] - a[2]) * (t - a[1]) / (b[1] - a[1])
		end
	end
	return sc[#sc][2]
end

local Base = {}
Base.__index = Base
FxKit.Base = Base

-- colors = { main, deep, accent } (accent = the second colour, e.g. gold)
function FxKit.init(self: any, model: Model, data: any, assets: { [string]: string }?, opts: { lowFx: boolean? }?, colors: { [string]: Color3 })
	self.model = model
	self.data = data
	self.assets = assets or {}
	self.col = colors
	self.low = if opts and opts.lowFx ~= nil then opts.lowFx else UserInputService.TouchEnabled
	self.k = if self.low then 0.5 else 1
	self.hrp = model:WaitForChild("HumanoidRootPart") :: BasePart
	self.token = 0
	self.updaters = {} :: { [any]: (number, number) -> boolean }
	self.temps = {} :: { [Instance]: boolean }
	self.folder = Instance.new("Folder")
	self.folder.Name = PREFIX .. "Persistent"
	self.folder.Parent = model
	local function tex(name: string, fallback: string): string
		local v = self.assets[name]
		return if v and v ~= "" then v else fallback
	end
	self.ringTex = tex("Ring", SPARK)
	self.sigilTex = tex("Sigil", self.ringTex)
	self.coinTex = tex("Coin", SPARK)
	self.tex = tex
	-- ground helper (invisible, follows the root): emitter shapes take their size from the part
	local ground = Instance.new("Part")
	ground.Name = PREFIX .. "Ground"
	ground.Size = Vector3.new(4.6, 0.2, 4.6)
	ground.Transparency = 1
	ground.Anchored, ground.CanCollide, ground.CanQuery, ground.CanTouch, ground.CastShadow = true, false, false, false, false
	ground.Parent = self.folder
	self.ground = ground
	self.groundOffset = CFrame.new(0, -data.hrpHeight + 0.05, 0)
	ground.CFrame = self.hrp.CFrame * self.groundOffset
end

function Base:_temp(inst: Instance, life: number)
	self.temps[inst] = true
	inst.Destroying:Once(function()
		self.temps[inst] = nil
	end)
	Debris:AddItem(inst, life)
end

-- A temporary invisible anchor at a world position (for bursts). Returns part, attachment.
function Base:_anchor(cf: CFrame, size: Vector3?, life: number): (Part, Attachment)
	local p = Instance.new("Part")
	p.Name = PREFIX .. "Anchor"
	p.Size = size or Vector3.new(0.2, 0.2, 0.2)
	p.Transparency = 1
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.CFrame = cf
	p.Parent = self.folder
	local a = Instance.new("Attachment")
	a.Parent = p
	self:_temp(p, life)
	return p, a
end

-- One expanding ring sprite (flat on the ground by default, or facing the camera).
function Base:_ring(cf: CFrame, d0: number, d1: number, life: number, color: Color3?, flat: boolean?, texture: string?)
	local p = self:_anchor(cf, nil, life + 0.6)
	local c = color or self.col.main
	newEmitter(p, {
		name = "Ring",
		Texture = texture or self.ringTex,
		Lifetime = NumberRange.new(life),
		Speed = NumberRange.new(0.01),
		EmissionDirection = Enum.NormalId.Top,
		Orientation = if flat == false then Enum.ParticleOrientation.FacingCamera else Enum.ParticleOrientation.VelocityPerpendicular,
		Size = ns({ { 0, d0 }, { 1, d1 } }),
		Transparency = ns({ { 0, 0.15 }, { 0.6, 0.4 }, { 1, 1 } }),
		Color = cs({ { 0, FxKit.WHITE }, { 0.3, c }, { 1, color or self.col.deep } }),
	}):Emit(1)
end

function Base:_burst(cf: CFrame, count: number, props: { [string]: any })
	local p = self:_anchor(cf, nil, 3)
	local e = newEmitter(p, props)
	e:Emit(math.max(1, math.floor(count * self.k)))
end

function Base:_at(token: number, delay: number, fn: () -> ())
	if delay <= 0 then
		fn()
		return
	end
	task.delay(delay, function()
		if token == self.token and self.model.Parent then
			fn()
		end
	end)
end

function Base:groundCF(rel: { number }?): CFrame
	local r = rel or { 0, -self.data.hrpHeight + 0.06, 0 }
	return self.hrp.CFrame * CFrame.new(r[1], r[2], r[3])
end

-- the clip started `el` seconds ago (server time)
function Base:onClip(clip: string, el: number)
	self.token += 1
	local fn = (self :: any)["_clip_" .. clip]
	if fn then
		fn(self, self.token, el)
	end
end

-- follow the root every frame, then the character's own step, then run active one-shot updaters
function Base:baseStep(now: number, dt: number)
	self.ground.CFrame = self.hrp.CFrame * self.groundOffset
	for key, fn in self.updaters do
		if not fn(now, dt) then
			self.updaters[key] = nil
		end
	end
end

function Base:stats()
	local enabled, live, temps = 0, 0, 0
	for _, d in self.model:GetDescendants() do
		if d:IsA("ParticleEmitter") then
			live += 1
			if d.Enabled then
				enabled += 1
			end
		end
	end
	for _ in self.temps do
		temps += 1
	end
	return { enabledEmitters = enabled, emitters = live, temps = temps, low = self.low }
end

-- Remove every one-shot object right now (the persistent aura stays).
function Base:cleanup()
	self.token += 1
	table.clear(self.updaters)
	for inst in self.temps do
		inst:Destroy()
	end
	if (self :: any).onCleanup then
		(self :: any):onCleanup()
	end
end

function Base:destroy()
	self:cleanup()
	self.folder:Destroy()
end

return FxKit
