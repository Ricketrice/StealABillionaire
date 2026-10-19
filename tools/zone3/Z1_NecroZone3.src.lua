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
	--@@BOXES@@
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
