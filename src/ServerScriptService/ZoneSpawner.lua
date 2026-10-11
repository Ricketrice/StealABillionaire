-- Studio location: ServerScriptService.ZoneSpawner (ModuleScript)
-- ZoneSpawner
-- Keeps one zone stocked with wandering NPCs. Every `spawnInterval` seconds it spawns an NPC at a
-- random free spawn point, until `maxNPCs` are active. An NPC despawns after `lifetime` seconds
-- unless it has been claimed (its "Claimed" attribute is true). Any NPC that is destroyed or
-- leaves the zone's NPCs folder (e.g. when stolen) frees its slot straight away.
-- An optional `shouldSpawn` check pauses new spawns while it returns false (e.g. while nobody in
-- the server can collect from the zone); NPCs already out still despawn on their own timers.

local NPCClaim = require(script.Parent:WaitForChild("NPCClaim"))
local NPCWanderer = require(script.Parent:WaitForChild("NPCWanderer"))
local ZoneArea = require(script.Parent:WaitForChild("ZoneArea"))

type ZoneArea = ZoneArea.ZoneArea

export type Config = {
	template: Model,
	spawnInterval: number,
	maxNPCs: number,
	lifetime: number,
	walkSpeed: number,
	shouldSpawn: (() -> boolean)?,
}

local ZoneSpawner = {}

local SPAWN_CLEARANCE = 3 -- studs; a spawn point with an NPC this close is treated as occupied

local function getFlatDistance(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

local function countActive(zone: ZoneArea): number
	return #zone.npcFolder:GetChildren()
end

-- A random spawn point that no NPC is currently standing on, or nil if all are occupied.
local function chooseSpawnPoint(zone: ZoneArea): BasePart?
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

local function trySpawn(zone: ZoneArea, config: Config)
	if countActive(zone) >= config.maxNPCs then
		return
	end
	if config.shouldSpawn and not config.shouldSpawn() then
		return
	end

	local point = chooseSpawnPoint(zone)
	if not point then
		return -- every spawn point is occupied; try again next interval
	end

	local ok, result = pcall(NPCWanderer.spawn, config.template, zone, point, config.walkSpeed)
	if not ok then
		warn("[ZoneSpawner]", zone.folder.Name, "failed to spawn", config.template.Name, "-", result)
		return
	end

	NPCClaim.attach(result, zone)
	scheduleDespawn(zone, result, config.lifetime)
	print(("[ZoneSpawner] %s: spawned %s at %s (%d/%d active)"):format(
		zone.folder.Name, config.template.Name, point.Name, countActive(zone), config.maxNPCs))
end

-- Starts the spawn loop for a zone. Runs for the lifetime of the server.
function ZoneSpawner.start(zone: ZoneArea, config: Config)
	task.spawn(function()
		while true do
			trySpawn(zone, config)
			task.wait(config.spawnInterval)
		end
	end)
end

return ZoneSpawner
