-- Studio location: ServerScriptService.LaneServer (Script)
-- LaneServer  (Milestone 030): entry point for the Rising Lane's Home / zone teleports and portals.

local LaneService = require(script.Parent:WaitForChild("LaneService"))

LaneService.start()
