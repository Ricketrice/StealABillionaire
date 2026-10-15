-- Studio location: ServerStorage.Build034.B3_EmberAcademy (ModuleScript)
-- 034 Phase 2: Ember Academy (terrace 3, the old Zone 6 island moved down; internal zone id BillionaireHills).
-- Fire as MAGIC, not a volcano: the Ember Spire (signature landmark: tall tower under a giant floating fire
-- crystal), three wizard towers with fire-crystal tops, a lantern-lit library with floating books, a brass
-- alchemy lab, rune circles in the courtyard, floating spellbooks, braziers and a stone balustrade round the
-- island. Palette: warm stone, deep plum, brass, ember orange glow.
-- Parks (once): the Velocity Royale look (VelocityRoyale_016B, Gateway, RoyaleFlame, WinnersPodium, the rest of
-- the old locked-villa entrance, the Zone 6 plaza art) -> _Parked034.EmberAcademy. Keeps the island, bridge, gate,
-- NPC area (Workspace.Zones.BillionaireHills) and the rocks/clouds under the rim (Summit031, moved here).
-- The Spell Run course is its own builder (B4_SpellRun). Parts tagged "AmbientBob" bob on the client.
-- Frame: u across (east +), v north from z -700 (the island's south edge), h above the island top (y 36.3).

local Z = require(script.Parent.Z)
local K = Z.K
local rgb = Z.rgb

local O = Vector3.new(-157, 36.3, -700)
local at = Z.frame(O)

local C = {
	stone = rgb(214, 196, 170),
	stoneDark = rgb(150, 128, 112),
	plum = rgb(92, 54, 112),
	plumDark = rgb(64, 36, 84),
	brass = rgb(214, 160, 70),
	ember = rgb(255, 120, 40),
	emberLight = rgb(255, 180, 90),
	glow = rgb(255, 196, 120),
	slit = rgb(46, 30, 40),
	paving = rgb(176, 150, 150),
	rune = rgb(255, 140, 60),
	book1 = rgb(170, 50, 50),
	book2 = rgb(60, 80, 160),
	book3 = rgb(60, 130, 80),
	pages = rgb(246, 236, 210),
	glass = rgb(200, 230, 240),
	potionA = rgb(120, 255, 140),
	potionB = rgb(255, 90, 200),
	potionC = rgb(90, 200, 255),
}

local rng = Random.new(343)

local function fireCrystal(parent: Instance, base: Vector3, size: number, floating: boolean)
	local m = Z.crystal(parent, "FireCrystal", base, size * 0.55, size, C.ember, rng:NextNumber(0, 90))
	local core = m:FindFirstChildWhichIsA("BasePart") :: BasePart
	local glowPart = Z.ball(m, "Core", base + Vector3.new(0, size / 2, 0), size * 0.3, C.emberLight, Enum.Material.Neon, true)
	glowPart.Transparency = 0.3
	Z.light(glowPart, C.ember, size * 3, 1.4)
	Z.particles(glowPart, "embers", 3)
	if floating then
		m.PrimaryPart = glowPart
		K.tag(m, "AmbientBob")
		m:SetAttribute("Amp", size * 0.08)
		m:SetAttribute("Speed", 0.7)
		m:SetAttribute("Phase", rng:NextNumber(0, 6.28))
	end
	return m, core
end

local function wizardTower(f: Instance, u: number, v: number, height: number, diameter: number, name: string)
	local m = Instance.new("Model")
	m.Name = name
	Z.cyl(m, "Base", at(u, 0.8, v), diameter + 2, 1.6, C.stoneDark, Enum.Material.Slate)
	Z.cyl(m, "Body", at(u, height / 2, v), diameter, height, C.stone, Enum.Material.Limestone)
	for _, h in { height * 0.33, height * 0.66 } do
		Z.cyl(m, "BrassBand", at(u, h, v), diameter + 0.6, 0.7, C.brass, Enum.Material.Metal, true)
	end
	-- windows (warm glow) on the courtyard side
	local toward = (Vector3.new(O.X, 0, O.Z - 60) - Vector3.new(at(u, 0, v).X, 0, at(u, 0, v).Z)).Unit
	for _, h in { height * 0.5, height * 0.8 } do
		local p = at(u, h, v) + toward * (diameter / 2 - 0.05)
		local win = Z.block(m, "Window", Vector3.new(1.8, 3, 0.3), CFrame.lookAt(p, p + toward), C.glow, Enum.Material.Neon, true)
		win.CastShadow = false
	end
	Z.cyl(m, "Balcony", at(u, height + 0.5, v), diameter + 3, 1, C.stoneDark, Enum.Material.Slate, true)
	for k = 0, 5 do
		local a = math.rad(k * 60)
		Z.block(
			m,
			"Pillar",
			Vector3.new(0.7, 3, 0.7),
			at(u + math.cos(a) * (diameter / 2 + 1), height + 2.5, v + math.sin(a) * (diameter / 2 + 1)),
			C.brass,
			Enum.Material.Metal,
			true
		)
	end
	Z.cone(m, "Roof", at(u, height + 4, v), diameter + 2, 5, C.plum, Enum.Material.SmoothPlastic)
	fireCrystal(m, at(u, height + 9.5, v), 5, true)
	m.Parent = f
	return m
end

local function spellbook(f: Instance, pos: Vector3, colour: Color3, yaw: number)
	local m = Instance.new("Model")
	m.Name = "Spellbook"
	local cf = CFrame.new(pos) * CFrame.Angles(0, math.rad(yaw), 0) * CFrame.Angles(math.rad(-20), 0, 0)
	local cover = Z.block(m, "Cover", Vector3.new(2.6, 0.4, 3.4), cf, colour, Enum.Material.Fabric, true)
	Z.block(m, "Pages", Vector3.new(2.4, 0.3, 3.2), cf * CFrame.new(0, 0.32, 0), C.pages, nil, true)
	local rune = Z.block(m, "Rune", Vector3.new(0.9, 0.05, 0.9), cf * CFrame.new(0, 0.5, 0), C.rune, Enum.Material.Neon, true)
	rune.CastShadow = false
	m.PrimaryPart = cover
	K.tag(m, "AmbientBob")
	m:SetAttribute("Amp", 0.6)
	m:SetAttribute("Speed", 0.9)
	m:SetAttribute("Phase", rng:NextNumber(0, 6.28))
	m.Parent = f
end

local function runeCircle(f: Instance, u: number, v: number, d: number)
	local ring = Z.cyl(f, "RuneRing", at(u, 0.06, v), d, 0.1, C.rune, Enum.Material.Neon, true)
	ring.CastShadow = false
	Z.cyl(f, "RuneInner", at(u, 0.08, v), d - 1.2, 0.1, C.paving, Enum.Material.Slate, true)
	local star = Z.cyl(f, "RuneCore", at(u, 0.1, v), d * 0.25, 0.1, C.rune, Enum.Material.Neon, true)
	star.CastShadow = false
	for k = 0, 3 do
		local a = math.rad(45 + k * 90)
		Z.block(f, "RuneStone", Vector3.new(1, 2.2, 1), at(u + math.cos(a) * (d / 2 + 1.2), 1.1, v + math.sin(a) * (d / 2 + 1.2)), C.stoneDark, Enum.Material.Slate, true)
	end
end

local function lantern(f: Instance, u: number, v: number, lit: boolean)
	Z.cyl(f, "LanternPost", at(u, 3, v), 0.5, 6, C.plumDark, Enum.Material.Metal, true)
	Z.block(f, "LanternArm", Vector3.new(0.3, 0.3, 1.4), at(u, 6, v + 0.6), C.plumDark, Enum.Material.Metal, true)
	local lamp = Z.block(f, "Lantern", Vector3.new(1, 1.4, 1), at(u, 5.4, v + 1.2), C.glow, Enum.Material.Neon, true)
	lamp.CastShadow = false
	Z.block(f, "LanternCap", Vector3.new(1.3, 0.3, 1.3), at(u, 6.2, v + 1.2), C.brass, Enum.Material.Metal, true)
	if lit then
		Z.light(lamp, C.glow, 14, 1)
	end
end

local function build(): string
	local world = workspace:WaitForChild("World")
	local parked = 0
	local vr = world:FindFirstChild("VelocityRoyale")
	if vr then
		for _, name in { "VelocityRoyale_016B", "Gateway", "RoyaleFlame", "WinnersPodium" } do
			parked += Z.park(vr:FindFirstChild(name), "EmberAcademy")
		end
	end
	parked += Z.park(world.LockedZoneEntrances:FindFirstChild("BillionaireHills"), "EmberAcademy")
	parked += Z.park(world.DistrictArchitecture:FindFirstChild("BillionaireHills"), "EmberAcademy")
	parked += Z.park(world.BillionaireCity:FindFirstChild("Zone6Plaza"), "EmberAcademy")

	local f = K.folder(world, "EmberAcademy", true)
	f:SetAttribute("Zone", "BillionaireHills")
	-- what stays from the old strip lives on here (the course template is parented here by RaceService)
	if vr then
		local summit = vr:FindFirstChild("Summit031")
		if summit then
			summit.Parent = f
		end
	end

	-- avenue from the bridge to the climb onward (z -700 .. -838) ---------------------------------------
	local avenue = K.folder(f, "Avenue")
	K.slab(avenue, "Avenue", O.X - 8, O.X + 8, O.Z - 138, O.Z + 2, O.Y + 0.1, 0.2, C.paving, Enum.Material.Slate).CanCollide = false
	for _, side in { -1, 1 } do
		K.slab(avenue, "Edge", O.X + side * 8.5 - 0.5, O.X + side * 8.5 + 0.5, O.Z - 138, O.Z + 2, O.Y + 0.14, 0.2, C.brass, Enum.Material.Metal).CanCollide = false
		for k, v in { 20, 50, 80, 110 } do
			lantern(avenue, side * 10, v, k % 2 == 0)
		end
	end
	for _, s in { { -12, 64 }, { 12, 64 }, { -12, 128 }, { 12, 128 } } do
		Z.cyl(avenue, "Brazier", at(s[1], 1.6, s[2]), 1, 3.2, C.plumDark, Enum.Material.Metal, true)
		local bowl = Z.cyl(avenue, "BrazierBowl", at(s[1], 3.4, s[2]), 2.6, 0.8, C.brass, Enum.Material.Metal, true)
		Z.flame(bowl, 2.5)
	end

	-- entrance arch over the neck ----------------------------------------------------------------------
	local arch = K.folder(f, "EntranceArch")
	for _, side in { -1, 1 } do
		Z.block(arch, "ArchBase", Vector3.new(4.6, 1.2, 4.6), at(side * 12, 0.6, 2), C.stoneDark, Enum.Material.Slate, true)
		Z.block(arch, "ArchPillar", Vector3.new(3.6, 16, 3.6), at(side * 12, 8, 2), C.stone, Enum.Material.Limestone)
		fireCrystal(arch, at(side * 12, 16.2, 2), 3.4, false)
	end
	Z.block(arch, "ArchBeam", Vector3.new(28, 2.4, 3), at(0, 13.4, 2), C.plum, Enum.Material.SmoothPlastic)
	Z.block(arch, "ArchTrim", Vector3.new(28.4, 0.5, 3.4), at(0, 12, 2), C.brass, Enum.Material.Metal, true)
	Z.sign(arch, CFrame.lookAt(at(0, 13.4, 0.4), at(0, 13.4, -20)), Vector3.new(20, 2, 0.3), "EMBER ACADEMY", C.plumDark, C.emberLight)

	-- rune circles in the courtyard (the catching area) --------------------------------------------------
	local runes = K.folder(f, "RuneCircles")
	runeCircle(runes, -26, 45, 12)
	runeCircle(runes, 30, 62, 10)

	-- the Ember Spire (signature landmark), north-west ---------------------------------------------------
	local spire = Instance.new("Model")
	spire.Name = "EmberSpire"
	local su, sv = -36, 108
	Z.cyl(spire, "Base", at(su, 1, sv), 22, 2, C.stoneDark, Enum.Material.Slate)
	Z.cyl(spire, "Lower", at(su, 9, sv), 17, 14, C.stone, Enum.Material.Limestone)
	Z.cyl(spire, "LowerBand", at(su, 16.4, sv), 18, 0.8, C.brass, Enum.Material.Metal, true)
	Z.cyl(spire, "Upper", at(su, 27, sv), 13, 22, C.stone, Enum.Material.Limestone)
	for _, h in { 24, 33 } do
		Z.cyl(spire, "UpperBand", at(su, h, sv), 13.8, 0.7, C.brass, Enum.Material.Metal, true)
	end
	Z.cyl(spire, "Crown", at(su, 38.6, sv), 16, 1.2, C.plum, Enum.Material.SmoothPlastic)
	for k = 0, 5 do
		local a = math.rad(k * 60)
		Z.block(spire, "CrownSpike", Vector3.new(1.2, 4, 1.2), at(su + math.cos(a) * 7.2, 41, sv + math.sin(a) * 7.2), C.plum, Enum.Material.SmoothPlastic, true)
	end
	local door = at(su + 8.6, 4, sv)
	Z.block(spire, "Door", Vector3.new(0.4, 6, 4), door, C.slit, nil, true)
	Z.block(spire, "DoorGlow", Vector3.new(0.3, 5.4, 3.4), door + Vector3.new(0.15, 0, 0), C.glow, Enum.Material.Neon, true).Transparency = 0.4
	for _, h in { 12, 22, 30 } do
		local p = at(su + (if h < 16 then 8.5 else 6.5), h, sv)
		Z.block(spire, "Window", Vector3.new(0.3, 3, 1.8), p, C.glow, Enum.Material.Neon, true).CastShadow = false
	end
	spire.Parent = f
	fireCrystal(f, at(su, 46, sv), 9, true).Name = "SpireCrystal"
	Z.sign(f, CFrame.lookAt(at(su + 12.5, 3.4, sv - 8), at(0, 3.4, sv - 8)), Vector3.new(8, 1.6, 0.3), "EMBER SPIRE", C.plumDark, C.emberLight)

	-- wizard towers --------------------------------------------------------------------------------------
	local towers = K.folder(f, "WizardTowers")
	wizardTower(towers, -58, 22, 24, 9, "TowerSouthWest")
	wizardTower(towers, 56, 24, 22, 8, "TowerSouthEast")
	wizardTower(towers, -60, 124, 26, 9, "TowerNorthWest")

	-- lantern-lit library, north-east ---------------------------------------------------------------------
	local lib = Instance.new("Model")
	lib.Name = "Library"
	local lu, lv = 38, 100
	Z.block(lib, "Plinth", Vector3.new(28, 1.2, 16), at(lu, 0.6, lv), C.stoneDark, Enum.Material.Slate)
	Z.block(lib, "Walls", Vector3.new(26, 13, 14), at(lu, 7.7, lv), C.stone, Enum.Material.Limestone)
	Z.block(lib, "Cornice", Vector3.new(27.4, 1, 15.4), at(lu, 14.6, lv), C.brass, Enum.Material.Metal, true)
	for _, side in { -1, 1 } do
		K.part({
			name = "Roof",
			parent = lib,
			shape = "Wedge",
			size = Vector3.new(27.6, 6, 8),
			cf = CFrame.new(at(lu, 18.1, lv + side * 3.9)) * CFrame.Angles(0, if side > 0 then math.pi else 0, 0),
			color = C.plum,
			mat = Enum.Material.Slate,
		})
	end
	for k = -2, 2 do -- tall warm windows on the courtyard (west) face
		if k ~= 0 then
			Z.block(lib, "Window", Vector3.new(0.3, 7, 2.6), at(lu - 13.1, 7.5, lv + k * 5), C.glow, Enum.Material.Neon, true).CastShadow = false
		end
	end
	Z.block(lib, "Door", Vector3.new(0.4, 7, 4), at(lu - 13.1, 4.6, lv), C.plumDark, nil, true)
	Z.sign(lib, CFrame.lookAt(at(lu - 13.6, 11.6, lv), at(0, 11.6, lv)), Vector3.new(10, 1.8, 0.3), "LIBRARY", C.plumDark, C.emberLight)
	lib.Parent = f
	for _, dv in { -5, 5 } do
		lantern(f, lu - 16, lv + dv, true)
	end
	for k = 1, 4 do
		spellbook(f, at(lu - 20 + k * 2, 8 + k, lv - 14 + k * 4), ({ C.book1, C.book2, C.book3 })[k % 3 + 1], k * 40)
	end

	-- brass alchemy lab, west ------------------------------------------------------------------------------
	local lab = K.folder(f, "AlchemyLab")
	local au, av = -56, 72
	Z.block(lab, "Floor", Vector3.new(16, 0.6, 14), at(au, 0.3, av), C.stoneDark, Enum.Material.Slate, true)
	for _, c in { { -7, -6 }, { 7, -6 }, { -7, 6 }, { 7, 6 } } do
		Z.cyl(lab, "Post", at(au + c[1], 5, av + c[2]), 0.8, 10, C.brass, Enum.Material.Metal)
	end
	Z.block(lab, "Canopy", Vector3.new(17, 0.8, 15), at(au, 10.4, av), C.plum, Enum.Material.Fabric, true)
	Z.block(lab, "Table", Vector3.new(3, 3, 10), at(au + 3, 1.5, av), C.stoneDark, Enum.Material.WoodPlanks, true)
	for k, colour in { C.potionA, C.potionB, C.potionC } do
		Z.cyl(lab, "Flask", at(au + 3, 3.6, av - 4 + k * 2), 1, 1.4, colour, Enum.Material.Neon, true).CastShadow = false
		Z.ball(lab, "FlaskBulb", at(au + 3, 3.1, av - 4 + k * 2), 1.4, C.glass, Enum.Material.Glass, true).Transparency = 0.5
	end
	Z.cyl(lab, "Cauldron", at(au - 3, 1.6, av - 2), 4.4, 3.2, C.plumDark, Enum.Material.Metal, true)
	local brew = Z.cyl(lab, "Brew", at(au - 3, 3.25, av - 2), 3.8, 0.2, C.potionA, Enum.Material.Neon, true)
	Z.particles(brew, "bubbles", 4)
	Z.light(brew, C.potionA, 12, 0.8)
	Z.rod(lab, "Pipe", at(au - 6, 1, av + 4), at(au - 6, 8, av + 4), 0.8, C.brass, Enum.Material.Metal, true)
	Z.rod(lab, "Pipe", at(au - 6, 8, av + 4), at(au + 3, 8, av + 4), 0.8, C.brass, Enum.Material.Metal, true)
	local furnace = Z.block(lab, "Furnace", Vector3.new(3, 3, 3), at(au - 6, 1.5, av + 4), C.stoneDark, Enum.Material.Brick, true)
	Z.flame(furnace, 1.6)
	Z.sign(lab, CFrame.lookAt(at(au + 8.6, 8.6, av), at(0, 8.6, av)), Vector3.new(7, 1.4, 0.3), "ALCHEMY LAB", C.plumDark, C.brass)

	-- floating spellbooks over the courtyard ---------------------------------------------------------------
	local books = K.folder(f, "FloatingBooks")
	for k, s in { { -20, 30 }, { 20, 36 }, { -34, 70 }, { 28, 80 }, { -16, 96 }, { 14, 18 } } do
		spellbook(books, at(s[1], 7 + (k % 3), s[2]), ({ C.book1, C.book2, C.book3 })[k % 3 + 1], k * 55)
	end

	-- balustrade round the main island (Land1: x -228..-85, z -711..-830), gaps for the avenue + the course --
	local rail = K.folder(f, "Balustrade")
	local x0, x1, z0, z1 = -227, -86, -711.5, -829.5
	local function railRun(a: Vector3, b: Vector3)
		local len = (b - a).Magnitude
		if len < 1 then
			return
		end
		local mid = (a + b) / 2
		K.part({
			name = "RailBase",
			parent = rail,
			size = Vector3.new(1.4, 1.2, len),
			cf = CFrame.lookAt(mid + Vector3.new(0, 0.6, 0), b + Vector3.new(0, 0.6, 0)),
			color = C.stoneDark,
			mat = Enum.Material.Slate,
		})
		K.part({
			name = "RailTop",
			parent = rail,
			size = Vector3.new(1.2, 0.6, len),
			cf = CFrame.lookAt(mid + Vector3.new(0, 3, 0), b + Vector3.new(0, 3, 0)),
			color = C.brass,
			mat = Enum.Material.Metal,
		})
		local posts = math.max(2, math.floor(len / 12) + 1)
		for i = 0, posts - 1 do
			local p = a:Lerp(b, i / (posts - 1))
			K.part({ name = "RailPost", parent = rail, size = Vector3.new(1.2, 3, 1.2), pos = p + Vector3.new(0, 1.5, 0), color = C.stone, mat = Enum.Material.Limestone })
		end
	end
	local y = O.Y
	-- south edge (the neck x -191..-136 joins here), west edge, north edge (gap: the climb onward x -169..-145 and
	-- the Spell Run finish ramp x -105..-95), east edge (gap: the Spell Run start bridge z -765..-755)
	railRun(Vector3.new(x0, y, z0), Vector3.new(-192, y, z0))
	railRun(Vector3.new(-135, y, z0), Vector3.new(x1, y, z0))
	railRun(Vector3.new(x0, y, z0), Vector3.new(x0, y, z1))
	railRun(Vector3.new(x0, y, z1), Vector3.new(-170, y, z1))
	railRun(Vector3.new(-144, y, z1), Vector3.new(-106, y, z1))
	railRun(Vector3.new(-94, y, z1), Vector3.new(x1, y, z1))
	railRun(Vector3.new(x1, y, z0), Vector3.new(x1, y, -754))
	railRun(Vector3.new(x1, y, -766), Vector3.new(x1, y, z1))

	return ("Ember Academy: %d parts (parked %d)"):format(K.count(f), parked)
end

return { build = build }
