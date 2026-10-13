-- Studio location: ServerScriptService.SpeedServer (Script)
-- SpeedServer  (Milestone 032): entry point for the Speed stat and speed trails. Off unless SpeedConfig.ENABLED
-- (or, in Studio only, ServerStorage attribute StudioSpeed = true); with it off walk speeds stay as before.

local SpeedService = require(script.Parent:WaitForChild("SpeedService"))

SpeedService.start()
