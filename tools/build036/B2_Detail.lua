-- tools/build036/B2_Detail.lua (036 Knight's Keep polish, step 2): materials + cheap phone-friendly detail. Look only.
-- Run in Edit (command bar / MCP loadstring). Re-runnable: removes its own Detail036 and restores every material it changed first.
-- UNDO = true only restores.
--   * Materials (old value kept in attributes Mat036 / Col036): courtyard paving -> Cobblestone, stone walls / towers / gatehouse / hall ->
--     Brick (same grey), wood in the gate, walls, towers, hall -> WoodPlanks, the island top outside the walls -> Grass (green).
--     The dirt road (Path_Main_Earth) stays. A thin cobblestone plate covers the island top inside the walls, under the paving.
--   * Courtyard: a well, 3 market stalls with striped awnings, 2 more training dummies, 6 banners, 6 flower boxes, 4 lanterns.
--     The dirt road (x -162.5..-153.5) and the 6 creature spawn points stay clear (nothing within 6 studs of a spawn).
--   * Outside the walls: trees + bushes on the island top (skipped where they would touch the castle); rocky cliff layers under the island.
-- Every new part: no collision / query / touch, CastShadow off (except the trees' canopies), so nothing changes for players or wanderers.
local UNDO = false

local world = workspace:WaitForChild("World")
local kk = world.KnightsKeep
local ruined = kk.KeepRuined.KnightKeep_Ruined

-- restore earlier material changes
for _, d in kk:GetDescendants() do
	if d:IsA("BasePart") and d:GetAttribute("Mat036") then
		d.Material = Enum.Material[d:GetAttribute("Mat036")]
		local c = d:GetAttribute("Col036")
		if typeof(c) == "Color3" then
			d.Color = c
		end
		d:SetAttribute("Mat036", nil)
		d:SetAttribute("Col036", nil)
	end
end
local old = kk:FindFirstChild("Detail036")
if old then
	old:Destroy()
end
if UNDO then
	return "B2 undone: materials restored, Detail036 removed"
end

local function setMat(p: BasePart, mat: Enum.Material, color: Color3?)
	p:SetAttribute("Mat036", p.Material.Name)
	if color then
		p:SetAttribute("Col036", p.Color)
		p.Color = color
	end
	p.Material = mat
end

-- Materials --------------------------------------------------------------------------------------------
local changed = 0
for _, groupName in { "Walls", "Towers", "Gate", "BackHall" } do
	local g = ruined:FindFirstChild(groupName)
	for _, d in (g and g:GetDescendants() or {}) do
		if d:IsA("BasePart") then
			if d.Name:find("Stone") then
				setMat(d, Enum.Material.Brick)
				changed += 1
			elseif d.Name:find("Wood") then
				setMat(d, Enum.Material.WoodPlanks)
				changed += 1
			end
		end
	end
end
for _, d in kk.CornerFill037:GetDescendants() do
	if d:IsA("BasePart") and d.Name:find("Stone") then
		setMat(d, Enum.Material.Brick)
		changed += 1
	end
end
local paving = ruined.Courtyard:FindFirstChild("Path_Main_Flagstone_Worn", true) :: BasePart
setMat(paving, Enum.Material.Cobblestone)
local islandTop = ruined.Terrain:FindFirstChild("Island_Top_Grass_Dead", true) :: BasePart
setMat(islandTop, Enum.Material.Grass, Color3.fromRGB(104, 168, 70))
changed += 2

-- Builders ---------------------------------------------------------------------------------------------
local folder = Instance.new("Folder")
folder.Name = "Detail036"
local groups: { [string]: Folder } = {}
local function group(name: string): Folder
	if not groups[name] then
		local f = Instance.new("Folder")
		f.Name = name
		f.Parent = folder
		groups[name] = f
	end
	return groups[name]
end
local count = 0
local function part(parent: Instance, props: { [string]: any }): BasePart
	local p = Instance.new(props.Class or "Part") :: BasePart
	p.Anchored = true
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = false, false, false, false
	for k, v in props do
		if k ~= "Class" then
			(p :: any)[k] = v
		end
	end
	p.Parent = parent
	count += 1
	return p
end
local FLOOR = 13.43 -- just above the island top (13.39), below the paving (13.46+)
local WOOD = Color3.fromRGB(122, 86, 56)
local DARKWOOD = Color3.fromRGB(92, 64, 44)
local STONE = Color3.fromRGB(150, 144, 134)

-- Courtyard --------------------------------------------------------------------------------------------
local court = group("Courtyard")
-- cobblestone over the island top inside the walls (x -185.7..-129.3, z -214.1..-297.5)
part(court, { Name = "CobbleFloor", Size = Vector3.new(56, 0.2, 83.4), CFrame = CFrame.new(-157.5, FLOOR - 0.1, -255.8), Material = Enum.Material.Cobblestone, Color = Color3.fromRGB(142, 136, 126) })

-- well (west of the road, half-way between spawn points 1 and 4)
do
	local c = Vector3.new(-173, FLOOR, -257)
	local f = group("Well")
	part(f, { Name = "Rim", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.4, 6.4, 6.4), CFrame = CFrame.new(c + Vector3.new(0, 1.2, 0)) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Brick, Color = STONE })
	part(f, { Name = "Water", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 5.2, 5.2), CFrame = CFrame.new(c + Vector3.new(0, 2.25, 0)) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Glass, Color = Color3.fromRGB(70, 150, 210), Transparency = 0.15 })
	for _, s in { -1, 1 } do
		part(f, { Name = "Post", Size = Vector3.new(0.5, 5, 0.5), CFrame = CFrame.new(c + Vector3.new(s * 2.9, 4.6, 0)), Material = Enum.Material.WoodPlanks, Color = WOOD })
		part(f, { Name = "Roof", Size = Vector3.new(7.6, 0.3, 2.9), CFrame = CFrame.new(c + Vector3.new(0, 7.75, s * 1.25)) * CFrame.Angles(math.rad(s * 32), 0, 0), Material = Enum.Material.WoodPlanks, Color = Color3.fromRGB(170, 70, 56) })
	end
	part(f, { Name = "Crossbar", Shape = Enum.PartType.Cylinder, Size = Vector3.new(5.8, 0.35, 0.35), CFrame = CFrame.new(c + Vector3.new(0, 6, 0)), Material = Enum.Material.Wood, Color = DARKWOOD })
