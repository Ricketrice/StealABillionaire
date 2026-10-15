-- Studio location: ServerScriptService.NPCSpawner (Script)
-- NPCSpawner
-- Entry point for NPC spawning. Each entry in ZONES keeps one zone stocked with wandering NPCs.
-- Everything is server-controlled: the server spawns the NPCs, owns their physics and picks
-- every destination.
--
-- To add a zone: create Workspace.Zones.<Name> with a ZoneBoundary part and a SpawnPoints
-- folder, then add an entry below. <Name> is the zone's ZoneConfig id and WorkerCatalogue roster.
--
-- District access (Milestone 015): a steal can only start in a zone the thief has unlocked
-- (ZoneProgress.isUnlocked, checked on the server as part of the reservation). District zones only
-- spawn while someone in the server has that district unlocked, so empty districts cost nothing.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local NPCCarry = require(script.Parent:WaitForChild("NPCCarry"))
local NPCClaim = require(script.Parent:WaitForChild("NPCClaim"))
local WorkerInventory = require(script.Parent:WaitForChild("WorkerInventory"))
local WorkerReveal = require(script.Parent:WaitForChild("WorkerReveal"))
local ZoneArea = require(script.Parent:WaitForChild("ZoneArea"))
local ZoneSpawner = require(script.Parent:WaitForChild("ZoneSpawner"))
local ZoneProgress = require(script.Parent:WaitForChild("ZoneProgress"))
local ZoneConfig = require(ReplicatedStorage:WaitForChild("ZoneConfig"))
local CustomWorkerRigs = require(script.Parent:WaitForChild("CustomWorkerRigs"))
local WorkerCatalogue = require(ReplicatedStorage:WaitForChild("WorkerCatalogue"))
local WorkerService = require(script.Parent:WaitForChild("WorkerService"))

-- A steal can only start once the player's data has loaded and they have room for another worker.
-- Reserving a mystery NPC secretly rolls which worker it is. A completed steal reveals it to
-- everyone, puts it on the thief's shoulder (they now own it) and shows them their reveal card.
NPCClaim.setReserveCheck(function(player, _npc, zone)
	local ok, message = WorkerInventory.canClaim(player)
	if not ok then
		return false, message
	end
	local zoneId = zone.folder.Name
	local district = ZoneConfig.get(zoneId)
	if not district then
		return false, "These creatures can't be collected."
	end
	if not ZoneProgress.isUnlocked(player, zoneId) then
		return false, ("Unlock %s to steal its creatures."):format(district.name)
	end
	return true
end)
NPCClaim.setReserveHandler(WorkerReveal.roll)
NPCClaim.setClaimHandler(function(player, npc)
	if not WorkerReveal.reveal(npc) then
		-- Never hand out an NPC without a worker identity.
		npc:Destroy()
		NPCClaim.release(player, npc)
		NPCClaim.notify(player, false, "Steal cancelled.")
		return
	end
	NPCCarry.start(player, npc)
	if NPCCarry.getCarried(player) == npc then
		WorkerInventory.onClaimed(player, npc)
		WorkerReveal.announce(player, npc)
	end
end)

local ZONES = {
	{
		zone = "MainStreet", -- folder under Workspace.Zones
		npcModel = "MysteryNPC", -- model under ServerStorage.NPCModels
		spawnInterval = 10, -- seconds between spawns
		maxNPCs = 6, -- active NPCs allowed in the zone at once
		lifetime = 60, -- seconds before an unclaimed NPC despawns
		walkSpeed = 6, -- studs per second
	},
	-- Districts: fewer NPCs each so a full server stays light on mobile. Food Court (Zone 2) is
	-- teammate-owned and has no spawner until its roster is approved.
	{ zone = "SunkenKingdom", npcModel = "MysteryNPC", spawnInterval = 12, maxNPCs = 4, lifetime = 60, walkSpeed = 6, district = true }, -- 034, ours
	{ zone = "BeachBoardwalk", npcModel = "MysteryNPC", spawnInterval = 12, maxNPCs = 4, lifetime = 60, walkSpeed = 6, district = true },
	{ zone = "ToyTown", npcModel = "MysteryNPC", spawnInterval = 12, maxNPCs = 4, lifetime = 60, walkSpeed = 6, district = true },
	{ zone = "NeonDowntown", npcModel = "MysteryNPC", spawnInterval = 12, maxNPCs = 4, lifetime = 60, walkSpeed = 6, district = true },
	{ zone = "BillionaireHills", npcModel = "MysteryNPC", spawnInterval = 12, maxNPCs = 4, lifetime = 60, walkSpeed = 6, district = true },
}

-- True while at least one player in the server can collect from this zone.
local function anyoneUnlocked(zoneId: string): boolean
	for _, player in Players:GetPlayers() do
		if ZoneProgress.isUnlocked(player, zoneId) then
			return true
		end
	end
	return false
end

local zonesFolder = workspace:WaitForChild("Zones")
local npcModels = ServerStorage:WaitForChild("NPCModels")

-- 035: wanderers are rolled when they spawn (same odds as the steal used) and show the real creature, so you see
-- what you are stealing. Zones/ids without a creature model keep the plain mystery NPC and roll at the steal.
local function creaturePicker(zoneId: string, mystery: Model): (() -> (Model, string?))?
	if not WorkerCatalogue.ZONES[zoneId] then
		return nil
	end
	return function()
		local ok, workerId = pcall(WorkerService.rollWorkerId, zoneId)
		if ok and workerId then
			local template = CustomWorkerRigs.getTemplate(workerId)
			if template and template:GetAttribute("CreatureId") then
				return template, workerId
			end
		end
		return mystery, nil
	end
end

for _, settings in ZONES do
	local mystery = npcModels:WaitForChild(settings.npcModel)
	ZoneSpawner.start(ZoneArea.new(zonesFolder:WaitForChild(settings.zone)), {
		template = mystery,
		pick = creaturePicker(settings.zone, mystery),
		adopt = function(npc: Model, workerId: string)
			WorkerReveal.adoptRolled(npc, settings.zone, workerId)
		end,
		spawnInterval = settings.spawnInterval,
		maxNPCs = settings.maxNPCs,
		lifetime = settings.lifetime,
		walkSpeed = settings.walkSpeed,
		shouldSpawn = if settings.district
			then function()
				return anyoneUnlocked(settings.zone)
			end
			else nil,
	})
end
