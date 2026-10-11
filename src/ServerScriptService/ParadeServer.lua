-- Studio location: ServerScriptService.ParadeServer (Script)
-- ParadeServer  (Milestone 028)
-- Entry point for the Worker Parade, Golden Parade, collection book and the flags the 028 clients
-- read (ReplicatedStorage ParadeOn / JuiceOn / GoalHudOn / BookOn). Each part is off unless its flag
-- in ReplicatedStorage.ParadeConfig is on (or, in Studio only, the matching ServerStorage attribute):
-- with every flag off nothing is added to the world and no saved data changes.

local ParadeService = require(script.Parent:WaitForChild("ParadeService"))

ParadeService.start()