end

-- market stalls: counter, two posts, a two-stripe awning sloping to the front, a crate of goods
local function stall(name: string, at: Vector3, facing: number, a: Color3, b: Color3, goods: Color3)
	local f = group(name)
	local base = CFrame.new(at) * CFrame.Angles(0, facing, 0) -- local -Z = towards the road
	part(f, { Name = "Counter", Size = Vector3.new(6, 2.6, 2), CFrame = base * CFrame.new(0, 1.3, -1), Material = Enum.Material.WoodPlanks, Color = WOOD })
	for _, s in { -1, 1 } do
		part(f, { Name = "Post", Size = Vector3.new(0.4, 6, 0.4), CFrame = base * CFrame.new(s * 2.8, 3, 1.6), Material = Enum.Material.Wood, Color = DARKWOOD })
	end
	for i, col in { a, b } do
		part(f, { Name = "Awning", Size = Vector3.new(3.2, 0.25, 4.6), CFrame = base * CFrame.new(-1.6 + (i - 1) * 3.2, 5.6, -0.6) * CFrame.Angles(math.rad(-16), 0, 0), Material = Enum.Material.Fabric, Color = col })
	end
	part(f, { Name = "Goods", Size = Vector3.new(4.4, 0.7, 1.4), CFrame = base * CFrame.new(0, 2.95, -1), Material = Enum.Material.SmoothPlastic, Color = goods })
end
stall("StallRed", Vector3.new(-143, FLOOR, -257), math.rad(90), Color3.fromRGB(210, 60, 60), Color3.fromRGB(245, 240, 228), Color3.fromRGB(220, 80, 60))
stall("StallBlue", Vector3.new(-143, FLOOR, -224), math.rad(90), Color3.fromRGB(60, 110, 210), Color3.fromRGB(250, 205, 70), Color3.fromRGB(240, 190, 60))
stall("StallGreen", Vector3.new(-171, FLOOR, -224), math.rad(-90), Color3.fromRGB(70, 160, 80), Color3.fromRGB(245, 240, 228), Color3.fromRGB(150, 90, 200))

