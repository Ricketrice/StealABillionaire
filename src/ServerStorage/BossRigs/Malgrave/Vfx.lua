-- Studio location: ServerStorage.BossRigs.Malgrave.Vfx (ModuleScript)
-- Vfx (Sir Malgrave): Roblox-native replacements for the authored effect meshes / emitter placeholders of Malgrave.glb (18 FX meshes). Built on Shared.FxKit.
-- Cosmetic only. Runs on every client; timings, sizes and the thrown-sword path come from the converted FX tracks in Data.
-- Persistent (the boss aura): rune circle on the ground, pulsing energy ring, smoke, embers, wisps, glow along the blade.
-- One-shot: Basic_SwordSwing (blade trail + slash arc), Special_Riftcleave (fissure line + rock chunks + wind ring + gust), Special_OathbreakerThrow (the sword flies out on its authored
-- path with a trail and a spinning ring, then returns), Special_Ironcall (rune flash, shock ring, two rings of iron blades rise from the ground and sink back).
-- Kid-safe: swords, stone, embers and runes only.

local FxKit = require(script.Parent:WaitForChild("FxKit"))

local ns, cs, newEmitter, ramp, scaleAt = FxKit.ns, FxKit.cs, FxKit.newEmitter, FxKit.ramp, FxKit.scaleAt
local WHITE, SPARK, PREFIX = FxKit.WHITE, FxKit.SPARK, FxKit.PREFIX
local RED = Color3.fromRGB(255, 70, 60)
local RED_DEEP = Color3.fromRGB(170, 12, 24)
local EMBER = Color3.fromRGB(255, 140, 50)
local STEEL = Color3.fromRGB(58, 62, 74)
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

local Vfx = setmetatable({}, { __index = FxKit.Base })
Vfx.__index = Vfx

