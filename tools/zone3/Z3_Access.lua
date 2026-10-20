-- Z3_Access.lua (2026-10-20, D53): Zone 3 is reached from the junction's dead-end north arm, not through Sunken Kingdom.
-- Run in Studio Edit: python3 tools/hub2b/run_file.py tools/zone3/Z3_Access.lua "local DRY = false" (DRY = list only).
-- Undo: tools/zone3/Z3_Undo.lua (before Z2/Z1/Z0 undo).
--
-- The north arm (spine x +-10, junction z 540 -> end z 465) points away from Zone 3 (east, past Sunken), so the whole
-- Zone 3 group is moved: one rigid move, quarter turn (the zone's "inward" +X becomes -Z = north), lowered so its gate
-- paving sits at 13.5 like the Keep island. The gate paving's outer edge lands at the top of a Keep-style path:
--   spine end z 465 -> flat 12 (top 0) -> ramp 44 up to 13.5 -> gate paving (gate barrier at z ~396).
-- Moved: World.EmberAcademy (Zone3Map, SpellRun, Balustrade, Summit031, Ember036EndRail), FutureZones.Zone6_BillionaireHills
-- (gate + price wall, FastTravelAnchor, ...), Zones.BillionaireHills (ZoneBoundary, SpawnPoints, GuardianPost), the
-- island, Lane.T3_EmberAcademy, the gate paving + its side guards, the gate's bridge guards, lane rocks/clouds east of
-- x 300 (not the rock under the old ramp), ServerStorage SpellRunCourse034 (race template) and the parked Ember/Necro
-- pieces (so they still fit if restored). Direction attributes (Inward, Axis) are turned.
-- Parked (ServerStorage._Parked2b.Zone3Access, attr ParkedFrom): the old Sunken -> Zone 3 ramp, its guards and rock, the
-- spine's end guard. New (Workspace.HubMap2b.Zone3Access): the path, rock under it, edge guards, and an invisible
-- blocker in the Sunken palace's back door (its door panel stays: it now reads as a closed door).
-- Records: moved -> attr PreZ3CFrame + tag MovedZ3; turned attrs -> PreZ3<name>; map attrs Zone3Access, Zone3Move.
local DRY = if DRY == nil then true else DRY

local SS = game:GetService("ServerStorage")
local CS = game:GetService("CollectionService")
local map = workspace:FindFirstChild("HubMap2b")
assert(map and map:FindFirstChild("Review2"), "run V2_Review2 first")
assert(map:GetAttribute("Zone3Access") == nil, "already done (run Z3_Undo.lua first)")
local vf = map.VisualFix2b
local World = workspace.World
local Lane = World.SkyCity.Lane

local log = {}
local function say(s: string)
	table.insert(log, s)
end
local function need(parent: Instance, name: string): Instance
	local c = parent:FindFirstChild(name)
	assert(c, "missing " .. parent:GetFullName() .. "." .. name)
	return c
end
local function centre(inst: Instance): Vector3?
	if inst:IsA("BasePart") then
		return inst.Position
	elseif inst:IsA("Model") then
		return inst:GetBoundingBox().Position
	end
	return nil
end

-- the transform -------------------------------------------------------------------------------------------------------
local floor = need(vf.RedPath, "Ember_GateFloor") :: BasePart
local spine = need(map.Review2.RedPath, "Spine") :: BasePart
local W = spine.Size.X / 2 -- 10
local SPINE_END = spine.Position.Z - spine.Size.Z / 2 -- 465
local FLAT, RAMP, TOP = 12, 44, 13.5
local Z_FLAT = SPINE_END - FLAT -- 453
local Z_RAMP = Z_FLAT - RAMP -- 409
local oldEdge = Vector3.new(floor.Position.X - floor.Size.X / 2, floor.Position.Y + floor.Size.Y / 2, floor.Position.Z)
local T = CFrame.new(spine.Position.X, TOP, Z_RAMP) * CFrame.Angles(0, math.pi / 2, 0) * CFrame.new(-oldEdge)
say(("spine end z %.1f, gate paving edge %s -> %s"):format(SPINE_END, tostring(oldEdge), tostring(T * oldEdge)))

-- 1. who moves --------------------------------------------------------------------------------------------------------
local FZ = World.FutureZones
local group: { Instance } = {
	World.EmberAcademy,
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
local toPark: { Instance } = {
	need(vf.RedPath, "Ember_Ramp"),
	need(vf.Guards, "GUARD_Ember_Ramp_N"),
	need(vf.Guards, "GUARD_Ember_Ramp_S"),
	need(vf.Guards, "GUARD_Spine_End"),
}
for _, f in { Lane.Rocks, Lane.Clouds } do
	for _, c in f:GetChildren() do
		local p = centre(c)
		if p and p.X > 300 then
			if f == Lane.Rocks and p.X < 316 then
				table.insert(toPark, c) -- the rock under the old ramp
			else
				table.insert(group, c)
			end
		end
	end
end
local moving = {}
for _, i in group do
	moving[i] = true
end
for _, i in toPark do
	moving[i] = true
end
local function covered(d: Instance): boolean
	local x = d
	while x do
		if moving[x] then
			return true
		end
		x = x.Parent
	end
	return false
end
local left = {}
for _, d in workspace:GetDescendants() do
	if d:IsA("BasePart") and d.Position.X > 285 and not covered(d) then
		local k = (d.Parent :: Instance):GetFullName()
		left[k] = (left[k] or 0) + 1
	end
end
for k, v in left do
	say(("NOT MOVED (x > 285): %s (%d parts)"):format(k, v))
end
local DIRS = { Axis = true, Inward = true }
local nParts, dirs = 0, 0
for _, i in group do
	for _, d in { i, table.unpack(i:GetDescendants()) } do
		if d:IsA("BasePart") then
			nParts += 1
		end
		for k, v in d:GetAttributes() do
			if DIRS[k] and typeof(v) == "Vector3" then
				dirs += 1
			end
		end
	end
end
say(("move %d items (%d parts, %d direction attrs), park %d"):format(#group, nParts, dirs, #toPark))
-- the target area must be empty (path + new zone footprint)
local lo, hi = Vector3.one * 1e9, -Vector3.one * 1e9
for _, i in group do
	for _, d in { i, table.unpack(i:GetDescendants()) } do
		if d:IsA("BasePart") and d:IsDescendantOf(workspace) then
			local p = T * d.Position
			lo, hi = lo:Min(p), hi:Max(p)
		end
	end
end
say(("new footprint x %.0f..%.0f y %.0f..%.0f z %.0f..%.0f"):format(lo.X, hi.X, lo.Y, hi.Y, lo.Z, hi.Z))
local inTarget = {}
for _, d in workspace:GetDescendants() do
	if d:IsA("BasePart") and not covered(d) then
		local p = d.Position
		if p.X > lo.X - 10 and p.X < hi.X + 10 and p.Z > lo.Z - 10 and p.Z < Z_FLAT and p.Y > -60 then
			local k = d:GetFullName()
			inTarget[k] = true
		end
	end
end
for k in inTarget do
	say("IN TARGET AREA: " .. k)
end
if DRY then
	return table.concat(log, "\n")
end

-- 2. move ---------------------------------------------------------------------------------------------------------------
local function record(inst: Instance, cf: CFrame)
	if inst:GetAttribute("PreZ3CFrame") == nil then
		inst:SetAttribute("PreZ3CFrame", cf)
		CS:AddTag(inst, "MovedZ3")
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
				d:SetAttribute("PreZ3" .. k, v)
				d:SetAttribute(k, T.Rotation * v)
			end
		end
	end
	moveItem(i)
	task.wait()
end

-- 3. park the old route -------------------------------------------------------------------------------------------------
local parkRoot = SS:FindFirstChild("_Parked2b") :: Folder
local parkFolder = Instance.new("Folder")
parkFolder.Name = "Zone3Access"
parkFolder.Parent = parkRoot
for _, i in toPark do
	i:SetAttribute("ParkedFrom", (i.Parent :: Instance):GetFullName())
	i.Parent = parkFolder
end

-- 4. the new path, rock, guards, Sunken back door -------------------------------------------------------------------------
local out = Instance.new("Model")
out.Name = "Zone3Access"
out.Parent = map
local path = Instance.new("Model")
path.Name = "RedPath"
path.Parent = out
local guards = Instance.new("Folder")
guards.Name = "Guards"
guards.Parent = out
local RED = spine.Color
local ROCK = (need(map.Review2.RedPath, "SpineRock") :: BasePart).Color
local X0 = spine.Position.X
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
-- a slab along Z whose top runs from (z0, top0) to (z1, top1), x0..x1 wide
local function slab(
	parent: Instance,
	name: string,
	z0: number,
	top0: number,
	z1: number,
	top1: number,
	x0: number,
	x1: number,
	thick: number,
	color: Color3,
	collide: boolean
): Part
	local xc = (x0 + x1) / 2
	local a, b = Vector3.new(xc, top0, z0), Vector3.new(xc, top1, z1)
	local along = (b - a).Unit
	local up = Vector3.new(0, -along.Z, along.Y) * (if along.Z <= 0 then 1 else -1)
	local c = (a + b) / 2 - up * thick / 2
	return part(parent, name, CFrame.fromMatrix(c, Vector3.xAxis, up), Vector3.new(x1 - x0, thick, (b - a).Magnitude), color, collide)
end
local function guard(name: string, z0: number, top0: number, z1: number, top1: number, x: number)
	local g = slab(guards, "GUARD_" .. name, z0, top0 + 6, z1, top1 + 6, x - 0.5, x + 0.5, 6, Color3.new(1, 1, 1), true)
	g.Transparency = 1
end
slab(path, "North_Flat", SPINE_END, 0, Z_FLAT, 0, X0 - W, X0 + W, 4, RED, true)
slab(path, "North_Ramp", Z_FLAT, 0, Z_RAMP, TOP, X0 - W, X0 + W, 4, RED, true)
slab(path, "North_FlatRock", SPINE_END + 2.5, -4, Z_FLAT, -4, X0 - W + 2, X0 + W - 2, 12, ROCK, false)
slab(path, "North_RampRock", Z_FLAT, -4, Z_RAMP, TOP - 4, X0 - W + 2, X0 + W - 2, 12, ROCK, false)
for _, s in { { "W", X0 - W - 0.5 }, { "E", X0 + W + 0.5 } } do
	guard("North_Flat_" .. s[1], SPINE_END + 1, 0, Z_FLAT, 0, s[2])
	guard("North_Ramp_" .. s[1], Z_FLAT, 0, Z_RAMP - 0.5, TOP, s[2])
end
-- the Sunken palace's back door (frames at x 269.2, z 535.7 / 544.3; side blocks to y 32)
local acc = World.SunkenKingdom:FindFirstChild("Access049")
local fl = acc and acc:FindFirstChild("BackDoorFrameL") :: BasePart?
local fr = acc and acc:FindFirstChild("BackDoorFrameR") :: BasePart?
assert(fl and fr, "Sunken back door frames not found")
local dz0, dz1 = math.min(fl.Position.Z, fr.Position.Z) - 1.5, math.max(fl.Position.Z, fr.Position.Z) + 1.5
local dx = (fl.Position.X + fr.Position.X) / 2
local blk = part(guards, "SunkenBackDoorBlock", CFrame.new(dx + 0.75, 23, (dz0 + dz1) / 2), Vector3.new(2.5, 20, dz1 - dz0), Color3.new(1, 1, 1), true)
blk.Transparency = 1
say(("Sunken back door blocked: x %.1f, z %.1f..%.1f, y 13..33"):format(dx + 0.75, dz0, dz1))
-- the Spell Run's Landing2 now ends ~12 studs from the old PlazaIsland's coast (27 studs lower): a fast jump could clear
-- the course's FallZone (z >= 62.5) and land on the island. An invisible wall on that coast stops it; the player
-- drops into the FallZone instead (put back at the pad).
local pg = part(guards, "PlazaIslandFallGuard", CFrame.new(123, 20, 73), Vector3.new(50, 52, 1), Color3.new(1, 1, 1), true)
pg.Transparency = 1

map:SetAttribute("Zone3Move", T)
map:SetAttribute("Zone3Access", true)
local barrier = FZ.Zone6_BillionaireHills.Gate.Barrier :: BasePart
say(("moved. Zone 3 gate barrier at %s, inward %s; path z %.0f -> %.0f"):format(tostring(barrier.Position), tostring(barrier:GetAttribute("Inward")), SPINE_END, Z_RAMP))
return table.concat(log, "\n")
