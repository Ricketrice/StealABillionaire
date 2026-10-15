-- Studio location: ServerStorage.Build034.B4_SpellRun (ModuleScript)
-- 034 Phase 3: Spell Run, the Ember Academy parkour race (replaces the Velocity Royale circuit; same race system).
-- A horizontal course off the island's east edge that climbs a little and comes back: rune bridge -> floating
-- platforms (climbing) -> three slow sliding spellbooks -> a rising rune bridge -> platforms back down -> a ramp to the
-- finish arch on the island. Wide platforms, gaps of 3-6 studs, rises of 2: phone-friendly, no precision jumps.
-- Builds two things:
--   * World.EmberAcademy.SpellRun: the course itself (always there). Moving books are Models tagged "SpellBook"
--     (attrs Axis, Amp, Period, Phase; the client slides them, ZoneAmbience). `FallZone` (ghost box) + `PadSpot`:
--     whoever falls below the course is popped back (RaceService: racers to their last rune gate, others to PadSpot).
--   * ServerStorage.SpellRunCourse034: the race template RaceService clones while the race is on (StartPad, Sign,
--     OddsBoard, Name1..3 over the podium, SafeVolume(s) tagged PvPSafeZone, Gates.CP1..5 + Finish, Walls).
-- Coordinates: world, island top Y0 = 36.3.

local ServerStorage = game:GetService("ServerStorage")

local Z = require(script.Parent.Z)
local K = Z.K
local rgb = Z.rgb

local Y0 = 36.3

local C = {
	stone = rgb(204, 186, 162),
	stoneDark = rgb(140, 118, 104),
	brass = rgb(214, 160, 70),
	rune = rgb(255, 140, 60),
	runeBlue = rgb(120, 200, 255),
	plum = rgb(92, 54, 112),
	plumDark = rgb(64, 36, 84),
	pages = rgb(246, 236, 210),
	book = { rgb(170, 50, 50), rgb(60, 80, 160), rgb(60, 130, 80) },
	gold = rgb(240, 196, 70),
	silver = rgb(214, 220, 230),
	bronze = rgb(200, 130, 80),
	pad = rgb(255, 150, 60),
}

-- course points (world), in race order
local PAD = Vector3.new(-95, Y0, -760)
local BRIDGE_A = { from = Vector3.new(-88, Y0, -760), to = Vector3.new(-42, Y0, -760) }
local FIELD1 = { { -36, 2, -774 }, { -26, 4, -790 }, { -38, 6, -806 }, { -27, 8, -822 }, { -37, 10, -838 } }
local L1 = Vector3.new(-34, Y0 + 12, -858)
local BOOKS = { { -34, 12.5, -876 }, { -34, 13, -892 }, { -34, 13.5, -908 } }
local L2 = Vector3.new(-34, Y0 + 14, -926)
local BRIDGE_B = { from = Vector3.new(-42, Y0 + 14, -926), to = Vector3.new(-92, Y0 + 18, -926) }
local L3 = Vector3.new(-100, Y0 + 18, -926)
local FIELD2 = { { -100, 16, -910 }, { -100, 14, -894 }, { -100, 12, -878 }, { -100, 10, -862 } }
local RAMP = { high = Vector3.new(-100, Y0 + 10, -856), low = Vector3.new(-100, Y0, -834) }
local FINISH = Vector3.new(-100, Y0, -824)
local PODIUM = Vector3.new(-116, Y0, -812) -- west of the finish path (the island rail is at x -86)

local function platform(f: Instance, name: string, centreTop: Vector3, w: number, d: number): BasePart
	local body = Z.block(f, name, Vector3.new(w, 2, d), centreTop - Vector3.new(0, 1, 0), C.stone, Enum.Material.Limestone)
	local rim = Z.block(f, name .. "Rim", Vector3.new(w + 0.6, 0.5, d + 0.6), centreTop - Vector3.new(0, 2.1, 0), C.brass, Enum.Material.Metal, true)
	rim.CastShadow = false
	local disc = Z.cyl(f, "RuneDisc", centreTop + Vector3.new(0, 0.06, 0), math.min(w, d) * 0.7, 0.1, C.rune, Enum.Material.Neon, true)
	disc.Transparency = 0.35
	disc.CastShadow = false
	return body
end

