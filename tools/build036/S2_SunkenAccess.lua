-- S2_SunkenAccess.lua (after S1): collision / shadows for World.SunkenKingdom.SunkenReef049 and the walk-through
-- access parts in World.SunkenKingdom.Access049. Run in Studio Edit; re-runnable; UNDO = true removes Access049,
-- returns the map's glass lock wall and resets every map part to collide + shadow (the as-imported state).
-- Route (lane line x -157): entry pad -> BridgeGapPlate -> reef bridge (guards both sides) -> gate -> courtyard
-- path -> palace steps -> PalacePassFloor (palace + back wall meshes no collide; PalaceBlock/BackBlock walls keep the
-- rest solid) -> BackWedge -> Ember ramp (starts z -564, y 24.3).
local UNDO = false

local SS = game:GetService("ServerStorage")
local SK = workspace.World.SunkenKingdom
local map = SK:FindFirstChild("SunkenReef049")
assert(map, "run S1 first")
local parked = SS:FindFirstChild("_ParkedSunken")
assert(parked, "run S1 first")

local old = SK:FindFirstChild("Access049")
if old then
	old:Destroy()
end
local lock = parked:FindFirstChild("Zone_Lock_Barrier_Glass_Dome")

if UNDO then
	if lock then
		lock:SetAttribute("ParkedFrom", nil)
		lock.Parent = map
	end
	for _, p in map:GetDescendants() do
		if p:IsA("MeshPart") then
			p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, true, true, true
			p.CollisionFidelity = Enum.CollisionFidelity.Default
		end
	end
	return "S2 undone"
end

-- 1. the map's own glass "zone lock" wall stands in its gate; the game has its own lane gate
local mapLock = map:FindFirstChild("Zone_Lock_Barrier_Glass_Dome")
if mapLock then
	mapLock:SetAttribute("ParkedFrom", "SunkenReef049")
	mapLock.Parent = parked
end

-- 2. collision + shadows by model name (first match wins)
local CF = Enum.CollisionFidelity
local RULES = {
	-- walk-through hall: collision comes from PalaceBlock / BackBlock
	{ "^Palace_Grand", "none", true },
	{ "^Wall_Back_Stone", "none", true },
	-- floors
	{ "^Seabed_Top", CF.PreciseConvexDecomposition, false },
	{ "^Path_Main_Path_Mosaic", CF.PreciseConvexDecomposition, false },
	{ "^Path_Main_Stone_Deep", CF.PreciseConvexDecomposition, false },
	{ "^Bridge_Reef_Path_Mosaic", CF.PreciseConvexDecomposition, false },
	{ "^Island_Reef_Reef_Rock", CF.PreciseConvexDecomposition, false },
	{ "^Amphitheater_Shell_Stone_Sunken", CF.PreciseConvexDecomposition, false },
	-- walls and big structures
	{ "^Wall_Corner_Towers_Stone", CF.PreciseConvexDecomposition, true },
	{ "^Wall_Front_[LR]_Stone", CF.Box, true },
	{ "^Wall_Left_Stone", CF.Box, true },
	{ "^Wall_Right_Stone", CF.Box, true },
	{ "^Gate_SunkenKingdom_Stone_Deep", CF.PreciseConvexDecomposition, true },
	{ "^Bridge_Reef_Stone_Sunken", CF.PreciseConvexDecomposition, true },
	{ "^Ruin_Colonnade_Stone_Sunken", CF.PreciseConvexDecomposition, true },
	{ "^Amphitheater_Shell_Coral_Pink", CF.PreciseConvexDecomposition, true },
	{ "^Amphitheater_Shell_Shell_Pearl", CF.PreciseConvexDecomposition, true },
	{ "^Crystal_Tower_Stone_Sunken", CF.Hull, true },
	{ "^Statue_SeaDragon_Verdigris", CF.Hull, true },
	{ "^Habitat_Dome_.-_Glass_Dome", CF.Hull, false },
	{ "^Habitat_Dome_.-_Stone_Deep", CF.Hull, true },
	{ "^Conch_House_.-_Shell_Pearl", CF.Hull, true },
	{ "^Conch_House_.-_Coral_Pink", CF.Hull, true },
	{ "^Market_Stall_.-_Driftwood", CF.Box, true },
	-- shadow-only (no collision) structure pieces
	{ "^Statue_SeaDragon_Dragon_Scale", "none", true },
	{ "^Palace", "none", true },
}
local counts = { collide = 0, none = 0, shadow = 0 }
for _, model in map:GetChildren() do
	local rule
	for _, r in RULES do
		if model.Name:find(r[1]) then
			rule = r
			break
		end
	end
	for _, p in model:GetDescendants() do
		if p:IsA("MeshPart") then
			local fid = rule and rule[2] or "none"
			if fid == "none" then
				p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
				counts.none += 1
			else
				p.CollisionFidelity = fid
				p.CanCollide, p.CanQuery, p.CanTouch = true, true, false
				counts.collide += 1
			end
			p.CastShadow = rule ~= nil and rule[3] == true
			if p.CastShadow then
				counts.shadow += 1
			end
		end
	end
