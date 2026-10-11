-- Studio location: ServerScriptService.WorkerReveal (ModuleScript)
-- WorkerReveal
-- Decides and reveals which worker a stolen mystery NPC is.
--   roll     (NPCClaim reserve handler) rolls the worker once, the moment the NPC is reserved. The
--            result stays on the server only, so nothing about it replicates before the reveal.
--   reveal   (end of the spin) writes the identity onto the NPC and changes its look for everyone.
--   announce (once the thief is carrying it) shows the thief their reveal card.
-- A cancelled steal destroys the NPC before reveal, so its roll is simply dropped: no worker is
-- created. An NPC that already has an identity is never rolled or revealed again.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorkerAppearance = require(script.Parent:WaitForChild("WorkerAppearance"))
local WorkerCatalogue = require(ReplicatedStorage:WaitForChild("WorkerCatalogue"))
local WorkerService = require(script.Parent:WaitForChild("WorkerService"))

local WorkerReveal = {}

local REVEAL_EVENT_NAME = "WorkerRevealed"

-- Fired to the thief with (workerId: string, workerUid: string); shown by StarterPlayerScripts.WorkerRevealCard.
local revealEvent = ReplicatedStorage:FindFirstChild(REVEAL_EVENT_NAME) :: RemoteEvent
if not revealEvent then
	revealEvent = Instance.new("RemoteEvent")
	revealEvent.Name = REVEAL_EVENT_NAME
	revealEvent.Parent = ReplicatedStorage
end

-- Rolled but not yet revealed identities. Weak keys: a destroyed (cancelled) NPC's roll is dropped.
local pending: { [Model]: WorkerService.Identity } = setmetatable({}, { __mode = "k" }) :: any

-- NPCClaim reserve handler. Must not yield.
function WorkerReveal.roll(_player: Player, npc: Model, zone: { folder: Instance })
	if pending[npc] or npc:GetAttribute("WorkerUid") ~= nil then
		return -- already decided; never reroll
	end
	local zoneId = zone.folder.Name
	if not WorkerCatalogue.ZONES[zoneId] then
		warn("[WorkerReveal] zone", zoneId, "has no worker roster; this steal can't produce a worker")
		return
	end
	pending[npc] = WorkerService.newIdentity(WorkerService.rollWorkerId(zoneId), zoneId)
end

-- Applies the rolled identity and look. Returns false if this NPC was never rolled.
function WorkerReveal.reveal(npc: Model): boolean
	local identity = pending[npc]
	pending[npc] = nil
	if not identity then
		return false
	end
	WorkerService.apply(npc, identity)
	WorkerAppearance.apply(npc, identity.workerId)
	return true
end

-- Shows `player` the reveal card for a revealed worker.
function WorkerReveal.announce(player: Player, npc: Model)
	local identity = WorkerService.getIdentity(npc)
	if identity and player.Parent then
		revealEvent:FireClient(player, identity.workerId, identity.uid)
	end
end

return WorkerReveal
