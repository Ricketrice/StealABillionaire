-- V1_VisualFix.lua (Hub 2b visual review fixes, 2026-10-20). Run once in Studio Edit: tools/hub2b/run_file.py <this file>.
-- 1. Red parade path half as wide: the export's red T (band + 40-stud spine, one mesh) and its rock are parked and rebuilt
--    as parts: the band as before, the spine 20 wide (x +-10), rock under both.
-- 2. Grey platforms and the white ramp-bridges are parked (ServerStorage._Parked2b.VisualFix, attr ParkedFrom): the export's
--    ZoneConnectors (platforms + short red branches), the 10-20 platform extensions / Ember platform + pedestal and their
--    guards, the Keep bridge (Bridge036), both lane ramps, the Ember bridge and its grey path. The red path runs from the
--    junction straight to each zone's entrance instead: west up to Knight's Keep (new "ZONE 1 - FREE" arch), east up to
--    the Sunken Kingdom gate, and from the Sunken palace's back door up to the Ember Academy gate and on to its island.
--    Red path parts collide; invisible 6-stud edge guards on every open edge.
-- Everything new: Workspace.HubMap2b.VisualFix2b. Undo: tools/hub2b/V_Undo.lua (run it BEFORE R_Undo.lua / Undo.lua).
local SS = game:GetService("ServerStorage")

local H = Vector3.new(0, 0, 700)
local map = workspace:FindFirstChild("HubMap2b")
assert(map and map:GetAttribute("Repair2b") == true, "run R1_LayoutRepair.lua first")
assert(map:GetAttribute("VisualFix2b") == nil, "already done (run V_Undo.lua first)")
local root = map:FindFirstChild("Hub2b") :: Model
local col2b = map:FindFirstChild("Collision2b") :: Folder
local rep = map:FindFirstChild("Repair2b") :: Model
local World = workspace.World

local log = {}
local function say(s: string)
	table.insert(log, s)
end
local function L(x: number, y: number, z: number): Vector3
	return H + Vector3.new(x, y, z)
end
local parkRoot = SS:FindFirstChild("_Parked2b") or Instance.new("Folder")
parkRoot.Name = "_Parked2b"
parkRoot.Parent = SS
local parkFolder = parkRoot:FindFirstChild("VisualFix") or Instance.new("Folder")
parkFolder.Name = "VisualFix"
parkFolder.Parent = parkRoot
local parked = 0
local function park(inst: Instance?)
	if inst then
		inst:SetAttribute("ParkedFrom", (inst.Parent :: Instance):GetFullName())
		inst.Parent = parkFolder
		parked += 1
	end
end

-- looks, read before parking
local contested = root:FindFirstChild("ContestedLane_2a") :: Model
local RED = (contested:FindFirstChild("ContestedLane_2a_lane_contested", true) :: BasePart).Color
local ROCK = (contested:FindFirstChild("ContestedLane_2a_island_rock", true) :: BasePart).Color

-- 1/2. park -----------------------------------------------------------------------------------------------------------
park(contested)
park(root:FindFirstChild("ZoneConnectors_Unchanged"))
park(rep:FindFirstChild("Platforms2b"))
park(rep:FindFirstChild("Guards"))
park(World.KnightsKeep:FindFirstChild("Bridge036"))
for _, c in World.SkyCity.Lane:GetChildren() do
	if c.Name == "Ramp" then
		park(c)
	end
end
park(World.Bridges:FindFirstChild("BillionaireHillsBridge"))
park(World.FutureZones.Zone6_BillionaireHills:FindFirstChild("Path"))
for _, n in
	{
		"COL_Platform_W",
		"COL_Platform_E",
		"COL_Branch_W",
		"COL_Branch_E",
		"COL_Spine_T1",
		"COL_SpineJoin",
		"GUARD_Plat_W_InnerN",
		"GUARD_Plat_W_InnerS",
		"GUARD_Plat_E_InnerN",
		"GUARD_Plat_E_InnerS",
		"GUARD_Plat_W_Far",
		"GUARD_Plat_E_Far",
		"GUARD_Branch_W_N",
		"GUARD_Branch_W_S",
		"GUARD_Branch_E_N",
		"GUARD_Branch_E_S",
		"GUARD_Spine_W_A",
		"GUARD_Spine_E_A",
		"GUARD_Spine_W_B",
		"GUARD_Spine_E_B",
		"GUARD_Spine_End",
		"GUARD_Band_N_W",
		"GUARD_Band_N_E",
	}