-- A rune arch over the path at `cf` (looking along the direction of travel), `w` wide.
local function arch(f: Instance, name: string, cf: CFrame, w: number, colour: Color3)
	local m = Instance.new("Model")
	m.Name = name
	for _, side in { -1, 1 } do
		Z.block(m, "Pillar", Vector3.new(1.4, 9, 1.4), cf * CFrame.new(side * (w / 2 + 0.7), 4.5, 0), C.stoneDark, Enum.Material.Slate, true)
	end
	Z.block(m, "Beam", Vector3.new(w + 3, 1.2, 1.4), cf * CFrame.new(0, 9.6, 0), C.plum, nil, true)
	local band = Z.block(m, "Runes", Vector3.new(w + 1, 0.5, 1.5), cf * CFrame.new(0, 8.8, 0), colour, Enum.Material.Neon, true)
	band.CastShadow = false
	m.Parent = f
	return m
end

local function bridge(f: Instance, walls: Folder?, a: Vector3, b: Vector3, w: number)
	local len = (b - a).Magnitude
	local cf = CFrame.lookAt((a + b) / 2, b)
	Z.block(f, "Bridge", Vector3.new(w, 1.2, len), cf * CFrame.new(0, -0.6, 0), C.stone, Enum.Material.Limestone)
	for _, side in { -1, 1 } do
		local edge = Z.block(f, "RuneEdge", Vector3.new(0.6, 0.2, len), cf * CFrame.new(side * (w / 2 - 0.4), 0.05, 0), C.rune, Enum.Material.Neon, true)
		edge.CastShadow = false
		Z.block(f, "BridgeRim", Vector3.new(0.8, 0.8, len), cf * CFrame.new(side * (w / 2 + 0.3), -1.1, 0), C.brass, Enum.Material.Metal, true)
		if walls then
			local wall = K.part({ name = "Wall", parent = walls, size = Vector3.new(0.6, 6, len), cf = cf * CFrame.new(side * (w / 2 + 0.3), 3, 0), color = C.rune })
			wall.Transparency = 1
			wall.CanQuery, wall.CanTouch = false, false
		end
	end
end

local function book(f: Instance, centreTop: Vector3, colour: Color3, phase: number): Model
	local m = Instance.new("Model")
	m.Name = "SpellBook"
	local cover = Z.block(m, "Cover", Vector3.new(16, 1.4, 10), centreTop - Vector3.new(0, 1.3, 0), colour, Enum.Material.Fabric)
	Z.block(m, "Pages", Vector3.new(15.2, 0.6, 9.4), centreTop - Vector3.new(0, 0.3, 0), C.pages, Enum.Material.SmoothPlastic)
	Z.block(m, "Spine", Vector3.new(16.4, 2, 1), centreTop - Vector3.new(0, 1, 5), colour, Enum.Material.Fabric, true)
	local rune = Z.cyl(m, "Rune", centreTop + Vector3.new(0, 0.06, 0), 4, 0.1, C.runeBlue, Enum.Material.Neon, true)
	rune.CastShadow = false
	m.PrimaryPart = cover
	K.tag(m, "SpellBook")
	m:SetAttribute("Axis", Vector3.new(1, 0, 0))
	m:SetAttribute("Amp", 4)
	m:SetAttribute("Period", 6)
	m:SetAttribute("Phase", phase)
	m.Parent = f
	return m
end

local function gateBox(gates: Folder, name: string, order: number, cf: CFrame, size: Vector3)
	local g = K.part({ name = name, parent = gates, ghost = true, size = size, cf = cf })
	g:SetAttribute("Order", order)
end

