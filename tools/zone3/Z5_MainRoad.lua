-- Z5_MainRoad.lua (2026-10-20, D55): the main road north past the junction, Zone 3 on its right (east) side.
-- Run in Studio Edit: python3 tools/hub2b/run_file.py tools/zone3/Z5_MainRoad.lua "local DRY = false" (DRY = list only).
-- Undo: tools/zone3/Z5_Undo.lua (before Z4_Undo).
--
-- 1. Main road: the red spine continues straight north from the junction (z 530) to z ROAD_END: 20 wide (x +-10, top 0),
--    rock under it (joins SpineRock), invisible 6-stud edge guards both sides (opening on the east for Zone 3's branch),
--    an end guard across the road at ROAD_END. Nothing on the road's right past Zone 3: room for the next zone.
-- 2. Zone 3 branch: east from the road edge at z BRANCH_Z: flat 12 (top 0) + ramp 44 to 13.5, 20 wide, rock, edge guards.
-- 3. The Zone 3 group (same items as Z4, Spell Run pieces in _ParkedSpellRun included so they still fit if restored) gets
--    one more rigid move: half turn (inward -X -> +X), gate paving's outer edge at the ramp top.
-- 4. The west branch (Z4's Zone3Side path, rock, guards, the band end opening) + the junction end guard ->
--    ServerStorage._Parked2b.Zone3West; the band's west end gets a whole end guard again. Decor in the way -> _Parked2b.MainRoad.
-- Records: moved -> attr PreZ5CFrame (+ tag MovedZ5); turned attrs PreZ5<name>; parked -> attr ParkedFrom;
-- created -> under Workspace.HubMap2b.MainRoad or attr CreatedZ5; map attrs MainRoad, Zone3Move5.
local DRY = if DRY == nil then true else DRY

local SS = game:GetService("ServerStorage")
local CS = game:GetService("CollectionService")
local map = workspace:FindFirstChild("HubMap2b")
assert(map and map:GetAttribute("Zone3Side") == true, "run Z4_SideZone3 first")
assert(map:GetAttribute("MainRoad") == nil, "already done (run Z5_Undo.lua first)")
local vf = map.VisualFix2b
local zs = map.Zone3Side
local World = workspace.World
local Lane = World.SkyCity.Lane
local EA = World.EmberAcademy
local FZ = World.FutureZones
local SR = SS._ParkedSpellRun

local log = {}
local function say(s: string)
	table.insert(log, s)
end
local function need(parent: Instance, name: string): Instance
	local c = parent:FindFirstChild(name)
	assert(c, "missing " .. parent:GetFullName() .. "." .. name)
	return c
end

-- layout ----------------------------------------------------------------------------------------------------------------
local W = 10
local JN = 530 -- the junction square's north edge
local BRANCH_Z = 400 -- Zone 3 branch centre line
local ROAD_END = 140 -- one more zone length past Zone 3 (next zone: right side z ~140..300)
local FLAT, RAMP, TOP = 12, 44, 13.5
local X_FLAT = W + FLAT
local X_RAMP = X_FLAT + RAMP

local floor = need(vf.RedPath, "Ember_GateFloor") :: BasePart
local spine = need(map.Review2.RedPath, "Spine") :: BasePart
local spineRock = need(map.Review2.RedPath, "SpineRock") :: BasePart
-- the gate paving's outer edge now (Z4: x -301.5, top 13.5, z 645), centre line
local edgeNow = (floor.CFrame * CFrame.new(-floor.Size.X / 2, floor.Size.Y / 2, 0)).Position
local T = CFrame.new(X_RAMP, TOP, BRANCH_Z) * CFrame.Angles(0, math.pi, 0) * CFrame.new(-edgeNow)
say(("paving edge %s -> %s"):format(tostring(edgeNow), tostring(T * edgeNow)))

-- 1. lists -------------------------------------------------------------------------------------------------------------
local group: { Instance } = {
	EA,
	need(FZ, "Zone6_BillionaireHills"),
	need(workspace.Zones, "BillionaireHills"),
	need(Lane, "T3_EmberAcademy"),
	floor,
	need(vf.Guards, "GUARD_Ember_Gate_N"),
	need(vf.Guards, "GUARD_Ember_Gate_S"),
	need(SS, "_ParkedEmber"),
	need(SS, "_ParkedNecro"),
}
for _, n in { "SpellRun", "Balustrade", "Ember036EndRail", "Summit031", "BillionaireHillsIsland", "SpellRunCourse034" } do
	table.insert(group, need(SR, n))
end
for _, g in World.BridgeGuards:GetChildren() do
	if g.Name:match("^BillionaireHillsBridgeGuard") then
		table.insert(group, g)
	end
end
for _, f in { Lane.Rocks, Lane.Clouds } do
	for _, c in f:GetChildren() do
		if CS:HasTag(c, "MovedZ4") then
			table.insert(group, c)
		end
	end
end
-- the west branch + the junction end guard
local west: { Instance } = { need(zs.Guards, "GUARD_Spine_JunctionEnd") }
for _, c in zs.RedPath:GetChildren() do
	table.insert(west, c)
end
for _, c in zs.Guards:GetChildren() do
	if c.Name:match("^GUARD_West3_") or c.Name:match("^GUARD_BandEnd_W_") then
		table.insert(west, c)
	end
end
local bandN = need(zs.Guards, "GUARD_BandEnd_W_N") :: BasePart
local bandS = need(zs.Guards, "GUARD_BandEnd_W_S") :: BasePart
say(("move %d items; park west branch %d"):format(#group, #west))

-- new footprint + what is in the way (Workspace parts not moving / parked)
local moveSet = {}
for _, i in group do
	moveSet[i] = true
end
local westSet = {}
for _, i in west do
	westSet[i] = true
end
local function under(d: Instance, set): boolean
	local x: Instance? = d
	while x do
		if set[x] then
			return true
		end
		x = x.Parent
	end
	return false
end
-- footprint of the zone itself (not the sky clouds/rocks that move with it)
local core = { EA, FZ.Zone6_BillionaireHills, workspace.Zones.BillionaireHills, Lane.T3_EmberAcademy, floor }
local lo, hi = Vector3.one * 1e9, -Vector3.one * 1e9
for _, i in core do
	for _, d in { i, table.unpack(i:GetDescendants()) } do
		if d:IsA("BasePart") and d:IsDescendantOf(workspace) then
			local p = T * d.Position
			lo, hi = lo:Min(p), hi:Max(p)
		end
	end
end
say(("new Zone 3 footprint x %.0f..%.0f y %.0f..%.0f z %.0f..%.0f"):format(lo.X, hi.X, lo.Y, hi.Y, lo.Z, hi.Z))
local boxes = {
	{ "zone", Vector3.new(W, lo.Y - 20, lo.Z - 15), Vector3.new(hi.X + 15, hi.Y + 20, hi.Z + 15) },
	{ "road", Vector3.new(-W - 15, -40, ROAD_END - 15), Vector3.new(W + 15, 30, JN - 2) },
	{ "next zone", Vector3.new(W, -40, ROAD_END), Vector3.new(hi.X + 15, 120, lo.Z - 15) },
}
local inWay: { Instance } = {}
local seen = {}
local blockers = 0
for _, d in workspace:GetDescendants() do
	if d:IsA("BasePart") and d ~= workspace.Terrain and not under(d, moveSet) and not under(d, westSet) then
		local p = d.Position
		for _, b in boxes do
			if p.X > b[2].X and p.X < b[3].X and p.Y > b[2].Y and p.Y < b[3].Y and p.Z > b[2].Z and p.Z < b[3].Z then
				local top = d
				while top.Parent and top.Parent:IsA("Model") and top.Parent.Parent ~= workspace do
					top = top.Parent
				end
				if not seen[top] then
					seen[top] = true
					local decor = top:IsDescendantOf(Lane.Rocks) or top:IsDescendantOf(Lane.Clouds) or top:IsDescendantOf(World.SkyCity.Ground.Rocks)
					if decor then
						table.insert(inWay, top)
					else
						blockers += 1
					end
					say(("IN %s%s: %s at %.0f,%.0f,%.0f"):format(b[1], if decor then " (decor, parked)" else " (BLOCKER)", top:GetFullName(), p.X, p.Y, p.Z))
				end
			end
		end
	end
end
if DRY or blockers > 0 then
	return (if blockers > 0 then "STOPPED: blockers\n" else "") .. table.concat(log, "\n")
end

-- 2. move ----------------------------------------------------------------------------------------------------------------
local DIRS = { Axis = true, Inward = true }
local function record(inst: Instance, cf: CFrame)
	if inst:GetAttribute("PreZ5CFrame") == nil then
		inst:SetAttribute("PreZ5CFrame", cf)
		CS:AddTag(inst, "MovedZ5")
	end
end
local function moveItem(inst: Instance)
	if inst:IsA("BasePart") then
		record(inst, inst.CFrame)
		inst.CFrame = T * inst.CFrame
	elseif inst:IsA("Model") then
		record(inst, inst:GetPivot())
		inst:PivotTo(T * inst:GetPivot())
	else
		for _, c in inst:GetChildren() do
			moveItem(c)
		end
	end
end
for _, i in group do
	for _, d in { i, table.unpack(i:GetDescendants()) } do
		for k, v in d:GetAttributes() do
			if DIRS[k] and typeof(v) == "Vector3" then
				d:SetAttribute("PreZ5" .. k, v)
				d:SetAttribute(k, T.Rotation * v)
			end
		end
	end
	moveItem(i)
	task.wait()
end

-- 3. park ------------------------------------------------------------------------------------------------------------------
local p2b = SS._Parked2b
local westFolder = Instance.new("Folder")
westFolder.Name = "Zone3West"
westFolder.Parent = p2b
local decorFolder = Instance.new("Folder")
decorFolder.Name = "MainRoad"
decorFolder.Parent = p2b
local function park(list: { Instance }, to: Instance)
	for _, i in list do
		i:SetAttribute("ParkedFrom", (i.Parent :: Instance):GetFullName())
		i.Parent = to
	end
end
-- the band's west end: one whole guard again (z of the two halves)
local bz0 = bandN.Position.Z - bandN.Size.Z / 2
local bz1 = bandS.Position.Z + bandS.Size.Z / 2
park(west, westFolder)
park(inWay, decorFolder)
say(("parked: west branch %d, in the way %d"):format(#west, #inWay))

-- 4. build ------------------------------------------------------------------------------------------------------------------
local out = Instance.new("Model")
out.Name = "MainRoad"
out.Parent = map
local path = Instance.new("Model")
path.Name = "RedPath"
path.Parent = out
local guards = Instance.new("Folder")
guards.Name = "Guards"
guards.Parent = out
local RED, ROCK = spine.Color, spineRock.Color
local function part(parent: Instance, name: string, cf: CFrame, size: Vector3, color: Color3, collide: boolean): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = spine.Material
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = collide, collide, false, false
	p.Parent = parent
	return p
end
local function box(parent: Instance, name: string, x0: number, x1: number, y0: number, y1: number, z0: number, z1: number, color: Color3, collide: boolean): Part
	return part(parent, name, CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), Vector3.new(x1 - x0, y1 - y0, z1 - z0), color, collide)
end
-- a slab along X whose top runs from (x0, top0) to (x1, top1), z0..z1 wide
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
	local zc = (z0 + z1) / 2
	local a, b = Vector3.new(x0, top0, zc), Vector3.new(x1, top1, zc)
	local along = (b - a).Unit
	local up = Vector3.new(-along.Y, along.X, 0) * (if along.X >= 0 then 1 else -1)
	local c = (a + b) / 2 - up * thick / 2
	return part(parent, name, CFrame.fromMatrix(c, along, up), Vector3.new((b - a).Magnitude, thick, z1 - z0), color, collide)
end
local WHITE = Color3.new(1, 1, 1)
local function guard(name: string, x0: number, x1: number, z0: number, z1: number): Part
	local p = box(guards, name, x0, x1, 0, 6, z0, z1, WHITE, true)
	p.Transparency = 1
	return p
end

-- the road (joins the spine at the junction's north edge)
box(path, "Road", -W, W, -4, 0, ROAD_END, JN, RED, true)
local rockTop = spineRock.Position.Y + spineRock.Size.Y / 2
local rockBot = spineRock.Position.Y - spineRock.Size.Y / 2
box(path, "RoadRock", -spineRock.Size.X / 2, spineRock.Size.X / 2, rockBot, rockTop, ROAD_END + 2, JN + 2, ROCK, false)
guard("GUARD_Road_W", -W - 1, -W, ROAD_END - 1, JN)
guard("GUARD_Road_E_South", W, W + 1, BRANCH_Z + W, JN)
guard("GUARD_Road_E_North", W, W + 1, ROAD_END - 1, BRANCH_Z - W)
guard("GUARD_Road_End", -W - 1, W + 1, ROAD_END - 1, ROAD_END)

-- Zone 3 branch (east)
local Z0, Z1 = BRANCH_Z - W, BRANCH_Z + W
slab(path, "East3_Flat", W, 0, X_FLAT, 0, Z0, Z1, 4, RED, true)
slab(path, "East3_Ramp", X_FLAT, 0, X_RAMP, TOP, Z0, Z1, 4, RED, true)
slab(path, "East3_FlatRock", W - 2, -4, X_FLAT, -4, Z0 + 2, Z1 - 2, 12, ROCK, false)
slab(path, "East3_RampRock", X_FLAT, -4, X_RAMP, TOP - 4, Z0 + 2, Z1 - 2, 12, ROCK, false)
for _, s in { { "N", Z0 - 0.5 }, { "S", Z1 + 0.5 } } do
	local g1 = slab(guards, "GUARD_East3_Flat_" .. s[1], W, 6, X_FLAT, 6, s[2] - 0.5, s[2] + 0.5, 6, WHITE, true)
	local g2 = slab(guards, "GUARD_East3_Ramp_" .. s[1], X_FLAT, 6, X_RAMP + 0.5, TOP + 6, s[2] - 0.5, s[2] + 0.5, 6, WHITE, true)
	g1.Transparency, g2.Transparency = 1, 1
	-- the flat/ramp seam leaves a low wedge between the two guards
	box(guards, "GUARD_East3_Seam_" .. s[1], X_FLAT - 1, X_FLAT + 3, 0, 7, s[2] - 0.5, s[2] + 0.5, WHITE, true).Transparency = 1
end

-- the band's west end guard, whole again
local bx = bandN.Position.X
local endW = box(map.Zone3Side.Guards, "GUARD_BandEnd_W", bx - 0.5, bx + 0.5, 0, 6, bz0, bz1, WHITE, true)
endW.Transparency = 1
endW:SetAttribute("CreatedZ5", true)

map:SetAttribute("Zone3Move5", T)
map:SetAttribute("MainRoad", true)
local barrier = FZ.Zone6_BillionaireHills.Gate.Barrier :: BasePart
say(
	("done. road z %.0f..%.0f; branch z %.0f x %.0f..%.0f; Zone 3 gate barrier %s inward %s; band end guard z %.1f..%.1f"):format(
		ROAD_END,
		JN,
		BRANCH_Z,
		W,
		X_RAMP,
		tostring(barrier.Position),
		tostring(barrier:GetAttribute("Inward")),
		bz0,
		bz1
	)
)
return table.concat(log, "\n")
