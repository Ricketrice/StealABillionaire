-- V2_Review2.lua (Hub 2b visual review 2, 2026-10-20). Run once in Studio Edit: tools/hub2b/run_file.py <this file>.
-- 1. Knight's Keep 66 studs closer to the hub (one rigid move along +X, no turn): the zone group (World.KnightsKeep,
--    Zones.MainStreet = ZoneBoundary/SpawnPoints/GuardianPost, the Keep's terrace/curb/MainStreet parts, Start_MainStreet,
--    hedges/rocks/trees/cloud around it, the HeistVault032 template + its Hinge/WheelCentre points, photo spots) and the
--    FREE arch. HubMap2b attr KeepMove2b gets the move too (the heist test reads it).
-- 2. The path from the spine to the Keep: 20 wide like the spine, ~64 studs (was ~130): flat, ramp up 13.5, onto the island.
--    The "SAFE ZONE ENDS HERE" gate (Lane Sign, BannerPosts, SafeLine stripes, SafeLineWide) stands on the flat part,
--    fitted to the 20-stud path (posts on its edges, outer stripes parked, sign/line 18/20 long).
-- 3. The red band in front of the bases: 55 -> 30 deep (z -70..-40, was -95..-40); the spine reaches the band at z -70.
-- Records: created -> Workspace.HubMap2b.Review2; parked -> ServerStorage._Parked2b.Review2 (attr ParkedFrom); moved/resized
-- -> attrs PreV2CFrame / PreV2Size / PreV2<attr> + tag MovedV2. Undo: tools/hub2b/V2_Undo.lua (before V_Undo/R_Undo/Undo).
local SS = game:GetService("ServerStorage")
local CS = game:GetService("CollectionService")

local H = Vector3.new(0, 0, 700)
local DX = 66 -- the Keep's move along +X
local MOVE = CFrame.new(DX, 0, 0)
local map = workspace:FindFirstChild("HubMap2b")
assert(map and map:GetAttribute("VisualFix2b") == true, "run V1_VisualFix.lua first")
assert(map:GetAttribute("Review2") == nil, "already done (run V2_Undo.lua first)")
local vf = map:FindFirstChild("VisualFix2b") :: Model
local col2b = map:FindFirstChild("Collision2b") :: Folder
local ext2b = map:FindFirstChild("Ext2b") :: Folder
local World = workspace.World
local City = World.SkyCity
local Lane = City.Lane

local log = {}
local function say(s: string)
	table.insert(log, s)
end
local function L(x: number, y: number, z: number): Vector3
	return H + Vector3.new(x, y, z)
end
local parkRoot = SS:FindFirstChild("_Parked2b") :: Folder
local parkFolder = parkRoot:FindFirstChild("Review2") or Instance.new("Folder")
parkFolder.Name = "Review2"
parkFolder.Parent = parkRoot
local parked = 0
local function park(inst: Instance?)
	if inst then
		inst:SetAttribute("ParkedFrom", (inst.Parent :: Instance):GetFullName())
		inst.Parent = parkFolder
		parked += 1
	end
end
local function record(inst: Instance, cf: CFrame)
	if inst:GetAttribute("PreV2CFrame") == nil then
		inst:SetAttribute("PreV2CFrame", cf)
		CS:AddTag(inst, "MovedV2")
	end
end
local function setCF(part: BasePart, cf: CFrame)
	record(part, part.CFrame)
	part.CFrame = cf
