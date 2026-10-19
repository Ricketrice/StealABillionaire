-- Z1_NecroZone3.lua (Hub 2b, 2026-10-20): the owner's necromap.glb replaces Ember Academy as Zone 3's map.
-- GENERATED from Z1_NecroZone3.src.lua + necro_boxes.luau.txt (tools/zone3/build_z1.py); edit those.
-- Run in Studio Edit (tools/hub2b/run_file.py). Re-runnable guard: stops if Zone3Map exists. Undo: Z1_Undo.lua.
-- In:  Workspace.necromap (owner's Import 3D, 1 stud = 1 m, grey, unanchored).
-- Out: Workspace.World.EmberAcademy.Zone3Map, x3, quarter turn: the map's gate (GLB -Y) faces the Zone 3 price gate
--      (west), GLB +X = north (+Z). Gate front at x 332 (price gate barrier x 324-328), floor y 24.1 (path/island 24),
--      town to x 453, z 464-616. Scale 3 (not the hub's 3.57) keeps the Spell Run start pad (x 460-473, z 596-608)
--      outside the map. Kid-safe pieces -> ServerStorage._ParkedNecro; Ember's buildings -> ServerStorage._ParkedEmber
--      (kept in place: SpellRun, Summit031 rocks under the island, the island, the price gate, the red path).
-- Collision: every map mesh no collide/query/touch except the ground slab (Box); 138 invisible boxes (one per solid
-- piece of the GLB, welded + merged offline: tools/zone3/necro_boxes.py, necro_merge.py) + edge guards on the wall
-- line (open: the gate, and the east-wall gap that leads onto Ember's island and the Spell Run).
local SS = game:GetService("ServerStorage")
local World = workspace.World
local E = World.EmberAcademy
local Z3 = workspace.Zones.BillionaireHills
local S = 3
local ORIGIN = Vector3.new(391.52, 24.1, 540) -- GLB origin (map centre, ground top)
local function W(bx: number, by: number, bz: number): Vector3 -- GLB metres -> world
	return ORIGIN + Vector3.new(by * S, bz * S, bx * S)
end

if E:FindFirstChild("Zone3Map") then
	return "Z1 already applied"
end
local map = workspace:FindFirstChild("necromap")
assert(map and map:IsA("Model"), "Workspace.necromap missing")

local report = {}
local function say(s)
	table.insert(report, s)
end

-- 0. backups (as imported / before)
local bk = SS:FindFirstChild("_Backups") or Instance.new("Folder")
bk.Name = "_Backups"
bk.Parent = SS
local pre = bk:FindFirstChild("PreZ1_Zone3")
if not pre then
	pre = Instance.new("Folder")
	pre.Name = "PreZ1_Zone3"
	map:Clone().Parent = pre
	Z3:Clone().Parent = pre
	pre.Parent = bk
end

-- 1. place the map: import-space axes from the GLB's marker cubes
-- The importer names a mesh after its geometry (all marker cubes are "Marker_Gate_Entry"); the GLB node name is
-- the parent Model's name (with or without "_Node").
local function nodeName(p: Instance): string
	return (p.Parent and p.Parent:IsA("Model") and p.Parent ~= map and p.Parent.Name or p.Name):gsub("_Node$", "")
end
local function find(name: string): BasePart
	for _, d in map:GetDescendants() do
		if d:IsA("BasePart") and nodeName(d) == name then
			return d
		end
	end
	error("marker missing: " .. name)
end
local gate, spire = find("Marker_Gate_Entry").Position, find("Marker_Spire_Door").Position
local s8, s5 = find("Marker_NPCSpawn_8").Position, find("Marker_NPCSpawn_5").Position
-- GLB: gate (0,-20.72,0.56), spire door (0,11.76,0.56), spawn 8 (17.92,0,0.56), spawn 5 (-21,0.56,0.56)
local ey = (spire - gate) / 32.48
local ex = (s8 - s5 + ey * 0.56) / 38.92
local ez = ex:Cross(ey)
local origin = gate + ey * 20.72 - ez * 0.56
say(("import axes |ex| %.3f |ey| %.3f ex.ey %.3f up %s"):format(ex.Magnitude, ey.Magnitude, ex:Dot(ey), tostring(ez.Unit)))
for _, d in map:GetDescendants() do
	if d:IsA("BasePart") then
		d.Anchored = true
	end
end
map.WorldPivot = CFrame.fromMatrix(origin, ey.Unit, ez.Unit, ex.Unit) -- X = GLB +Y, Y = GLB +Z, Z = GLB +X
map:ScaleTo(S)
map:PivotTo(CFrame.new(ORIGIN))
local g2 = find("Marker_Gate_Entry").Position
say(("gate marker at %s (want %s)"):format(tostring(g2), tostring(W(0, -20.72, 0.56))))

-- 2. kid-safe: park skull/bone pieces, the graveyard (tombstones, crosses, crypt, grave slabs, fence), the pentagram
local PARK = {
	Ground_bone = true,
	Gate_bone = true,
	Plaza_bone = true,
	Graveyard_bone = true,
	Ruins_bone = true,
	Spire_bone = true,
	Houses_bone = true,
	Props_bone = true,
	Graveyard_stone_dark = true,
	Graveyard_stone_grey = true,
	Graveyard_cobble_dark = true,
	Graveyard_iron_black = true,
	Graveyard_glow_necro = true,
	Graveyard_wood_dark = true,
	Graveyard_vine = true,
	Plaza_glow_necro = true,
}
local parked = SS:FindFirstChild("_ParkedNecro") or Instance.new("Folder")
parked.Name = "_ParkedNecro"
parked.Parent = SS
local helpers = parked:FindFirstChild("Helpers_Markers") or Instance.new("Folder")
helpers.Name = "Helpers_Markers"
helpers.Parent = parked
local nPark = {}
for _, node in map:GetDescendants() do
	local mesh = node:IsA("Model") and node:FindFirstChildWhichIsA("BasePart")
	if mesh and #node:GetChildren() == 1 then
		local name = nodeName(mesh)
		if PARK[name] then
			node:SetAttribute("ParkedFrom", node.Parent:GetFullName())
			node.Parent = parked
			table.insert(nPark, name)
		elseif name:match("^Marker_") then
			node:SetAttribute("ParkedFrom", node.Parent:GetFullName())
			node.Parent = helpers
		end
	end
end
say("kid-safe parked: " .. table.concat(nPark, ", "))

-- 3. colours / materials / collision / shadows
local COL = {
	brick_exposed = { 92, 59, 70 },
	cobble = { 90, 83, 102 },
	cobble_dark = { 64, 58, 75 },
	deadwood = { 81, 68, 61 },
	fx_mist = { 140, 122, 168 },
	fx_orb = { 227, 199, 255 },
	fx_rune = { 194, 140, 255 },
	fx_veil = { 143, 90, 214 },
	fx_wisp = { 157, 255, 214 },
	glow_necro = { 194, 140, 255 },
	glow_soul = { 157, 255, 214 },
	ground_ash = { 47, 42, 56 },
	iron_black = { 36, 33, 43 },
	island_rock = { 42, 36, 49 },
	moss_dead = { 75, 86, 57 },
	plaster_worn = { 135, 123, 146 },
	roof_purple = { 88, 48, 126 },
	roof_shingle_dark = { 63, 33, 96 },
	stone_dark = { 68, 61, 82 },
	stone_grey = { 108, 100, 122 },
	vine = { 58, 77, 51 },
	wood_dark = { 74, 53, 48 },
}
local FX = {
	FX_GateVeil = "fx_veil",
	FX_RuneRing = "fx_rune",
	FX_ThroneHalo = "fx_rune",
	FX_Crystal = "fx_rune",
	FX_SpireOrb = "fx_orb",
	FX_SpireHalo = "fx_rune",
	FX_ShardRing = "fx_rune",
	FX_Wisps = "fx_wisp",
	FX_Mist = "fx_mist",
}
local SHADOW = { stone_dark = true, stone_grey = true, plaster_worn = true, wood_dark = true, brick_exposed = true, roof_purple = true, roof_shingle_dark = true }
local nMesh, unknown = 0, {}
for _, p in map:GetDescendants() do
	if not p:IsA("MeshPart") then
		continue
	end
	local full = nodeName(p)
	p.Name = full
	local group, key = full:match("^(%a+)_(.+)$")
	key = FX[full] or key
	local c = COL[key]
	if not c then
		table.insert(unknown, full)
		continue
	end
	nMesh += 1
	p.Color = Color3.fromRGB(c[1], c[2], c[3])
	p.Material = if key:match("^glow") or key:match("^fx_")
		then Enum.Material.Neon
		elseif key == "wood_dark" or key == "deadwood" then Enum.Material.Wood
		elseif key == "iron_black" then Enum.Material.CorrodedMetal
		else Enum.Material.Plastic
	if key == "fx_mist" then
		p.Material, p.Transparency = Enum.Material.SmoothPlastic, 0.82
	elseif key == "fx_veil" then
		p.Transparency = 0.85
	end
	p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
	p.CastShadow = SHADOW[key] == true and group ~= "Props" and group ~= "FX"
	if p.Name == "Ground_ground_ash" then
		p.CollisionFidelity = Enum.CollisionFidelity.Box
		p.CanCollide, p.CanQuery = true, true
	end
end
map.LevelOfDetail = Enum.ModelLevelOfDetail.Automatic
say(("meshes coloured %d, unknown %d %s"):format(nMesh, #unknown, table.concat(unknown, ",")))

-- 4. collision boxes + edge guards
local BOXES = {
		{ "Ground", -15.186, -19.531, -0.081, -14.551, -19.009, 0.305 },
	{ "Ground", -15.940, -20.230, -0.083, -15.285, -19.628, 0.307 },
	{ "Ground", -14.056, -19.656, 1.104, -5.544, -18.872, 1.942 },
	{ "Ground", 7.094, -20.448, -0.119, 7.852, -19.698, 0.343 },
	{ "Ground", 5.804, -19.092, -0.151, 6.545, -18.278, 0.375 },
	{ "Ground", 8.344, -19.656, 0.920, 25.256, -18.872, 2.341 },
	{ "Ground", -25.256, 18.872, 1.018, -11.144, 19.656, 2.109 },
	{ "Ground", -10.016, 19.012, -0.056, -9.559, 19.469, 0.280 },
	{ "Ground", -8.456, 18.872, 0.859, 25.256, 19.656, 2.282 },
	{ "Ground", -25.956, -12.321, -0.082, -25.377, -11.604, 0.306 },
	{ "Ground", -25.256, -11.256, 1.442, -24.429, -2.744, 2.082 },
	{ "Ground", -25.399, -1.346, -0.008, -25.056, -1.003, 0.232 },
	{ "Ground", -24.348, 4.173, -0.047, -23.914, 4.606, 0.271 },
	{ "Ground", -24.645, 6.650, 1.427, -24.197, 7.350, 1.819 },
	{ "Ground", -25.256, 5.544, 0.933, -24.382, 19.656, 1.878 },
	{ "Ground", -25.616, 17.718, 1.631, -25.168, 18.682, 2.023 },
	{ "Ground", 24.472, -19.656, 1.003, 25.258, -13.944, 1.716 },
	{ "Ground", 23.814, -12.367, -0.114, 24.473, -11.609, 0.338 },
	{ "Ground", 24.360, -11.256, 0.931, 25.256, 5.656, 2.065 },
	{ "Ground", -25.256, -19.656, 1.033, -16.744, -18.872, 1.345 },
	{ "Ground", -15.649, -18.824, -0.083, -15.111, -18.286, 0.307 },
	{ "Ground", 6.186, -19.743, -0.067, 6.699, -19.230, 0.291 },
	{ "Ground", -9.320, 19.162, -0.144, -8.632, 20.003, 0.368 },
	{ "Ground", -10.745, 19.155, -0.006, -10.503, 19.397, 0.230 },
	{ "Ground", -25.256, -19.656, 1.387, -24.472, -13.944, 1.791 },
	{ "Ground", -24.407, -13.286, -0.058, -23.925, -12.804, 0.282 },
	{ "Ground", -26.068, -2.507, -0.144, -25.315, -1.649, 0.368 },
	{ "Ground", -24.728, -1.312, -0.119, -24.099, -0.559, 0.343 },
	{ "Ground", -25.256, -0.056, 1.141, -24.472, 2.856, 1.309 },
	{ "Ground", -24.467, 3.163, -0.063, -23.974, 3.714, 0.287 },
	{ "Ground", -25.295, 4.219, -0.111, -24.659, 4.864, 0.335 },
	{ "Ground", 24.328, -13.421, -0.081, 24.805, -12.945, 0.305 },
	{ "Ground", 24.581, -12.167, -0.082, 25.055, -11.693, 0.306 },
	{ "Ground", 24.374, 7.092, -0.069, 24.884, 7.602, 0.293 },
	{ "Ground", 24.482, 6.286, -0.113, 25.124, 6.956, 0.337 },
	{ "Ground", 24.472, 8.344, 1.040, 25.256, 19.656, 1.456 },
	{ "Gate", -4.536, -19.376, 0.000, -2.744, -17.584, 6.580 },
	{ "Gate", 2.744, -19.376, 0.000, 4.536, -17.584, 4.060 },
	{ "Gate", 1.473, -17.567, -0.129, 4.127, -15.473, 1.081 },
	{ "Gate", -6.244, -18.844, 0.000, -4.956, -17.556, 1.960 },
	{ "Gate", 4.956, -18.844, 0.000, 6.244, -17.556, 1.960 },
	{ "Plaza", -2.458, -2.458, 0.056, 2.458, 2.458, 6.384 },
	{ "Plaza", -7.332, 6.861, 0.000, -4.801, 9.041, 1.836 },
	{ "Plaza", 3.994, 3.994, 0.045, 5.114, 5.114, 3.685 },
	{ "Plaza", 3.528, -5.782, -0.075, 6.383, -3.808, 2.005 },
	{ "Plaza", -5.114, -5.114, 0.045, -3.994, -3.994, 3.125 },
	{ "Plaza", -5.114, 3.994, 0.045, -3.994, 5.114, 1.445 },
	{ "Plaza", -4.025, 4.160, -0.072, -3.421, 4.669, 0.296 },
	{ "Plaza", -8.996, 4.835, 0.000, -6.861, 7.332, 2.015 },
	{ "Plaza", -5.169, 8.419, 0.000, -2.480, 10.047, 2.175 },
	{ "Plaza", -2.653, 9.403, -0.000, 2.653, 10.413, 3.141 },
	{ "Plaza", 2.480, 8.419, 0.000, 5.169, 10.047, 2.455 },
	{ "Plaza", 4.835, 6.861, -0.000, 7.332, 8.996, 2.278 },
	{ "Plaza", 6.861, 4.835, 0.000, 8.996, 7.332, 2.800 },
	{ "Ruins", 13.440, 3.024, 0.000, 22.960, 3.696, 3.319 },
	{ "Ruins", 13.004, -3.875, -0.137, 22.960, -2.968, 1.955 },
	{ "Ruins", 22.568, -3.360, 0.000, 23.352, 3.360, 2.520 },
	{ "Ruins", 13.104, -3.360, 0.000, 13.776, -1.120, 5.040 },
	{ "Ruins", 13.104, 1.120, 0.000, 13.776, 3.360, 3.920 },
	{ "Ruins", 14.700, -2.100, 0.000, 15.540, -1.260, 3.584 },
	{ "Ruins", 14.700, 1.260, 0.000, 15.540, 2.100, 1.344 },
	{ "Ruins", 16.940, -2.100, 0.000, 17.780, -1.260, 2.744 },
	{ "Ruins", 16.684, -0.747, -0.074, 18.542, 2.100, 1.064 },
	{ "Ruins", 19.180, -2.273, -0.144, 20.600, -1.260, 2.184 },
	{ "Ruins", 19.180, 1.260, 0.000, 20.020, 2.100, 3.304 },
	{ "Ruins", 21.420, -2.100, 0.000, 22.260, -1.260, 0.784 },
	{ "Ruins", 21.420, 1.260, 0.000, 22.260, 2.100, 1.904 },
	{ "Ruins", 20.141, -1.536, -0.148, 22.064, 0.924, 1.064 },
	{ "Ruins", 15.222, -2.807, -0.104, 15.926, -2.101, 0.328 },
	{ "Ruins", 17.988, -2.853, -0.073, 18.442, -2.400, 0.297 },
	{ "Ruins", 20.978, 2.086, -0.043, 21.330, 2.438, 0.267 },
	{ "Ruins", 18.366, 3.273, -0.153, 19.215, 4.007, 0.377 },
	{ "Ruins", 23.146, 3.045, -0.128, 23.976, 3.958, 0.352 },
	{ "Ruins", 21.967, 3.847, -0.057, 22.685, 4.414, 0.281 },
	{ "Ruins", 13.337, -4.314, -0.128, 14.333, -3.513, 0.352 },
	{ "Ruins", 14.560, 8.008, 0.000, 18.592, 8.792, 1.461 },
	{ "Ruins", 19.208, 9.380, 0.000, 19.992, 12.320, 1.848 },
	{ "Ruins", 19.537, 11.795, -0.108, 22.736, 16.016, 2.520 },
	{ "Ruins", 20.610, 10.620, -0.144, 22.142, 11.468, 0.368 },
	{ "Ruins", 12.796, 14.756, 0.000, 13.524, 15.484, 3.640 },
	{ "Ruins", 15.596, 14.756, 0.000, 16.324, 15.484, 3.640 },
	{ "Ruins", 15.068, 11.324, 0.000, 18.532, 13.316, 0.896 },
	{ "Ruins", 21.484, -2.708, -0.031, 21.808, -2.384, 0.255 },
	{ "Ruins", 22.420, 4.203, -0.120, 23.165, 4.972, 0.344 },
	{ "B", -6.888, 11.914, -0.080, 7.065, 20.300, 13.384 },
	{ "B", -9.366, -18.033, 0.000, -5.194, -13.636, 4.056 },
	{ "B", -5.404, -16.352, 0.000, -4.956, -15.008, 0.112 },
	{ "B", -9.366, -12.767, 0.000, -5.194, -8.736, 3.461 },
	{ "B", -5.404, -11.312, 0.000, -4.956, -9.968, 0.112 },
	{ "B", 5.054, -17.673, 0.000, 9.506, -13.746, 3.943 },
	{ "B", 4.816, -16.352, 0.000, 5.264, -15.008, 2.190 },
	{ "B", 5.334, -13.285, 0.000, 9.226, -8.596, 4.328 },
	{ "B", 5.096, -11.312, 0.000, 5.544, -9.968, 0.112 },
	{ "B", -15.666, -16.604, 0.000, -11.214, -11.915, 4.045 },
	{ "B", -11.424, -15.232, 0.000, -10.976, -13.888, 0.112 },
	{ "B", 11.354, -16.487, 0.000, 15.526, -12.546, 3.676 },
	{ "B", 11.116, -15.232, 0.000, 11.564, -13.888, 2.192 },
	{ "B", -10.484, 11.914, 0.000, -6.384, 16.086, 4.204 },
	{ "B", -9.072, 11.676, 0.000, -7.728, 12.124, 2.098 },
	{ "B", 6.772, 11.914, 0.000, 11.004, 16.086, 3.766 },
	{ "B", 8.288, 11.676, 0.000, 9.632, 12.124, 0.112 },
	{ "B", -5.292, -17.151, 1.891, -5.124, -16.307, 2.033 },
	{ "B", -5.292, -12.011, 1.916, -5.124, -11.168, 2.046 },
	{ "B", 4.984, -15.285, 1.993, 5.152, -14.444, 2.087 },
	{ "B", 4.984, -16.965, 1.893, 5.152, -16.124, 2.109 },
	{ "B", 5.264, -12.104, 1.896, 5.432, -11.260, 2.035 },
	{ "B", -11.312, -13.945, 1.899, -11.139, -13.101, 2.237 },
	{ "B", 11.284, -14.103, 1.964, 11.452, -13.261, 2.064 },
	{ "B", 11.284, -15.782, 1.996, 11.452, -14.941, 2.095 },
	{ "B", -9.726, 11.844, 1.989, -8.886, 12.012, 2.075 },
	{ "B", -7.906, 11.844, 1.985, -7.066, 12.012, 2.071 },
	{ "B", 7.501, 11.844, 1.899, 8.344, 12.012, 2.037 },
	{ "B", 13.285, -16.545, 1.540, 13.613, -16.406, 1.783 },
	{ "B", -6.188, -13.679, 0.000, -5.572, -13.145, 0.728 },
	{ "B", -7.013, -13.789, 0.000, -6.259, -13.035, 0.616 },
	{ "B", -6.188, -8.779, 0.000, -5.572, -8.245, 0.728 },
	{ "B", -7.013, -8.889, 0.000, -6.259, -8.135, 0.616 },
	{ "B", 5.432, -18.075, 0.000, 6.048, -17.541, 0.728 },
	{ "B", 6.119, -18.185, 0.000, 6.873, -17.431, 0.616 },
	{ "B", 4.788, -12.629, 1.835, 5.404, -12.515, 2.288 },
	{ "B", 10.808, -16.217, 1.990, 11.424, -16.124, 2.439 },
	{ "B", 11.732, -16.955, 0.000, 12.348, -16.421, 0.728 },
	{ "B", 12.419, -17.065, 0.000, 13.173, -16.311, 0.616 },
	{ "B", -6.646, 11.368, 1.956, -6.561, 11.984, 2.404 },
	{ "B", 10.961, 12.292, 0.000, 11.495, 12.908, 0.728 },
	{ "B", 10.851, 12.979, 0.000, 11.605, 13.733, 0.616 },
	{ "Props", -3.018, -17.052, 0.000, -2.582, -16.548, 3.080 },
	{ "Props", 2.582, -17.052, 0.000, 3.018, -16.548, 3.080 },
	{ "Props", -3.018, -12.572, 0.000, -2.582, -12.068, 3.080 },
	{ "Props", 2.582, -12.572, 0.000, 3.018, -12.068, 3.080 },
	{ "Props", -3.018, -8.652, 0.000, -2.582, -8.148, 3.080 },
	{ "Props", 2.582, -8.652, 0.000, 3.018, -8.148, 3.080 },
	{ "Props", -2.458, 8.148, 0.000, -2.022, 8.652, 3.080 },
	{ "Props", 2.022, 8.148, 0.000, 2.458, 8.652, 3.080 },
	{ "Props", -8.618, -2.212, 0.000, -8.182, -1.708, 3.080 },
	{ "Props", -8.618, 1.708, 0.000, -8.182, 2.212, 3.080 },
	{ "Props", 8.182, -2.212, 0.000, 8.618, -1.708, 3.080 },
	{ "Props", 8.182, 1.708, 0.000, 8.618, 2.212, 3.080 },
}
local col = Instance.new("Folder")
col.Name = "Collision"
local function block(name: string, lo: Vector3, hi: Vector3, parent: Instance): Part
	local a, b = W(lo.X, lo.Y, lo.Z), W(hi.X, hi.Y, hi.Z)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, true, true, false, false
	p.Transparency = 1
	p.Size = Vector3.new(math.max(math.abs(b.X - a.X), 0.3), math.max(math.abs(b.Y - a.Y), 0.3), math.max(math.abs(b.Z - a.Z), 0.3))
	p.CFrame = CFrame.new((a + b) / 2)
	p.Parent = parent
	return p
end
for i, b in BOXES do
	block(("C_%s_%d"):format(b[1], i), Vector3.new(b[2], b[3], math.max(b[4], -0.05)), Vector3.new(b[5], b[6], b[7]), col)
end
local guards = Instance.new("Folder")
guards.Name = "Guards"
local T, H = 0.4, 5 -- half thickness (m), height (m) = 15 studs
local GUARDS = { -- { name, x0, y0, x1, y1 } along the wall line (GLB metres)
	{ "Guard_GateWall_S", -25.3, -19.264, -2.8, -19.264 }, -- gate opening x -2.8..2.8 stays open
	{ "Guard_GateWall_N", 2.8, -19.264, 25.3, -19.264 },
	{ "Guard_East_S", -25.3, 19.264, -11.2, 19.264 }, -- gap x -11.2..-8.4 = the way out to the Spell Run
	{ "Guard_East_N", -8.4, 19.264, 25.3, 19.264 },
	{ "Guard_South", -24.819, -19.7, -24.819, 19.7 },
	{ "Guard_North", 24.808, -19.7, 24.808, 19.7 },
}
for _, g in GUARDS do
	block(g[1], Vector3.new(math.min(g[2], g[4]) - T, math.min(g[3], g[5]) - T, 0), Vector3.new(math.max(g[2], g[4]) + T, math.max(g[3], g[5]) + T, H), guards)
end

-- 5. park Ember's buildings (Spell Run, its island and the rocks under it stay)
local KEEP = { SpellRun = true, Summit031 = true, RaceCourse = true }
local pe = SS:FindFirstChild("_ParkedEmber") or Instance.new("Folder")
pe.Name = "_ParkedEmber"
pe.Parent = SS
local nE = 0
for _, item in E:GetChildren() do
	if not KEEP[item.Name] then
		item:SetAttribute("ParkedFrom", "World.EmberAcademy")
		item.Parent = pe
		nE += 1
	end
end
-- the red path's side guards ran up to x 368-377 (under the old Ember gate): cut them inside the map's gate wall
-- (wall x 330.2-338.7 beside the opening), so the path edge stays guarded up to the wall
local CUT = 334.5
local cut = {}
for _, g in
	{
		workspace.HubMap2b.VisualFix2b.Guards:FindFirstChild("GUARD_Ember_Gate_N"),
		workspace.HubMap2b.VisualFix2b.Guards:FindFirstChild("GUARD_Ember_Gate_S"),
		World.BridgeGuards:FindFirstChild("BillionaireHillsBridgeGuard-1"),
		World.BridgeGuards:FindFirstChild("BillionaireHillsBridgeGuard1"),
	}
do
	if not g then
		continue
	end
	local axis = if g.Size.X >= g.Size.Z then Vector3.xAxis else Vector3.zAxis
	local len = if axis == Vector3.xAxis then g.Size.X else g.Size.Z
	local dir = g.CFrame:VectorToWorldSpace(axis)
	if dir.X < 0 then
		dir = -dir
	end
	local x0 = (g.Position - dir * len / 2).X
	local x1 = (g.Position + dir * len / 2).X
	if x1 > CUT then
		g:SetAttribute("PreZ1CFrame", g.CFrame)
		g:SetAttribute("PreZ1Size", g.Size)
		if x0 >= CUT - 1 then
			g:SetAttribute("ParkedFrom", g.Parent:GetFullName())
			g.Parent = pe
			table.insert(cut, g.Name .. " parked")
		else
			local newLen = (CUT - x0) / dir.X
			local start = g.Position - dir * len / 2
			g.Size = if axis == Vector3.xAxis then Vector3.new(newLen, g.Size.Y, g.Size.Z) else Vector3.new(g.Size.X, g.Size.Y, newLen)
			g.CFrame = g.CFrame.Rotation + (start + dir * newLen / 2)
			table.insert(cut, ("%s x %.0f..%.0f -> %.0f"):format(g.Name, x0, x1, CUT))
		end
	end
end
say(("Ember parked %d; guards: %s"):format(nE, table.concat(cut, "; ")))

map.Name = "Zone3Map"
map.Parent = E
col.Parent = map
guards.Parent = map

-- 6. Zone 3 anchors: catch area = the old graveyard lot (open ground, GLB x -23.4..-9.3, y -11.5..11.5)
local boundary = Z3.ZoneBoundary
local lo, hi = W(-23.4, -11.5, 0), W(-9.3, 11.5, 0)
boundary.CFrame = CFrame.new((lo.X + hi.X) / 2, ORIGIN.Y + 10, (lo.Z + hi.Z) / 2)
boundary.Size = Vector3.new(math.abs(hi.X - lo.X), 20, math.abs(hi.Z - lo.Z))
local post = Z3:FindFirstChild("GuardianPost")
if post then
	post.CFrame = CFrame.new(W(-10.5, 0, 0) + Vector3.new(0, post.Size.Y / 2 - 0.5, 0)) * post.CFrame.Rotation
end
local SPOTS = { { -16.2, -2.2 }, { -21, 0.56 }, { -12.6, 0.56 }, { -16.2, 5.6 }, { -20.5, -8.5 }, { -12.5, -8.5 }, { -20.5, 9 }, { -12.5, 9 } }
local folder = Z3.SpawnPoints
local template = folder:FindFirstChildWhichIsA("BasePart")
local prm = RaycastParams.new()
prm.FilterType = Enum.RaycastFilterType.Exclude
prm.FilterDescendantsInstances = { boundary, folder }
local made, rep, bad = {}, {}, 0
for i, s in SPOTS do
	local at = W(s[1], s[2], 0)
	local down = workspace:Raycast(at + Vector3.new(0, 20, 0), Vector3.new(0, -30, 0), prm)
	local okFloor = down ~= nil and down.Instance.Name == "Ground_ground_ash"
	local near = {}
	for _, d in { Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis } do
		local r = workspace:Raycast(at + Vector3.new(0, 2.5, 0), d * 4, prm)
		if r then
			table.insert(near, r.Instance.Name)
		end
	end
	if not okFloor or #near > 0 then
		bad += 1
	end
	table.insert(
		rep,
		("%d:%s%s"):format(
			i,
			okFloor and ("ok y%.2f"):format(down.Position.Y) or ("FLOOR " .. (down and down.Instance:GetFullName() or "none")),
			#near > 0 and (" NEAR " .. table.concat(near, ",")) or ""
		)
	)
	local p = template:Clone()
	p.Name = "Spawn" .. i
	p.CFrame = CFrame.new(at.X, (if down then down.Position.Y else ORIGIN.Y) + 0.5, at.Z)
	table.insert(made, p)
end
for _, c in folder:GetChildren() do
	c:Destroy()
end
for _, p in made do
	p.Parent = folder
end
say(
	("zone: boundary %s %s; post %s; spawns (%d bad): %s"):format(
		tostring(boundary.Position),
		tostring(boundary.Size),
		post and tostring(post.Position) or "none",
		bad,
		table.concat(rep, " ")
	)
)

-- 7. the way out to the Spell Run: ground just outside the east-wall gap
local out = {}
for _, xz in { { 451.5, 510.6 }, { 455, 510.6 }, { 460, 560 }, { 466, 595 } } do
	local r = workspace:Raycast(Vector3.new(xz[1], 50, xz[2]), Vector3.new(0, -40, 0))
	table.insert(out, ("(%d,%d) %s %.2f"):format(xz[1], xz[2], r and r.Instance.Name or "NONE", r and r.Position.Y or 0))
end
say("exit route ground: " .. table.concat(out, "; "))
local cf, size = map:GetBoundingBox()
say(("map bbox centre %s size %s"):format(tostring(cf.Position), tostring(size)))
return "Z1 ok\n" .. table.concat(report, "\n")
