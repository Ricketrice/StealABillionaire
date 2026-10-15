-- Studio location: ServerStorage.Build034.B2_SunkenKingdom (ModuleScript)
-- 034 Phase 2: Sunken Kingdom (terrace 2, ours, new). Underwater look without water (players walk normally):
-- coral entrance arch, the Shell Palace (signature landmark: pearl dome, scallop fan, spiral-shell towers),
-- sunken ruins, a kelp forest along the edges, coral clusters, glowing anemones, two bubble domes, light shafts,
-- bubble streams, treasure chests and little fish schools. The blue fog/tint is client-side (ZoneAmbience).
-- Parts tagged "AmbientBob" (attrs Amp, Speed, Phase) bob/sway on the client, only near the camera.
-- The terrace itself (sand, path, wall, railings) is built by Build027.B8_Lane (Lane.T2_SunkenKingdom).
-- Frame: u across (east +), v north from the terrace's south edge (z -404), h above the sand (y 24.0).

local Z = require(script.Parent.Z)
local K = Z.K
local rgb = Z.rgb

local O = Vector3.new(-157, 24.0, -404)
local at = Z.frame(O)

local C = {
	pearl = rgb(238, 236, 248),
	shellPink = rgb(250, 190, 196),
	shellPeach = rgb(252, 206, 160),
	lilac = rgb(196, 170, 236),
	teal = rgb(40, 170, 190),
	deep = rgb(30, 74, 110),
	kelp = rgb(70, 140, 70),
	kelpDark = rgb(46, 104, 60),
	coralPink = rgb(250, 110, 140),
	coralOrange = rgb(252, 150, 70),
	coralPurple = rgb(150, 90, 210),
	ruin = rgb(170, 182, 176),
	ruinDark = rgb(120, 134, 132),
	gold = rgb(240, 196, 70),
	wood = rgb(120, 82, 52),
	glow = rgb(120, 240, 230),
	ray = rgb(190, 235, 255),
	fishA = rgb(255, 170, 60),
	fishB = rgb(90, 200, 255),
}

local rng = Random.new(34)

local function bob(part: BasePart, amp: number, speed: number)
	K.tag(part, "AmbientBob")
	part:SetAttribute("Amp", amp)
	part:SetAttribute("Speed", speed)
	part:SetAttribute("Phase", rng:NextNumber(0, 6.28))
end

local function kelp(f: Instance, u: number, v: number, height: number)
	local m = Instance.new("Model")
	m.Name = "Kelp"
	local seg = height / 3
	local lean = rng:NextNumber(-8, 8)
	for i = 0, 2 do
		local p = Z.block(
			m,
			"Frond",
			Vector3.new(0.5, seg + 0.4, 1.4 - i * 0.25),
			CFrame.new(at(u + math.sin(math.rad(lean)) * seg * i, seg * (i + 0.5), v)) * CFrame.Angles(0, math.rad(rng:NextNumber(0, 180)), math.rad(lean * (i + 1) * 0.6)),
			if i == 2 then C.kelp else C.kelpDark,
			Enum.Material.SmoothPlastic,
			true
		)
		p.CastShadow = false
		if i == 2 then
			bob(p, 0.4, 0.8)
		end
	end
	m.Parent = f
end

local function coral(f: Instance, u: number, v: number, colour: Color3, size: number)
	local m = Instance.new("Model")
	m.Name = "Coral"
	Z.ball(m, "Mound", at(u, size * 0.25, v), size, colour, Enum.Material.Pebble, true)
	for k = 1, 3 do
		local a = math.rad(k * 120 + rng:NextNumber(-20, 20))
		local base = at(u + math.cos(a) * size * 0.3, size * 0.4, v + math.sin(a) * size * 0.3)
		Z.rod(m, "Branch", base, base + Vector3.new(math.cos(a) * size * 0.3, size * 0.8, -math.sin(a) * size * 0.3), size * 0.22, colour, Enum.Material.SmoothPlastic, true)
	end
	m.Parent = f
end

