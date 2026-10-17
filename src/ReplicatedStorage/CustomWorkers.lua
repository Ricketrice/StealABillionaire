-- Studio location: ReplicatedStorage.CustomWorkers (ModuleScript)
-- CustomWorkers  (Milestone 019)
-- Which workers use a custom character model instead of the recoloured MysteryNPC look.
-- This is the single switch, read by the server (CustomWorkerRigs) and the UI (WorkerPreview):
--   ENABLED = false     every worker goes back to its original look and preview
--   remove one line     that worker goes back to its original look and preview
-- The originals are never deleted (WorkerAppearance.LOOKS, ReplicatedStorage.WorkerPreviews), and
-- the display name (`name`) is the only catalogue value this sets: ids, rarities, odds, stats and
-- saved data are never touched, and a worker switched off here gets its original name back.
-- Models: ServerStorage.WorkerRigs019.<id> (rig) and ReplicatedStorage.WorkerPreviews019.<id> (preview).
--   rig = "avatar"      the worker is a real Roblox avatar (Milestone 019R): ServerStorage.WorkerRigs019R,
--                       ReplicatedStorage.WorkerPreviews019R, looks in ServerStorage.CustomWorkerLooks.
--                       Delete just that field and the worker falls back to its Milestone 019 model.

local CustomWorkers = {}

CustomWorkers.ENABLED = true

CustomWorkers.WORKERS = {
	-- Knight's Keep (zone id MainStreet; 034 creature names, D43)
	broke_bob = { name = "Rookie Squire", rig = "avatar" },
	delivery_dave = { name = "Scroll Page", rig = "avatar" },
	street_hustler = { name = "Apple Archer", rig = "avatar" },
	business_betty = { name = "Banner Bearer", rig = "avatar" },
	security_sam = { name = "Shield Knight", rig = "avatar" },
	crypto_carl = { name = "Forge Master", rig = "avatar" },
	ceo_chad = { name = "Golden Paladin", rig = "avatar" },
	mystery_millionaire = { name = "Sir Malgrave", rig = "avatar" },
	-- Ember Academy (zone id BillionaireHills)
	butler_barnaby = { name = "Candle Imp", rig = "avatar" },
	caddie_gus = { name = "Ember Newt", rig = "avatar" },
	polo_pro_penny = { name = "Ember Owl", rig = "avatar" },
	chef_pierre = { name = "Fire Apprentice", rig = "avatar" },
	bodyguard_boris = { name = "Rune Golem", rig = "avatar" },
	hedge_fund_hank = { name = "Phoenix", rig = "avatar" },
	oil_baron_oswald = { name = "Flame Archmage", rig = "avatar" },
	the_trillionaire = { name = "Vault Wizard", rig = "avatar" },
}

-- The custom entry for a worker, or nil when it uses its original look.
function CustomWorkers.get(workerId: string): { name: string, rig: string? }?
	return if CustomWorkers.ENABLED then CustomWorkers.WORKERS[workerId] else nil
end

return CustomWorkers
