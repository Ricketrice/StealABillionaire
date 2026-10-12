-- Studio location: ServerScriptService.RewardsServer (Script)
-- RewardsServer  (Milestone 029)
-- Entry point for the V1 rewards (daily streak, playtime gifts, offline earnings), the index
-- completion bonus, saved settings and favourites. Publishes the four V1Flags switches for clients.
-- With every switch off it adds nothing to any save and pays nothing (see RewardsService).

local RewardsService = require(script.Parent:WaitForChild("RewardsService"))

RewardsService.start()
