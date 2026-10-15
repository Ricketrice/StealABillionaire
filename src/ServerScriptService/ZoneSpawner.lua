-- Studio location: ServerScriptService.ZoneSpawner (ModuleScript)
-- ZoneSpawner
-- Keeps one zone stocked with wandering NPCs. About every `spawnInterval` seconds (faster when the cap needs it) it spawns an NPC at a
-- random free spawn point, until `maxNPCs` are active. An NPC despawns after `lifetime` seconds
-- unless it has been claimed (its "Claimed" attribute is true). Any NPC that is destroyed or
-- leaves the zone's NPCs folder (e.g. when stolen) frees its slot straight away.
-- An optional `shouldSpawn` check pauses new spawns while it returns false (e.g. while nobody in
-- the server can collect from the zone); NPCs already out still despawn on their own timers.

local Players = game:GetService("Players")

local NPCAnimation = require(script.Parent:WaitForChild("NPCAnimation"))
local NPCClaim = require(script.Parent:WaitForChild("NPCClaim"))
local NPCWanderer = require(script.Parent:WaitForChild("NPCWanderer"))
local ZoneArea = require(script.Parent:WaitForChild("ZoneArea"))

type ZoneArea = ZoneArea.ZoneArea

export type Config = {
	template: Model,
	spawnInterval: number,
	maxNPCs: number, -- cap while nobody is in the zone
	-- 035: with a player in the zone the cap is activeCap + 1 per extra player there, up to maxCap; wanderers spawn near
	-- players and only walk/animate while a player is within activeRadius studs.
	activeCap: number?,
	maxCap: number?,
	activeRadius: number?,
	lifetime: number,
	walkSpeed: number,
	shouldSpawn: (() -> boolean)?,
	-- 035: rolls the creature when the wanderer spawns; returns the model to spawn and the rolled worker id
	-- (nil = spawn the plain template and roll at the steal, as before).
	pick: (() -> (Model, string?))?,
	adopt: ((npc: Model, workerId: string) -> ())?,
}

local ZoneSpawner = {}

local NEAR_MIN, NEAR_MAX = 20, 120 -- studs from a player: close enough to find, not on top of them
local DEFAULT_ACTIVE_RADIUS = 80
local DORMANCY_TICK = 1 -- seconds between proximity checks
local SPAWN_CLEARANCE = 3 -- studs; a spawn point with an NPC this close is treated as occupied

