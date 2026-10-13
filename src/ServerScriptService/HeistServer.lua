-- Studio location: ServerScriptService.HeistServer (Script)
-- HeistServer  (Milestone 032): entry point for the Boss Heist on Main Street. Off unless HeistConfig.ENABLED
-- (or, in Studio only, ServerStorage attribute StudioHeist = true): with it off nothing is added to the world.

local HeistService = require(script.Parent:WaitForChild("HeistService"))

HeistService.start()
