-- Studio location: ServerScriptService.HubServer026 (Script)
-- HubServer026  (Milestone 026)
-- Entry point for the hub gameplay: the worker battle arena, the shops, the City Guide and the Quest
-- Board. Each is off unless its flag in ReplicatedStorage.HubConfig is on (or, in Studio only, the
-- matching ServerStorage attribute): with the flags off these modules accept no requests, add
-- nothing to the world and change no saved data.

local HubBase = require(script.Parent:WaitForChild("HubBase"))
local HubArena = require(script.Parent:WaitForChild("HubArena"))
local HubShops = require(script.Parent:WaitForChild("HubShops"))
local HubQuests = require(script.Parent:WaitForChild("HubQuests"))

HubBase.start()
HubArena.start()
HubShops.start()
HubQuests.start(HubArena.Won)
