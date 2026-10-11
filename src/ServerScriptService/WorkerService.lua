-- Studio location: ServerScriptService.WorkerService (ModuleScript)
-- WorkerService
-- Server-side worker identities. A worker is an NPC model the server has revealed as a catalogue
-- worker. Its identity is written onto the model as attributes exactly once, at reveal:
--   WorkerUid  unique per copy (GUID), so duplicate WorkerIds stay distinct
--   WorkerId   catalogue id            ZoneId  zone it was caught in
--   Level      1                       Tier    "Normal"
-- plus display-only copies of catalogue values (WorkerName, Rarity, Role, Income, Attack, Speed,
-- Defence) for clients and future UI. The server never reads those copies back: income and stats
-- are always recomputed from WorkerId + Level + Tier through the catalogue. Clients can't change
-- server-side attributes.
--
-- An Identity table holds only what a future inventory, save, levelling or merge needs to store.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local WorkerCatalogue = require(ReplicatedStorage:WaitForChild("WorkerCatalogue"))

local WorkerService = {}

export type Identity = {
	uid: string,
	workerId: string,
	zoneId: string,
	level: number,
	tier: string,
}

local rng = Random.new()

-- TEST HOOK, Studio only. While testing in Studio, setting the ServerStorage attribute
-- "TestForceWorkerId" to a worker id from the zone being stolen from makes every roll return that
-- worker. It is ignored outside Studio (RunService:IsStudio() is false on live servers), and
-- clients can't write ServerStorage, so it can't be used to pick a worker in a real game.
local TEST_FORCE_ATTRIBUTE = "TestForceWorkerId"
local function getTestOverride(zoneId: string): string?
	if not RunService:IsStudio() then
		return nil
	end
	local forced = ServerStorage:GetAttribute(TEST_FORCE_ATTRIBUTE)
	if forced == nil then
		return nil
	end
	local worker = WorkerCatalogue.get(forced)
	if worker and worker.zone == zoneId then
		print("[WorkerService] Studio test override: rolled", forced)
		return forced
	end
	print("[WorkerService] Studio test override ignored:", forced, "isn't a", zoneId, "worker")
	return nil
end

-- Rolls which worker a steal in this zone catches.
function WorkerService.rollWorkerId(zoneId: string): string
	return getTestOverride(zoneId) or WorkerCatalogue.rollWorker(zoneId, rng)
end

-- A brand-new caught worker: Level 1, Normal tier, with its own unique id.
function WorkerService.newIdentity(workerId: string, zoneId: string): Identity
	assert(WorkerCatalogue.get(workerId), "unknown worker " .. tostring(workerId))
	return {
		uid = HttpService:GenerateGUID(false),
		workerId = workerId,
		zoneId = zoneId,
		level = WorkerCatalogue.LEVEL,
		tier = WorkerCatalogue.TIER,
	}
end

-- Writes an identity onto an NPC model. A model's identity is permanent: this errors if it already has one.
function WorkerService.apply(npc: Model, identity: Identity)
	assert(npc:GetAttribute("WorkerUid") == nil, "a worker's identity can't be changed")
	local worker = WorkerCatalogue.get(identity.workerId) :: WorkerCatalogue.Worker
	local income, attack, speed, defence = WorkerCatalogue.getStats(identity.workerId, identity.level, identity.tier)

	npc:SetAttribute("WorkerId", identity.workerId)
	npc:SetAttribute("ZoneId", identity.zoneId)
	npc:SetAttribute("Level", identity.level)
	npc:SetAttribute("Tier", identity.tier)
	-- Display copies.
	npc:SetAttribute("WorkerName", worker.name)
	npc:SetAttribute("Rarity", worker.rarity)
	npc:SetAttribute("Role", worker.role)
	npc:SetAttribute("Income", income)
	npc:SetAttribute("Attack", attack)
	npc:SetAttribute("Speed", speed)
	npc:SetAttribute("Defence", defence)
	npc:SetAttribute("WorkerUid", identity.uid) -- last: its presence marks the identity as complete
	npc.Name = worker.name
end

-- The identity written on an NPC model, or nil if it isn't a revealed worker.
function WorkerService.getIdentity(npc: Instance): Identity?
	local uid = npc:GetAttribute("WorkerUid")
	if uid == nil then
		return nil
	end
	return {
		uid = uid,
		workerId = npc:GetAttribute("WorkerId"),
		zoneId = npc:GetAttribute("ZoneId"),
		level = npc:GetAttribute("Level"),
		tier = npc:GetAttribute("Tier"),
	}
end

-- $/sec this worker earns when placed, from the catalogue. 0 for anything that isn't a worker.
function WorkerService.getIncome(npc: Instance): number
	local identity = WorkerService.getIdentity(npc)
	if not identity then
		return 0
	end
	return (WorkerCatalogue.getStats(identity.workerId, identity.level, identity.tier))
end

return WorkerService