local function anemone(f: Instance, u: number, v: number, lit: boolean)
	Z.cyl(f, "AnemoneStalk", at(u, 0.8, v), 0.8, 1.6, C.lilac, nil, true)
	local tip = Z.ball(f, "AnemoneGlow", at(u, 1.9, v), 1.4, C.glow, Enum.Material.Neon, true)
	tip.CastShadow = false
	bob(tip, 0.15, 1.6)
	if lit then
		Z.light(tip, C.glow, 12, 0.8)
	end
end

local function fishSchool(f: Instance, centre: Vector3, colour: Color3)
	for k = 1, 4 do
		local pos = centre + Vector3.new(rng:NextNumber(-3, 3), rng:NextNumber(-1.5, 1.5), rng:NextNumber(-3, 3))
		local body = Z.ball(f, "Fish", pos, 1.1, colour, nil, true)
		body.Size = Vector3.new(1.6, 1, 0.7)
		body.Shape = Enum.PartType.Block
		local tail = K.part({
			name = "FishTail",
			parent = f,
			shape = "Wedge",
			size = Vector3.new(0.2, 0.9, 0.7),
			cf = CFrame.new(pos + Vector3.new(1.1, 0, 0)) * CFrame.Angles(0, math.rad(90), 0),
			color = colour,
			deco = true,
		})
		body.CastShadow, tail.CastShadow = false, false
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1 = body, tail
		weld.Parent = body
		bob(body, 0.8, 0.6 + k * 0.1)
	end
end

