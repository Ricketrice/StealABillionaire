-- Studio location: ReplicatedStorage.LaneConfig (ModuleScript)
-- LaneConfig  (Milestone 030, the Rising Lane): numbers and names shared by the lane server and client.
-- The lane itself is the map (Workspace.World.SkyCity.Lane, built by tools/build027/B8_Lane).

local LaneConfig = {}

LaneConfig.ENABLED = true -- false: Home / Zones requests are refused (the map stays)
LaneConfig.COOLDOWN = 3 -- seconds between teleports per player
LaneConfig.COMBAT_SECONDS = 8 -- no teleport this long after losing health or while a bat is charging
LaneConfig.PORTAL_TAG = "LanePortal" -- trigger part with a ProximityPrompt and a ZoneId attribute
LaneConfig.START_TAG = "LaneStart" -- ghost part with a ZoneId attribute: where a teleport lands
LaneConfig.REQUEST = "LaneTravel" -- RemoteEvent client -> server: "Home" or "Zone", zoneId
LaneConfig.NOTICE = "LaneNotice" -- RemoteEvent server -> client: ok, title, message

-- Zones whose area and unlock are ours: always open. Every other zone follows ZoneConfig (a zone is open
-- only if its gate is wired and the player bought it; the rest are teammates' and "coming soon").
LaneConfig.OURS = { MainStreet = true, BillionaireHills = true }

return LaneConfig
