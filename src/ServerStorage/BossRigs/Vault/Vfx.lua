-- Studio location: ServerStorage.BossRigs.Vault.Vfx (ModuleScript)
-- Vfx (Vault Wizard): Roblox-native replacements for the authored effect meshes (14 meshes / 24,140 triangles in the GLB). Built on Shared.FxKit.
-- Cosmetic only (no damage, economy or rewards). Runs on every client; timings and sizes come from the converted FX tracks in Data (ramps of the authored FX nodes).
-- Persistent (always on): idle aura sparks, spike streaks, spinning rune circle, 5 orbiting coins.
-- One-shot: Takeover Beam, Vault Lock, Market Crash, Bankrupt Nova, and the Repossess shockwave.

local FxKit = require(script.Parent:WaitForChild("FxKit"))

local ns, cs, newEmitter, ramp, scaleAt = FxKit.ns, FxKit.cs, FxKit.newEmitter, FxKit.ramp, FxKit.scaleAt
local WHITE = FxKit.WHITE
local PREFIX = FxKit.PREFIX
local LAV = Color3.fromRGB(176, 148, 255)
local LAV_DEEP = Color3.fromRGB(120, 70, 255)
local GOLD = Color3.fromRGB(240, 190, 80)

local Vfx = setmetatable({}, { __index = FxKit.Base })
Vfx.__index = Vfx

function Vfx.new(model: Model, data: any, assets: { [string]: string }?, opts: { lowFx: boolean? }?)
	local self = setmetatable({}, Vfx)
	FxKit.init(self, model, data, assets, opts, { main = LAV, deep = LAV_DEEP, accent = GOLD })
	local k, ground = self.k, self.ground
	self.orbitSpeed = 1
	self.orbitAngle = 0
	ground.Size = Vector3.new(4.6, 0.2, 4.6) * self.s

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
	for i = 1, nCoins do
		local c = Instance.new("Part")
		c.Name = PREFIX .. "Coin" .. i
		c.Shape = Enum.PartType.Cylinder
		c.Size = Vector3.new(0.14, 0.75, 0.75) * self.s
		c.Material = Enum.Material.Metal
		c.Color = GOLD
		c.Anchored, c.CanCollide, c.CanQuery, c.CanTouch, c.CastShadow = true, false, false, false, false
		c.Parent = self.folder
		table.insert(self.coins, c)
	end
	self.orbitRadius = data.meshBox.CoinOrbit.max[1] * self.s
	self.orbitCenter = { data.fx.FX_CoinOrbit.inHrp[1] * self.s, data.fx.FX_CoinOrbit.inHrp[2] * self.s, data.fx.FX_CoinOrbit.inHrp[3] * self.s } -- {x,y,z} relative to the root
	return self
end

-- every frame: follow the root, spin the coins, run active one-shot updaters
function Vfx:step(now: number, dt: number)
	self:baseStep(now, dt)
	local hrpCF = self.hrp.CFrame
	self.orbitAngle += dt * self.orbitSpeed * (math.pi * 2 / 6)
	local c = self.orbitCenter
	local tilt = CFrame.Angles(math.rad(8.6), 0, 0) -- the authored orbit plane is tilted ~8.6 degrees
	for i, coin in self.coins do
		local a = self.orbitAngle + (i - 1) * math.pi * 2 / #self.coins
		local local_ = CFrame.new(c[1], c[2], c[3]) * tilt * CFrame.new(math.cos(a) * self.orbitRadius, 0, math.sin(a) * self.orbitRadius) * CFrame.Angles(0, -a, math.rad(90))
		coin.CFrame = hrpCF * local_
	end
end

function Vfx:onCleanup()
	self.orbitSpeed = 1
	self.auraSpikes.Rate = 5 * self.k
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
	local length = -self.data.meshBox.TakeoverBeam_Neon.min[2] * self.s
	local radius = self.data.meshBox.TakeoverBeam_Neon.max[1] * self.s
	self:_at(token, t0 - el, function()
		local a1 = Instance.new("Attachment")
		a1.Name = PREFIX .. "BeamEnd"
		a1.Parent = hand
		local glow, core = Instance.new("Beam"), Instance.new("Beam")
		for _, b in { glow, core } do
			b.Attachment0, b.Attachment1 = a0, a1
			b.LightEmission = 1
			b.LightInfluence = 0
			b.FaceCamera = true
			b.Segments = 6
			b.Name = PREFIX .. "Beam"
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
		local cf = self:groundCF(fx.inHrp)
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
-- Where the zone guardian's attack lands (GuardianService sets VW_HitSpot = the warning's ground point), so the hit effects
-- sit on the warning the hit is tested against. nil = the authored spot.
local function hitSpot(self: any): Vector3?
	local p = self.model:GetAttribute("VW_HitSpot")
	return if typeof(p) == "Vector3" then p else nil
end

function Vfx:_clip_Event_MarketCrash(token: number, el: number)
	local rainFx, marksFx = self.data.fx.FX_CoinRain, self.data.fx.FX_CoinRainMarks
	local r0, r1 = ramp(rainFx, "Event_MarketCrash")
	local m0, m1 = ramp(marksFx, "Event_MarketCrash")
	local box = self.data.meshBox.CoinRain
	local sizeX, sizeZ = box.max[1] - box.min[1], box.max[3] - box.min[3]
	self:_at(token, r0 - el, function()
		local sc = self.s
		local top = self.hrp.CFrame
			* CFrame.new((rainFx.inHrp[1] + (box.max[1] + box.min[1]) / 2) * sc, rainFx.inHrp[2] * sc, (rainFx.inHrp[3] + (box.max[3] + box.min[3]) / 2) * sc)
		local spot = hitSpot(self)
		if spot then -- (the rain falls on the locked circle)
			top = CFrame.new(spot.X, top.Position.Y, spot.Z) * top.Rotation
		end
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
		local g = self:groundCF(marksFx.inHrp) * CFrame.new((box2.max[1] + box2.min[1]) / 2 * self.s, 0, (box2.max[3] + box2.min[3]) / 2 * self.s)
		local spot = hitSpot(self)
		if spot then
			g = CFrame.new(spot + Vector3.new(0, 0.06 * self.s, 0)) * g.Rotation
		end
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
		self:_ring(self:groundCF(), 4, 13, 0.8, LAV)
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
		self:_ring(self:groundCF(), 10, 4, 0.6, LAV)
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
		self:_ring(self:groundCF(), 6, 12, 0.9, LAV)
		self.auraSpikes.Rate = 12 * self.k
	end)
	for i = 0, 2 do
		self:_at(token, t0 + i * 0.1 - el, function()
			local spot = hitSpot(self) -- (the shockwave's centre)
			local cf = if spot then CFrame.new(spot + Vector3.new(0, 0.06 * self.s, 0)) else self:groundCF(fx.inHrp)
			self:_ring(cf, r * 2, r * 2 * (10 - i * 1.4), life, if i == 1 then GOLD else LAV)
		end)
	end
	self:_at(token, t0 - el, function()
		self:_burst(self:groundCF(), 48, {
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

return Vfx
