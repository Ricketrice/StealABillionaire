-- Studio location: ServerScriptService.PvPServer (Script)
-- PvPServer  (Milestone 022)
-- Entry point for PvP stealing, base defence and bats. Both features are off unless their flag in
-- ReplicatedStorage.PvPConfig is on (or, in Studio only, the matching ServerStorage attribute):
-- with the flags off these modules add no prompts, accept no requests and change nothing.

local PvPBase = require(script.Parent:WaitForChild("PvPBase"))
local PvPCombat = require(script.Parent:WaitForChild("PvPCombat"))
local PvPSteal = require(script.Parent:WaitForChild("PvPSteal"))

PvPBase.start()
PvPSteal.start()
PvPCombat.start()
