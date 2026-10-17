-- Studio location: ServerStorage.VaultWizardTest.RuntimeSrc.Vfx (ModuleScript)
-- Vfx: Roblox-native replacements for the Vault wizard's authored effect meshes (14 meshes / 24,140 triangles in the GLB).
-- Cosmetic only (no damage, economy or rewards). Runs on every client; timings and sizes come from the converted FX tracks in VaultData (ramps of the authored FX nodes).
-- Persistent (always on): idle aura sparks, spike streaks, spinning rune circle, 5 orbiting coins.
-- One-shot: Takeover Beam, Vault Lock, Market Crash, Bankrupt Nova, and the Repossess shockwave. Every one-shot object is registered and destroyed by Debris; cleanup() removes the rest.

local Debris = game:GetService("Debris")
local UserInputService = game:GetService("UserInputService")

local Vfx = {}
Vfx.__index = Vfx

local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local LAV = Color3.fromRGB(176, 148, 255)
local LAV_DEEP = Color3.fromRGB(120, 70, 255)
local GOLD = Color3.fromRGB(240, 190, 80)
local WHITE = Color3.fromRGB(255, 255, 255)
local FX_PREFIX = "VWFX_"

local function ns(keys: { { number } }): NumberSequence
	local k = {}
	for _, p in keys do
		table.insert(k, NumberSequenceKeypoint.new(p[1], p[2], p[3] or 0))
	end
	return NumberSequence.new(k)
end

local function cs(keys: { { any } }): ColorSequence
	local k = {}
	for _, p in keys do
		table.insert(k, ColorSequenceKeypoint.new(p[1], p[2]))
	end
	return ColorSequence.new(k)
end

