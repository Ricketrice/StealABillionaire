-- tools/build036/P1_ParkZones4to7.lua (D48): parks the teammate zones 4-7 and the sea plane in ServerStorage._ParkedZones4to7.
-- Run in Edit AFTER ZoneConfig/NPCSpawner/ParadeConfig are synced (ZoneProgress asserts a barrier for every gated zone).
-- Re-runnable; UNDO = true puts everything back where it was (each parked object remembers its parent in Parked48From).
-- Kept (ours / shared): FutureZones.Zone6_BillionaireHills (Ember), Our_SunkenKingdom, BillionairePlaza (ArenaFloor: ZoneProgress);
-- Islands.PlazaIsland (Vault, Arena venue), BillionaireHillsIsland; Bridges/BridgeGuards BillionaireHills*; WorldBounds PlazaRing*;
-- Hub.GateLines Zone6_*; Lane clouds. Also closes the end of Ember Academy's avenue (z -836, the lane opening the ramp to stop 4
-- used) with a rail in the Balustrade's style (Ember036EndRail, 4 parts).
local UNDO = false

local ServerStorage = game:GetService("ServerStorage")
local world = workspace:WaitForChild("World")
local sky = world.SkyCity
local lane = sky.Lane

local parked = ServerStorage:FindFirstChild("_ParkedZones4to7") or Instance.new("Folder")
parked.Name = "_ParkedZones4to7"
parked.Parent = ServerStorage

local function resolve(path: string): Instance?
	local node: Instance? = game
	for _, name in string.split(path, ".") do
		node = node and (node:FindFirstChild(name) or (node == game and game:GetService(name) or nil))
	end
	return node
end

-- undo first (also makes a re-run start clean)
for _, inst in parked:GetChildren() do
	local home = resolve(inst:GetAttribute("Parked48From"))
	if home then
		inst:SetAttribute("Parked48From", nil)
		inst.Parent = home
	end
end
local oldRail = world.EmberAcademy:FindFirstChild("Ember036EndRail")
if oldRail then
	oldRail:Destroy()
end
if UNDO then
	return "P1 undone: zones 4-7 and the sea are back"
end

local list: { Instance } = {}
local function add(inst: Instance?)
	if inst and not table.find(list, inst) then
		table.insert(list, inst)
	end
end
for _, name in { "BeachBoardwalk", "NeonDowntown", "ToyTown" } do
	add(workspace.Zones:FindFirstChild(name))
end
for _, name in { "Zone2_FoodCourt", "Zone3_BeachBoardwalk", "Zone4_ToyTown", "Zone5_NeonDowntown" } do
	add(world.FutureZones:FindFirstChild(name))
end
for _, name in { "ToyTownIsland", "NeonDowntownIsland", "BoardwalkBayIsland" } do
	add(world.Islands:FindFirstChild(name))
end
for _, name in { "NeonDowntownBridge", "ToyTownBridge", "BoardwalkBayBridge" } do
	add(world.Bridges:FindFirstChild(name))
end
for _, g in world.BridgeGuards:GetChildren() do
	if not g.Name:find("BillionaireHills") then
		add(g)
	end
end
for _, name in { "LandmarkPlinths", "DistrictPaths", "DistrictArchitecture", "LockedZoneEntrances" } do
	add(world:FindFirstChild(name))
end
add(world.WorldBounds:FindFirstChild("BayDividerL"))
add(world.WorldBounds:FindFirstChild("BayDividerR"))
for _, line in sky.Hub.GateLines:GetChildren() do
	if not line.Name:find("Zone6") then
		add(line)
	end
end
for _, name in { "Stop4_FoodCourt", "Stop5_BeachBoardwalk", "Stop6_ToyTown", "Stop7_NeonDowntown" } do
	add(lane:FindFirstChild(name))
end
for _, m in lane:GetChildren() do
	local w = m.Name == "Ramp" and m:FindFirstChild("Wedge")
	if w and w:IsA("BasePart") and w.Position.Z < -830 then
		add(m) -- the four ramps past Ember Academy
	end
end
for _, r in lane.Rocks:GetChildren() do
	local cf = if r:IsA("Model") then r:GetPivot() elseif r:IsA("BasePart") then r.CFrame else nil
	if cf and cf.Position.Z < -935 then
		add(r) -- floating rocks that only framed the removed stops
	end
end
add(workspace:FindFirstChild("Baseplate")) -- the blue sea plane east of the hub
add(sky.Ground:FindFirstChild("SeaSkirt")) -- the cliff wall along the sea's edge

local parts, report = 0, {}
for _, inst in list do
	local n = if inst:IsA("BasePart") then 1 else 0
	for _, d in inst:GetDescendants() do
		if d:IsA("BasePart") then
			n += 1
		end
	end
	parts += n
	table.insert(report, ("%s (%d)"):format(inst:GetFullName(), n))
	inst:SetAttribute("Parked48From", (inst.Parent :: Instance):GetFullName())
	inst.Parent = parked
end

-- close Ember Academy's lane end (posts at x -171 / -145, avenue edge z -836) like its Balustrade
local bal = world.EmberAcademy.Balustrade
local base = bal:FindFirstChild("RailBase") :: BasePart
local top = bal:FindFirstChild("RailTop") :: BasePart
local post = bal:FindFirstChild("RailPost") :: BasePart
local rail = Instance.new("Model")
rail.Name = "Ember036EndRail"
local z, y = -835.4, 36.4
local function copy(src: BasePart, size: Vector3, pos: Vector3)
	local p = src:Clone()
	p:ClearAllChildren()
	p.Size = size
	p.CFrame = CFrame.new(pos)
	p.Parent = rail
end
copy(base, Vector3.new(26, 1.2, 1.4), Vector3.new(-158, y + 0.5, z))
copy(top, Vector3.new(26, 0.6, 1.2), Vector3.new(-158, y + 2.9, z))
copy(post, Vector3.new(1.2, 3, 1.2), Vector3.new(-164.5, y + 1.4, z))
copy(post, Vector3.new(1.2, 3, 1.2), Vector3.new(-151.5, y + 1.4, z))
rail.Parent = world.EmberAcademy

return ("P1 parked %d objects, %d parts:\n%s\n+ Ember036EndRail (4 parts)"):format(#list, parts, table.concat(report, "\n"))
