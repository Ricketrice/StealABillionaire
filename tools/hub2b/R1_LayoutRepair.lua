-- R1_LayoutRepair.lua (Hub 2b layout repair, 2026-10-20). Run once in Studio Edit: tools/hub2b/run_file.py <this file>.
-- 1. Town wall: the export's KingdomWall is one merged mesh per colour (both side walls in one mesh), and cut mesh pieces
--    are not saved in the place file, so the wall is parked and rebuilt from parts: the same boxes and colours, towers /
--    gold rings / cone roofs as 12-sided part unions (saved with the place). The side walls stand 72 studs further out
--    (x +-242, end walls +-240): all 12 bases are inside and the 4 outer bases' back doors open onto the town walkway.
--    The two AgeDetails meshes with pieces on the old side walls (stone_worn, foliage_light) are parked and rebuilt too.
-- 2. Town floor / walkway / rock for the two new strips (x +-170..243.5), lanterns on the walkway, collision moved/added,
--    extension guards updated (the old back-door guard behind bases 9-12 is gone).
-- 3. Grey platforms: extended under Knight's Keep (to x -290) and the Sunken Kingdom (to x 280), a connector under the
--    Sunken -> Ember ramp and a third platform under Ember Academy; a pedestal (the island's own cliff parts carried down)
--    seats Ember's island on it; edge guards; two Ember clouds / the hanging rocks lowered under the new floor.
-- 4. Parade lane: the whole red spine (spine end z -233 -> NorthGate z -44, was junction -> gate).
-- Records: everything created -> Workspace.HubMap2b.Repair2b; moved/resized -> attrs PreR2CFrame / PreR2Size + tag MovedR2;
-- parked -> ServerStorage._ParkedR2 (attr ParkedFrom). Undo: tools/hub2b/R_Undo.lua (run it BEFORE tools/hub2b/Undo.lua).
local SS = game:GetService("ServerStorage")
local CS = game:GetService("CollectionService")

local H = Vector3.new(0, 0, 700) -- hub-local (0, 0, 0)
local map = workspace:FindFirstChild("HubMap2b")
assert(map and map:GetAttribute("Fit2b") == true, "Workspace.HubMap2b is not fitted (H1 first)")
assert(map:GetAttribute("Repair2b") == nil, "already repaired (run R_Undo.lua first)")
local root = map:FindFirstChild("Hub2b") :: Model
local col2b = map:FindFirstChild("Collision2b") :: Folder
local ext2b = map:FindFirstChild("Ext2b") :: Folder
local World = workspace.World

local log = {}
local function say(s: string)
	table.insert(log, s)
end
local function folder(parent: Instance, name: string): Instance
	local f = parent:FindFirstChild(name)
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = parent
	end
	return f
end
local function L(x: number, y: number, z: number): Vector3
	return H + Vector3.new(x, y, z)
end
local function moveTo(part: BasePart, cf: CFrame)
	if part:GetAttribute("PreR2CFrame") == nil then
		part:SetAttribute("PreR2CFrame", part.CFrame)
		CS:AddTag(part, "MovedR2")
	end
	part.CFrame = cf
end
local function resize(part: BasePart, size: Vector3)
	if part:GetAttribute("PreR2Size") == nil then
		part:SetAttribute("PreR2Size", part.Size)
	end
	if part:GetAttribute("PreR2CFrame") == nil then
		part:SetAttribute("PreR2CFrame", part.CFrame)
		CS:AddTag(part, "MovedR2")
	end
	part.Size = size
end
local parkRoot = folder(SS, "_ParkedR2")
local function park(inst: Instance, sub: string)
	inst:SetAttribute("ParkedFrom", (inst.Parent :: Instance):GetFullName())
	inst.Parent = folder(parkRoot, sub)
end
local function need(parent: Instance, name: string): Instance
	local c = parent:FindFirstChild(name, true)
	assert(c, "missing " .. parent:GetFullName() .. "/" .. name)
	return c
end

local rep = Instance.new("Model")
rep.Name = "Repair2b"
rep.Parent = map
local work = Instance.new("Folder") -- CSG operands (removed at the end)
work.Name = "_R2Work"
work.Parent = workspace

type Look = { color: Color3, material: Enum.Material, shadow: boolean }
local function look(color: Color3, material: Enum.Material?, shadow: boolean?): Look
	return { color = color, material = material or Enum.Material.Plastic, shadow = shadow == true }
end
local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end
local function style(p: BasePart, lk: Look, collide: boolean)
	p.Anchored = true
	p.Color = lk.color
	p.Material = lk.material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = collide
	p.CanQuery = collide
	p.CanTouch = false
	p.CastShadow = lk.shadow
end
local function block(parent: Instance, name: string, c: Vector3, s: Vector3, lk: Look, collide: boolean): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = s
	p.CFrame = CFrame.new(H + c)
	style(p, lk, collide)
	p.Parent = parent
	return p
end
local function cylinder(parent: Instance, name: string, c: Vector3, dia: number, h: number, lk: Look, collide: boolean): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(h, dia, dia)
	p.CFrame = CFrame.new(H + c) * CFrame.Angles(0, 0, math.pi / 2) -- axis up
	style(p, lk, collide)
	p.Parent = parent
	return p
end
local function invisible(parent: Instance, name: string, c: Vector3, s: Vector3): Part
	local p = block(parent, name, c, s, look(rgb(255, 255, 255)), true)
	p.Transparency = 1
	return p
end

-- 12-sided shapes (vertices at 0, 30, ... degrees, like the export's towers) as part unions ----------------------------
local A15 = math.cos(math.rad(15))
local function finish(u: BasePart, parent: Instance, name: string, lk: Look)
	u.Name = name
	u.UsePartColor = true
	style(u, lk, false)
	u.Parent = parent
end
local function operand(cf: CFrame, s: Vector3): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = s
	p.CFrame = cf
	p.Parent = work
	return p
end
-- A block minus one big block outside each of the 12 faces (IntersectAsync keeps what is inside ANY cutter, so
-- the shapes are made by subtracting the outside instead).
local function carve(main: Part, cutters: { Part }, parent: Instance, name: string, lk: Look)
	local u = main:SubtractAsync(cutters, Enum.CollisionFidelity.Box, Enum.RenderFidelity.Precise)
	finish(u, parent, name, lk)
	main:Destroy()
	for _, o in cutters do
		o:Destroy()
	end
end
-- prism: radius r (centre to vertex), from y0 to y1
local function prism(parent: Instance, name: string, x: number, z: number, r: number, y0: number, y1: number, lk: Look)
	local a = r * A15
	local c = L(x, (y0 + y1) / 2, z)
	local main = operand(CFrame.new(c), Vector3.new(2 * r + 2, y1 - y0, 2 * r + 2))
	local cutters = {}
	for k = 0, 11 do
		local t = math.rad(15 + 30 * k)
		local n = Vector3.new(math.cos(t), 0, math.sin(t))
		table.insert(cutters, operand(CFrame.fromMatrix(c + n * (a + 20), Vector3.yAxis, n), Vector3.new(60 + y1 - y0, 40, 40)))
	end
	carve(main, cutters, parent, name, lk)
end
-- cone roof: 12-sided pyramid, base radius r at y0, apex at y1
local function cone(parent: Instance, name: string, x: number, z: number, r: number, y0: number, y1: number, lk: Look)
	local a = r * A15
	local h = y1 - y0
	local apex = L(x, y1, z)
	local big = 4 * r + 2 * h
	local main = operand(CFrame.new(L(x, (y0 + y1) / 2, z)), Vector3.new(2 * r + 2, h, 2 * r + 2))
	local cutters = {}
	for k = 0, 11 do
		local t = math.rad(15 + 30 * k)
		local n = Vector3.new(h * math.cos(t), a, h * math.sin(t)).Unit -- outward face normal
		local right = Vector3.new(-math.sin(t), 0, math.cos(t))
		table.insert(cutters, operand(CFrame.fromMatrix(apex + n * big / 2, right, n), Vector3.one * big))
	end
	carve(main, cutters, parent, name, lk)
end

-- 1. the town wall -------------------------------------------------------------------------------------------------
local kw = need(root, "KingdomWall") :: Model
local function meshColor(model: Instance, name: string): Color3
	return (need(model, name) :: BasePart).Color
end
local STONE = look(meshColor(kw, "KingdomWall_stone_light"), nil, true)
local GOLD = look(meshColor(kw, "KingdomWall_gold_trim"), nil, true)
local ROOF = look(meshColor(kw, "KingdomWall_roof_red"), nil, true)
local DARK = look(meshColor(kw, "KingdomWall_stone_dark"), nil, true)
local FLAG = look(meshColor(kw, "KingdomWall_fabric_blue"), Enum.Material.Fabric, true)
local age = need(root, "AgeDetails") :: Model
local WORN = look(meshColor(age, "AgeDetails_stone_worn"))
local MOSS = look(meshColor(age, "AgeDetails_foliage_light"))

local wall = Instance.new("Model")
wall.Name = "KingdomWall2b"
wall.Parent = rep
local kwMeshes = #kw:GetDescendants()
park(kw, "KingdomWall")
for _, n in { "AgeDetails_stone_worn", "AgeDetails_foliage_light" } do
	park(need(age, n), "AgeDetails")
end

local XS, XE = 242, 240 -- side wall centre, end wall / front tower centre (export: 170, 168)
local SKIP_SIDE = { [-1] = { [56] = true, [160] = true }, [1] = {} } -- merlons the export leaves out (kept)
local SKIP_BACK = { [-1] = { [132] = true }, [1] = { [68] = true, [140] = true } }
for _, s in { -1, 1 } do
	local tag = if s < 0 then "W" else "E"
	block(wall, "SideWall_" .. tag, Vector3.new(s * XS, 4, 105), Vector3.new(3, 8, 190), STONE, false)
	block(wall, "SideTrim_" .. tag, Vector3.new(s * XS, 8.4, 105), Vector3.new(3.6, 0.8, 190.6), GOLD, false)
	for z = 24, 192, 8 do
		if (z < 100 or z > 110) and not SKIP_SIDE[s][z] then
			block(wall, "SideMerlon_" .. tag, Vector3.new(s * XS, 10.3, z), Vector3.new(3.4, 3, 3), STONE, false)
		end
	end
	block(wall, "EndWall_" .. tag, Vector3.new(s * XE, 7, -15), Vector3.new(4, 14, 50), STONE, false)
	block(wall, "BackWall_" .. tag, Vector3.new(s * 129.5, 4, 200), Vector3.new(225, 8, 3), STONE, false)
	block(wall, "BackTrim_" .. tag, Vector3.new(s * 129.5, 8.4, 200), Vector3.new(225.6, 0.8, 3.6), GOLD, false)
	for x = 28, 236, 8 do
		if not SKIP_BACK[s][x] then
			block(wall, "BackMerlon_" .. tag, Vector3.new(s * x, 10.3, 200), Vector3.new(3, 3, 3.4), STONE, false)
		end
	end
	-- towers: front corner (base row end), middle of the side wall, back corner
	for _, t in
		{
			{ "Front", s * XE, -40, 5, 26, 5.4, 6.4, 37.5 },
			{ "Mid", s * XS, 105, 5, 22, 5.4, 6.4, 33.5 },
			{ "Back", s * XS, 200, 6, 26, 6.4, 7.4, 39.8 },
		}
	do
		local n, x, z, r, top, ring, roofR, apex = t[1], t[2], t[3], t[4], t[5], t[6], t[7], t[8]
		prism(wall, "Tower" .. n .. "_" .. tag, x, z, r, 0, top, STONE)
		prism(wall, "TowerRing" .. n .. "_" .. tag, x, z, ring, top - 1.5, top - 0.5, GOLD)
		cone(wall, "TowerRoof" .. n .. "_" .. tag, x, z, roofR, top, apex, ROOF)
	end
	block(wall, "FlagPole_" .. tag, Vector3.new(s * XE, 42, -39.95), Vector3.new(0.4, 9, 0.5), DARK, false)
	block(wall, "Flag_" .. tag, Vector3.new(s * XE + 2.6, 44.1, -39.95), Vector3.new(5, 4, 0.3), FLAG, false)
	task.wait()
end
-- the parked AgeDetails pieces: wall-side ones on the new walls, the rest where they were
local aged = Instance.new("Model")
aged.Name = "AgeDetails2b"
aged.Parent = rep
block(aged, "WornPatch", Vector3.new(-240.25, 3.75, 150), Vector3.new(0.3, 3.5, 9), WORN, false)
block(aged, "WornPatch", Vector3.new(240.25, 3, 60), Vector3.new(0.3, 4, 8), WORN, false)
block(aged, "WornPatch", Vector3.new(240.25, 5, 176), Vector3.new(0.3, 3, 6), WORN, false)
block(aged, "WornPatch", Vector3.new(-120, 3.5, 198.25), Vector3.new(10, 4, 0.3), WORN, false)
block(aged, "WornPatch", Vector3.new(54, 4.5, 198.25), Vector3.new(7, 3, 0.3), WORN, false)
block(aged, "StumpBase", Vector3.new(-66, 0.5, 194), Vector3.new(4.4, 1, 4.4), WORN, false)
cylinder(aged, "Stump", Vector3.new(-66, 3, 194), 3.5, 6, WORN, false)
cylinder(aged, "StumpMoss", Vector3.new(-66, 6.25, 194), 3.8, 0.5, MOSS, false)
local fallen = cylinder(aged, "FallenColumn", Vector3.new(-60, 1.8, 191), 3.4, 4, WORN, false)
fallen.CFrame = CFrame.new(L(-60, 1.8, 191)) * CFrame.Angles(0, math.rad(45), 0)
block(aged, "StumpBase", Vector3.new(88, 0.5, 142), Vector3.new(4.4, 1, 4.4), WORN, false)
cylinder(aged, "Stump", Vector3.new(88, 1.75, 142), 3.4, 3.5, WORN, false)
cylinder(aged, "StumpMoss", Vector3.new(88, 3.7, 142), 3.8, 0.4, MOSS, false)
cylinder(aged, "TowerMoss", Vector3.new(-XS, 0.35, 200), 12.8, 0.7, MOSS, false)
cylinder(aged, "TowerMoss", Vector3.new(XS, 0.3, 105), 10.8, 0.6, MOSS, false)
block(aged, "WallMoss", Vector3.new(-240.05, 0.4, 150), Vector3.new(0.5, 0.8, 12), MOSS, false)
block(aged, "WallMoss", Vector3.new(240.05, 0.4, 60), Vector3.new(0.5, 0.8, 9), MOSS, false)
block(aged, "WallMoss", Vector3.new(-120, 0.4, 198.05), Vector3.new(9, 0.8, 0.5), MOSS, false)
block(aged, "WallMoss", Vector3.new(80, 0.3, 198.05), Vector3.new(6, 0.6, 0.5), MOSS, false)
say(("wall: %d parts (parked KingdomWall, %d instances, + 2 AgeDetails meshes)"):format(#wall:GetChildren(), kwMeshes))
task.wait()

-- 2. town strips: floor, walkway, rock, lanterns; collision -----------------------------------------------------------
local floorM = Instance.new("Model")
floorM.Name = "TownStrips2b"
floorM.Parent = rep
local hubFloor = need(root, "HubFloor")
local GRASS = look(meshColor(hubFloor, "HubFloor_grass"))
local PATH = look(meshColor(hubFloor, "HubFloor_path_warm"))
local ROCK = look((need(ext2b, "Rock_E") :: BasePart).Color, Enum.Material.Rock)
local lanterns = need(root, "Lanterns")
local POST = look(meshColor(lanterns, "Lanterns_stone_dark"), nil, true)
local GLOW = look(meshColor(lanterns, "Lanterns_glow_warm"), Enum.Material.Neon)
local function c2b(name: string): BasePart
	return need(col2b, name) :: BasePart
end
for _, s in { -1, 1 } do
	local tag = if s < 0 then "W" else "E"
	block(floorM, "TownGrass_" .. tag, Vector3.new(s * 206.75, -2, 119), Vector3.new(73.5, 4, 162), GRASS, false)
	block(floorM, "TownRock_" .. tag, Vector3.new(s * 205, -22, 100), Vector3.new(66, 36, 170), ROCK, false)
	for _, x in { 194, 230 } do -- two more walkway lanterns, like the export's at x 122 / 158
		block(floorM, "LanternPost_" .. tag, Vector3.new(s * x, 4.5, 37), Vector3.new(0.6, 9, 0.8), POST, false)
		block(floorM, "LanternGlow_" .. tag, Vector3.new(s * x, 9.8, 37), Vector3.new(1.6, 1.6, 1.6), GLOW, false)
		block(floorM, "LanternCap_" .. tag, Vector3.new(s * x, 11.2, 37), Vector3.new(2.8, 1.2, 2.8), POST, false)
	end
	-- the base-row floor becomes the walkway floor too (to z 38); band and rock reach the new corner
	local rowFloor = need(ext2b, "BaseRowFloor_" .. tag) :: BasePart
	resize(rowFloor, Vector3.new(73.5, 4, 78))
	moveTo(rowFloor, CFrame.new(L(s * 206.75, -2, -1)))
	local band = need(ext2b, "RedBand_" .. tag) :: BasePart
	resize(band, Vector3.new(75, 4, 55))
	moveTo(band, CFrame.new(L(s * 207.5, -2, -67.5)))
	local rock = need(ext2b, "Rock_" .. tag) :: BasePart
	resize(rock, Vector3.new(68, 26, 103))
	moveTo(rock, CFrame.new(L(s * 206, -17, -41.5)))
	-- collision
	local side = c2b(if s < 0 then "COL_West" else "COL_East")
	moveTo(side, CFrame.new(L(s * XS, 5, 105)))
	moveTo(c2b("COL_EndWall_" .. tag), CFrame.new(L(s * XE, 7, -15)))
	local back = c2b("COL_South_" .. tag)
	resize(back, Vector3.new(225, 10, 3))
	moveTo(back, CFrame.new(L(s * 129.5, 5, 200)))
	local rowCol = c2b("COL_Ext_BaseRow_" .. tag)
	resize(rowCol, Vector3.new(73.5, 4, 78))
	moveTo(rowCol, CFrame.new(L(s * 206.75, -2, -1)))
	local bandCol = c2b("COL_Ext_RedBand_" .. tag)
	resize(bandCol, Vector3.new(75, 4, 55))
	moveTo(bandCol, CFrame.new(L(s * 207.5, -2, -67.5)))
	local endGuard = c2b("GUARD_Ext_End_" .. tag)
	resize(endGuard, Vector3.new(1, 6, 55))
	moveTo(endGuard, CFrame.new(L(s * 245.5, 3, -67.5)))
	park(c2b("GUARD_Ext_Back_" .. tag), "Collision2b") -- stood behind bases 9-12's back doors
	park(c2b(if s < 0 then "GUARD_Band_N_WW" else "GUARD_Band_N_EE"), "Collision2b") -- the band now meets a platform there
end
local colR = Instance.new("Folder")
colR.Name = "Collision"
colR.Parent = rep
for _, s in { -1, 1 } do
	local tag = if s < 0 then "W" else "E"
	invisible(colR, "COL_Ext_Town_" .. tag, Vector3.new(s * 206.75, -2, 119), Vector3.new(73.5, 4, 162))
	invisible(colR, "COL_TowerFront_" .. tag, Vector3.new(s * XE, 13, -40), Vector3.new(10, 26, 10))
	invisible(colR, "COL_TowerMid_" .. tag, Vector3.new(s * XS, 11, 105), Vector3.new(10, 22, 10))
	invisible(colR, "COL_TowerBack_" .. tag, Vector3.new(s * XS, 13, 200), Vector3.new(12, 26, 12))
end
task.wait()

-- 3. grey platforms -----------------------------------------------------------------------------------------------
local zc = need(root, "ZoneConnectors_Unchanged")
local GREY = look(meshColor(zc, "ZoneConnectors_Unchanged_zone_unchanged"))
local plat = Instance.new("Model")
plat.Name = "Platforms2b"
plat.Parent = rep
block(plat, "PlatformExt_W", Vector3.new(-250, -2, -160), Vector3.new(80, 4, 130), GREY, true) -- x -290..-210 (Keep to -284)
block(plat, "PlatformExt_E", Vector3.new(245, -2, -160), Vector3.new(70, 4, 130), GREY, true) -- x 210..280 (Sunken to 274)
block(plat, "Connector_E", Vector3.new(318.5, -2, -160), Vector3.new(77, 4, 50), GREY, true) -- under the Sunken -> Ember ramp
block(plat, "Platform_Ember", Vector3.new(502, -2, -150), Vector3.new(290, 4, 266), GREY, true) -- x 357..647, z -283..-17
-- Ember's island floats 15 studs up: its cliff parts carried down to the platform (same shape, colour, footprint)
local island = World.Islands.BillionaireHillsIsland
for _, n in { "Cliff1", "Cliff2", "Cliff3", "Cliff4" } do
	local cliff = need(island, n) :: BasePart
	local cf = cliff.CFrame
	local axes = { cf.RightVector, cf.UpVector, cf.LookVector }
	local up = 1
	for i = 2, 3 do
		if math.abs(axes[i].Y) > math.abs(axes[up].Y) then
			up = i
		end
	end
	local bottom = cliff.Position.Y - cliff.Size[({ "X", "Y", "Z" })[up]] / 2 - H.Y
	local size = { cliff.Size.X, cliff.Size.Y, cliff.Size.Z }
	size[up] = bottom
	local p = cliff:Clone()
	p:ClearAllChildren()
	for k in p:GetAttributes() do
		p:SetAttribute(k, nil)
	end
	for _, t in CS:GetTags(p) do
		CS:RemoveTag(p, t)
	end
	p.Name = "EmberPedestal_" .. n
	p.Size = Vector3.new(size[1], size[2], size[3])
	p.CFrame = cf - Vector3.new(0, cliff.Position.Y - H.Y - bottom / 2, 0)
	p.CanCollide, p.CanQuery, p.CanTouch, p.Anchored = true, true, false, true
	p.Parent = plat
end
-- edge guards (invisible, 6 tall) on every new open edge
local guards = Instance.new("Folder")
guards.Name = "Guards"
guards.Parent = rep
for _, g in
	{
		{ "PlatW_Far", -250, -225.5, 80, 1 },
		{ "PlatW_West", -290.5, -160, 1, 130 },
		{ "PlatW_Near", -267.5, -94.5, 45, 1 },
		{ "PlatE_Far", 245, -225.5, 70, 1 },
		{ "PlatE_Near", 262.5, -94.5, 35, 1 },
		{ "PlatE_EastS", 280.5, -205, 1, 40 },
		{ "PlatE_EastN", 280.5, -115, 1, 40 },
		{ "Conn_S", 318.5, -185.5, 77, 1 },
		{ "Conn_N", 318.5, -134.5, 77, 1 },
		{ "Ember_WestS", 356.5, -234, 1, 98 },
		{ "Ember_WestN", 356.5, -76, 1, 118 },
		{ "Ember_Far", 502, -283.5, 290, 1 },
		{ "Ember_Near", 502, -16.5, 290, 1 },
		{ "Ember_East", 647.5, -150, 1, 266 },
	}
do
	invisible(guards, "GUARD_" .. g[1], Vector3.new(g[2], 3, g[3]), Vector3.new(g[4], 6, g[5]))
end
-- Ember's under-island dressing that would poke through the new floor: lowered
local summit = World.EmberAcademy:FindFirstChild("Summit031")
local lowered = 0
if summit then
	for _, d in summit:GetDescendants() do
		if d:IsA("BasePart") then
			local cf, s = d.CFrame, d.Size
			local top = d.Position.Y - H.Y + math.abs(cf.RightVector.Y) * s.X / 2 + math.abs(cf.UpVector.Y) * s.Y / 2 + math.abs(cf.LookVector.Y) * s.Z / 2
			if top > -0.5 then
				moveTo(d, d.CFrame - Vector3.new(0, top + 0.5, 0))
				lowered += 1
			end
		end
	end
end
say(("platforms: W to x -290, E to x 280, connector, Ember platform + 4 pedestal parts, %d guards, %d Ember dressing parts lowered"):format(#guards:GetChildren(), lowered))
task.wait()

-- 4. parade lane: the whole red spine -------------------------------------------------------------------------------
local lane = World.SkyCity.Ground.ParadeLane.Lane :: BasePart
local rot = lane.CFrame - lane.CFrame.Position
resize(lane, Vector3.new(16, 0.5, 189))
moveTo(lane, CFrame.new(L(0, -0.2, -138.5)) * rot) -- z -233..-44, still walking +Z (towards the gate)
say(("parade lane: z %.0f..%.0f"):format(lane.Position.Z - H.Z - 94.5, lane.Position.Z - H.Z + 94.5))

work:Destroy()
map:SetAttribute("Repair2b", true)
local n = 0
for _, d in rep:GetDescendants() do
	if d:IsA("BasePart") then
		n += 1
	end
end
say(("Repair2b parts: %d"):format(n))
return table.concat(log, "\n")