function Vfx.new(model: Model, data: any, assets: { [string]: string }?, opts: { lowFx: boolean? }?)
	local self = setmetatable({}, Vfx)
	FxKit.init(self, model, data, assets, opts, { main = RED, deep = RED_DEEP, accent = EMBER })
	local k, ground, box = self.k, self.ground, data.meshBox
	self.arcTex, self.glowTex, self.zigTex, self.helixTex = self.tex("Arc", self.ringTex), self.tex("Glow", SPARK), self.tex("Zigzag", self.ringTex), self.tex("Helix", SPARK)
	local auraR = box.AuraEnergy_FX.max[1]
	ground.Size = Vector3.new(auraR * 2, 0.2, auraR * 2) * self.s

	-- the rune circle (authored GroundSigil) and the energy ring (AuraEnergy)
	self.sigil = newEmitter(ground, {
		name = "Sigil",
		Texture = self.sigilTex,
		Rate = 0.5,
		Lifetime = NumberRange.new(4),
		Speed = NumberRange.new(0.01),
		EmissionDirection = Enum.NormalId.Top,
		Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
		Size = NumberSequence.new(box.GroundSigil_FX.max[1] * 2),
		Transparency = ns({ { 0, 1 }, { 0.2, 0.3 }, { 0.8, 0.3 }, { 1, 1 } }),
		RotSpeed = NumberRange.new(12, 12),
		Rotation = NumberRange.new(0, 360),
		Enabled = true,
	})
	self.energy = newEmitter(ground, {
		name = "AuraEnergy",
		Texture = self.ringTex,
		Rate = 0.8,
		Lifetime = NumberRange.new(2.2),
		Speed = NumberRange.new(0.01),
		EmissionDirection = Enum.NormalId.Top,
		Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
		Size = ns({ { 0, auraR * 1.4 }, { 1, auraR * 2.2 } }),
		Transparency = ns({ { 0, 1 }, { 0.25, 0.55 }, { 1, 1 } }),
		Enabled = true,
	})
	-- smoke, embers, wisps (the authored AuraSmoke / AuraEmbers / AuraWisps emitter placeholders)
	self.smoke = newEmitter(ground, {
		name = "AuraSmoke",
		Texture = SMOKE,
		Rate = 6 * k,
		Lifetime = NumberRange.new(2, 3),
		Speed = NumberRange.new(0.6, 1.2),
		EmissionDirection = Enum.NormalId.Top,
		Shape = Enum.ParticleEmitterShape.Cylinder,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		Size = ns({ { 0, 1.2 }, { 1, 3.2 } }),
		Transparency = ns({ { 0, 1 }, { 0.2, 0.78 }, { 1, 1 } }),
		Color = cs({ { 0, Color3.fromRGB(70, 12, 14) }, { 1, Color3.fromRGB(16, 16, 20) } }),
		LightEmission = 0,
		RotSpeed = NumberRange.new(-30, 30),
		Rotation = NumberRange.new(0, 360),
		Enabled = true,
	})
	self.embers = newEmitter(ground, {
		name = "AuraEmbers",
		Rate = 8 * k,
		Lifetime = NumberRange.new(1.5, 2.5),
		Speed = NumberRange.new(2, 4),
		Acceleration = Vector3.new(0, 1, 0),
		EmissionDirection = Enum.NormalId.Top,
		Shape = Enum.ParticleEmitterShape.Cylinder,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		Size = ns({ { 0, 0.3 }, { 1, 0 } }),
		Color = cs({ { 0, EMBER }, { 1, RED } }),
		Enabled = true,
	})
	self.wisps = newEmitter(ground, {
		name = "AuraWisps",
		Texture = self.helixTex,
		Rate = 1.5 * k,
		Lifetime = NumberRange.new(2),
		Speed = NumberRange.new(1.5, 2.5),
		EmissionDirection = Enum.NormalId.Top,
		Orientation = Enum.ParticleOrientation.FacingCameraWorldUp,
		Shape = Enum.ParticleEmitterShape.Cylinder,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		Size = ns({ { 0, 1.6 }, { 1, 2.4 } }),
		Transparency = ns({ { 0, 1 }, { 0.2, 0.55 }, { 1, 1 } }),
		Enabled = true,
	})
	-- glow along the blade (authored SwordEnergy)
	local sword = model:FindFirstChild("Greatsword") :: BasePart?
	local energyAtt = sword and sword:FindFirstChild("FX_SwordEnergy")
	if energyAtt then
		self.swordGlow = newEmitter(energyAtt, {
			name = "SwordGlow",
			Rate = 6 * k,
			Lifetime = NumberRange.new(0.5, 0.8),
			Speed = NumberRange.new(0.3, 1),
			SpreadAngle = Vector2.new(180, 180),
			Size = ns({ { 0, 0.4 }, { 1, 0 } }),
			Color = cs({ { 0, WHITE }, { 1, RED } }),
			Enabled = true,
		})
	end
	-- prototypes of the held sword (taken now, while it is full size) for the Oathbreaker throw
	self.proto = {}
	for _, n in { "Greatsword", "Greatsword_Neon" } do
		local p = model:FindFirstChild(n)
		if p then
			local c = p:Clone()
			c.Anchored, c.CanCollide, c.CanQuery, c.CanTouch, c.Massless = true, false, false, false, true
			for _, d in c:GetDescendants() do
				if d:IsA("Motor6D") or d:IsA("Weld") then
					d:Destroy()
				end
			end
			self.proto[n] = c
		end
	end
	return self
end

function Vfx:step(now: number, dt: number)
	self:baseStep(now, dt)
end

function Vfx:onCleanup()
	-- the aura is untouched by the one-shots; nothing to restore
end

-- A flat sprite lying on the world (or the waist plane) that grows and fades.
function Vfx:_flat(cf: CFrame, texture: string, d0: number, d1: number, life: number, color: Color3?, spin: number?)
	local p = self:_anchor(cf, nil, life + 0.6)
	newEmitter(p, {
		name = "Flat",
		Texture = texture,
		Lifetime = NumberRange.new(life),
		Speed = NumberRange.new(0.01),
		EmissionDirection = Enum.NormalId.Top,
		Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
		Size = ns({ { 0, d0 }, { 1, d1 } }),
		Transparency = ns({ { 0, 0.1 }, { 0.6, 0.4 }, { 1, 1 } }),
		Color = ColorSequence.new(color or WHITE),
		RotSpeed = NumberRange.new(spin or 0, spin or 0),
		Rotation = NumberRange.new(0, 360),
	}):Emit(1)