end
map.LevelOfDetail = Enum.ModelLevelOfDetail.Automatic

-- 3. access parts
local acc = Instance.new("Folder")
acc.Name = "Access049"
local MOSAIC, GOLD, DOOR = Color3.fromRGB(226, 214, 182), Color3.fromRGB(224, 177, 72), Color3.fromRGB(14, 32, 40)
local function part(name: string, cf: CFrame, size: Vector3, visible: boolean, color: Color3?, solid: boolean?, cls: string?): BasePart
	local p = Instance.new(cls or "Part") :: BasePart
	p.Name = name
	p.Anchored = true
	p.CFrame = cf
	p.Size = size
	p.CanCollide = solid ~= false
	p.CanTouch = false
	p.CastShadow = false
	if visible then
		p.Material = Enum.Material.SmoothPlastic
		p.Color = color or MOSAIC
		p.CanQuery = true
	else
		p.Transparency = 1
		p.CanQuery = false -- invisible walls must not stop the camera or creature rays
	end
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = acc
	return p
end
local X = -157
local FLOOR = 24.3
-- bridge: the GLB's bridge ends 10 studs before its deck starts (z -403..-412)
part("BridgeGapPlate", CFrame.new(X, FLOOR - 0.25, -408), Vector3.new(9.6, 0.5, 10), true, MOSAIC)
-- guards: bridge edges (outside the curbs) and the entry pad's open south edge
-- the deck mesh's collision has a 1-stud seam at z -428: invisible plate just under the deck surface (24.2)
part("BridgeDeckPlate", CFrame.new(X, 24.15 - 0.2, -431.5), Vector3.new(9.6, 0.4, 40), false)
part("BridgeGuardL", CFrame.new(-165.4, FLOOR + 5, -425.1), Vector3.new(0.6, 10, 51), false)
part("BridgeGuardR", CFrame.new(-148.6, FLOOR + 5, -425.1), Vector3.new(0.6, 10, 51), false)
part("EntryGuardL", CFrame.new(-168.85, FLOOR + 5, -404.3), Vector3.new(6.3, 10, 0.6), false)
part("EntryGuardR", CFrame.new(-145.15, FLOOR + 5, -404.3), Vector3.new(6.3, 10, 0.6), false)
-- palace hall: floor at the top of the palace steps (y 26.7), corridor x -161..-153
local HALL_Y = 26.7
part("PalacePassFloor", CFrame.new(X, HALL_Y - 0.25, -554.1), Vector3.new(8, 0.5, 18.6), true, MOSAIC)
part("PalaceBlockL", CFrame.new(-168.8, FLOOR + 10, -551.65), Vector3.new(15.6, 20, 13.3), false)
part("PalaceBlockR", CFrame.new(-145.2, FLOOR + 10, -551.65), Vector3.new(15.6, 20, 13.3), false)
part("BackBlockL", CFrame.new(-175.6, FLOOR + 10, -560.4), Vector3.new(29.2, 20, 4.2), false)
part("BackBlockR", CFrame.new(-138.4, FLOOR + 10, -560.4), Vector3.new(29.2, 20, 4.2), false)
-- doorways on the palace front and the back wall (dark panel you walk through + gold frame)
for _, d in { { "Front", -545.2 }, { "Back", -562.7 } } do
	local z = d[2]
	part(d[1] .. "DoorPanel", CFrame.new(X, HALL_Y + 4.5, z), Vector3.new(7.6, 9, 0.3), true, DOOR, false)
	part(d[1] .. "DoorFrameL", CFrame.new(X - 4.3, HALL_Y + 4.8, z), Vector3.new(1, 9.6, 1), true, GOLD)
	part(d[1] .. "DoorFrameR", CFrame.new(X + 4.3, HALL_Y + 4.8, z), Vector3.new(1, 9.6, 1), true, GOLD)
	part(d[1] .. "DoorLintel", CFrame.new(X, HALL_Y + 10.1, z), Vector3.new(9.6, 1, 1), true, GOLD)
end
-- down onto the Ember ramp: wedge from the hall floor (z -562.8, y 26.7) to the ramp surface (z -567, y 25.05)
local wedge = part("BackWedge", CFrame.new(X, 0, 0), Vector3.new(8, 1.65, 4.2), false, nil, true, "WedgePart")
wedge.CFrame = CFrame.new(X, 25.05 + 1.65 / 2, -564.9) -- a WedgePart is tallest on its +Z side (the hall)
for _, p in acc:GetChildren() do
	p:SetAttribute("Built049", true)
end
acc.Parent = SK
return string.format(
	"S2 ok: %d meshes collide, %d no-collide, %d cast shadows; %d access parts; lock wall parked: %s",
	counts.collide,
	counts.none,
	counts.shadow,
	#acc:GetChildren(),
	tostring(mapLock ~= nil or lock ~= nil)
)
