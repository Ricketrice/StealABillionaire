-- Studio location: ServerScriptService.RaceServer (Script)
-- RaceServer  (Milestone 031): entry point for the Royale Race in Zone 6. Off unless RaceConfig.ENABLED (or,
-- in Studio only, ServerStorage attribute StudioRace = true): with it off nothing is added to the world.

local RaceService = require(script.Parent:WaitForChild("RaceService"))

RaceService.start()