end
local function setBox(part: BasePart, x0: number, x1: number, y0: number, y1: number, z0: number, z1: number)
	if part:GetAttribute("PreV2Size") == nil then
		part:SetAttribute("PreV2Size", part.Size)
	end
	setCF(part, CFrame.new(L((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)))
	part.Size = Vector3.new(x1 - x0, y1 - y0, z1 - z0)
end
local function need(parent: Instance, name: string): Instance
	local c = parent:FindFirstChild(name, true)
	assert(c, "missing " .. parent:GetFullName() .. "/" .. name)
	return c
end

-- 1. move the Keep group -------------------------------------------------------------------------------------------
local function centre(inst: Instance): Vector3?
	if inst:IsA("BasePart") then
		return inst.Position
	elseif inst:IsA("Model") then
		return inst:GetBoundingBox().Position
	end
	local lo, hi, n = Vector3.one * 1e9, -Vector3.one * 1e9, 0
	for _, d in inst:GetDescendants() do
		if d:IsA("BasePart") then
			lo, hi, n = lo:Min(d.Position), hi:Max(d.Position), n + 1
		end
	end
	return if n > 0 then (lo + hi) / 2 else nil
end
local group: { Instance } = {
	World.KnightsKeep,
	workspace.Zones.MainStreet,
	need(City, "MainStreet"),
	need(City.Ground, "Island4"),
	need(City.Ground, "MainStreetCurb"),
	City.Ground:FindFirstChild("MainStreet") :: Instance,
	need(SS, "HeistVault032"),
	need(Lane, "Start_MainStreet"),
	need(vf, "KeepEntranceArch"),
}
for _, f in { City.Ground.Edge, City.Ground.Rocks, City.Dressing.Trees, Lane.Rocks, Lane.Clouds, World.Islands, SS:FindFirstChild("PhotoSpotsDev") } do
	for _, c in (if f then f:GetChildren() else {}) do
		local p = centre(c)
		local l = p and p - H
		if l and l.X > -300 and l.X < -115 and l.Z > -240 and l.Z < -80 then
			table.insert(group, c)
		end
	end
end
local POINTS = { Hinge = true, WheelCentre = true }
local function moveItem(inst: Instance)
	if inst:IsA("BasePart") then
		setCF(inst, MOVE * inst.CFrame)
	elseif inst:IsA("Model") then
		record(inst, inst:GetPivot())
		inst:PivotTo(MOVE * inst:GetPivot())
	else
		for _, c in inst:GetChildren() do
			moveItem(c)
		end
	end
end
local points = 0
for _, i in group do
	for _, d in { i, table.unpack(i:GetDescendants()) } do
		for k, v in d:GetAttributes() do
			if POINTS[k] and typeof(v) == "Vector3" then
				d:SetAttribute("PreV2" .. k, v)
				d:SetAttribute(k, v + MOVE.Position)
				CS:AddTag(d, "MovedV2")
				points += 1
			end
		end
		if d:IsA("Vector3Value") or d:IsA("CFrameValue") then
			d:SetAttribute("PreV2Value", d.Value)
			d.Value = if d:IsA("CFrameValue") then MOVE * d.Value else d.Value + MOVE.Position
			CS:AddTag(d, "MovedV2")
		end
	end
	moveItem(i)
end
local km = map:GetAttribute("KeepMove2b")
map:SetAttribute("PreV2KeepMove2b", km)
map:SetAttribute("KeepMove2b", (CFrame.new(MOVE.Position) * (if typeof(km) == "CFrame" then km else CFrame.identity)))
say(("Keep group moved %d studs: %d items, %d point attrs"):format(DX, #group, points))
task.wait()

-- builders --------------------------------------------------------------------------------------------------------------
local out = Instance.new("Model")
out.Name = "Review2"
out.Parent = map
local guards = Instance.new("Folder")
guards.Name = "Guards"
guards.Parent = out
local RED = (need(vf, "Spine") :: BasePart).Color
local ROCK = (need(vf, "SpineRock") :: BasePart).Color
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
	local up = Vector3.new(-along.Y, along.X, 0) * (if along.X >= 0 then 1 else -1)
	local c = (a + b) / 2 - up * thick / 2
	return part(parent, name, CFrame.fromMatrix(c, along, up), Vector3.new((b - a).Magnitude, thick, z1 - z0), color, collide)
end
local function edge(name: string, x0: number, top0: number, x1: number, top1: number, z: number)
	local g = slab(guards, "GUARD_" .. name, x0, top0 + 6, x1, top1 + 6, z - 0.5, z + 0.5, 6, Color3.new(1, 1, 1), true)
	g.Transparency = 1
end
local function wall(name: string, x0: number, x1: number, z0: number, z1: number, base: number)
	local g = box(guards, "GUARD_" .. name, x0, x1, base, base + 6, z0, z1, Color3.new(1, 1, 1), true)
	g.Transparency = 1
end
local path = Instance.new("Model")
path.Name = "RedPath"
path.Parent = out

-- 2. the Keep path: spine edge x -10 -> flat to -22 (safe gate at -16) -> ramp to 13.5 at -66 -> onto the island to -74 ----
local W = 10
local Z0, Z1 = -160 - W, -160 + W
local TOP = 13.5
for _, n in { "West_Flat", "West_Ramp", "West_Span" } do
	park(vf.RedPath:FindFirstChild(n))
end
for _, g in vf.Guards:GetChildren() do
	if g.Name:match("^GUARD_West_") then
		park(g)
	end
end
slab(path, "Keep_Flat", -W, 0, -22, 0, Z0, Z1, 4, RED, true)
slab(path, "Keep_Ramp", -22, 0, -66, TOP, Z0, Z1, 4, RED, true)
slab(path, "Keep_Span", -66, TOP, -76, TOP, Z0, Z1, 4, RED, true)
box(path, "Keep_FlatRock", -22, -W + 2, -12, -4, Z0 + 2, Z1 - 2, ROCK, false)
for _, s in { { "N", Z0 - 0.5 }, { "S", Z1 + 0.5 } } do
	edge("Keep_Flat_" .. s[1], -W, 0, -22, 0, s[2])
	edge("Keep_Ramp_" .. s[1], -22, 0, -66, TOP, s[2])
end
-- the safe-zone gate on the flat part, fitted to the 20-stud path
local GX = -16
for _, c in Lane:GetChildren() do
	if c.Name == "Sign" and c:IsA("BasePart") then
		setCF(c, c.CFrame + Vector3.new(L(GX, 0, 0).X - c.Position.X, 0, 0))
		c:SetAttribute("PreV2Size", c.Size)
		c.Size = Vector3.new(18, c.Size.Y, c.Size.Z)
	elseif c.Name == "BannerPost" and c:IsA("BasePart") then
		local side = if c.Position.Z < L(0, 0, -160).Z then -1 else 1
		setCF(c, CFrame.new(L(GX, c.Position.Y - H.Y, -160 + side * (W - 0.7))) * c.CFrame.Rotation)
	elseif c.Name == "SafeLineWide" and c:IsA("BasePart") then
		setCF(c, c.CFrame + Vector3.new(L(GX, 0, 0).X - c.Position.X, 0, 0))
		c:SetAttribute("PreV2Size", c.Size)
		c.Size = Vector3.new(2 * W, c.Size.Y, c.Size.Z)
	elseif c.Name == "SafeLine" and c:IsA("BasePart") then
		if math.abs(c.Position.Z - L(0, 0, -160).Z) > W - 1 then
			park(c) -- (the two outer stripes hung over the void)
		else
			setCF(c, c.CFrame + Vector3.new(L(GX, 0, 0).X - c.Position.X, 0, 0))
		end
	end
end
say("Keep path: x -10..-76, gate at x " .. GX)

-- 3. the red band 55 -> 30 deep, the spine reaches it -------------------------------------------------------------------
local BAND_N = -70
park(vf.RedPath:FindFirstChild("Band"))
park(vf.RedPath:FindFirstChild("BandRock"))
park(vf.RedPath:FindFirstChild("Spine"))
park(vf.RedPath:FindFirstChild("SpineRock"))
for _, n in { "GUARD_Band_N_W", "GUARD_Band_N_E", "GUARD_Spine_W_A", "GUARD_Spine_E_A" } do
	park(vf.Guards:FindFirstChild(n))
end
park(col2b:FindFirstChild("COL_RedBand_Far"))
box(path, "Band", -170, 170, -4, 0, BAND_N, -40, RED, false) -- (collision: Collision2b.COL_ReturnPlaza, z -70..-40)
box(path, "BandRock", -156, 156, -32, -4, BAND_N, -28.5, ROCK, false)
box(path, "Spine", -W, W, -4, 0, -235, BAND_N, RED, true)
box(path, "SpineRock", -W + 2, W - 2, -16, -4, -233, BAND_N - 2, ROCK, false)
wall("Band_N_W", -245.5, -W, BAND_N - 1, BAND_N, 0)
wall("Band_N_E", W, 245.5, BAND_N - 1, BAND_N, 0)
wall("Spine_W_A", -W - 1, -W, -150, BAND_N, 0)
wall("Spine_E_A", W, W + 1, -150, BAND_N, 0)
for _, s in { -1, 1 } do
	local tag = if s < 0 then "W" else "E"
	local x0, x1 = if s < 0 then -245 else 170, if s < 0 then -170 else 245
	setBox(need(ext2b, "RedBand_" .. tag) :: BasePart, x0, x1, -4, 0, BAND_N, -40)
	setBox(need(col2b, "COL_Ext_RedBand_" .. tag) :: BasePart, x0, x1, -4, 0, BAND_N, -40)
	local rock = need(ext2b, "Rock_" .. tag) :: BasePart
	local rx0, rx1 = rock.Position.X - H.X - rock.Size.X / 2, rock.Position.X - H.X + rock.Size.X / 2
	setBox(rock, rx0, rx1, -30, -4, BAND_N + 2, 10)
	setBox(need(col2b, "GUARD_Ext_End_" .. tag) :: BasePart, s * 245.5 - 0.5, s * 245.5 + 0.5, 0, 6, BAND_N, -40)
end
say(("band z %d..-40; parked %d"):format(BAND_N, parked))

map:SetAttribute("Review2", true)
return table.concat(log, "\n")