local function build(): string
	local world = workspace:WaitForChild("World")
	local f = K.folder(world, "SunkenKingdom", true)
	f:SetAttribute("Zone", "SunkenKingdom")

	-- entrance: coral arch over the path just past the gate -------------------------------------------
	local arch = K.folder(f, "CoralArch")
	for _, side in { -1, 1 } do
		Z.cyl(arch, "Pillar", at(side * 14, 6, 6), 3.4, 12, C.coralPink, Enum.Material.Pebble)
		Z.ball(arch, "PillarTop", at(side * 14, 12.4, 6), 4.4, C.coralOrange, Enum.Material.Pebble, true)
		coral(arch, side * 16.5, 3.5, C.coralPurple, 3)
	end
	Z.block(arch, "Span", Vector3.new(30, 2.2, 3), at(0, 13.6, 6), C.pearl, Enum.Material.Marble)
	K.part({
		name = "ShellCrest",
		parent = arch,
		shape = "Cylinder",
		size = Vector3.new(1, 9, 9),
		cf = CFrame.new(at(0, 16.2, 6)) * CFrame.Angles(0, math.rad(90), 0),
		color = C.shellPink,
		deco = true,
	})
	Z.sign(arch, CFrame.lookAt(at(0, 13.6, 4.4), at(0, 13.6, -10)), Vector3.new(18, 2, 0.3), "SUNKEN KINGDOM", C.deep, C.pearl)

	-- Shell Palace (signature landmark), west, near the far end ---------------------------------------
	local palace = K.folder(f, "ShellPalace")
	local pu, pv = -38, 122
	Z.cyl(palace, "Steps", at(pu, 0.6, pv), 30, 1.2, C.pearl, Enum.Material.Marble)
	Z.cyl(palace, "Drum", at(pu, 4, pv), 22, 6, C.shellPeach, Enum.Material.Marble)
	local dome = Z.ball(palace, "PearlDome", at(pu, 7, pv), 22, C.pearl, Enum.Material.Glass)
	dome.Reflectance = 0.15
	Z.ball(palace, "Pearl", at(pu, 19.6, pv), 3.4, C.pearl, Enum.Material.Glass, true).Reflectance = 0.3
	for k = 0, 5 do -- scallop fan behind the dome
		local a = math.rad(-75 + k * 30)
		K.part({
			name = "ShellRib",
			parent = palace,
			size = Vector3.new(3.4, 24, 0.8),
			cf = CFrame.new(at(pu - 9, 2, pv)) * CFrame.Angles(0, math.rad(90), 0) * CFrame.Angles(0, 0, a) * CFrame.new(0, 12, 0),
			color = if k % 2 == 0 then C.shellPink else C.shellPeach,
			mat = Enum.Material.Marble,
		})
	end
	for _, dv in { -11, 11 } do -- spiral-shell towers
		Z.cyl(palace, "TowerBody", at(pu + 6, 6, pv + dv), 5, 12, C.pearl, Enum.Material.Marble)
		Z.cone(palace, "SpiralShell", at(pu + 6, 12, pv + dv), 6, 9, C.lilac, Enum.Material.SmoothPlastic)
		Z.ball(palace, "TowerPearl", at(pu + 6, 21.6, pv + dv), 1.4, C.gold, nil, true)
	end
	for _, dv in { -5, 5 } do -- columns at the door
		Z.cyl(palace, "Column", at(pu + 11.5, 4, pv + dv), 1.6, 8, C.pearl, Enum.Material.Marble)
	end
	Z.block(palace, "Door", Vector3.new(0.4, 6, 6), at(pu + 11, 3.2, pv), C.deep, nil, true)
	Z.sign(palace, CFrame.lookAt(at(pu + 12.5, 9.4, pv), at(0, 9.4, pv)), Vector3.new(9, 1.6, 0.3), "SHELL PALACE", C.deep, C.gold)
	Z.light(Z.ball(palace, "Glow", at(pu + 13, 3, pv), 0.6, C.glow, Enum.Material.Neon, true), C.glow, 18, 1)

	-- sunken ruins, east --------------------------------------------------------------------------------
	local ruins = K.folder(f, "Ruins")
	local ru, rv = 40, 118
	Z.block(ruins, "Floor", Vector3.new(26, 0.8, 30), at(ru, 0.4, rv), C.ruinDark, Enum.Material.Slate, true)
	for k, c in { { -10, -12, 9 }, { 10, -12, 5 }, { -10, 12, 7 }, { 10, 12, 10 }, { 0, -12, 3 } } do
		local col = Z.cyl(ruins, "Column", at(ru + c[1], c[3] / 2 + 0.8, rv + c[2]), 2.2, c[3], C.ruin, Enum.Material.Limestone)
		col.CFrame = col.CFrame * CFrame.Angles(math.rad(rng:NextNumber(-6, 6)), 0, 0)
		if k % 2 == 0 then
			Z.block(ruins, "Capital", Vector3.new(3, 0.8, 3), at(ru + c[1], c[3] + 1.2, rv + c[2]), C.ruin, Enum.Material.Limestone, true)
		end
	end
	Z.block(ruins, "Lintel", Vector3.new(3, 1.6, 22), CFrame.new(at(ru - 10, 8.4, rv + 1)) * CFrame.Angles(math.rad(8), 0, 0), C.ruin, Enum.Material.Limestone)
	Z.rod(ruins, "FallenColumn", at(ru + 4, 1.9, rv + 2), at(ru + 12, 1.9, rv - 4), 2.2, C.ruin, Enum.Material.Limestone)
	Z.ball(ruins, "StatueHead", at(ru + 2, 2, rv + 8), 4, C.ruin, Enum.Material.Limestone)
	for k = 1, 3 do
		local jar = Z.cyl(ruins, "Amphora", at(ru - 4 + k * 3, 1.3, rv - 9), 1.6, 2.4, C.coralOrange, Enum.Material.Slate, true)
		jar.CFrame = jar.CFrame * CFrame.Angles(math.rad(k * 20), 0, 0)
	end
	Z.sign(ruins, CFrame.lookAt(at(ru - 13.5, 1.6, rv - 14), at(0, 1.6, rv - 14)), Vector3.new(6, 1.2, 0.3), "OLD RUINS", C.deep, C.pearl)

	-- kelp forest, coral, anemones ---------------------------------------------------------------------
	local life = K.folder(f, "SeaLife")
	for k = 1, 14 do
		local side = if k % 2 == 0 then -1 else 1
		local u = side * rng:NextNumber(48, 61)
		local v = 8 + (k - 1) * 10.5 + rng:NextNumber(-3, 3)
		if not (side < 0 and v > 100 and v < 145) and not (side > 0 and v > 100 and v < 135) then
			kelp(life, u, v, rng:NextNumber(10, 16))
		end
	end
	local coralSpots = { { -24, 22 }, { 26, 30 }, { -30, 60 }, { 30, 66 }, { -22, 96 }, { 24, 92 }, { -55, 40 }, { 56, 52 }, { 18, 150 }, { -20, 152 } }
	local colours = { C.coralPink, C.coralOrange, C.coralPurple }
	for k, s in coralSpots do
		coral(life, s[1], s[2], colours[k % 3 + 1], rng:NextNumber(2.6, 4))
	end
	for k, s in { { -20, 40 }, { 21, 48 }, { -19, 78 }, { 20, 84 }, { -45, 92 }, { 46, 80 }, { -50, 12 }, { 50, 20 } } do
		anemone(life, s[1], s[2], k <= 4)
	end
	for k = 1, 16 do -- shells on the sand
		local u = rng:NextNumber(-60, 60)
		if math.abs(u) > 14 then
			local shell = K.part({
				name = "Shell",
				parent = life,
				shape = "Cylinder",
				size = Vector3.new(0.3, 1.2, 1.2),
				cf = CFrame.new(at(u, 0.15, rng:NextNumber(10, 155))) * CFrame.Angles(0, rng:NextNumber(0, 6), math.rad(90)),
				color = if k % 2 == 0 then C.shellPink else C.shellPeach,
				deco = true,
			})
			shell.CastShadow = false
		end
	end

	-- bubble domes (glass), each over a small coral garden --------------------------------------------
	local domes = K.folder(f, "BubbleDomes")
	for _, s in { { -36, 44 }, { 36, 40 } } do
		Z.cyl(domes, "DomeRing", at(s[1], 0.3, s[2]), 15, 0.6, C.pearl, Enum.Material.Marble, true)
		local glass = Z.ball(domes, "Dome", at(s[1], 0, s[2]), 14, C.ray, Enum.Material.Glass, true)
		glass.Transparency = 0.65
		glass.CastShadow = false
		coral(domes, s[1], s[2], C.coralPink, 3.4)
		Z.particles(Z.block(domes, "BubbleSource", Vector3.new(0.4, 0.4, 0.4), at(s[1], 6.6, s[2]), C.ray, nil, true), "bubbles", 3)
	end

	-- treasure chests -------------------------------------------------------------------------------
	for _, s in { { -48, 70 }, { 52, 140 } } do
		local chest = Z.block(f, "Chest", Vector3.new(3, 2, 2), at(s[1], 1, s[2]), C.wood, Enum.Material.WoodPlanks, true)
		Z.block(f, "ChestLid", Vector3.new(3.1, 0.8, 2.1), CFrame.new(at(s[1], 2.4, s[2] + 0.3)) * CFrame.Angles(math.rad(-25), 0, 0), C.wood, Enum.Material.WoodPlanks, true)
		local gold = Z.block(f, "Coins", Vector3.new(2.6, 0.4, 1.6), at(s[1], 2.1, s[2]), C.gold, Enum.Material.Neon, true)
		gold.CastShadow = false
		Z.particles(gold, "sparkle", 2)
		chest.CastShadow = true
	end

	-- light shafts + bubble streams + fish ------------------------------------------------------------
	local fx = K.folder(f, "Ambience")
	for k, s in { { -30, 30 }, { 25, 58 }, { -10, 92 }, { 34, 112 }, { -40, 150 }, { 8, 140 } } do
		local shaft = Z.block(
			fx,
			"LightShaft",
			Vector3.new(5, 46, 5),
			CFrame.new(at(s[1], 22, s[2])) * CFrame.Angles(math.rad(14), math.rad(k * 23), math.rad(10)),
			C.ray,
			Enum.Material.Neon,
			true
		)
		shaft.Transparency = 0.88
		shaft.CastShadow = false
	end
	for _, s in { { -58, 30 }, { 58, 75 }, { -58, 140 }, { 60, 150 }, { -12, 70 }, { 12, 120 } } do
		local src = Z.block(fx, "BubbleSource", Vector3.new(0.4, 0.4, 0.4), at(s[1], 0.5, s[2]), C.ray, nil, true)
		src.Transparency = 1
		Z.particles(src, "bubbles", 4)
	end
	for k, s in { { -25, 10, 70 }, { 30, 12, 100 }, { 0, 14, 40 } } do
		fishSchool(fx, at(s[1], s[2], s[3]), if k % 2 == 0 then C.fishB else C.fishA)
	end

	return ("Sunken Kingdom: %d parts"):format(K.count(f))
end

return { build = build }
