-- Z4_SideZone3.lua (2026-10-20, D54): Spell Run removed, Zone 3 on its own side branch, parade on the hub side.
-- Run in Studio Edit: python3 tools/hub2b/run_file.py tools/zone3/Z4_SideZone3.lua "local DRY = false" (DRY = list only).
-- Undo: tools/zone3/Z4_Undo.lua (before Z3_Undo).
--
-- 1. Spell Run: the course (SpellRun), its island (BillionaireHillsIsland + Balustrade rails, Ember036EndRail, Summit031
--    rocks) and the race template (SpellRunCourse034) -> ServerStorage._ParkedSpellRun. The old plaza island west of
--    the hub (PlazaIsland + its PlazaRing bounds + everything standing on it: Golden Vault, Arena ring + venue, gate
--    lines, trees, hedges, rocks, BillionairePlaza rings) and the PlazaIslandFallGuard -> _ParkedSpellRun.Plaza.
--    BillionairePlaza.ArenaFloor stays (ZoneProgress waits for it) but is hidden (no collide). The Zone 3 wall gap that
--    led to the Spell Run gets an invisible guard like the rest of that wall line. (The race switch is code: RaceConfig.)
-- 2. Zone 3 moves to the west side: the spine ends at the junction (north stub + Zone 3 north path parked), a new
--    branch leaves the red band's west end (x -245.5, z 645): flat 12 + ramp 44 to 13.5, 20 wide, rock, edge guards.
--    The Zone 3 group (as in Z3_Access) gets one more rigid move: quarter turn (inward -Z -> -X), gate paving edge
--    at the ramp top.
-- 3. Parade lane = the red band in front of the bases, x -92.5..92.5 (walkers spawn at the west end, leave at the
--    east end; ~175 studs walked at 2.6 = ~67 s, one every 9 s -> 7-8 on it). Speed/interval unchanged.
-- Records: moved/resized -> attrs PreZ4CFrame / PreZ4Size (+ tag MovedZ4); turned attrs PreZ4<name>; changed props
-- PreZ4Transparency / PreZ4CanCollide; parked -> attr ParkedFrom; created -> attr CreatedZ4 or under
-- Workspace.HubMap2b.Zone3Side; map attrs Zone3Side, Zone3Move4.
local DRY = if DRY == nil then true else DRY

local SS = game:GetService("ServerStorage")
local CS = game:GetService("CollectionService")
local map = workspace:FindFirstChild("HubMap2b")
assert(map and map:GetAttribute("Zone3Access") == true, "run Z3_Access first")
assert(map:GetAttribute("Zone3Side") == nil, "already done (run Z4_Undo.lua first)")
local vf = map.VisualFix2b
local z3a = map.Zone3Access
local World = workspace.World
local Lane = World.SkyCity.Lane
local EA = World.EmberAcademy

local log = {}
local function say(s: string)
	table.insert(log, s)
end
local function need(parent: Instance, name: string): Instance
	local c = parent:FindFirstChild(name)
	assert(c, "missing " .. parent:GetFullName() .. "." .. name)
	return c
end