local function getFlatDistance(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

local function countActive(zone: ZoneArea): number
	return #zone.npcFolder:GetChildren()
end

local function playerPositions(): { Vector3 }
	local list = {}
	for _, player in Players:GetPlayers() do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			table.insert(list, root.Position)
		end
	end
	return list
end

-- Positions of the players standing inside the zone.
local function playersInZone(zone: ZoneArea): { Vector3 }
	local list = {}
	for _, position in playerPositions() do
		if zone:contains(position) then
			table.insert(list, position)
		end
	end
	return list
end

local function currentCap(config: Config, present: number): number
	if config.activeCap and present > 0 then
		return math.min(config.maxCap or 14, config.activeCap + present - 1)
	end
	return config.maxNPCs
end

-- A random spawn point that no NPC is currently standing on, or nil if all are occupied.
-- With `near` (players in the zone) it prefers points 20-120 studs from one of them.
local function chooseSpawnPoint(zone: ZoneArea, near: { Vector3 }?): BasePart?
	local free = {}
	for _, point in zone:getSpawnPoints() do
		local occupied = false
		for _, npc in zone.npcFolder:GetChildren() do
			local root = npc:FindFirstChild("HumanoidRootPart")
			if root and getFlatDistance(root.Position, point.Position) < SPAWN_CLEARANCE then
				occupied = true
				break
			end
		end
		if not occupied then
			table.insert(free, point)
		end
	end
	if #free == 0 then
		return nil
	end
	if near and #near > 0 then
		local anchor = near[math.random(#near)]
		local good = {}
		for _, point in free do
			local d = getFlatDistance(point.Position, anchor)
			if d >= NEAR_MIN and d <= NEAR_MAX then
				table.insert(good, point)
			end
		end
		if #good == 0 then -- nothing in range: take one of the 3 closest to that player
			table.sort(free, function(a, b)
				return getFlatDistance(a.Position, anchor) < getFlatDistance(b.Position, anchor)
			end)
			for i = 1, math.min(3, #free) do
				table.insert(good, free[i])
			end
		end
		return good[math.random(#good)]
	end
	return free[math.random(#free)]
end

local function scheduleDespawn(zone: ZoneArea, npc: Model, lifetime: number)
	task.delay(lifetime, function()
		if npc.Parent == zone.npcFolder and npc:GetAttribute("Claimed") ~= true then
			npc:Destroy()
			print(("[ZoneSpawner] %s: an NPC despawned after %ds (%d active)"):format(zone.folder.Name, lifetime, countActive(zone)))
		end
	end)
end

-- Spawns one wanderer if the zone is below its cap. Returns the cap it used (ZoneSpawner.start paces itself by it).
local function trySpawn(zone: ZoneArea, config: Config): number
	local near = playersInZone(zone)
	local cap = currentCap(config, #near)
	if countActive(zone) >= cap then
		return cap
	end
	if config.shouldSpawn and not config.shouldSpawn() then
		return cap
	end

	local point = chooseSpawnPoint(zone, near)
	if not point then
		return cap -- every spawn point is occupied; try again next interval
	end

	local template, rolledId = config.template, nil
	if config.pick then
		template, rolledId = config.pick()
	end
	local ok, result = pcall(NPCWanderer.spawn, template, zone, point, config.walkSpeed)
	if not ok then
		warn("[ZoneSpawner]", zone.folder.Name, "failed to spawn", config.template.Name, "-", result)
		return cap
	end

	if rolledId and config.adopt then
		config.adopt(result, rolledId)
	end
	NPCClaim.attach(result, zone)
	local prompt = (result:FindFirstChild("HumanoidRootPart") :: Instance?) and result.HumanoidRootPart:FindFirstChild("StealPrompt")
	if rolledId and prompt then
		prompt.ObjectText = result:GetAttribute("PromptName") or result.Name
	end
	scheduleDespawn(zone, result, config.lifetime)
	print(("[ZoneSpawner] %s: spawned %s at %s (%d/%d active)"):format(zone.folder.Name, config.template.Name, point.Name, countActive(zone), cap))
	return cap
end

-- Wanderers with no player within `radius` studs stand still and stop animating (attribute Dormant).
local function updateDormancy(zone: ZoneArea, radius: number)
	local positions = playerPositions()
	for _, npc in zone.npcFolder:GetChildren() do
		local root = npc:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			local near = false
			for _, position in positions do
				if (position - root.Position).Magnitude <= radius then
					near = true
					break
				end
			end
			local asleep = npc:GetAttribute("Dormant") == true
			if near == asleep then -- state changed
				npc:SetAttribute("Dormant", if near then nil else true)
				NPCAnimation.setActive(npc, near)
				if not near then
					local humanoid = npc:FindFirstChildOfClass("Humanoid")
					if humanoid then
						humanoid:MoveTo(root.Position)
					end
				end
			end
		end
	end
end

-- Starts the spawn loop for a zone. Runs for the lifetime of the server.
function ZoneSpawner.start(zone: ZoneArea, config: Config)
	task.spawn(function()
		while true do
			local cap = trySpawn(zone, config)
			-- fast enough that `cap` wanderers can be alive at once given their lifetime
			task.wait(math.min(config.spawnInterval, config.lifetime / cap * 0.9))
		end
	end)
	if config.activeCap then
		local radius = config.activeRadius or DEFAULT_ACTIVE_RADIUS
		task.spawn(function()
			while true do
				updateDormancy(zone, radius)
				task.wait(DORMANCY_TICK)
			end
		end)
	end
end

return ZoneSpawner