end

local function trail(self: any, part: BasePart, life: number, duration: number)
	local a0, a1 = part:FindFirstChild("FX_SwordTrail_Att0"), part:FindFirstChild("FX_SwordTrail_Att1")
	if not (a0 and a1) then
		return
	end
	local t = Instance.new("Trail")
	t.Name = PREFIX .. "Trail"
	t.Attachment0, t.Attachment1 = a0 :: Attachment, a1 :: Attachment
	t.Lifetime = life
	t.LightEmission = 1
	t.LightInfluence = 0
	t.FaceCamera = true
	t.Color = cs({ { 0, WHITE }, { 0.3, RED }, { 1, RED_DEEP } })
	t.Transparency = ns({ { 0, 0.2 }, { 1, 1 } })
	t.Parent = part
	self:_temp(t, duration + life + 0.5)
	task.delay(duration, function()
		t.Enabled = false
	end)
end

-- Basic_SwordSwing: blade trail through the swing + a flat slash arc at waist height (authored FX_SlashArc)
-- Where the zone guardian's attack lands (GuardianService sets VW_HitSpot = the warning's ground point, plus VW_HitAcross /
-- VW_HitLength for the line attack), so the hit effects sit on the warning the hit is tested against. nil = authored spot.
local function hitSpot(self: any): Vector3?
	local p = self.model:GetAttribute("VW_HitSpot")
	return if typeof(p) == "Vector3" then p else nil
end

function Vfx:_clip_Basic_SwordSwing(token: number, el: number)
	local fx = self.data.fx.FX_SlashArc
	local t0, t1 = ramp(fx, "Basic_SwordSwing")
	local sword = self.model:FindFirstChild("Greatsword") :: BasePart
	local width = self.data.meshBox.SlashArc_FX.max[1] * 2
	local sc = self.s
	self:_at(token, t0 - 0.15 - el, function()
		trail(self, sword, 0.35, t1 - t0 + 0.3)
	end)
	self:_at(token, t0 - el, function()
		self:_flat(self.hrp.CFrame * CFrame.new(fx.inHrp[1] * sc, fx.inHrp[2] * sc, fx.inHrp[3] * sc), self.arcTex, width * 0.6, width * 1.1, t1 - t0 + 0.15, RED, -160)
		self:_burst(sword.CFrame, 10, {
			name = "SwingSparks",
			Lifetime = NumberRange.new(0.25, 0.45),
			Speed = NumberRange.new(4, 8),
			SpreadAngle = Vector2.new(180, 180),
			Size = ns({ { 0, 0.4 }, { 1, 0 } }),
			Color = cs({ { 0, WHITE }, { 1, RED } }),
		})
	end)
end

