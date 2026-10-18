-- Studio location: ServerScriptService.GuardianServer (Script)
-- GuardianServer  (Hub 2b): entry point for the zone guardians. Off unless GuardianConfig.ENABLED (Studio: ServerStorage
-- attribute StudioGuardian overrides it); with it off nothing is added to the world.

local GuardianService = require(script.Parent:WaitForChild("GuardianService"))

GuardianService.start()
