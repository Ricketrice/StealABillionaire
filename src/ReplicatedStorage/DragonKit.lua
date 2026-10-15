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
	local function spikeUp(n: string, at: Vector3, h: number, w: number, color: Color3, tilt: number?)
		add(n, "Wedge", S(w, h, w * 1.3), cf(at) * CFrame.Angles(rad(tilt or 0), 0, 0), color, { mat = METAL })
	end
	local function sway(amp: number, speed: number, phase: number, pivot: Vector3): any
		return { kind = "swing", axis = "Y", amp = amp, speed = speed, phase = phase, pivot = cf(pivot) }
	end

	-- BODY: four overlapping balls, light belly plates underneath, spikes along the back
	local bodyZ = { 0.9, 0.25, -0.4, -0.95 }
	local bodySize = { v3(1.7, 1.55, 1.5), v3(1.9, 1.75, 1.5), v3(1.9, 1.75, 1.4), v3(1.6, 1.5, 1.2) }
	for i, z in bodyZ do
		add("Body" .. i, "Ball", S(bodySize[i].X, bodySize[i].Y, bodySize[i].Z), cf(P(0, 0.05 + (i % 2) * 0.05, z)), if i % 2 == 0 then c.back2 else c.back)
		add("BellyPlate" .. i, "Block", S(1.05, 0.3, 0.55), cf(P(0, -0.8, z)), c.belly)
		spikeUp("BackSpike" .. i, P(0, 0.95, z), 0.6, 0.22, c.gold)
	end
	add("BellyPlate5", "Block", S(0.9, 0.28, 0.5), cf(P(0, -0.7, 1.45)), c.belly)

	-- NECK: five balls in an S curve (rising, then leaning forward), a gold spike on each
	local neck = { P(0, 0.6, -1.2), P(0, 1.25, -1.65), P(0, 1.95, -1.85), P(0, 2.65, -2.05), P(0, 3.15, -2.45) }
	local neckR = { 0.62, 0.56, 0.5, 0.46, 0.44 }
	for i, pos in neck do
		add("Neck" .. i, "Ball", S(neckR[i] * 2, neckR[i] * 2, neckR[i] * 2), cf(pos), if i % 2 == 0 then c.back2 else c.back, { anim = sway(2 + i, 1.1, i * 0.35, neck[1]) })
		add("NeckSpike" .. i, "Wedge", S(0.2, 0.5, 0.3), cf(pos + v3(0, neckR[i] * u * 0.95, 0)), c.gold, { mat = METAL, anim = sway(2 + i, 1.1, i * 0.35, neck[1]) })
	end
	add("NeckBelly", "Block", S(0.5, 2.6, 0.3), cf(P(0, 1.85, -1.55)) * CFrame.Angles(rad(-14), 0, 0), c.belly)

	-- HEAD (neck joint H0 at the end of the neck)
	local H0 = P(0, 3.1, -2.75)
	if meshes then
		local col = {
			Skull = c.back,
			Snout = c.back2,
			Jaw = c.belly,
			Teeth = { color = rgb(250, 250, 255), skip = not DragonKit.SPIKES_FIXED },
			Nostrils = c.dark,
			Horns = { color = c.gold, mat = METAL },
			CheekFins = { color = c.membrane, neon = true, trans = 0.3 },
			Sockets = c.dark,
			Eyes = { color = c.eye, neon = true },
			Crest = { color = c.gold, mat = METAL, skip = not DragonKit.SPIKES_FIXED },
		}
		table.insert(props, {
			n = "HeadMesh",
			on = "LowerTorso",
			model = "DragonHead",
			at = cf(H0),
			fit = { axis = "Z", size = 4.3 * u },
			colors = col,
			partAnim = { Jaw = { kind = "swing", axis = "X", amp = 11, speed = 1.6, pivot = cf(H0 + v3(0, 0.1 * u, -0.25 * u)) } },
		})
		if not DragonKit.SPIKES_FIXED then
			for i = 1, 3 do
				spikeUp("Crest" .. i, H0 + D(0, 1.0, -0.15 + i * 0.4), 0.55 - i * 0.08, 0.2, c.gold)
			end
		end
	else
		add("Head", "Ball", S(1.1, 1.0, 1.2), cf(H0 + D(0, 0.5, -0.5)), c.back)
		add("Snout", "Block", S(0.72, 0.55, 1.7), cf(H0 + D(0, 0.42, -1.6)), c.back2)
		add("SnoutTip", "Block", S(0.52, 0.4, 0.4), cf(H0 + D(0, 0.38, -2.55)), c.back2)
		add(
			"Jaw",
			"Block",
			S(0.56, 0.2, 1.9),
			cf(H0 + D(0, 0.08, -1.45)),
			c.belly,
			{ anim = { kind = "swing", axis = "X", amp = 11, speed = 1.6, pivot = cf(H0 + D(0, 0.1, -0.25)) } }
		)
		for _, s in { -1, 1 } do
			add("Nostril" .. s, "Ball", S(0.12, 0.1, 0.1), cf(H0 + D(s * 0.15, 0.63, -2.72)), c.dark)
			add("Eye" .. s, "Ball", S(0.3, 0.3, 0.3), cf(H0 + D(s * 0.5, 0.65, -0.85)), c.eye, { neon = true })
			limb("HornA" .. s, H0 + D(s * 0.33, 1.0, -0.15), H0 + D(s * 0.5, 1.4, 0.7), 0.26, c.gold, { mat = METAL })
			limb("HornB" .. s, H0 + D(s * 0.5, 1.4, 0.7), H0 + D(s * 0.66, 1.3, 1.65), 0.16, c.gold, { mat = METAL })
			add("CheekFin" .. s, "Block", S(0.06, 0.6, 0.9), cf(H0 + D(s * 0.7, 0.2, 0.05)) * CFrame.Angles(0, rad(-s * 20), 0), c.membrane, { neon = true, trans = 0.3 })
		end
		for i = 1, 3 do
			spikeUp("Crest" .. i, H0 + D(0, 1.0, -0.15 + i * 0.4), 0.55 - i * 0.08, 0.2, c.gold)
		end
	end
	fx[#fx + 1] = { on = "Snout", kind = "puff", color = rgb(170, 235, 255), rate = 20, size = 2.0 * u, at = v3(0, 0, -(if meshes then 1.2 else 0.85) * u), aura = true }

	-- WINGS: arm bone, four finger bones and translucent membrane panels, flapping slowly about the shoulder
	for _, s in { 1, -1 } do
		local side = if s > 0 then "R" else "L"
		local S0 = P(s * 0.8, 1.05, -0.2)
		local flapAnim = { kind = "swing", axis = "Z", amp = s * flap, speed = 1.3, pivot = cf(S0) }
		if meshes then
			table.insert(props, {
				n = "Wing" .. side,
				on = "LowerTorso",
				model = if s > 0 then "DragonWingL" else "DragonWingR", -- (Blender's X arrives mirrored: the ...L file reaches toward +X)
				at = cf(S0),
				fit = { axis = "X", size = 6.4 * u },
				anim = flapAnim,
				colors = {
					Bones = c.bone,
					Claw = { color = c.gold, mat = METAL, skip = not DragonKit.SPIKES_FIXED },
					Membrane = { color = c.membrane, neon = true, trans = 0.35 },
					Edge = { color = c.edge, neon = true },
				},
			})
			if not DragonKit.SPIKES_FIXED then
				add("WingClaw" .. side, "Wedge", S(0.2, 0.5, 0.25), cf(S0 + D(s * 3.95, 2.4, -0.85)), c.gold, { mat = METAL, anim = flapAnim })
			end
		else
			local E = P(s * 2.7, 2.45, 0.4)
			local W = P(s * 4.6, 3.15, -0.7)
			local T = { P(s * 6.8, 2.75, -1.5), P(s * 6.6, 1.25, 0.7), P(s * 5.3, 0.15, 1.9), P(s * 3.5, -0.05, 2.3) }
			local function anim(): any
				return flapAnim
			end
			add("WingJoint" .. side, "Ball", S(0.7, 0.7, 0.7), cf(S0), c.bone, { anim = anim() })
			limb("WingArm" .. side, S0, E, 0.3, c.bone, { anim = anim() })
			limb("WingFore" .. side, E, W, 0.24, c.edge, { anim = anim(), neon = true })
			for i, t in T do
				limb("WingFinger" .. side .. i, W, t, 0.15, c.bone, { anim = anim() })
			end
			add("WingClaw" .. side, "Wedge", S(0.2, 0.5, 0.25), cf(W + D(s * 0.15, 0.3, -0.35)), c.gold, { mat = METAL, anim = anim() })
			local mem = { neon = true, trans = 0.35, anim = anim() }
			tri("Membrane" .. side .. 1, W, T[1], T[2], c.membrane, mem)
			tri("Membrane" .. side .. 2, W, T[2], T[3], c.membrane, mem)
			tri("Membrane" .. side .. 3, W, T[3], T[4], c.membrane, mem)
			tri("Membrane" .. side .. 4, E, W, T[4], c.membrane, mem)
		end
	end

	-- LEGS: four legs that stand on the ground (feet bottoms at y = ground), claws on the toes, a slow diagonal step in idle
	local legs = {
		{ "FrontR", 1, v3(0.85, -0.5, -0.75), v3(0.95, -1.3, -0.95), v3(0.9, -2.0, -0.8), -1.0 },
		{ "FrontL", -1, v3(0.85, -0.5, -0.75), v3(0.95, -1.3, -0.95), v3(0.9, -2.0, -0.8), -1.0 },
		{ "HindR", 1, v3(0.95, -0.45, 0.95), v3(1.1, -1.25, 0.7), v3(1.0, -1.95, 1.2), 1.0 },
		{ "HindL", -1, v3(0.95, -0.45, 0.95), v3(1.1, -1.25, 0.7), v3(1.0, -1.95, 1.2), 1.0 },
	}
	for i, l in legs do
		local name, s, hip, knee, ankle = l[1], l[2], l[3], l[4], l[5]
		local hipP = P(s * hip.X, hip.Y, hip.Z)
		local la = { kind = "swing", axis = "X", amp = 7, speed = 1.5, phase = if i == 1 or i == 4 then 0 else math.pi, pivot = cf(hipP) }
		limb("Thigh" .. name, hipP, P(s * knee.X, knee.Y, knee.Z), 0.6, c.back, { anim = la })
		limb("Shin" .. name, P(s * knee.X, knee.Y, knee.Z), P(s * ankle.X, ankle.Y, ankle.Z), 0.42, c.back2, { anim = la })
		add("Foot" .. name, "Block", S(0.64, 0.2, 0.95), cf(P(s * ankle.X, -2.15, ankle.Z - 0.12)), c.back, { anim = la })
		for k = -1, 1, 2 do
			add("Claw" .. name .. k, "Wedge", S(0.14, 0.2, 0.38), cf(P(s * ankle.X + k * 0.2, -2.14, ankle.Z - 0.7)), c.gold, { mat = METAL, anim = la })
		end
	end

	-- TAIL: tapering balls sweeping back, gold spikes along the top, ends in a spiked fin
	local tailPts = {}
	local tailN = if meshes then 5 else 8
	for i = 0, 7 do
		table.insert(tailPts, P(0, -0.1 - i * 0.14, 1.5 + i * 0.58))
	end
	local pivot0 = tailPts[1]
	for i = 1, tailN do
		local r = 0.56 - (i - 1) * 0.055
		add("Tail" .. i, "Ball", S(r * 2, r * 1.8, r * 2.3), cf(tailPts[i]), if i % 2 == 0 then c.back2 else c.back, { anim = sway(2 + i * 1.2, 1.2, i * 0.4, pivot0) })
		if i % 2 == 1 then
			add("TailSpike" .. i, "Wedge", S(0.2, 0.45, 0.3), cf(tailPts[i] + v3(0, r * u * 0.9, 0)), c.gold, { mat = METAL, anim = sway(2 + i * 1.2, 1.2, i * 0.4, pivot0) })
		end
	end
	if meshes then
		table.insert(props, {
			n = "TailTip",
			on = "LowerTorso",
			model = "DragonTail",
			at = cf(tailPts[tailN]),
			fit = { axis = "Z", size = 3.2 * u },
			anim = sway(14, 1.2, 2.2, pivot0),
			colors = { Segments = c.back, Fin = { color = c.membrane, neon = true, trans = 0.25 }, Spikes = { color = c.gold, mat = METAL, skip = not DragonKit.SPIKES_FIXED } },
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
		add("TailFinV", "Block", S(0.06, 1.7, 1.5), cf(tip + D(0, 0, 0.85)), c.membrane, { neon = true, trans = 0.25, anim = a })
		add("TailFinH", "Block", S(1.8, 0.06, 1.5), cf(tip + D(0, 0, 0.85)), c.membrane, { neon = true, trans = 0.25, anim = a })
		add("TailTipSpike", "Wedge", S(0.26, 0.3, 0.9), cf(tip + D(0, 0, 1.8)) * CFrame.Angles(rad(90), 0, 0), c.gold, { mat = METAL, anim = a })
	end

	-- dorsal fins down the back (glowing), and the water glow underfoot
	for i, z in { 0.7, 0.0, -0.7 } do
		add(
			"DorsalFin" .. i,
			"Block",
			S(0.06, 0.8, 0.55),
			cf(P(0, 1.15, z)),
			c.membrane,
			{ neon = true, trans = 0.35, anim = { kind = "swing", axis = "X", amp = 5, speed = 2, phase = i } }
		)
	end
	fx[#fx + 1] = { on = "Body2", kind = "drop", color = rgb(170, 235, 255), rate = 14, size = 1.4 * u, aura = true }
	fx[#fx + 1] = { on = "Neck3", kind = "bubble", color = rgb(190, 235, 255), rate = 6, size = 1.2 * u, aura = true }
	fx[#fx + 1] = { on = "Eye1", kind = "spark", color = c.eye, rate = 3, size = 0.6 * u }
	return props, fx
end

-- The Dragon Pup: the same dragon at about a third of the size in warm colours.
function DragonKit.pup(meshes: boolean?): any
	local props, fx = DragonKit.build({ u = 0.4, colors = DragonKit.EMBER, meshes = meshes ~= false, flap = 22 })
	return { hideBody = true, scale = 1, skin = DragonKit.EMBER.back, props = props, fx = fx, light = Color3.fromRGB(255, 190, 120) }
end

return DragonKit
