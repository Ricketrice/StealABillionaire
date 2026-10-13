-- Studio location: ServerScriptService.NPCWanderer (ModuleScript)
-- NPCWanderer
-- Creates one server-controlled NPC in a zone and makes it wander to random spots inside the
-- zone's boundary. Every NPC runs its own wander loop, which ends by itself when the NPC is
-- destroyed, dies or leaves the zone.

local PhysicsService = game:GetService("PhysicsService")

local NPCAnimation = require(script.Parent:WaitForChild("NPCAnimation"))
local ZoneArea = require(script.Parent:WaitForChild("ZoneArea"))

type ZoneArea = ZoneArea.ZoneArea

local NPCWanderer = {}

local MIN_TRAVEL_DISTANCE = 10 -- ignore destinations closer than this (studs, horizontal)
local PAUSE_BETWEEN_WALKS = 2 -- seconds to idle after each walk
local EXTRA_MOVE_TIME = 3 -- slack added to the expected travel time before a walk is abandoned
local DEFAULT_HIP_HEIGHT = 2 -- fallback if the rig's feet can't be measured
local NPC_COLLISION_GROUP = "NPCs" -- NPCs pass through each other but still collide with players and the world

if not PhysicsService:IsCollisionGroupRegistered(NPC_COLLISION_GROUP) then
	PhysicsService:RegisterCollisionGroup(NPC_COLLISION_GROUP)
end
PhysicsService:CollisionGroupSetCollidable(NPC_COLLISION_GROUP, NPC_COLLISION_GROUP, false)

local function getFlatDistance(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

-- Distance from the bottom of the root part down to the soles of the feet.
-- A Humanoid needs this as its HipHeight to stand on the floor instead of dragging.
local function measureHipHeight(npc: Model, root: BasePart): number
	local feetBottom = math.huge
	for _, part in npc:GetDescendants() do
		if part:IsA("BasePart") and part.Name:match("Foot$") then
			feetBottom = math.min(feetBottom, part.Position.Y - part.Size.Y / 2)
		end
	end
	if feetBottom == math.huge then
		return DEFAULT_HIP_HEIGHT
	end
	return (root.Position.Y - root.Size.Y / 2) - feetBottom
end

-- Still wandering in this zone: not destroyed, not dead and not taken out of the zone.
local function isActive(npc: Model, humanoid: Humanoid, zone: ZoneArea): boolean
	return npc.Parent == zone.npcFolder and humanoid.Parent ~= nil and humanoid.Health > 0
end

-- A random spot on the ground inside the zone, far enough away to be worth walking to.
-- Every destination is inside the boundary and the boundary is a box, so the straight
-- line the Humanoid walks along stays inside it too.
local function chooseDestination(zone: ZoneArea, root: BasePart): Vector3?
	return zone:getRandomGroundPoint(nil, function(point)
		return getFlatDistance(root.Position, point) >= MIN_TRAVEL_DISTANCE
	end)
end

-- Walks toward a destination. Returns true if it arrived, false if it timed out,
-- got blocked, or the NPC stopped being active. Never waits longer than the timeout.
local function walkTo(npc: Model, humanoid: Humanoid, root: BasePart, zone: ZoneArea, destination: Vector3): boolean
	local timeout = getFlatDistance(root.Position, destination) / humanoid.WalkSpeed + EXTRA_MOVE_TIME
	local reached: boolean? = nil
	local connection = humanoid.MoveToFinished:Once(function(success)
		reached = success
	end)

	humanoid:MoveTo(destination)

	local deadline = os.clock() + timeout
	while reached == nil and os.clock() < deadline and isActive(npc, humanoid, zone) do
		task.wait(0.1)
	end
	connection:Disconnect()

	if reached == nil and isActive(npc, humanoid, zone) then
		humanoid:MoveTo(root.Position) -- cancel the stuck walk
	end
	return reached == true
end

local function wander(npc: Model, humanoid: Humanoid, root: BasePart, zone: ZoneArea)
	-- Stagger NPCs so they don't all pick new destinations on the same frame.
	task.wait(math.random() * PAUSE_BETWEEN_WALKS)

	while isActive(npc, humanoid, zone) do
		if not zone:contains(root.Position) then
			-- Only happens if something pushed it out; the next destination brings it back inside.
			warn("[NPCWanderer]", npc.Name, "is outside", zone.folder.Name, "at", root.Position)
		end

		local destination = chooseDestination(zone, root)
		if destination then
			walkTo(npc, humanoid, root, zone, destination)
		else
			warn("[NPCWanderer] No walkable destination found in", zone.folder.Name)
		end
		task.wait(PAUSE_BETWEEN_WALKS)
	end
end

-- Clones `template` with its Humanoid's HipHeight measured and every part in the NPC collision
-- group, ready to be positioned and parented (used for wandering NPCs and for workers rebuilt
-- straight onto a station).
function NPCWanderer.cloneRig(template: Model): Model
	local npc = template:Clone()
	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	local root = npc:FindFirstChild("HumanoidRootPart")
	assert(humanoid and root and root:IsA("BasePart"), template.Name .. " needs a Humanoid and a HumanoidRootPart")

	humanoid.HipHeight = measureHipHeight(npc, root)
	-- No Humanoid name tag ("MysteryNPC") or health bar over any NPC (033 fix).
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	for _, part in npc:GetDescendants() do
		if part:IsA("BasePart") then
			part.CollisionGroup = NPC_COLLISION_GROUP
		end
	end
	return npc
end

-- Clones `template` at a spawn point, stands it on the ground and starts it wandering.
function NPCWanderer.spawn(template: Model, zone: ZoneArea, spawnPoint: BasePart, walkSpeed: number): Model
	local npc = NPCWanderer.cloneRig(template)
	local humanoid = npc:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = npc:FindFirstChild("HumanoidRootPart") :: BasePart
	humanoid.WalkSpeed = walkSpeed

	-- Stand the NPC on the ground at the spawn point, keeping the model's own pivot offset.
	local ground = zone:findGround(spawnPoint.Position)
	local groundY = if ground then ground.Y else spawnPoint.Position.Y
	local rootCFrame = CFrame.new(spawnPoint.Position.X, groundY + humanoid.HipHeight + root.Size.Y / 2, spawnPoint.Position.Z)
	npc:PivotTo(rootCFrame * root.CFrame:ToObjectSpace(npc:GetPivot()))

	npc.Parent = zone.npcFolder
	root:SetNetworkOwner(nil)
	NPCAnimation.attach(npc)

	task.spawn(wander, npc, humanoid, root, zone)
	return npc
end

return NPCWanderer
