-- Studio location: ReplicatedStorage.DragonKit (ModuleScript)
-- DragonKit  (Milestone 035)
-- One reusable dragon for CreatureSpecs: Aquaris (the Sunken Kingdom Secret, scale 3) and the Dragon Pup (same shapes, small).
--   local props, fx = DragonKit.build({ u = 1, colors = DragonKit.WATER, meshes = false })
--   u       overall size (1 = Aquaris before the spec's own scale); feet always stand on the rig's ground
--   meshes  false = a complete dragon from plain parts (head, wings, tail tip too); true = the Blender head, wings and tail tip
--           from ServerStorage.Imports035 (DragonHead / DragonWingR / DragonWingL / DragonTail, tools/blender/build_035_dragon.py)
--           replace those parts (the neck, body, legs, tail, spikes and belly plates stay parts)
-- Everything hangs on the hidden R15 LowerTorso (design space: +X right, +Y up, -Z forward, ground at y = -2.25); idles are
-- code-driven (wing flap, jaw, leg swing, tail sway) and run by CreatureAnim like every other creature.

local DragonKit = {}

local v3, cf, rad = Vector3.new, CFrame.new, math.rad
local rgb = Color3.fromRGB
local METAL = Enum.Material.Metal

export type Colors = {
	back: Color3,
	back2: Color3,
	belly: Color3,
	bone: Color3,
	membrane: Color3,
	wing: Color3, -- solid wing / fin membrane
	edge: Color3,
	gold: Color3,
	eye: Color3,
	dark: Color3,
}

-- The first Blender export built its spike pieces wrongly (teeth, crest, claw, tail spikes); until the corrected FBX files are
-- imported those four pieces are skipped and made from plain parts. Set true after re-importing assets/export/035.
DragonKit.SPIKES_FIXED = false

DragonKit.WATER = {
	back = rgb(18, 84, 176),
	back2 = rgb(30, 110, 205),
	belly = rgb(190, 245, 255),
	bone = rgb(16, 60, 150),
	membrane = rgb(130, 238, 252),
	wing = rgb(40, 150, 215),
	edge = rgb(70, 235, 255),
	gold = rgb(255, 200, 60),
	eye = rgb(120, 255, 255),
	dark = rgb(12, 24, 50),
} :: Colors

DragonKit.EMBER = { -- the pup: warm and friendly
	back = rgb(232, 96, 40),
	back2 = rgb(250, 128, 56),
	belly = rgb(255, 232, 190),
	bone = rgb(170, 60, 30),
	membrane = rgb(255, 196, 120),
	wing = rgb(226, 118, 52),
	edge = rgb(255, 150, 50),
	gold = rgb(255, 214, 80),
	eye = rgb(255, 255, 160),
	dark = rgb(50, 20, 20),
} :: Colors

function DragonKit.build(o: { u: number?, ground: number?, colors: Colors?, meshes: boolean?, flap: number? }): ({ any }, { any })
	local u = o.u or 1
	local G = o.ground or -2.25
	local c: Colors = o.colors or DragonKit.WATER
	local meshes = o.meshes == true
	local flap = o.flap or 16
	local props: { any } = {}
	local fx: { any } = {}

	local function P(x: number, y: number, z: number): Vector3 -- design point -> rig space
		return v3(x * u, G + (y + 2.25) * u, z * u)
	end
	local function D(x: number, y: number, z: number): Vector3 -- an offset (may be negative)
		return v3(x * u, y * u, z * u)
	end
	local function S(x: number, y: number, z: number): Vector3 -- a part size
		return v3(math.max(x * u, 0.05), math.max(y * u, 0.05), math.max(z * u, 0.05))
	end
	local function add(n: string, shape: string, size: Vector3, at: CFrame, color: Color3, extra: { [string]: any }?)
		local p: any = { n = n, on = "LowerTorso", shape = shape, size = size, at = at, color = color }
		if extra then
			for k, v in extra do
				p[k] = v
			end
		end
		table.insert(props, p)
	end
	-- a block laid from point a to point b, t thick
	local function limb(n: string, a: Vector3, b: Vector3, t: number, color: Color3, extra: { [string]: any }?)
		local d = b - a
		local up = if math.abs(d.Unit.Y) > 0.95 then v3(1, 0, 0) else v3(0, 1, 0)
		add(n, "Block", v3(math.max(t * u, 0.05), math.max(t * u, 0.05), d.Magnitude), CFrame.lookAt((a + b) / 2, b, up), color, extra)
	end
	-- a thin membrane panel hung on triangle apex a, base b-c
	local function tri(n: string, a: Vector3, b: Vector3, cc: Vector3, color: Color3, extra: { [string]: any }?)
		local mid = (b + cc) / 2
		local along = mid - a
		local normal = (b - a):Cross(cc - a).Unit
		local center = a + along * 0.55
		add(n, "Block", v3(math.max((cc - b).Magnitude * 0.5, 0.05), 0.04 * u + 0.02, along.Magnitude * 0.9), CFrame.lookAt(center, center + along, normal), color, extra)
	end
	local function spikeUp(n: string, at: Vector3, h: number, w: number, color: Color3, tilt: number?, anim: any?)
		add(n, "Wedge", S(w, h, w * 1.3), cf(at) * CFrame.Angles(rad(tilt or 0), 0, 0), color, { mat = METAL, anim = anim })
	end
	local function sway(amp: number, speed: number, phase: number, pivot: Vector3): any
		return { kind = "swing", axis = "Y", amp = amp, speed = speed, phase = phase, pivot = cf(pivot) }
	end

	-- a tapered cylinder from rig-space point a to b, d0 -> d1 thick (design units); over = how far it overlaps the next piece
	local function seg(n: string, a: Vector3, b: Vector3, d0: number, d1: number, color: Color3, extra: { [string]: any }?, over: number?)
		local len = (b - a).Magnitude * (over or 1.3)
		local d = (d0 + d1) / 2 * u
		add(n, "Cylinder", v3(d, len, d), CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(rad(90), 0, 0), color, extra)
	end

	-- BODY: three big overlapping balls (chest, belly, rump), a row of light belly plates underneath, spikes along the back
	local bodyZ = { 0.95, 0.1, -0.85 }
	local bodySize = { v3(2.5, 2.5, 2.2), v3(2.8, 2.6, 2.4), v3(2.6, 2.5, 2.1) }
	for i, z in bodyZ do
		add("Body" .. i, "Ball", S(bodySize[i].X, bodySize[i].Y, bodySize[i].Z), cf(P(0, 0.3, z)), if i % 2 == 0 then c.back2 else c.back)
	end
	for i = 1, 7 do
		local z = 1.5 - (i - 1) * 0.45
		local w = 1.5 - math.abs(z - 0.1) * 0.35
		add("BellyPlate" .. i, "Block", S(w, 0.22, 0.5), cf(P(0, -0.92 + math.abs(z - 0.1) * 0.12, z)), c.belly)
	end
	for i, z in { 1.3, 0.65, 0, -0.65, -1.25 } do
		spikeUp("BackSpike" .. i, P(0, 1.45, z), 0.65, 0.24, c.gold)
	end

	-- NECK: three thick tapered cylinders (thick at the shoulders, thinner toward the head), a light strip down the front,
	-- gold spikes on the back of the neck
	local neck = { P(0, 0.9, -1.0), P(0, 1.55, -1.65), P(0, 2.15, -2.15), P(0, 2.65, -2.6) }
	local neckD = { 1.5, 1.25, 1.05, 0.95 }
	for i = 1, 3 do
		local an = sway(2 + i, 1.1, i * 0.35, neck[1])
		seg("Neck" .. i, neck[i], neck[i + 1], neckD[i], neckD[i + 1], if i % 2 == 0 then c.back2 else c.back, { anim = an })
		local off = D(0, -0.05, -neckD[i] * 0.4)
		seg("NeckBelly" .. i, neck[i] + off, neck[i + 1] + off, 0.5, 0.45, c.belly, { anim = an }, 1.1)
	end
	for i, pos in neck do
		spikeUp("NeckSpike" .. i, pos + D(0, neckD[i] * 0.45, neckD[i] * 0.4), 0.55, 0.22, c.gold, 25)(props[#props] :: any).anim = sway(2 + i, 1.1, i * 0.35, neck[1])
	end

	-- HEAD (neck joint H0 at the end of the neck): the Blender head at 1.4x, tilted down, on a short thick neck end
	local H0 = P(0, 2.75, -2.7)
	local HS = 1.4
	local hr = CFrame.Angles(rad(-12), 0, 0)
	local function hp(x: number, y: number, z: number): Vector3 -- a point in head space
		return H0 + hr * (D(x, y, z) * HS)
	end
	if meshes then
		local col = {
			Skull = c.back,
			Snout = c.back2,
			Jaw = c.belly,
			Teeth = { color = rgb(250, 250, 255), skip = not DragonKit.SPIKES_FIXED },
			Nostrils = c.dark,
			Horns = { color = c.gold, mat = METAL },
			CheekFins = { color = c.wing, trans = 0.1 },
			Sockets = c.dark,
			Eyes = { color = c.eye, neon = true },
			Crest = { color = c.gold, mat = METAL, skip = not DragonKit.SPIKES_FIXED },
		}
		table.insert(props, {
			n = "HeadMesh",
			on = "LowerTorso",
			model = "DragonHead",
			at = cf(H0) * hr,
			fit = { axis = "Z", size = 4.3 * u * HS },
			colors = col,
			partAnim = {
				Jaw = { kind = "swing", axis = "X", amp = 11, speed = 1.6, pivot = cf(hp(0, 0.1, -0.25)) * hr },
			},
		})
		if not DragonKit.SPIKES_FIXED then
			for i = 1, 3 do
				spikeUp("Crest" .. i, hp(0, 1.0, -0.15 + i * 0.4), (0.55 - i * 0.08) * HS, 0.2 * HS, c.gold, -12)
			end
		end
	else
		add("Head", "Ball", S(1.5, 1.4, 1.7), cf(hp(0, 0.5, -0.5)) * hr, c.back)
		add("Snout", "Block", S(1.0, 0.8, 2.3), cf(hp(0, 0.42, -1.6)) * hr, c.back2)
		add("SnoutTip", "Block", S(0.72, 0.56, 0.56), cf(hp(0, 0.38, -2.55)) * hr, c.back2)
		add(
			"Jaw",
			"Block",
			S(0.78, 0.28, 2.6),
			cf(hp(0, 0.08, -1.45)) * hr,
			c.belly,
			{ anim = { kind = "swing", axis = "X", amp = 11, speed = 1.6, pivot = cf(hp(0, 0.1, -0.25)) * hr } }
		)
		for _, s in { -1, 1 } do
			add("Nostril" .. s, "Ball", S(0.17, 0.14, 0.14), cf(hp(s * 0.15, 0.63, -2.72)) * hr, c.dark)
			add("Eye" .. s, "Ball", S(0.42, 0.42, 0.42), cf(hp(s * 0.5, 0.65, -0.85)) * hr, c.eye, { neon = true })
			limb("HornA" .. s, hp(s * 0.33, 1.0, -0.15), hp(s * 0.5, 1.4, 0.7), 0.36, c.gold, { mat = METAL })
			limb("HornB" .. s, hp(s * 0.5, 1.4, 0.7), hp(s * 0.66, 1.3, 1.65), 0.22, c.gold, { mat = METAL })
			add("CheekFin" .. s, "Block", S(0.08, 0.84, 1.26), cf(hp(s * 0.7, 0.2, 0.05)) * hr * CFrame.Angles(0, rad(-s * 20), 0), c.wing)
		end
		for i = 1, 3 do
			spikeUp("Crest" .. i, hp(0, 1.0, -0.15 + i * 0.4), (0.55 - i * 0.08) * HS, 0.2 * HS, c.gold, -12)
		end
	end
	fx[#fx + 1] = {
		on = "Snout",
		kind = "puff",
		color = rgb(170, 235, 255),
		rate = 20,
		size = 2.0 * u,
		at = v3(0, 0, -(if meshes then 1.2 else 0.85) * u * HS),
		aura = true,
	}

	-- WINGS (65% size): arm bone, four finger bones and solid membrane panels, angled up and back from the shoulders, flapping about the shoulder
	local ws = 0.65
	for _, s in { 1, -1 } do
		local side = if s > 0 then "R" else "L"
		local S0 = P(s * 1.0, 1.25, -0.2)
		local flapAnim = { kind = "swing", axis = "Z", amp = s * flap, speed = 1.3, pivot = cf(S0) }
		local wr = CFrame.Angles(0, -s * rad(25), s * rad(28)) -- up and back
		local function wp(x: number, y: number, z: number): Vector3 -- a wing-space offset (design units, before the 65%) -> rig space
			return S0 + wr * (D(x, y, z) * ws)
		end
		if meshes then
			table.insert(props, {
				n = "Wing" .. side,
				on = "LowerTorso",
				model = if s > 0 then "DragonWingL" else "DragonWingR", -- (Blender's X arrives mirrored: the ...L file reaches toward +X)
				at = cf(S0) * wr,
				fit = { axis = "X", size = 6.4 * u * ws },
				anim = flapAnim,
				colors = {
					Bones = { color = c.bone:Lerp(c.edge, 0.3), neon = true },
					Claw = { color = c.gold, mat = METAL, skip = not DragonKit.SPIKES_FIXED },
					Membrane = { color = c.wing, trans = 0.05 },
					Edge = { color = c.edge, neon = true },
				},
			})
			if not DragonKit.SPIKES_FIXED then
				add("WingClaw" .. side, "Wedge", S(0.2 * ws, 0.5 * ws, 0.25 * ws), cf(wp(s * 3.95, 2.4, -0.85)) * wr, c.gold, { mat = METAL, anim = flapAnim })
			end
		else
			local E = wp(s * 1.9, 1.4, 0.6)
			local W = wp(s * 3.8, 2.1, -0.5)
			local T = { wp(s * 6.0, 1.7, -1.3), wp(s * 5.8, 0.2, 0.9), wp(s * 4.5, -0.9, 2.1), wp(s * 2.7, -1.1, 2.5) }
			add("WingJoint" .. side, "Ball", S(0.6, 0.6, 0.6), cf(S0), c.bone, { anim = flapAnim })
			limb("WingArm" .. side, S0, E, 0.3, c.bone, { anim = flapAnim })
			limb("WingFore" .. side, E, W, 0.24, c.edge, { anim = flapAnim, neon = true })
			for i, t in T do
				limb("WingFinger" .. side .. i, W, t, 0.15, c.bone, { anim = flapAnim })
			end
			add("WingClaw" .. side, "Wedge", S(0.15, 0.35, 0.2), cf(W + D(s * 0.1, 0.2, -0.25)), c.gold, { mat = METAL, anim = flapAnim })
			local mem = { trans = 0.05, anim = flapAnim }
			tri("Membrane" .. side .. 1, W, T[1], T[2], c.wing, mem)
			tri("Membrane" .. side .. 2, W, T[2], T[3], c.wing, mem)
			tri("Membrane" .. side .. 3, W, T[3], T[4], c.wing, mem)
			tri("Membrane" .. side .. 4, E, W, T[4], c.wing, mem)
		end
	end

	-- LEGS: four thick bent legs that stand on the ground: tapered thigh and shin, a flat foot with three claws, a slow diagonal step in idle
	local legs = {
		{ "FrontR", 1, v3(1.05, -0.2, -0.85), v3(1.4, -1.15, -1.15), v3(1.2, -2.0, -0.95), -1.0 },
		{ "FrontL", -1, v3(1.05, -0.2, -0.85), v3(1.4, -1.15, -1.15), v3(1.2, -2.0, -0.95), -1.0 },
		{ "HindR", 1, v3(1.1, -0.1, 0.95), v3(1.5, -1.1, 0.55), v3(1.2, -2.0, 1.15), 1.0 },
		{ "HindL", -1, v3(1.1, -0.1, 0.95), v3(1.5, -1.1, 0.55), v3(1.2, -2.0, 1.15), 1.0 },
	}
	for i, l in legs do
		local name, s, hip, knee, ankle = l[1], l[2], l[3], l[4], l[5]
		local hipP = P(s * hip.X, hip.Y, hip.Z)
		local kneeP = P(s * knee.X, knee.Y, knee.Z)
		local ankleP = P(s * ankle.X, ankle.Y, ankle.Z)
		local la = {
			kind = "swing",
			axis = "X",
			amp = 5,
			speed = 1.5,
			phase = if i == 1 or i == 4 then 0 else math.pi,
			pivot = cf(hipP),
		}
		seg("Thigh" .. name, hipP, kneeP, 1.0, 0.8, c.back, { anim = la })
		add("Knee" .. name, "Ball", S(0.85, 0.85, 0.85), cf(kneeP), c.back, { anim = la })
		seg("Shin" .. name, kneeP, ankleP, 0.75, 0.62, c.back2, { anim = la }, 1.15)
		add("Foot" .. name, "Block", S(0.95, 0.24, 1.25), cf(P(s * ankle.X, -2.13, ankle.Z - 0.2)), c.back, { anim = la })
		for k = -1, 1 do
			add("Claw" .. name .. k, "Wedge", S(0.17, 0.22, 0.42), cf(P(s * ankle.X + k * 0.3, -2.13, ankle.Z - 0.95)), c.gold, { mat = METAL, anim = la })
		end
	end

	-- TAIL: thick at the rump, tapering back; tapered overlapping cylinders, a light strip underneath, gold spikes along the top
	local tailPts = {}
	local tailN = if meshes then 5 else 8
	for i = 0, 7 do
		table.insert(tailPts, P(0, 0.05 - i * 0.12, 1.5 + i * 0.7))
	end
	local pivot0 = tailPts[1]
	for i = 1, tailN - 1 do
		local d0 = 1.35 - (i - 1) * 0.14
		local d1 = d0 - 0.14
		local an = sway(2 + i * 1.2, 1.2, i * 0.4, pivot0)
		seg("Tail" .. i, tailPts[i], tailPts[i + 1], d0, d1, if i % 2 == 0 then c.back2 else c.back, { anim = an })
		if i <= 4 then
			local off = D(0, -d0 * 0.4, 0)
			seg("TailBelly" .. i, tailPts[i] + off, tailPts[i + 1] + off, 0.45, 0.4, c.belly, { anim = an }, 1.1)
		end
		spikeUp("TailSpike" .. i, (tailPts[i] + tailPts[i + 1]) / 2 + D(0, d0 * 0.5, 0), 0.5, 0.22, c.gold)(props[#props] :: any).anim = an
	end
	if meshes then
		table.insert(props, {
			n = "TailTip",
			on = "LowerTorso",
			model = "DragonTail",
			at = cf(tailPts[tailN]),
			fit = { axis = "Z", size = 3.2 * u },
			anim = sway(14, 1.2, 2.2, pivot0),
			colors = {
				Segments = c.back,
				Fin = { color = c.wing, trans = 0.1 },
				Spikes = { color = c.gold, mat = METAL, skip = not DragonKit.SPIKES_FIXED },
			},
		})
		if not DragonKit.SPIKES_FIXED then
			local a = sway(14, 1.2, 2.2, pivot0)
			add("TailTipSpike", "Wedge", S(0.26, 0.3, 0.9), cf(tailPts[tailN] + D(0, 0, 3.3)) * CFrame.Angles(rad(90), 0, 0), c.gold, { mat = METAL, anim = a })
			for i = 1, 3 do
				add("TipSpike" .. i, "Wedge", S(0.2, 0.45, 0.3), cf(tailPts[tailN] + D(0, 0.4, 0.5 + i * 0.7)), c.gold, { mat = METAL, anim = a })
			end
		end
	else
		local tip = tailPts[8]
		local a = sway(14, 1.2, 3.3, pivot0)
		add("TailFinV", "Block", S(0.06, 1.7, 1.5), cf(tip + D(0, 0, 0.85)), c.wing, { trans = 0.1, anim = a })
		add("TailFinH", "Block", S(1.8, 0.06, 1.5), cf(tip + D(0, 0, 0.85)), c.wing, { trans = 0.1, anim = a })
		add("TailTipSpike", "Wedge", S(0.26, 0.3, 0.9), cf(tip + D(0, 0, 1.8)) * CFrame.Angles(rad(90), 0, 0), c.gold, { mat = METAL, anim = a })
	end

	-- solid dorsal fins between the back spikes
	for i, z in { 0.95, 0.3, -0.35 } do
		add("DorsalFin" .. i, "Block", S(0.06, 0.7, 0.5), cf(P(0, 1.4, z)), c.wing, { trans = 0.1, anim = { kind = "swing", axis = "X", amp = 5, speed = 2, phase = i } })
	end
	fx[#fx + 1] = { on = "Body2", kind = "drop", color = rgb(170, 235, 255), rate = 14, size = 1.4 * u, aura = true }
	fx[#fx + 1] = { on = "Neck2", kind = "bubble", color = rgb(190, 235, 255), rate = 6, size = 1.2 * u, aura = true }
	fx[#fx + 1] = { on = "Eye1", kind = "spark", color = c.eye, rate = 3, size = 0.6 * u }
	return props, fx
end

-- The Dragon Pup: the same dragon at about a third of the size in warm colours.
function DragonKit.pup(meshes: boolean?): any
	local props, fx = DragonKit.build({ u = 0.4, colors = DragonKit.EMBER, meshes = meshes ~= false, flap = 22 })
	return {
		hideBody = true,
		scale = 1,
		skin = DragonKit.EMBER.back,
		props = props,
		fx = fx,
		light = Color3.fromRGB(255, 190, 120),
	}
end

return DragonKit
