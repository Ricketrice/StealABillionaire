-- S3_SunkenZone.lua (after S2): fits Workspace.Zones.SunkenKingdom (ZoneArea: wild NPC area) to the new courtyard.
-- Run in Studio Edit; re-runnable. The old ZoneBoundary + SpawnPoints are kept in
-- ServerStorage._Backups.Pre049_SunkenMap (S0); UNDO = true copies them back.
-- Boundary: courtyard between the walls (x -187..-127) from the front wall (z -451.6) to the palace front (z -545),
-- y 24.3..44.3 as before. Spawn points: 8 hand-picked spots on open seabed (floor 24.30), clear of every colliding
-- prop by bounding box (domes, conch houses, stalls, colonnade, statue, tower, amphitheatre) and off the main path
-- (x -162..-152). Each is checked with 1 down ray + 4 side rays (no area scans).
local UNDO = false

local SS = game:GetService("ServerStorage")
local zone = workspace.Zones.SunkenKingdom
local pre = SS._Backups.Pre049_SunkenMap

if UNDO then
	zone.ZoneBoundary:Destroy()
	zone.SpawnPoints:Destroy()
	pre.ZoneBoundary:Clone().Parent = zone
	pre.SpawnPoints:Clone().Parent = zone
	return "S3 undone"
end

local boundary = zone.ZoneBoundary
boundary.CFrame = CFrame.new(-157, 34.3, -498)
boundary.Size = Vector3.new(59, 20, 92)

local SPOTS = {
	Vector3.new(-165, 0, -458),
	Vector3.new(-150, 0, -470),
	Vector3.new(-140, 0, -485),
	Vector3.new(-148, 0, -490),
	Vector3.new(-176, 0, -505),
	Vector3.new(-165, 0, -532),
	Vector3.new(-145, 0, -535),
	Vector3.new(-176, 0, -484),
}
local folder = zone.SpawnPoints
local template = pre.SpawnPoints:FindFirstChildWhichIsA("BasePart")
local prm = RaycastParams.new()
prm.RespectCanCollide = true
prm.FilterType = Enum.RaycastFilterType.Exclude
prm.FilterDescendantsInstances = { boundary, folder }
local report, bad = {}, 0
local made = {}
for i, s in SPOTS do
	local down = workspace:Raycast(Vector3.new(s.X, 44, s.Z), Vector3.new(0, -25, 0), prm)
	local floor = down and down.Position.Y or 24.3
	local okFloor = down ~= nil and down.Instance.Name:find("^Seabed") ~= nil and math.abs(floor - 24.3) < 0.05
	local near = {}
	for _, d in { Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis } do
		local r = workspace:Raycast(Vector3.new(s.X, floor + 2, s.Z), d * 3, prm)
		if r then
			table.insert(near, r.Instance.Name)
		end
	end
	if not okFloor or #near > 0 then
		bad += 1
	end
	table.insert(
		report,
		("%d:%s%s"):format(i, okFloor and "ok" or ("FLOOR " .. (down and down.Instance.Name or "none")), #near > 0 and (" NEAR " .. table.concat(near, ",")) or "")
	)
	local p = template and template:Clone() or Instance.new("Part")
	p.Name = "SpawnPoint" .. i
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.Transparency = 1
	p.CFrame = CFrame.new(s.X, floor + 3, s.Z)
	table.insert(made, p)
	if i % 4 == 0 then
		task.wait()
	end
end
if bad > 0 then
	for _, p in made do
		p:Destroy()
	end
	return "S3 STOPPED, spawn points not changed: " .. table.concat(report, " ")
end
for _, c in folder:GetChildren() do
	c:Destroy()
end
for _, p in made do
	p.Parent = folder
end
return ("S3 ok: boundary %s %s; %d spawn points: %s"):format(tostring(boundary.Position), tostring(boundary.Size), #folder:GetChildren(), table.concat(report, " "))
