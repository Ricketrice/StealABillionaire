-- Studio location: ReplicatedStorage.RaceConfig (ModuleScript)
-- RaceConfig  (Milestone 031, D21 Royale Race): every number for the race, shared by server and client.
-- ALL VALUES BELOW ARE PROPOSED (Checkpoint 1) until the owner approves them.
-- Switch: RaceEnabled. OFF = Zone 6 behaves exactly as before 031. In Studio, set the ServerStorage
-- attribute StudioRace = true; the server publishes ReplicatedStorage attribute RaceOn for clients.

local RaceConfig = {}

RaceConfig.ENABLED = false
RaceConfig.STUDIO_ATTRIBUTE = "StudioRace"
RaceConfig.PUBLISHED = "RaceOn"

-- Timing (seconds)
RaceConfig.INTERVAL = 180 -- a race every 3 minutes if at least 1 player is on the pad
RaceConfig.COUNTDOWN = 5 -- big numbers + sound; stepping off the pad before GO = not in the race
RaceConfig.TIME_LIMIT = 90 -- from GO; unfinished racers get nothing
RaceConfig.PODIUM_SECONDS = 20 -- top 3 names stay on the podium board
RaceConfig.LAPS = 3 -- one lap is ~15 s on the circuit (estimate, measured in the build), so 3 laps ~ 45 s and the limit is ~2x

-- Rewards. Gold for the top GOLD_PLACES finishers, Silver for everyone else who finishes.
-- Small races: with fewer than SMALL_RACE_MIN racers only 1st gets Gold (stops solo servers farming Gold).
RaceConfig.GOLD_PLACES = 3
RaceConfig.SMALL_RACE_MIN = 4
RaceConfig.SMALL_RACE_GOLD_PLACES = 1

-- Capsule odds, percent. Mapped to the whole Zone 6 pool (BillionaireHills, 8 workers): inside a rarity every
-- worker is equally likely. Gold is better than Silver; neither guarantees Legendary or Secret.
-- For reference: normal parade 70/20/8/1.8/0.2, Golden Parade 50/30/14.5/5/0.5. Existing Zone 6 catch odds are untouched.
RaceConfig.ODDS = {
	Silver = { Common = 62, Rare = 24, Epic = 10, Legendary = 3.7, Secret = 0.3 },
	Gold = { Common = 40, Rare = 32, Epic = 19, Legendary = 8, Secret = 1 },
}
RaceConfig.ZONE = "BillionaireHills"

return RaceConfig
