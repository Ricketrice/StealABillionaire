-- S1_SunkenSwap.lua (D48 step 6 / D49): swap the Sunken Kingdom visuals for the owner's cleaned map.
-- Run in Studio Edit (MCP execute_luau or the command bar). Re-runnable; UNDO = true puts everything back.
-- In:  ServerStorage.SunkenKingdomMap (owner's Import 3D of sunken_kingdom_clean.glb, anchored + coloured).
-- Out: Workspace.World.SunkenKingdom.SunkenReef049 (the map: half turn, x1.07, bridge just past the lane gate,
--      walkway on the lane line x -157, floor y 24.3 like the lane). Old visuals parked in ServerStorage._ParkedSunken
--      (each keeps attribute ParkedFrom = its old parent path). Kept in place: Ambience.AmbienceVolume, the lane gate
--      (FutureZones.Our_SunkenKingdom), the entry pad (T2 Island/Paving/2 short Borders), both Ramps, Zones.SunkenKingdom.
local UNDO = false

local SS = game:GetService("ServerStorage")
local World = workspace:WaitForChild("World")
local SK = World:WaitForChild("SunkenKingdom")
local T2 = World.SkyCity.Lane:WaitForChild("T2_SunkenKingdom")

local SCALE = 1.07
local AXIS_X, FLOOR_Y = -157, 24.3
local BRIDGE_END_Z = -401.5 -- the gate's back face is z -399.5; the entry pad runs to -404

local parked = SS:FindFirstChild("_ParkedSunken")

local function keepT2(p: Instance): boolean
	if p.Name == "Island" or p.Name == "Paving" then
		return true
	end
	return p.Name == "Border" and p:IsA("BasePart") and p.Position.Z > -404
end

if UNDO then
	assert(parked, "nothing parked")
	local map = SK:FindFirstChild("SunkenReef049")
	if map then
		map.Name = "SunkenKingdomMap"
		map.Parent = SS
	end
	for _, item in parked:GetChildren() do
		local from = item:GetAttribute("ParkedFrom")
		local parent = if from == "T2" then T2 elseif from == "SKAmb" then SK.Ambience else SK
		item:SetAttribute("ParkedFrom", nil)
		item.Parent = parent
	end
	parked:Destroy()
	return "S1 undone"
end

if SK:FindFirstChild("SunkenReef049") then
	return "S1 already applied"
end
local map = SS:FindFirstChild("SunkenKingdomMap")
assert(map and map:IsA("Model"), "ServerStorage.SunkenKingdomMap missing")

-- 1. park the old visuals
parked = Instance.new("Folder")
parked.Name = "_ParkedSunken"
parked.Parent = SS
local nOld, nT2 = 0, 0
for _, item in SK:GetChildren() do
	if item.Name ~= "Ambience" then
		item:SetAttribute("ParkedFrom", "SK")
		item.Parent = parked
		nOld += 1
	end
end
for _, item in SK.Ambience:GetChildren() do
	if item.Name ~= "AmbienceVolume" then
		item:SetAttribute("ParkedFrom", "SKAmb")
		item.Parent = parked
		nOld += 1
	end
end
for _, item in T2:GetChildren() do
	if not keepT2(item) then
		item:SetAttribute("ParkedFrom", "T2")
		item.Parent = parked
		nT2 += 1
	end
end
-- 2. place the map: pivot = (path axis, seabed top, bridge's far end) in import space
local gate = map:FindFirstChild("Gate_SunkenKingdom_Stone_Deep")
local gcf, gsize = gate:GetBoundingBox()
local minZ = math.huge
for _, m in map:GetChildren() do
	if m.Name:find("^Bridge_Reef") then
		local cf, size = m:GetBoundingBox()
		minZ = math.min(minZ, cf.Position.Z - size.Z / 2)
	end
end
local seabed = map:FindFirstChild("Seabed_Top_Sand_Seabed")
local scf, ssize = seabed:GetBoundingBox()
local pivot = Vector3.new(gcf.Position.X, scf.Position.Y + ssize.Y / 2, minZ)
map.WorldPivot = CFrame.new(pivot)
map:ScaleTo(SCALE)
map:PivotTo(CFrame.new(AXIS_X, FLOOR_Y, BRIDGE_END_Z) * CFrame.Angles(0, math.pi, 0))
map.Name = "SunkenReef049"
map.Parent = SK
local cf, size = map:GetBoundingBox()
return string.format(
	"S1 ok: parked %d old + %d lane parts; import pivot %s (gate %.1f wide); map bbox centre %s size %s",
	nOld,
	nT2,
	tostring(pivot),
	gsize.X,
	tostring(cf.Position),
	tostring(size)
)
