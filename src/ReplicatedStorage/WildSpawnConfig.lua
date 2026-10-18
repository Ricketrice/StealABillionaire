-- Studio location: ReplicatedStorage.WildSpawnConfig (ModuleScript)
-- WildSpawnConfig  (Hub 2b): how many wild creatures each of our zones holds. Read by NPCSpawner (-> ZoneSpawner batch
-- mode, 037): at most BATCH_SIZE wanderers at once, and every BATCH_EVERY seconds the unclaimed ones go and a fresh
-- batch spawns (no refill in between). Odds are not here: every wanderer is rolled by WorkerService as before.
-- Knight's Keep had this since 037 (owner); Hub 2b gives the Sunken Kingdom and Ember Academy the same rotation.

local WildSpawnConfig = {}

WildSpawnConfig.BATCH_SIZE = 8 -- wild creatures at a time, per zone (any number of players)
WildSpawnConfig.BATCH_EVERY = 120 -- seconds: full refresh rotation (<= 8 rolls per 2 min per zone = 240 an hour)

return WildSpawnConfig