do
	park(col2b:FindFirstChild(n))
end
say("parked " .. parked)

-- builders --------------------------------------------------------------------------------------------------------------
local out = Instance.new("Model")
out.Name = "VisualFix2b"
out.Parent = map
local function part(parent: Instance, name: string, cf: CFrame, size: Vector3, color: Color3, collide: boolean): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.Plastic
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = collide, collide, false, false
	p.Parent = parent
	return p
end
local function box(parent: Instance, name: string, x0: number, x1: number, y0: number, y1: number, z0: number, z1: number, color: Color3, collide: boolean): Part
	return part(parent, name, CFrame.new(L((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)), Vector3.new(x1 - x0, y1 - y0, z1 - z0), color, collide)
end
-- a slab along x whose TOP runs from (x0, top0) to (x1, top1), across z0..z1, `thick` studs deep (a ramp when top0 ~= top1)
local function slab(
	parent: Instance,
	name: string,
	x0: number,
	top0: number,
	x1: number,
	top1: number,
	z0: number,
	z1: number,
	thick: number,
	color: Color3,
	collide: boolean
): Part
	local a, b = L(x0, top0, (z0 + z1) / 2), L(x1, top1, (z0 + z1) / 2)
	local along = (b - a).Unit
	local up = Vector3.new(-along.Y, along.X, 0) * (if along.X >= 0 then 1 else -1) -- the normal with +Y
	local centre = (a + b) / 2 - up * thick / 2
	return part(parent, name, CFrame.fromMatrix(centre, along, up), Vector3.new((b - a).Magnitude, thick, z1 - z0), color, collide)
end
local guards = Instance.new("Folder")
guards.Name = "Guards"
guards.Parent = out
-- invisible 6-stud wall standing on a path edge from (x0, top0) to (x1, top1) at z
local function edge(name: string, x0: number, top0: number, x1: number, top1: number, z: number)
	local g = slab(guards, "GUARD_" .. name, x0, top0 + 6, x1, top1 + 6, z - 0.5, z + 0.5, 6, Color3.new(1, 1, 1), true)
	g.Transparency = 1
end
local function wall(name: string, x0: number, x1: number, z0: number, z1: number, base: number)
	local g = box(guards, "GUARD_" .. name, x0, x1, base, base + 6, z0, z1, Color3.new(1, 1, 1), true)
	g.Transparency = 1
end

-- 1. band + narrow spine --------------------------------------------------------------------------------------------
local path = Instance.new("Model")
path.Name = "RedPath"
path.Parent = out
box(path, "Band", -170, 170, -4, 0, -95, -40, RED, false) -- (the band's collision boxes stay in Collision2b)
box(path, "BandRock", -156, 156, -32, -4, -95, -28.5, ROCK, false)
local W = 10 -- half width of the red path (the spine was 20)
box(path, "Spine", -W, W, -4, 0, -235, -95, RED, true)
box(path, "SpineRock", -W + 2, W - 2, -16, -4, -233, -97, ROCK, false)
wall("Band_N_W", -245.5, -W, -96, -95, 0)
wall("Band_N_E", W, 245.5, -96, -95, 0)
wall("Spine_W_A", -W - 1, -W, -150 + 0, -95, 0)
wall("Spine_E_A", W, W + 1, -150, -95, 0)
-- (the spine's sides between z -150 and -170 open into the west and east paths)
wall("Spine_W_B", -W - 1, -W, -235, -170, 0)
wall("Spine_E_B", W, W + 1, -235, -170, 0)
wall("Spine_End", -W - 1, W + 1, -236, -235, 0)

-- 2. west: junction -> Knight's Keep (flat, ramp up 13.5, flat onto the island at x -132) ------------------------------
local Z0, Z1 = -160 - W, -160 + W
local KEEP_TOP = 13.5
slab(path, "West_Flat", -W, 0, -50, 0, Z0, Z1, 4, RED, true)
slab(path, "West_Ramp", -50, 0, -98, KEEP_TOP, Z0, Z1, 4, RED, true)
slab(path, "West_Span", -98, KEEP_TOP, -140, KEEP_TOP, Z0, Z1, 4, RED, true)
for _, s in { { "N", Z0 - 0.5 }, { "S", Z1 + 0.5 } } do
	edge("West_Flat_" .. s[1], -W, 0, -50, 0, s[2])
	edge("West_Ramp_" .. s[1], -50, 0, -98, KEEP_TOP, s[2])
	edge("West_Span_" .. s[1], -98, KEEP_TOP, -132, KEEP_TOP, s[2])
end

-- 3. east: junction -> Sunken Kingdom gate (x 104; its paving top 12 from x 92 to 116, the reef bridge from 119, 10 wide) --
local SUNKEN_TOP = 12
slab(path, "East_Flat", W, 0, 50, 0, Z0, Z1, 4, RED, true)
slab(path, "East_Ramp", 50, 0, 92, SUNKEN_TOP - 0.05, Z0, Z1, 4, RED, true)
slab(path, "East_GateFloor", 92, SUNKEN_TOP - 0.05, 116, SUNKEN_TOP - 0.05, Z0, Z1, 4, RED, true) -- (under the gate paving)
for _, s in { { "N", Z0 - 0.5 }, { "S", Z1 + 0.5 } } do
	edge("East_Flat_" .. s[1], W, 0, 50, 0, s[2])
	edge("East_Ramp_" .. s[1], 50, 0, 92, SUNKEN_TOP, s[2])
	edge("East_Gate_" .. s[1], 92, SUNKEN_TOP, 116.5, SUNKEN_TOP, s[2])
end
wall("East_EndN", 116, 117, Z0 - 1, -165, SUNKEN_TOP) -- the reef bridge beyond is only z -165..-155
wall("East_EndS", 116, 117, -155, Z1 + 1, SUNKEN_TOP)

-- 4. Sunken palace back door (x 269, floor ~13.6) -> Ember Academy gate (x 325.5; paving top 24 from x 313) -> its island ----
local EMBER_TOP = 24
slab(path, "Ember_Ramp", 269.7, 13.6, 313, EMBER_TOP - 0.05, Z0, Z1, 4, RED, true) -- (starts at the door: only a 4-stud ledge beyond it)
slab(path, "Ember_GateFloor", 313, EMBER_TOP - 0.05, 372, EMBER_TOP - 0.05, Z0, Z1, 4, RED, true) -- (under the gate paving)
for _, s in { { "N", Z0 - 0.5 }, { "S", Z1 + 0.5 } } do
	edge("Ember_Ramp_" .. s[1], 269.7, 13.6, 313, EMBER_TOP, s[2])
	edge("Ember_Gate_" .. s[1], 313, EMBER_TOP, 368, EMBER_TOP, s[2])
end
say("red path parts: " .. #path:GetChildren() .. ", guards: " .. #guards:GetChildren())

-- 5. Knight's Keep entrance arch: a copy of the zone gate frame, open, "ZONE 1 - KNIGHT'S KEEP - FREE" --------------------
local src = World.FutureZones.Our_SunkenKingdom:FindFirstChild("Gate") :: Model
local arch = src:Clone()
arch.Name = "KeepEntranceArch"
for _, n in { "Barrier", "LockPlate" } do
	for _, d in arch:GetChildren() do
		if d.Name == n then
			d:Destroy()
		end
	end
end
local STONE, GOLD = Color3.fromRGB(99, 95, 98), Color3.fromRGB(242, 182, 50)
for _, d in arch:GetDescendants() do
	if d:IsA("BasePart") then
		if d.Name == "PostA" or d.Name == "PostB" or d.Name == "GateWing" then
			d.Color = STONE
		elseif d.Name == "AccentStripe" then
			d.Color = Color3.fromRGB(196, 40, 28)
		end
	elseif d:IsA("TextLabel") then
		d.Text = "ZONE 1 · KNIGHT'S KEEP · FREE"
	end
end
-- the Sunken gate stands at x 104 on floor 12, facing along x: same facing here, at x -136 on floor 13.5
arch:PivotTo(CFrame.new(L(-136 - 104, KEEP_TOP - SUNKEN_TOP, 0)) * arch:GetPivot())
arch.Parent = out

map:SetAttribute("VisualFix2b", true)
return table.concat(log, "\n")