-- transform ----------------------------------------------------------------------------------------------------------
local floor = need(vf.RedPath, "Ember_GateFloor") :: BasePart
local spine = need(map.Review2.RedPath, "Spine") :: BasePart
local spineRock = need(map.Review2.RedPath, "SpineRock") :: BasePart
local bandEndGuard = map:FindFirstChild("GUARD_Ext_End_W", true) :: BasePart
assert(bandEndGuard, "band end guard missing")
local W = 10
local BAND_END = bandEndGuard.Position.X -- -245.5
local ZC = bandEndGuard.Position.Z -- 645 (the band's centre line)
local FLAT, RAMP, TOP = 12, 44, 13.5
local X_FLAT = BAND_END - FLAT
local X_RAMP = X_FLAT - RAMP
-- the gate paving's outer edge now (Z3): its south end, centre line
local edgeNow = (floor.CFrame * CFrame.new(-floor.Size.X / 2, floor.Size.Y / 2, 0)).Position
local T = CFrame.new(X_RAMP, TOP, ZC) * CFrame.Angles(0, math.pi / 2, 0) * CFrame.new(-edgeNow)
say(("band end x %.1f z %.1f; paving edge %s -> %s"):format(BAND_END, ZC, tostring(edgeNow), tostring(T * edgeNow)))

-- 1. lists -------------------------------------------------------------------------------------------------------------
local FZ = World.FutureZones
local group: { Instance } = {
	EA,
	need(FZ, "Zone6_BillionaireHills"),
	need(workspace.Zones, "BillionaireHills"),
	need(World.Islands, "BillionaireHillsIsland"),
	need(Lane, "T3_EmberAcademy"),
	floor,
	need(vf.Guards, "GUARD_Ember_Gate_N"),
	need(vf.Guards, "GUARD_Ember_Gate_S"),
	need(SS, "SpellRunCourse034"),
	need(SS, "_ParkedEmber"),
	need(SS, "_ParkedNecro"),
}
for _, g in World.BridgeGuards:GetChildren() do
	if g.Name:match("^BillionaireHillsBridgeGuard") then
		table.insert(group, g)
	end
end
for _, f in { Lane.Rocks, Lane.Clouds } do
	for _, c in f:GetChildren() do
		if CS:HasTag(c, "MovedZ3") then
			table.insert(group, c)
		end
	end
end
-- parked after the move (Spell Run + its island)
local spellRun: { Instance } = {
	need(EA, "SpellRun"),
	need(EA, "Balustrade"),
	need(EA, "Ember036EndRail"),
	need(EA, "Summit031"),
	need(World.Islands, "BillionaireHillsIsland"),
	need(SS, "SpellRunCourse034"),
}
-- the old plaza island and everything standing on it
local plaza: { Instance } = { need(World.Islands, "PlazaIsland"), need(z3a.Guards, "PlazaIslandFallGuard") }
for _, c in World.WorldBounds:GetChildren() do
	if c.Name:match("^PlazaRing") then
		table.insert(plaza, c)
	end
end
local hub = World.SkyCity.Hub
for _, n in { "Vault", "Arena", "GateLines" } do
	table.insert(plaza, need(hub, n))
end
table.insert(plaza, need(workspace.Venues, "Arena"))
local bp = need(FZ, "BillionairePlaza")
for _, n in { "CentreSeal", "BypassRing", "ArenaEdge" } do
	table.insert(plaza, need(bp, n))
end
local function pivotOf(c: Instance): Vector3?
	if c:IsA("Model") then
		return c:GetPivot().Position
	elseif c:IsA("BasePart") then
		return c.Position
	end
	return nil
end
for _, f in { World.SkyCity.Dressing.Trees, World.SkyCity.Ground.Edge, World.SkyCity.Ground.Rocks } do
	for _, c in f:GetChildren() do
		local p = pivotOf(c)
		if p and p.X > 80 and p.X < 270 and p.Z > -100 and p.Z < 100 then
			table.insert(plaza, c)
		end
	end
end
-- the junction's north stub and the Zone 3 north path
local stub: { Instance } = { need(vf.Guards, "GUARD_Spine_E_B"), need(vf.Guards, "GUARD_Spine_W_B") }
for _, c in z3a.RedPath:GetChildren() do
	table.insert(stub, c)
end
for _, c in z3a.Guards:GetChildren() do
	if c.Name:match("^GUARD_North_") then
		table.insert(stub, c)
	end
end
say(("move %d items; park: spell run %d, plaza %d, north stub %d"):format(#group, #spellRun, #plaza, #stub))

-- new footprint check (moving parts in Workspace, excluding what gets parked)
local parkSet = {}
for _, list in { spellRun, plaza, stub } do
	for _, i in list do
		parkSet[i] = true
	end
end
local function under(d: Instance, set): boolean
	local x = d
	while x do
		if set[x] then
			return true
		end
		x = x.Parent
	end
	return false
end
local moveSet = {}
for _, i in group do
	moveSet[i] = true
end
local lo, hi = Vector3.one * 1e9, -Vector3.one * 1e9
for _, i in group do
	for _, d in { i, table.unpack(i:GetDescendants()) } do
		if d:IsA("BasePart") and d:IsDescendantOf(workspace) and not under(d, parkSet) then
			local p = T * d.Position
			lo, hi = lo:Min(p), hi:Max(p)
		end
	end
end
say(("new Zone 3 footprint x %.0f..%.0f y %.0f..%.0f z %.0f..%.0f"):format(lo.X, hi.X, lo.Y, hi.Y, lo.Z, hi.Z))
local hits = {}
for _, d in workspace:GetDescendants() do
	if d:IsA("BasePart") and not under(d, moveSet) and not under(d, parkSet) and d ~= workspace.Terrain then
		local p = d.Position
		if p.X > lo.X - 15 and p.X < X_FLAT and p.Z > lo.Z - 15 and p.Z < hi.Z + 15 and p.Y > lo.Y - 20 and p.Y < hi.Y + 20 then
			local k = (d.Parent :: Instance):GetFullName()
			hits[k] = (hits[k] or 0) + 1
		end
	end
end
for k, v in hits do
	say(("IN NEW AREA: %s (%d)"):format(k, v))
end
if DRY then
	return table.concat(log, "\n")
end

-- 2. close the Zone 3 wall gap (before the move, so it moves with the map) --------------------------------------------
local gn = need(EA.Zone3Map.Guards, "Guard_East_N") :: BasePart
local gs = need(EA.Zone3Map.Guards, "Guard_East_S") :: BasePart
local function ends(g: BasePart): (number, number)
	local a = (g.CFrame * CFrame.new(0, 0, -g.Size.Z / 2)).Position.X
	local b = (g.CFrame * CFrame.new(0, 0, g.Size.Z / 2)).Position.X
	return math.min(a, b), math.max(a, b)
end
local _, sHi = ends(gs)
local nLo, _ = ends(gn)
local gap = gn:Clone()
gap.Name = "Guard_East_Gap"
gap.Size = Vector3.new(gn.Size.X, gn.Size.Y, (nLo - sHi) + 2)
gap.CFrame = CFrame.new((sHi + nLo) / 2, gn.Position.Y, gn.Position.Z) * gn.CFrame.Rotation
gap:SetAttribute("CreatedZ4", true)
gap.Parent = gn.Parent
say(("Zone 3 wall gap x %.1f..%.1f closed"):format(sHi, nLo))

-- 3. move -------------------------------------------------------------------------------------------------------------
local DIRS = { Axis = true, Inward = true }
local function record(inst: Instance, cf: CFrame)
	if inst:GetAttribute("PreZ4CFrame") == nil then
		inst:SetAttribute("PreZ4CFrame", cf)
		CS:AddTag(inst, "MovedZ4")
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
				d:SetAttribute("PreZ4" .. k, v)
				d:SetAttribute(k, T.Rotation * v)
			end
		end
	end
	moveItem(i)
	task.wait()
end

-- 4. park ---------------------------------------------------------------------------------------------------------------
local srFolder = Instance.new("Folder")
srFolder.Name = "_ParkedSpellRun"
srFolder.Parent = SS
local plazaFolder = Instance.new("Folder")
plazaFolder.Name = "Plaza"
plazaFolder.Parent = srFolder
local p2b = SS:FindFirstChild("_Parked2b") :: Folder
local stubFolder = Instance.new("Folder")
stubFolder.Name = "Zone3Side"
stubFolder.Parent = p2b
local function park(list: { Instance }, to: Instance)
	for _, i in list do
		i:SetAttribute("ParkedFrom", (i.Parent :: Instance):GetFullName())
		i.Parent = to
	end
end
park(spellRun, srFolder)
park(plaza, plazaFolder)
park(stub, stubFolder)
local floorPart = need(bp, "ArenaFloor") :: BasePart
floorPart:SetAttribute("PreZ4Transparency", floorPart.Transparency)
floorPart:SetAttribute("PreZ4CanCollide", floorPart.CanCollide)
floorPart:SetAttribute("PreZ4CanQuery", floorPart.CanQuery)
floorPart.Transparency, floorPart.CanCollide, floorPart.CanQuery = 1, false, false
say("parked; ArenaFloor hidden")

-- 5. spine ends at the junction ------------------------------------------------------------------------------------------
local function setBox(part: BasePart, z0: number, z1: number)
	if part:GetAttribute("PreZ4Size") == nil then
		part:SetAttribute("PreZ4Size", part.Size)
	end
	record(part, part.CFrame)
	part.Size = Vector3.new(part.Size.X, part.Size.Y, z1 - z0)
	part.CFrame = CFrame.new(part.Position.X, part.Position.Y, (z0 + z1) / 2)
end
local JN = 530 -- the junction square's north edge (the Keep/Sunken arms are z 530..550)
local spineS = spine.Position.Z + spine.Size.Z / 2
setBox(spine, JN, spineS)
setBox(spineRock, JN + 2, spineRock.Position.Z + spineRock.Size.Z / 2)

local out = Instance.new("Model")
out.Name = "Zone3Side"
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
	p.Material = Enum.Material.Plastic
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = collide, collide, false, false
	p.Parent = parent
	return p
end
local function box(parent: Instance, name: string, x0: number, x1: number, y0: number, y1: number, z0: number, z1: number, color: Color3, collide: boolean): Part
	return part(parent, name, CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), Vector3.new(x1 - x0, y1 - y0, z1 - z0), color, collide)
end
-- a slab along X whose top runs from (x0, top0) to (x1, top1), z0..z1 wide (x1 < x0: heading west)
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
local function invisible(p: Part): Part
	p.Transparency = 1
	return p
end
invisible(box(guards, "GUARD_Spine_JunctionEnd", -W - 0.5, W + 0.5, 0, 6, JN - 1, JN, Color3.new(1, 1, 1), true))

-- 6. the west branch -----------------------------------------------------------------------------------------------------
local Z0, Z1 = ZC - W, ZC + W
slab(path, "West3_Flat", BAND_END, 0, X_FLAT, 0, Z0, Z1, 4, RED, true)
slab(path, "West3_Ramp", X_FLAT, 0, X_RAMP, TOP, Z0, Z1, 4, RED, true)
slab(path, "West3_FlatRock", BAND_END + 2, -4, X_FLAT, -4, Z0 + 2, Z1 - 2, 12, ROCK, false)
slab(path, "West3_RampRock", X_FLAT, -4, X_RAMP, TOP - 4, Z0 + 2, Z1 - 2, 12, ROCK, false)
for _, s in { { "N", Z0 - 0.5 }, { "S", Z1 + 0.5 } } do
	invisible(slab(guards, "GUARD_West3_Flat_" .. s[1], BAND_END + 1, 6, X_FLAT, 6, s[2] - 0.5, s[2] + 0.5, 6, Color3.new(1, 1, 1), true))
	invisible(slab(guards, "GUARD_West3_Ramp_" .. s[1], X_FLAT, 6, X_RAMP - 0.5, TOP + 6, s[2] - 0.5, s[2] + 0.5, 6, Color3.new(1, 1, 1), true))
end
-- the band's end guard gets an opening the width of the path
local bz0 = bandEndGuard.Position.Z - bandEndGuard.Size.Z / 2
local bz1 = bandEndGuard.Position.Z + bandEndGuard.Size.Z / 2
park({ bandEndGuard }, stubFolder)
invisible(box(guards, "GUARD_BandEnd_W_N", BAND_END - 0.5, BAND_END + 0.5, 0, 6, bz0, Z0, Color3.new(1, 1, 1), true))
invisible(box(guards, "GUARD_BandEnd_W_S", BAND_END - 0.5, BAND_END + 0.5, 0, 6, Z1, bz1, Color3.new(1, 1, 1), true))

-- 7. parade lane on the band ---------------------------------------------------------------------------------------------
local laneP = World.SkyCity.Ground.ParadeLane.Lane :: BasePart
laneP:SetAttribute("PreZ4Size", laneP.Size)
record(laneP, laneP.CFrame)
laneP.Size = Vector3.new(185, laneP.Size.Y, 16)
laneP.CFrame = CFrame.new(0, laneP.Position.Y, ZC)

map:SetAttribute("Zone3Move4", T)
map:SetAttribute("Zone3Side", true)
local barrier = FZ.Zone6_BillionaireHills.Gate.Barrier :: BasePart
say(
	("done. Zone 3 gate barrier %s inward %s; spine z %.0f..%.0f; lane x -92.5..92.5 z %.0f"):format(
		tostring(barrier.Position),
		tostring(barrier:GetAttribute("Inward")),
		JN,
		spineS,
		ZC
	)
)
return table.concat(log, "\n")
