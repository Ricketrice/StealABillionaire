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
	-- Main Street
	broke_bob = { name = "Broke Bob", rig = "avatar" },
	delivery_dave = { name = "Coupon Carl", rig = "avatar" },
	street_hustler = { name = "Hustle Hannah", rig = "avatar" },
	business_betty = { name = "Influencer Ivy", rig = "avatar" },
	security_sam = { name = "Landlord Larry", rig = "avatar" },
	crypto_carl = { name = "Stonks Steve", rig = "avatar" },
	ceo_chad = { name = "CEO Chad", rig = "avatar" },
	mystery_millionaire = { name = "Old Money Margaret", rig = "avatar" },
	-- Velocity Royale (zone id BillionaireHills)
	butler_barnaby = { name = "Pit Crew Pete", rig = "avatar" },
	caddie_gus = { name = "Flag Marshal Fiona", rig = "avatar" },
	polo_pro_penny = { name = "Paparazzi Paz", rig = "avatar" },
	chef_pierre = { name = "Valet Vince", rig = "avatar" },
	bodyguard_boris = { name = "Team Boss Bianca", rig = "avatar" },
	hedge_fund_hank = { name = "Turbo Taylor", rig = "avatar" },
	oil_baron_oswald = { name = "Garage Baron Gideon", rig = "avatar" },
	the_trillionaire = { name = "The Trillionaire", rig = "avatar" },
}

-- The custom entry for a worker, or nil when it uses its original look.
function CustomWorkers.get(workerId: string): { name: string, rig: string? }?
	return if CustomWorkers.ENABLED then CustomWorkers.WORKERS[workerId] else nil
end

return CustomWorkers
