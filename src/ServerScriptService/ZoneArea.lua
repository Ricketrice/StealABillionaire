-- Studio location: ServerScriptService.ZoneArea (ModuleScript)
-- ZoneArea
-- Wraps a zone folder (e.g. Workspace.Zones.MainStreet) and answers spatial questions about it.
-- A zone needs:
--   ZoneBoundary  an anchored box Part covering the area NPCs may walk in
--                 (optional number attribute "WanderMargin": studs to keep away from its edges)
--   SpawnPoints   a Folder of Parts where NPCs can appear
-- No coordinates live in code: everything comes from the zone's own parts, so a new zone
-- only needs those two objects. At runtime an "NPCs" folder is added to hold the zone's NPCs.

local Players = game:GetService("Players")

local ZoneArea = {}
ZoneArea.__index = ZoneArea

local DEFAULT_MARGIN = 4
local MAX_POINT_ATTEMPTS = 20
local MIN_GROUND_NORMAL_Y = 0.7 -- reject surfaces steeper than about 45 degrees
local GROUND_SEARCH_DEPTH = 5 -- studs the ground ray continues below the boundary's bottom face,
-- so ground lying exactly on (or just under) that face is still found

export type ZoneArea = typeof(setmetatable(
	{} :: { folder: Instance, boundary: BasePart, spawnPoints: Instance, npcFolder: Folder, margin: number },
	ZoneArea
))

function ZoneArea.new(folder: Instance): ZoneArea
	local boundary = folder:WaitForChild("ZoneBoundary")
	local spawnPoints = folder:WaitForChild("SpawnPoints")
	assert(boundary:IsA("BasePart"), folder.Name .. ".ZoneBoundary must be a Part")

	local margin = boundary:GetAttribute("WanderMargin")

	-- The boundary is only meant to be seen while editing.
	boundary.Transparency = 1

	local npcFolder = folder:FindFirstChild("NPCs")
	if not npcFolder then
		npcFolder = Instance.new("Folder")
		npcFolder.Name = "NPCs"
		npcFolder.Parent = folder
	end

	return setmetatable({
		folder = folder,
		boundary = boundary,
		spawnPoints = spawnPoints,
		npcFolder = npcFolder :: Folder,
		margin = if typeof(margin) == "number" then margin else DEFAULT_MARGIN,
	}, ZoneArea)
end

function ZoneArea.getSpawnPoints(self: ZoneArea): { BasePart }
	local points = {}
	for _, child in self.spawnPoints:GetChildren() do
		if child:IsA("BasePart") then
			table.insert(points, child)
		end
	end
	return points
end

-- True if the position is inside the boundary's footprint, shrunk by an optional margin.
function ZoneArea.contains(self: ZoneArea, position: Vector3, margin: number?): boolean
	local localPosition = self.boundary.CFrame:PointToObjectSpace(position)
	local half = self.boundary.Size / 2
	local inset = margin or 0
	return math.abs(localPosition.X) <= half.X - inset
		and math.abs(localPosition.Z) <= half.Z - inset
		and math.abs(localPosition.Y) <= half.Y
end

-- Raycasts straight down through the boundary at a horizontal position and returns the
-- walkable surface it hits, or nil if there is no ground there. Zone markers, the zone's NPCs,
-- players and anything in `ignore` are skipped so they never count as ground.
function ZoneArea.findGround(self: ZoneArea, position: Vector3, ignore: { Instance }?): Vector3?
	local exclude: { Instance } = { self.boundary, self.spawnPoints, self.npcFolder }
	for _, instance in ignore or {} do
		table.insert(exclude, instance)
	end
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(exclude, player.Character)
		end
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude

	local top = self.boundary.Position.Y + self.boundary.Size.Y / 2
	local origin = Vector3.new(position.X, top, position.Z)
	local result = workspace:Raycast(origin, Vector3.new(0, -(self.boundary.Size.Y + GROUND_SEARCH_DEPTH), 0), params)
	if result and result.Normal.Y >= MIN_GROUND_NORMAL_Y then
		return result.Position
	end
	return nil
end

-- Picks a random point on the ground inside the boundary, at least `margin` studs from its
-- edges. `accept` can reject candidates (e.g. ones too close to the NPC). Returns nil if no
-- valid point is found after a few attempts.
function ZoneArea.getRandomGroundPoint(
	self: ZoneArea,
	ignore: { Instance }?,
	accept: ((Vector3) -> boolean)?
): Vector3?
	local half = self.boundary.Size / 2
	local rangeX = math.max(half.X - self.margin, 0)
	local rangeZ = math.max(half.Z - self.margin, 0)

	for _ = 1, MAX_POINT_ATTEMPTS do
		local offset = Vector3.new((math.random() * 2 - 1) * rangeX, 0, (math.random() * 2 - 1) * rangeZ)
		local candidate = self.boundary.CFrame:PointToWorldSpace(offset)
		local ground = self:findGround(candidate, ignore)
		if ground and (accept == nil or accept(ground)) then
			return ground
		end
	end
	return nil
end

return ZoneArea
