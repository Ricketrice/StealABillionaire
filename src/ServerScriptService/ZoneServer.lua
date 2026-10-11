-- Studio location: ServerScriptService.ZoneServer (Script)
-- ZoneServer
-- Entry point for district unlocking (Milestone 014): cash purchases of districts in order, and the
-- server-side check that keeps players out of gated districts they haven't unlocked.

local ZoneProgress = require(script.Parent:WaitForChild("ZoneProgress"))

ZoneProgress.start()