local function newEmitter(parent: Instance, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = FX_PREFIX .. (props.name or "Emitter")
	e.Texture = SPARK
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Rate = 0
	e.Lifetime = NumberRange.new(1)
	e.Speed = NumberRange.new(0)
	e.Size = NumberSequence.new(0.4)
	e.Transparency = ns({ { 0, 1 }, { 0.15, 0.2 }, { 1, 1 } })
	e.Color = ColorSequence.new(LAV)
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

-- Time the authored FX node is "on": first key before its scale rises above 2%, and the key after it falls back.
local function ramp(fx: any, clip: string): (number, number, { { number } })
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

local function scaleAt(sc: { { number } }, t: number): number
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

function Vfx.new(model: Model, data: any, assets: { [string]: string }?, opts: { lowFx: boolean? }?)
	local self = setmetatable({}, Vfx)
	self.model = model
	self.data = data
	self.assets = assets or {}
	self.low = if opts and opts.lowFx ~= nil then opts.lowFx else UserInputService.TouchEnabled
	self.hrp = model:WaitForChild("HumanoidRootPart") :: BasePart
	self.token = 0
	self.updaters = {} :: { [any]: (number, number) -> boolean }
	self.temps = {} :: { [Instance]: boolean }
	self.orbitSpeed = 1
	self.orbitAngle = 0
	self.folder = Instance.new("Folder")
	self.folder.Name = FX_PREFIX .. "Persistent"
	self.folder.Parent = model
	local k = if self.low then 0.5 else 1
	self.k = k
	self.ringTex = if self.assets.Ring and self.assets.Ring ~= "" then self.assets.Ring else SPARK
	self.sigilTex = if self.assets.Sigil and self.assets.Sigil ~= "" then self.assets.Sigil else self.ringTex
	self.coinTex = if self.assets.Coin and self.assets.Coin ~= "" then self.assets.Coin else SPARK

	-- ground helper (invisible, follows the root): emitter shapes take their size from the part
	local ground = Instance.new("Part")
	ground.Name = FX_PREFIX .. "Ground"
	ground.Size = Vector3.new(4.6, 0.2, 4.6)
	ground.Transparency = 1
	ground.Anchored, ground.CanCollide, ground.CanQuery, ground.CanTouch, ground.CastShadow = true, false, false, false, false
	ground.Parent = self.folder
	self.ground = ground
	self.groundOffset = CFrame.new(0, -data.hrpHeight + 0.05, 0)
	ground.CFrame = self.hrp.CFrame * self.groundOffset

	self.auraSparks = newEmitter(ground, {
		name = "AuraSparks",
		Rate = 9 * k,
		Lifetime = NumberRange.new(1.6, 2.6),
		Speed = NumberRange.new(0.6, 1.6),
		Acceleration = Vector3.new(0, 1.5, 0),
		EmissionDirection = Enum.NormalId.Top,
		Shape = Enum.ParticleEmitterShape.Cylinder,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		Size = ns({ { 0, 0.35 }, { 0.5, 0.5 }, { 1, 0 } }),
		Color = cs({ { 0, WHITE }, { 0.4, LAV }, { 1, LAV_DEEP } }),
		RotSpeed = NumberRange.new(-60, 60),
		Rotation = NumberRange.new(0, 360),
		Enabled = true,
	})
	self.auraSpikes = newEmitter(ground, {
		name = "AuraSpikes",
		Rate = 5 * k,
		Lifetime = NumberRange.new(0.9, 1.4),
		Speed = NumberRange.new(2.5, 4.5),
		EmissionDirection = Enum.NormalId.Top,
		Shape = Enum.ParticleEmitterShape.Cylinder,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		Orientation = Enum.ParticleOrientation.VelocityParallel,
		Squash = ns({ { 0, -2 }, { 1, -2 } }),
		Size = ns({ { 0, 0.5 }, { 0.3, 0.9 }, { 1, 0 } }),
		Color = cs({ { 0, LAV }, { 1, LAV_DEEP } }),
		Transparency = ns({ { 0, 0.9 }, { 0.2, 0.25 }, { 1, 1 } }),
		Enabled = true,
	})
	-- the rune circle: one big flat sprite at a time, slowly spinning and pulsing (VelocityPerpendicular + tiny upward velocity = lies flat on the ground)
	self.sigil = newEmitter(ground, {
		name = "Sigil",
		Texture = self.sigilTex,
		Rate = 0.5,
		Lifetime = NumberRange.new(4),
		Speed = NumberRange.new(0.01),
		EmissionDirection = Enum.NormalId.Top,
		Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
		Size = NumberSequence.new(data.meshBox.GroundSigil_Neon.max[1] * 2),
		Transparency = ns({ { 0, 1 }, { 0.2, 0.35 }, { 0.8, 0.35 }, { 1, 1 } }),
		RotSpeed = NumberRange.new(15, 15),
		Rotation = NumberRange.new(0, 360),
		Color = cs({ { 0, LAV }, { 1, LAV } }),
		Enabled = true,
	})

	-- orbiting coins (the authored CoinOrbit mesh: 1,408 triangles; here 5 thin cylinders)
	self.coins = {} :: { BasePart }
	local nCoins = if self.low then 3 else 5
	local radius = data.meshBox.CoinOrbit.max[1]
	for i = 1, nCoins do
		local c = Instance.new("Part")
		c.Name = FX_PREFIX .. "Coin" .. i
		c.Shape = Enum.PartType.Cylinder
		c.Size = Vector3.new(0.14, 0.75, 0.75)
		c.Material = Enum.Material.Metal
		c.Color = GOLD
		c.Anchored, c.CanCollide, c.CanQuery, c.CanTouch, c.CastShadow = true, false, false, false, false
		c.Parent = self.folder
		table.insert(self.coins, c)
	end
	self.orbitRadius = radius
	self.orbitCenter = data.fx.FX_CoinOrbit.inHrp -- {x,y,z} relative to the root
	return self
end

function Vfx:_temp(inst: Instance, life: number)
	self.temps[inst] = true
	inst.Destroying:Once(function()
		self.temps[inst] = nil
	end)
	Debris:AddItem(inst, life)
end

-- A temporary invisible anchor at a world position (for bursts). Returns part, attachment.
function Vfx:_anchor(cf: CFrame, size: Vector3?, life: number): (Part, Attachment)
	local p = Instance.new("Part")
	p.Name = FX_PREFIX .. "Anchor"
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

function Vfx:_ring(cf: CFrame, d0: number, d1: number, life: number, color: Color3?, flat: boolean?)
	local p = self:_anchor(cf, nil, life + 0.6)
	newEmitter(p, {
		name = "Ring",
		Texture = self.ringTex,
		Lifetime = NumberRange.new(life),
		Speed = NumberRange.new(0.01),
		EmissionDirection = Enum.NormalId.Top,
		Orientation = if flat == false then Enum.ParticleOrientation.FacingCamera else Enum.ParticleOrientation.VelocityPerpendicular,
		Size = ns({ { 0, d0 }, { 1, d1 } }),
		Transparency = ns({ { 0, 0.15 }, { 0.6, 0.4 }, { 1, 1 } }),
		Color = cs({ { 0, WHITE }, { 0.3, color or LAV }, { 1, color or LAV_DEEP } }),
	}):Emit(1)
end

function Vfx:_burst(cf: CFrame, count: number, props: { [string]: any })
	local p = self:_anchor(cf, nil, 3)
	local e = newEmitter(p, props)
	e:Emit(math.max(1, math.floor(count * self.k)))
end

-- every frame: follow the root, spin the coins, run active one-shot updaters
function Vfx:step(now: number, dt: number)
	local hrpCF = self.hrp.CFrame
	self.ground.CFrame = hrpCF * self.groundOffset
	self.orbitAngle += dt * self.orbitSpeed * (math.pi * 2 / 6)
	local c = self.orbitCenter
	local tilt = CFrame.Angles(math.rad(8.6), 0, 0) -- the authored orbit plane is tilted ~8.6 degrees
	for i, coin in self.coins do
		local a = self.orbitAngle + (i - 1) * math.pi * 2 / #self.coins
		local local_ = CFrame.new(c[1], c[2], c[3]) * tilt * CFrame.new(math.cos(a) * self.orbitRadius, 0, math.sin(a) * self.orbitRadius) * CFrame.Angles(0, -a, math.rad(90))
		coin.CFrame = hrpCF * local_
	end
	for key, fn in self.updaters do
		if not fn(now, dt) then
			self.updaters[key] = nil
		end
	end
end

function Vfx:_at(token: number, delay: number, fn: () -> ())
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

-- the clip started `el` seconds ago (server time)
function Vfx:onClip(clip: string, el: number)
	self.token += 1
	local token = self.token
	local fn = (Vfx :: any)["_clip_" .. clip]
	if fn then
		fn(self, token, el)
	end
end

local function groundCF(self: any, rel: { number }?): CFrame
	local r = rel or { 0, -self.data.hrpHeight + 0.06, 0 }
	return self.hrp.CFrame * CFrame.new(r[1], r[2], r[3])
end

-- Event_HostileTakeover: a Beam from the left hand along the hand's pointing axis, length and width follow the authored FX_TakeoverBeam scale track.
function Vfx:_clip_Event_HostileTakeover(token: number, el: number)
	local fx = self.data.fx.FX_TakeoverBeam
	local t0, t1, sc = ramp(fx, "Event_HostileTakeover")
	local hand = self.model:FindFirstChild("LeftHand") :: BasePart
	local a0 = hand and hand:FindFirstChild("FX_TakeoverBeam") :: Attachment?
	if not a0 then
		return
	end
	local length = -self.data.meshBox.TakeoverBeam_Neon.min[2]
	local radius = self.data.meshBox.TakeoverBeam_Neon.max[1]
	self:_at(token, t0 - el, function()
		local a1 = Instance.new("Attachment")
		a1.Name = FX_PREFIX .. "BeamEnd"
		a1.Parent = hand
		local glow, core = Instance.new("Beam"), Instance.new("Beam")
		for _, b in { glow, core } do
			b.Attachment0, b.Attachment1 = a0, a1
			b.LightEmission = 1
			b.LightInfluence = 0
			b.FaceCamera = true
			b.Segments = 6
			b.Name = FX_PREFIX .. "Beam"
			b.Parent = hand
		end
		glow.Color = cs({ { 0, LAV }, { 1, LAV_DEEP } })
		glow.Transparency = ns({ { 0, 0.55 }, { 1, 0.85 } })
		core.Color = cs({ { 0, WHITE }, { 1, LAV } })
		core.Transparency = ns({ { 0, 0.05 }, { 1, 0.3 } })
		local sparks = newEmitter(a1, {
			name = "BeamTip",
			Rate = 40 * self.k,
			Lifetime = NumberRange.new(0.3, 0.6),
			Speed = NumberRange.new(4, 9),
			SpreadAngle = Vector2.new(180, 180),
			Size = ns({ { 0, 0.5 }, { 1, 0 } }),
			Color = cs({ { 0, WHITE }, { 1, LAV } }),
			Enabled = true,
		})
		self:_temp(a1, t1 - t0 + 1)
		self:_temp(glow, t1 - t0 + 1)
		self:_temp(core, t1 - t0 + 1)
		local start = os.clock()
		local key = {}
		self.updaters[key] = function()
			if token ~= self.token or not a1.Parent then
				return false
			end
			local s = scaleAt(sc, t0 + (os.clock() - start) + math.max(0, el - t0))
			if os.clock() - start > t1 - t0 or s <= 0.02 then
				sparks.Enabled = false
				glow:Destroy()
				core:Destroy()
				return false
			end
			a1.CFrame = a0.CFrame * CFrame.new(0, -length * s, 0)
			glow.Width0, glow.Width1 = radius * 4 * s, radius * 3 * s
			core.Width0, core.Width1 = radius * 1.6 * s, radius * 1.2 * s
			return true
		end
	end)
end

-- Normal_Repossess: shockwave ring on the ground in front (authored FX_Shockwave: ring radius x scale 1 -> 4.5)
function Vfx:_clip_Normal_Repossess(token: number, el: number)
	local fx = self.data.fx.FX_Shockwave
	local t0, t1 = ramp(fx, "Normal_Repossess")
	local r = self.data.meshBox.Shockwave_Neon.max[1]
	self:_at(token, t0 - el, function()
		local cf = groundCF(self, fx.inHrp)
		self:_ring(cf, r * 2, r * 2 * 4.5, t1 - t0, GOLD)
		self:_ring(cf, r * 1.2, r * 2 * 3.4, (t1 - t0) * 0.9, LAV)
		self:_burst(cf, 16, {
			name = "ShockDust",
			Lifetime = NumberRange.new(0.35, 0.6),
			Speed = NumberRange.new(8, 14),
			SpreadAngle = Vector2.new(70, 70),
			EmissionDirection = Enum.NormalId.Top,
			Acceleration = Vector3.new(0, -25, 0),
			Size = ns({ { 0, 0.55 }, { 1, 0 } }),
			Color = cs({ { 0, WHITE }, { 1, GOLD } }),
		})
	end)
end

-- Event_MarketCrash: coin rain from the authored FX_CoinRain volume (falls over ~1 s) and impact rings (authored FX_CoinRainMarks)
function Vfx:_clip_Event_MarketCrash(token: number, el: number)
	local rainFx, marksFx = self.data.fx.FX_CoinRain, self.data.fx.FX_CoinRainMarks
	local r0, r1 = ramp(rainFx, "Event_MarketCrash")
	local m0, m1 = ramp(marksFx, "Event_MarketCrash")
	local box = self.data.meshBox.CoinRain
	local sizeX, sizeZ = box.max[1] - box.min[1], box.max[3] - box.min[3]
	self:_at(token, r0 - el, function()
		local top = self.hrp.CFrame * CFrame.new(rainFx.inHrp[1] + (box.max[1] + box.min[1]) / 2, rainFx.inHrp[2], rainFx.inHrp[3] + (box.max[3] + box.min[3]) / 2)
		local p = self:_anchor(top, Vector3.new(sizeX, 0.3, sizeZ), r1 - r0 + 2.5)
		local rain = newEmitter(p, {
			name = "CoinRain",
			Texture = self.coinTex,
			Rate = 38 * self.k,
			Lifetime = NumberRange.new(0.8, 1.0),
			Speed = NumberRange.new(2, 3),
			EmissionDirection = Enum.NormalId.Bottom,
			Acceleration = Vector3.new(0, -14, 0),
			Shape = Enum.ParticleEmitterShape.Box,
			ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
			Size = ns({ { 0, 0.9 }, { 1, 0.9 } }),
			Transparency = ns({ { 0, 0 }, { 0.85, 0 }, { 1, 1 } }),
			Color = cs({ { 0, WHITE }, { 1, WHITE } }),
			LightEmission = 0.3,
			RotSpeed = NumberRange.new(-420, 420),
			Rotation = NumberRange.new(0, 360),
			Enabled = true,
		})
		task.delay(r1 - r0, function()
			rain.Enabled = false
		end)
	end)
	self:_at(token, m0 + 0.5 - el, function()
		local box2 = self.data.meshBox.CoinRainMarks_Neon
		local g = groundCF(self, marksFx.inHrp) * CFrame.new((box2.max[1] + box2.min[1]) / 2, 0, (box2.max[3] + box2.min[3]) / 2)
		local p = self:_anchor(g, Vector3.new(box2.max[1] - box2.min[1], 0.2, box2.max[3] - box2.min[3]), m1 - m0 + 1)
		local marks = newEmitter(p, {
			name = "CoinMarks",
			Texture = self.ringTex,
			Rate = 14 * self.k,
			Lifetime = NumberRange.new(0.45),
			Speed = NumberRange.new(0.01),
			EmissionDirection = Enum.NormalId.Top,
			Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
			Shape = Enum.ParticleEmitterShape.Box,
			ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
			Size = ns({ { 0, 0.8 }, { 1, 2.4 } }),
			Transparency = ns({ { 0, 0.2 }, { 1, 1 } }),
			Color = cs({ { 0, GOLD }, { 1, GOLD } }),
			Enabled = true,
		})
		task.delay(m1 - m0 - 0.5, function()
			marks.Enabled = false
		end)
	end)
end

-- Event_VaultLock: the halo flies in front and grows (model animation); sparkles trail it, a rune circle flares, rings pulse when it arrives and when the lock closes.
function Vfx:_clip_Event_VaultLock(token: number, el: number)
	local halo = self.model:FindFirstChild("VaultHalo") :: BasePart
	self.orbitSpeed = 3
	self:_at(token, 0.6 - el, function()
		self:_ring(groundCF(self), 4, 13, 0.8, LAV)
	end)
	self:_at(token, 0.5 - el, function()
		local a = Instance.new("Attachment")
		a.Parent = halo
		local e = newEmitter(a, {
			name = "HaloTrail",
			Rate = 28 * self.k,
			Lifetime = NumberRange.new(0.5, 0.9),
			Speed = NumberRange.new(1, 3),
			SpreadAngle = Vector2.new(180, 180),
			Size = ns({ { 0, 0.55 }, { 1, 0 } }),
			Color = cs({ { 0, GOLD }, { 1, LAV } }),
			Enabled = true,
		})
		self:_temp(a, 2.6)
		task.delay(1.6, function()
			e.Enabled = false
		end)
	end)
	self:_at(token, 1.1 - el, function()
		self:_ring(halo.CFrame, 3, 14, 0.7, GOLD, false)
	end)
	self:_at(token, 1.9 - el, function()
		self:_ring(groundCF(self), 10, 4, 0.6, LAV)
		self:_ring(halo.CFrame, 14, 4, 0.5, LAV, false)
	end)
	self:_at(token, 2.4 - el, function()
		if token == self.token then
			self.orbitSpeed = 1
		end
	end)
end

-- Event_BankruptNova: three expanding rings from the ground (authored FX_NovaRing 1 -> 10), a spark dome, a bigger rune flare
function Vfx:_clip_Event_BankruptNova(token: number, el: number)
	local fx = self.data.fx.FX_NovaRing
	local t0, t1 = ramp(fx, "Event_BankruptNova")
	local r = self.data.meshBox.NovaRing_Neon.max[1]
	local life = t1 - t0
	self.orbitSpeed = 3
	self:_at(token, 1.2 - el, function()
		self:_ring(groundCF(self), 6, 12, 0.9, LAV)
		self.auraSpikes.Rate = 12 * self.k
	end)
	for i = 0, 2 do
		self:_at(token, t0 + i * 0.1 - el, function()
			self:_ring(groundCF(self, fx.inHrp), r * 2, r * 2 * (10 - i * 1.4), life, if i == 1 then GOLD else LAV)
		end)
	end
	self:_at(token, t0 - el, function()
		self:_burst(groundCF(self), 48, {
			name = "NovaSparks",
			Lifetime = NumberRange.new(0.5, 0.9),
			Speed = NumberRange.new(16, 28),
			SpreadAngle = Vector2.new(85, 85),
			EmissionDirection = Enum.NormalId.Top,
			Acceleration = Vector3.new(0, -12, 0),
			Size = ns({ { 0, 0.7 }, { 1, 0 } }),
			Color = cs({ { 0, WHITE }, { 0.4, LAV }, { 1, LAV_DEEP } }),
		})
	end)
	self:_at(token, 2.3 - el, function()
		if token == self.token then
			self.orbitSpeed = 1
			self.auraSpikes.Rate = 5 * self.k
		end
	end)
end

-- Steal_Grab: a small lavender flick at the grabbing hand (kept tiny: the clip's story is the arm motion)
function Vfx:_clip_Steal_Grab(token: number, el: number)
	local hand = self.model:FindFirstChild("LeftHand") :: BasePart
	self:_at(token, 0.55 - el, function()
		self:_burst(hand.CFrame, 14, {
			name = "GrabFlick",
			Lifetime = NumberRange.new(0.25, 0.45),
			Speed = NumberRange.new(5, 9),
			SpreadAngle = Vector2.new(180, 180),
			Size = ns({ { 0, 0.45 }, { 1, 0 } }),
			Color = cs({ { 0, WHITE }, { 1, LAV } }),
		})
	end)
end

function Vfx:stats()
	local persistent, temps, live = 0, 0, 0
	for _, d in self.model:GetDescendants() do
		if d:IsA("ParticleEmitter") then
			if d.Enabled then
				persistent += 1
			end
			live += 1
		end
	end
	for _ in self.temps do
		temps += 1
	end
	return { enabledEmitters = persistent, emitters = live, temps = temps, low = self.low }
end

-- Remove every one-shot object right now (the persistent aura stays).
function Vfx:cleanup()
	self.token += 1
	table.clear(self.updaters)
	for inst in self.temps do
		inst:Destroy()
	end
	self.orbitSpeed = 1
	self.auraSpikes.Rate = 5 * self.k
end

function Vfx:destroy()
	self:cleanup()
	self.folder:Destroy()
end

return Vfx