-- Special_Riftcleave: a glowing crack runs forward along the ground (zigzag Beam) with rock chunks, a wind ring and a gust
function Vfx:_clip_Special_Riftcleave(token: number, el: number)
	local d = self.data
	local fis, burst, gust = d.fx.FX_Fissure, d.fx.FX_WindBurst, d.fx.FX_WindGust
	local f0, f1, fsc = ramp(fis, "Special_Riftcleave")
	local b0, b1 = ramp(burst, "Special_Riftcleave")
	local fb = d.meshBox.Fissure
	local sc = self.s
	local len = (fb.min[3] * -1 - -fb.max[3]) * sc -- near edge to far edge along -Z
	local near = -fb.max[3] * sc
	self:_at(token, f0 - el, function()
		local base = self.hrp.CFrame * CFrame.new(fis.inHrp[1] * sc, (fis.inHrp[2] + 0.1) * sc, fis.inHrp[3] * sc)
		local spot, across, length = hitSpot(self), self.model:GetAttribute("VW_HitAcross"), self.model:GetAttribute("VW_HitLength")
		if spot and typeof(across) == "Vector3" and type(length) == "number" then
			-- the crack runs along the red warning strip, end to end (that strip is where the hit lands)
			local from = spot - across * (length / 2) + Vector3.new(0, 0.1 * sc, 0)
			base = CFrame.lookAt(from, from + across)
			near, len = 0, length
		end
		local pa, a0 = self:_anchor(base * CFrame.new(0, 0, -near), nil, f1 - f0 + 1)
		local _, a1 = self:_anchor(base * CFrame.new(0, 0, -near), nil, f1 - f0 + 1)
		local glow, core = Instance.new("Beam"), Instance.new("Beam")
		for _, b in { glow, core } do
			b.Attachment0, b.Attachment1 = a0, a1
			b.LightEmission = 1
			b.LightInfluence = 0
			b.FaceCamera = true
			b.Segments = 12
			b.Name = PREFIX .. "Fissure"
			b.Parent = pa
		end
		glow.Color = cs({ { 0, RED }, { 1, RED_DEEP } })
		glow.Width0, glow.Width1 = 3 * sc, 2 * sc
		glow.Transparency = ns({ { 0, 0.6 }, { 1, 0.85 } })
		core.Texture = self.zigTex
		core.TextureMode = Enum.TextureMode.Wrap
		core.TextureLength = 5 * sc
		core.Color = ColorSequence.new(WHITE)
		core.Width0, core.Width1 = 1.1 * sc, 0.9 * sc
		core.Transparency = ns({ { 0, 0.05 }, { 1, 0.3 } })
		-- rock chunks along the crack (dark stone, pop up and sink back)
		local rng = Random.new(7)
		local chunks = {}
		local n = math.max(3, math.floor(9 * self.k))
		for i = 1, n do
			local c = Instance.new("Part")
			c.Name = PREFIX .. "Rock"
			c.Material = Enum.Material.Slate
			c.Color = Color3.fromRGB(46, 49, 60)
			local s = rng:NextNumber(0.5, 1.1) * sc
			c.Size = Vector3.new(s, s * rng:NextNumber(0.8, 1.4), s * 0.8)
			c.Anchored, c.CanCollide, c.CanQuery, c.CanTouch, c.CastShadow = true, false, false, false, false
			local z = -near - (i / n) * len
			c.CFrame = base * CFrame.new(rng:NextNumber(-0.9, 0.9) * sc, -1 * sc, z) * CFrame.Angles(rng:NextNumber(-0.5, 0.5), rng:NextNumber(0, 6), rng:NextNumber(-0.5, 0.5))
			c.Parent = self.folder
			self:_temp(c, f1 - f0 + 1)
			table.insert(chunks, { part = c, cf = c.CFrame, delay = (i / n) * 0.3 })
		end
		self:_burst(base * CFrame.new(0, 0, -near), 18, {
			name = "FissureSparks",
			Lifetime = NumberRange.new(0.4, 0.8),
			Speed = NumberRange.new(5, 11),
			SpreadAngle = Vector2.new(60, 60),
			EmissionDirection = Enum.NormalId.Top,
			Acceleration = Vector3.new(0, -18, 0),
			Size = ns({ { 0, 0.5 }, { 1, 0 } }),
			Color = cs({ { 0, WHITE }, { 1, RED } }),
		})
		local start = os.clock() - math.max(0, el - f0)
		local key = {}
		self.updaters[key] = function()
			if token ~= self.token or not pa.Parent then
				return false
			end
			local t = f0 + (os.clock() - start)
			local s = scaleAt(fsc, t)
			if t > f1 then
				glow:Destroy()
				core:Destroy()
				return false
			end
			local show = math.clamp(s, 0, 1)
			a1.WorldCFrame = base * CFrame.new(0, 0, -near - len * show)
			glow.Enabled, core.Enabled = show > 0.02, show > 0.02
			for _, ch in chunks do
				local up = math.clamp((t - f0 - ch.delay) / 0.2, 0, 1) * (if show < 1 then show else 1)
				ch.part.CFrame = ch.cf * CFrame.new(0, up * 1.0 * sc, 0)
			end
			return true
		end
	end)
	self:_at(token, b0 - el, function()
		local cf = self:groundCF(burst.inHrp)
		local r = d.meshBox.WindBurst_Wind.max[1]
		local gray = Color3.fromRGB(200, 210, 230)
		self:_ring(cf, r * 2, r * 2 * 7, b1 - b0, gray)
		local gcf = self.hrp.CFrame * CFrame.new(gust.inHrp[1] * sc, (gust.inHrp[2] + 0.7) * sc, gust.inHrp[3] * sc)
		self:_burst(gcf, 16, {
			name = "WindGust",
			Lifetime = NumberRange.new(0.5, 0.8),
			Speed = NumberRange.new(8, 12),
			EmissionDirection = Enum.NormalId.Front,
			SpreadAngle = Vector2.new(12, 12),
			Orientation = Enum.ParticleOrientation.VelocityParallel,
			Squash = ns({ { 0, -2 }, { 1, -2 } }),
			Size = ns({ { 0, 0.7 }, { 1, 0.2 } }),
			Color = cs({ { 0, WHITE }, { 1, gray } }),
			LightEmission = 0.4,
		})
	end)