-- training dummies (the map has a set on the west wall; two more by the back wall)
for _, x in { -170, -144 } do
	local f = group("Dummy")
	local c = Vector3.new(x, FLOOR, -291)
	part(f, { Name = "Pole", Size = Vector3.new(0.4, 5.2, 0.4), CFrame = CFrame.new(c + Vector3.new(0, 2.6, 0)), Material = Enum.Material.Wood, Color = DARKWOOD })
	part(f, { Name = "Body", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.6, 1.6, 1.6), CFrame = CFrame.new(c + Vector3.new(0, 3.2, 0)) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Fabric, Color = Color3.fromRGB(196, 168, 112) })
	part(f, { Name = "Head", Shape = Enum.PartType.Ball, Size = Vector3.new(1.3, 1.3, 1.3), CFrame = CFrame.new(c + Vector3.new(0, 5.1, 0)), Material = Enum.Material.Fabric, Color = Color3.fromRGB(196, 168, 112) })
	part(f, { Name = "Arms", Size = Vector3.new(3.6, 0.3, 0.3), CFrame = CFrame.new(c + Vector3.new(0, 4, 0)), Material = Enum.Material.Wood, Color = DARKWOOD })
end

-- banners on poles: flanking the road at the gate and at the hall steps, two half-way
local banners = { { -165, -218, 1 }, { -149, -218, 2 }, { -165, -296, 2 }, { -149, -296, 1 }, { -149, -246, 1 }, { -165, -268, 2 } }
local BANNER = { { Color3.fromRGB(196, 44, 52), Color3.fromRGB(248, 200, 64) }, { Color3.fromRGB(44, 86, 180), Color3.fromRGB(245, 240, 228) } }
for _, b in banners do
	local f = group("Banner")
	local c = Vector3.new(b[1], FLOOR, b[2])
	part(f, { Name = "Pole", Size = Vector3.new(0.35, 10, 0.35), CFrame = CFrame.new(c + Vector3.new(0, 5, 0)), Material = Enum.Material.Wood, Color = DARKWOOD })
	part(f, { Name = "Cloth", Size = Vector3.new(0.12, 4.2, 2.6), CFrame = CFrame.new(c + Vector3.new(0, 7.4, 1.45)), Material = Enum.Material.Fabric, Color = BANNER[b[3]][1] })
	part(f, { Name = "Trim", Size = Vector3.new(0.14, 0.5, 2.6), CFrame = CFrame.new(c + Vector3.new(0, 5.45, 1.45)), Material = Enum.Material.Fabric, Color = BANNER[b[3]][2] })
end