local function build(): string
	local world = workspace:WaitForChild("World")
	local ember = world:WaitForChild("EmberAcademy")
	local f = K.folder(ember, "SpellRun", true)

	-- template (ServerStorage) -------------------------------------------------------------------------
	local old = ServerStorage:FindFirstChild("SpellRunCourse034")
	if old then
		old:Destroy()
	end
	local template = Instance.new("Folder")
	template.Name = "SpellRunCourse034"
	local gates = K.folder(template, "Gates")
	local walls = K.folder(template, "Walls")

	-- start: pad, sign, odds -----------------------------------------------------------------------------
	Z.cyl(f, "PadRing", PAD + Vector3.new(0, 0.1, 0), 13, 0.2, C.brass, Enum.Material.Metal, true)
	local padGlow = Z.cyl(f, "PadRunes", PAD + Vector3.new(0, 0.22, 0), 11, 0.1, C.rune, Enum.Material.Neon, true)
	padGlow.CastShadow = false
	Z.particles(padGlow, "embers", 3)
	local startPad =
		K.part({ name = "StartPad", parent = template, size = Vector3.new(10, 0.3, 10), pos = PAD + Vector3.new(0, 0.3, 0), color = C.pad, mat = Enum.Material.Neon, deco = true })
	startPad.Transparency = 0.6
	startPad:SetAttribute("PadHeight", 8)
	local signCf = CFrame.lookAt(PAD + Vector3.new(4, 8, 12), PAD + Vector3.new(-40, 8, 12))
	K.part({ name = "Sign", parent = template, size = Vector3.new(14, 8, 0.4), cf = signCf, color = C.plumDark, deco = true })
	K.part({ name = "SignTrim", parent = template, size = Vector3.new(14.6, 8.6, 0.3), cf = signCf * CFrame.new(0, 0, 0.1), color = C.brass, deco = true })
	local oddsCf = CFrame.lookAt(PAD + Vector3.new(4, 8, -13), PAD + Vector3.new(-40, 8, -13))
	K.part({ name = "OddsBoard", parent = template, size = Vector3.new(16, 10, 0.4), cf = oddsCf, color = C.plumDark, deco = true })
	K.part({ name = "OddsTrim", parent = template, size = Vector3.new(16.6, 10.6, 0.3), cf = oddsCf * CFrame.new(0, 0, 0.1), color = C.brass, deco = true })
	for _, s in { -7, 7 } do
		K.part({ name = "OddsPost", parent = template, size = Vector3.new(0.6, 3.4, 0.6), cf = oddsCf * CFrame.new(s, -6.6, 0.3), color = C.brass, deco = true })
		K.part({ name = "SignPost", parent = template, size = Vector3.new(0.6, 4.4, 0.6), cf = signCf * CFrame.new(s * 0.85, -5.6, 0.3), color = C.brass, deco = true })
	end
	K.part({ name = "SafeVolume", parent = template, ghost = true, size = Vector3.new(26, 16, 40), pos = PAD + Vector3.new(0, 7, 0) })
	K.part({ name = "SafeVolume2", parent = template, ghost = true, size = Vector3.new(96, 50, 196), pos = Vector3.new(-62, Y0 + 18, -845) })
	for _, name in { "SafeVolume", "SafeVolume2" } do
		K.tag(template:FindFirstChild(name) :: Instance, "PvPSafeZone")
	end

	-- 1. rune bridge east -> CP1, then a landing -------------------------------------------------------------------------
	bridge(f, walls, BRIDGE_A.from, BRIDGE_A.to, 10)
	local cp1 = CFrame.lookAt(BRIDGE_A.to + Vector3.new(-3, 0, 0), BRIDGE_A.to + Vector3.new(10, 0, 0))
	arch(f, "Gate1", cp1, 10, C.rune)
	gateBox(gates, "CP1", 1, cp1 * CFrame.new(0, 4, 0), Vector3.new(12, 10, 6))
	-- landing at the bridge's end (the walled bridge has no side exits): platform 1 is a short jump straight north
	platform(f, "Landing0", Vector3.new(-37, Y0, -760), 12, 12)

	-- 2. floating platforms, climbing north -> landing L1 (CP2) --------------------------------------------
	for i, p in FIELD1 do
		platform(f, "Platform" .. i, Vector3.new(p[1], Y0 + p[2], p[3]), 12, 12)
	end
	platform(f, "Landing1", L1, 16, 16)
	local cp2 = CFrame.lookAt(L1, L1 + Vector3.new(0, 0, -10))
	arch(f, "Gate2", cp2 * CFrame.new(0, 0, -4), 14, C.rune)
	gateBox(gates, "CP2", 2, cp2 * CFrame.new(0, 4, 0), Vector3.new(16, 10, 16))

	-- 3. three slow sliding spellbooks -> landing L2 (CP3) -------------------------------------------------
	for i, b in BOOKS do
		book(f, Vector3.new(b[1], Y0 + b[2], b[3]), C.book[i], (i - 1) * 2.1)
	end
	platform(f, "Landing2", L2, 16, 16)
	local cp3 = CFrame.lookAt(L2, L2 + Vector3.new(-10, 0, 0))
	arch(f, "Gate3", cp3 * CFrame.new(0, 0, -4), 14, C.runeBlue)
	gateBox(gates, "CP3", 3, cp3 * CFrame.new(0, 4, 0), Vector3.new(16, 10, 16))

	-- 4. rising rune bridge west -> platform L3 (CP4) ------------------------------------------------------
	bridge(f, walls, BRIDGE_B.from, BRIDGE_B.to, 10)
	platform(f, "Landing3", L3, 14, 14)
	local cp4 = CFrame.lookAt(L3, L3 + Vector3.new(0, 0, 10))
	arch(f, "Gate4", cp4 * CFrame.new(0, 0, -3), 12, C.rune)
	gateBox(gates, "CP4", 4, cp4 * CFrame.new(0, 4, 0), Vector3.new(14, 10, 14))

	-- 5. platforms back down, south -> CP5 on the last one ----------------------------------------------
	for i, p in FIELD2 do
		platform(f, "Platform" .. (#FIELD1 + i), Vector3.new(p[1], Y0 + p[2], p[3]), 12, 12)
	end
	local last = FIELD2[#FIELD2]
	local q = Vector3.new(last[1], Y0 + last[2], last[3])
	local cp5 = CFrame.lookAt(q, q + Vector3.new(0, 0, 10))
	arch(f, "Gate5", cp5 * CFrame.new(0, 0, 3), 10, C.runeBlue)
	gateBox(gates, "CP5", 5, cp5 * CFrame.new(0, 4, 0), Vector3.new(12, 10, 12))

	-- 6. ramp down to the island -> Finish ----------------------------------------------------------------
	local len = RAMP.high.Z - RAMP.low.Z -- (negative: the high end is north)
	local rise = RAMP.high.Y - RAMP.low.Y
	K.part({
		name = "Ramp",
		parent = f,
		shape = "Wedge",
		size = Vector3.new(10, rise, math.abs(len)),
		cf = CFrame.new(RAMP.low.X, RAMP.low.Y + rise / 2, (RAMP.high.Z + RAMP.low.Z) / 2) * CFrame.Angles(0, math.pi, 0),
		color = C.stone,
		mat = Enum.Material.Limestone,
	})
	local finishCf = CFrame.lookAt(FINISH, FINISH + Vector3.new(0, 0, 10))
	arch(f, "FinishArch", finishCf, 12, C.gold)
	Z.crystal(f, "FinishCrystal", FINISH + Vector3.new(0, 10.4, 0), 2.4, 4, C.gold)
	gateBox(gates, "Finish", 0, finishCf * CFrame.new(0, 4, 0), Vector3.new(14, 10, 6))

	-- podium + the names above it -------------------------------------------------------------------------
	for i, s in { { 0, 3 }, { -4.5, 2 }, { 4.5, 1.2 } } do
		local colour = ({ C.gold, C.silver, C.bronze })[i]
		Z.block(f, "Podium" .. i, Vector3.new(4.4, s[2], 4.4), PODIUM + Vector3.new(s[1], s[2] / 2, 0), colour, Enum.Material.SmoothPlastic)
		K.part({ name = "Name" .. i, parent = template, ghost = true, size = Vector3.new(1, 1, 1), pos = PODIUM + Vector3.new(s[1], s[2] + 6, 0) })
	end
	Z.sign(f, CFrame.lookAt(PODIUM + Vector3.new(0, 1.5, -2.3), PODIUM + Vector3.new(0, 1.5, 10)), Vector3.new(13, 1.2, 0.3), "SPELL RUN CHAMPIONS", C.plumDark, C.gold)

	-- fall catch ---------------------------------------------------------------------------------------------
	local fall = K.part({ name = "FallZone", parent = f, ghost = true, size = Vector3.new(110, 140, 215), pos = Vector3.new(-62, Y0 - 78, -845) })
	fall:SetAttribute("Note", "below the course: RaceService pops anyone in here back (racers to their last gate)")
	K.part({ name = "PadSpot", parent = f, ghost = true, size = Vector3.new(2, 1, 2), cf = CFrame.lookAt(PAD + Vector3.new(-6, 3, 0), PAD + Vector3.new(10, 3, 0)) })

	template.Parent = ServerStorage
	return ("Spell Run: course %d parts, template %d parts, %d gates"):format(K.count(f), K.count(template), #gates:GetChildren())
end

return { build = build }