end

local function interpTrs(rows: { { number } }, t: number, k: number): (CFrame, number)
	if t <= rows[1][1] then
		local r = rows[1]
		return CFrame.new(r[2] * k, r[3] * k, r[4] * k, r[5], r[6], r[7], r[8]), r[9]
	end
	for i = 1, #rows - 1 do
		local a, b = rows[i], rows[i + 1]
		if t >= a[1] and t <= b[1] then
			local u = (t - a[1]) / (b[1] - a[1])
			local ca = CFrame.new(a[2] * k, a[3] * k, a[4] * k, a[5], a[6], a[7], a[8])
			local cb = CFrame.new(b[2] * k, b[3] * k, b[4] * k, b[5], b[6], b[7], b[8])
			return ca:Lerp(cb, u), a[9] + (b[9] - a[9]) * u
		end
	end
	local r = rows[#rows]
	return CFrame.new(r[2] * k, r[3] * k, r[4] * k, r[5], r[6], r[7], r[8]), r[9]
end

-- Special_OathbreakerThrow: a copy of the sword flies out along the authored path (spinning, with a trail and a ring) and vanishes where the held one reappears
function Vfx:_clip_Special_OathbreakerThrow(token: number, el: number)
	local d = self.data
	local fx = d.fx.FX_ThrownSword
	local t0, t1 = ramp(fx, "Special_OathbreakerThrow")
	local rows = fx.clips.Special_OathbreakerThrow.trs
	local sc = self.s
	local child = CFrame.new(fx.child[1] * sc, fx.child[2] * sc, fx.child[3] * sc)
	local rr = d.restRot.Greatsword
	local rest = CFrame.new(0, 0, 0, rr[1], rr[2], rr[3], rr[4], rr[5], rr[6], rr[7], rr[8], rr[9])
	local hitT, hitD = t0, 0
	for _, r in rows do
		if r[1] > t0 and r[1] < t1 and -r[4] > hitD then
			hitT, hitD = r[1], -r[4]
		end
	end
	self:_at(token, t0 - el, function()
		local copies = {}
		for name, proto in self.proto do
			local c = proto:Clone()
			c.Parent = self.folder
			self:_temp(c, t1 - t0 + 1.5)
			copies[name] = c
		end
		local base = copies.Greatsword
		if base then
			trail(self, base, 0.3, t1 - t0)
			local a = Instance.new("Attachment")
			a.Parent = base
			local ring = newEmitter(a, {
				name = "SawRing",
				Texture = self.arcTex,
				Rate = 7 * self.k,
				Lifetime = NumberRange.new(0.35),
				Speed = NumberRange.new(0.01),
				Orientation = Enum.ParticleOrientation.FacingCamera,
				Size = ns({ { 0, 2.2 }, { 1, d.meshBox.ThrownSawRing_FX.max[1] * 2 } }),
				Transparency = ns({ { 0, 0.3 }, { 1, 1 } }),
				RotSpeed = NumberRange.new(300, 500),
				Rotation = NumberRange.new(0, 360),
				Enabled = true,
			})
			task.delay(t1 - t0, function()
				ring.Enabled = false
			end)
		end
		local start = os.clock() - math.max(0, el - t0)
		local hit = false
		local key = {}
		local spot = hitSpot(self)
		-- (with a spot: the authored flight is shifted sideways, growing to the full shift at the hit and back to the hand)
		local function shiftAt(t: number): Vector3
			if not spot then
				return Vector3.zero
			end
			local authored = (self.hrp.CFrame * interpTrs(rows, hitT, sc) * child).Position
			local w = if t <= hitT then (t - t0) / math.max(hitT - t0, 1e-3) else 1 - (t - hitT) / math.max(t1 - hitT, 1e-3)
			return Vector3.new(spot.X - authored.X, 0, spot.Z - authored.Z) * math.clamp(w, 0, 1)
		end
		self.updaters[key] = function()
			if token ~= self.token or not self.model.Parent then
				return false
			end
			local t = t0 + (os.clock() - start)
			if t >= t1 then
				for _, c in copies do
					c:Destroy()
				end
				return false
			end
			local node = interpTrs(rows, t, sc)
			local cf = self.hrp.CFrame * node * child * rest:Inverse() + shiftAt(t)
			for _, c in copies do
				c.CFrame = cf
			end
			if not hit and t >= hitT then
				hit = true
				local pos = (self.hrp.CFrame * node * child).Position + shiftAt(hitT)
				local g = CFrame.new(pos.X, if spot then spot.Y + 0.06 * sc else self.hrp.Position.Y - (self.data.hrpHeight - 0.06 / sc) * sc, pos.Z)
				self:_ring(g, 1.5, 9, 0.5, RED)
				self:_burst(CFrame.new(pos), 20, {
					name = "ThrowHit",
					Lifetime = NumberRange.new(0.3, 0.6),
					Speed = NumberRange.new(6, 12),
					SpreadAngle = Vector2.new(180, 180),
					Size = ns({ { 0, 0.5 }, { 1, 0 } }),
					Color = cs({ { 0, WHITE }, { 1, RED } }),
				})
			end
			return true
		end
	end)
end

-- Special_Ironcall: rune flash, shock ring, then two rings of iron blades rise out of the ground (authored GraveBlades, renamed) and sink back
function Vfx:_clip_Special_Ironcall(token: number, el: number)
	local d = self.data
	local marks, shock = d.fx.FX_IronMarks, d.fx.FX_IronShock
	local sc = self.s
	local m0, m1 = ramp(marks, "Special_Ironcall")
	local s0, s1 = ramp(shock, "Special_Ironcall")
	-- with a spot (the shockwave's centre): centred there instead of the authored offsets
	local function at(rel: { number }): CFrame
		local spot = hitSpot(self)
		return if spot then CFrame.new(spot + Vector3.new(0, 0.06 * sc, 0)) * self.hrp.CFrame.Rotation else self:groundCF(rel)
	end
	self:_at(token, m0 - el, function()
		local w = d.meshBox.IronMarks_FX.max[1] * 2
		self:_flat(at(marks.inHrp), self.sigilTex, w * 0.8, w, m1 - m0, RED, 20)
	end)
	self:_at(token, s0 - el, function()
		local r = d.meshBox.IronShock_FX.max[1]
		self:_ring(at(shock.inHrp), r * 2, r * 2 * 11, s1 - s0, RED)
		self:_burst(at(shock.inHrp), 24, {
			name = "IronShockSparks",
			Lifetime = NumberRange.new(0.4, 0.8),
			Speed = NumberRange.new(10, 18),
			SpreadAngle = Vector2.new(80, 80),
			EmissionDirection = Enum.NormalId.Top,
			Acceleration = Vector3.new(0, -16, 0),
			Size = ns({ { 0, 0.55 }, { 1, 0 } }),
			Color = cs({ { 0, WHITE }, { 0.4, EMBER }, { 1, RED } }),
		})
	end)
	for _, spec in { { "FX_IronBlades_Inner", "IronBlades_Inner", 8 }, { "FX_IronBlades_Outer", "IronBlades_Outer", 12 } } do
		local fx = d.fx[spec[1]]
		local b0, b1 = ramp(fx, "Special_Ironcall")
		local posKeys = fx.clips.Special_Ironcall.pos
		local bb = d.meshBox[spec[2]]
		local radius, h0, h1 = (bb.max[1] - 0.25) * sc, bb.min[2] * sc, bb.max[2] * sc
		local count = math.max(4, math.floor(spec[3] * self.k))
		self:_at(token, b0 - 0.05 - el, function()
			local origin = self.hrp.CFrame * CFrame.new(fx.inHrp[1] * sc, 0, fx.inHrp[3] * sc)
			local spot = hitSpot(self)
			if spot then
				origin = CFrame.new(spot.X, origin.Position.Y, spot.Z) * origin.Rotation
			end
			local blades = {}
			for i = 1, count do
				local a = (i - 1) * math.pi * 2 / count
				local cfBase = origin * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -radius)
				local body = Instance.new("Part")
				body.Name = PREFIX .. "Blade"
				body.Material = Enum.Material.Metal
				body.Color = STEEL
				body.Size = Vector3.new(0.12 * sc, h1 - h0 - 0.5 * sc, 0.6 * sc)
				local tip = Instance.new("WedgePart")
				tip.Name = PREFIX .. "BladeTip"
				tip.Material = Enum.Material.Metal
				tip.Color = STEEL
				tip.Size = Vector3.new(0.12 * sc, 0.5 * sc, 0.6 * sc)
				local edge = Instance.new("Part")
				edge.Name = PREFIX .. "BladeEdge"
				edge.Material = Enum.Material.Neon
				edge.Color = RED
				edge.Size = Vector3.new(0.14 * sc, h1 - h0, 0.1 * sc)
				for _, p in { body, tip, edge } do
					p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
					p.Parent = self.folder
					self:_temp(p, b1 - b0 + 1.5)
				end
				table.insert(blades, { cf = cfBase, body = body, tip = tip, edge = edge })
			end
			local start = os.clock() - math.max(0, el - b0)
			local key = {}
			self.updaters[key] = function()
				if token ~= self.token or not self.model.Parent then
					return false
				end
				local t = b0 - 0.05 + (os.clock() - start)
				if t > b1 + 0.05 then
					for _, bl in blades do
						bl.body:Destroy()
						bl.tip:Destroy()
						bl.edge:Destroy()
					end
					return false
				end
				-- base height from the authored translation track (studs relative to the root), blade mesh origin = its bottom
				local y = posKeys[1][3] * sc
				for j = 1, #posKeys - 1 do
					local ka, kb = posKeys[j], posKeys[j + 1]
					if t >= ka[1] and t <= kb[1] then
						y = (ka[3] + (kb[3] - ka[3]) * (t - ka[1]) / (kb[1] - ka[1])) * sc
					elseif t > kb[1] then
						y = kb[3] * sc
					end
				end
				local base = self.hrp.CFrame.Position.Y + y
				for _, bl in blades do
					local p = bl.cf.Position
					local upright = CFrame.new(p.X, base, p.Z) * (bl.cf - bl.cf.Position)
					bl.body.CFrame = upright * CFrame.new(0, h0 + (h1 - h0 - 0.5 * sc) / 2, 0)
					bl.tip.CFrame = upright * CFrame.new(0, h0 + (h1 - h0 - 0.5 * sc) + 0.25 * sc, 0) * CFrame.Angles(0, math.pi, 0)
					bl.edge.CFrame = upright * CFrame.new(0, h0 + (h1 - h0) / 2, 0.3 * sc)
				end
				return true
			end
		end)
	end
end

return Vfx