-- flower boxes against the front and back walls
local boxes = { { -180, -215.4, 0 }, { -174.5, -215.4, 0 }, { -139.5, -215.4, 0 }, { -134, -215.4, 0 }, { -175, -296.4, 0 }, { -139, -296.4, 0 } } -- (clear of the gatehouses, x -170..-144)
local PETALS = { Color3.fromRGB(240, 110, 160), Color3.fromRGB(250, 210, 70), Color3.fromRGB(170, 110, 230) }
for i, b in boxes do
	local f = group("FlowerBox")
	local c = Vector3.new(b[1], FLOOR, b[2])
	part(f, { Name = "Box", Size = Vector3.new(4, 1, 1.2), CFrame = CFrame.new(c + Vector3.new(0, 0.5, 0)), Material = Enum.Material.WoodPlanks, Color = WOOD })
	part(f, { Name = "Leaves", Size = Vector3.new(3.6, 0.5, 0.9), CFrame = CFrame.new(c + Vector3.new(0, 1.15, 0)), Material = Enum.Material.Grass, Color = Color3.fromRGB(80, 150, 64) })
	part(f, { Name = "Flowers", Size = Vector3.new(3.2, 0.35, 0.6), CFrame = CFrame.new(c + Vector3.new(0, 1.5, 0)), Material = Enum.Material.SmoothPlastic, Color = PETALS[(i - 1) % #PETALS + 1] })
end

-- lanterns on posts just off the road
for _, p in { { -164.5, -232 }, { -149.5, -232 }, { -164.5, -282 }, { -149.5, -282 } } do
	local f = group("Lantern")
	local c = Vector3.new(p[1], FLOOR, p[2])
	part(f, { Name = "Post", Size = Vector3.new(0.4, 6, 0.4), CFrame = CFrame.new(c + Vector3.new(0, 3, 0)), Material = Enum.Material.Wood, Color = DARKWOOD })
	part(f, { Name = "Lamp", Size = Vector3.new(1, 1.2, 1), CFrame = CFrame.new(c + Vector3.new(0, 6.5, 0)), Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 206, 120) })
end

-- Outside the walls: trees and bushes on the island top (x -200.5..-115.5, z -197.5..-324.5) --------------
local outside = group("Outside")
local castle = OverlapParams.new()
castle.FilterType = Enum.RaycastFilterType.Include
castle.FilterDescendantsInstances = { kk.KeepRuined, kk.CornerFill037, kk.Access037, folder }
local function clear(at: Vector3, radius: number, height: number): boolean
	return #workspace:GetPartBoundsInBox(CFrame.new(at + Vector3.new(0, height / 2 + 0.6, 0)), Vector3.new(radius * 2, height, radius * 2), castle) == 0
end
local skipped = 0
local LEAF = { Color3.fromRGB(74, 150, 64), Color3.fromRGB(92, 168, 72), Color3.fromRGB(62, 132, 58) }
local treeSpots = { { -194, -224 }, { -194, -258 }, { -194, -282 }, { -194, -310 }, { -121, -226 }, { -121, -258 }, { -121, -284 }, { -121, -312 } }
for i, t in treeSpots do
	local base = Vector3.new(t[1], 13.39, t[2])
	if clear(base, 3.2, 9) then
		part(outside, { Name = "TreeTrunk", Shape = Enum.PartType.Cylinder, Size = Vector3.new(6, 1.3, 1.3), CFrame = CFrame.new(base + Vector3.new(0, 3, 0)) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Wood, Color = DARKWOOD })
		part(outside, { Name = "TreeTop", Shape = Enum.PartType.Ball, Size = Vector3.new(6.4, 6.4, 6.4), CFrame = CFrame.new(base + Vector3.new(0, 7.4, 0)), Material = Enum.Material.Grass, Color = LEAF[(i - 1) % 3 + 1], CastShadow = true })
		part(outside, { Name = "TreeTop", Shape = Enum.PartType.Ball, Size = Vector3.new(4.4, 4.4, 4.4), CFrame = CFrame.new(base + Vector3.new(0.8, 10, -0.6)), Material = Enum.Material.Grass, Color = LEAF[i % 3 + 1] })
	else
		skipped += 1
	end
end
local bushSpots = { { -197, -240 }, { -191, -270 }, { -197, -296 }, { -190, -318 }, { -118, -242 }, { -124, -270 }, { -118, -298 }, { -125, -320 } }
for i, s in bushSpots do
	local at = Vector3.new(s[1], 13.39, s[2])
	if clear(at, 1.8, 3) then
		part(outside, { Name = "Bush", Shape = Enum.PartType.Ball, Size = Vector3.new(3.4, 2.8, 3.4), CFrame = CFrame.new(at + Vector3.new(0, 1, 0)), Material = Enum.Material.Grass, Color = LEAF[(i - 1) % 3 + 1] })
	else
		skipped += 1
	end
end

-- Rocky cliff under the island (its rock body ends at y -8.9): layers that shrink downwards, each block turned a little
local cliff = group("Cliff")
local ROCK = { Color3.fromRGB(112, 102, 92), Color3.fromRGB(98, 90, 82), Color3.fromRGB(126, 116, 104) }
local layers = {
	{ y = -13, size = Vector3.new(44, 10, 62), at = { { -22, -30 }, { 22, -30 }, { -22, 30 }, { 22, 30 } } },
	{ y = -22, size = Vector3.new(34, 10, 46), at = { { -14, -22 }, { 14, 0 }, { -10, 24 } } },
	{ y = -31, size = Vector3.new(22, 10, 28), at = { { -6, -10 }, { 6, 12 } } },
	{ y = -39, size = Vector3.new(12, 8, 14), at = { { 0, 0 } } },
}
local CENTER = Vector3.new(-158, 0, -261)
local k = 0
for _, l in layers do
	for _, o in l.at do
		k += 1
		local turn = CFrame.Angles(math.rad((k * 37) % 11 - 5), math.rad((k * 53) % 40 - 20), math.rad((k * 29) % 9 - 4))
		part(cliff, { Name = "Rock", Size = l.size, CFrame = CFrame.new(CENTER + Vector3.new(o[1], l.y, o[2])) * turn, Material = Enum.Material.Rock, Color = ROCK[k % 3 + 1] })
	end
end

folder.Parent = kk
return ("B2 detail: %d materials changed, %d new parts (skipped %d trees/bushes touching the castle)"):format(changed, count, skipped)
