-- Studio location: ServerScriptService.HubServer (Script)
-- HubServer
-- Entry point for the safe hub: assigns base plots, enables placing carried NPCs on stations and
-- pays owners for their placed workers, and loads/saves player data and worker inventories.

local BaseService = require(script.Parent:WaitForChild("BaseService"))
local NPCPlacement = require(script.Parent:WaitForChild("NPCPlacement"))
local PassiveIncome = require(script.Parent:WaitForChild("PassiveIncome"))
local PlotService = require(script.Parent:WaitForChild("PlotService"))
local WorkerInventory = require(script.Parent:WaitForChild("WorkerInventory"))

local plots = workspace:WaitForChild("Hub"):WaitForChild("Plots")

PlotService.start(plots)
NPCPlacement.start(plots)
PassiveIncome.start(plots)
BaseService.start() -- (033) before the inventory, so bought pads are up before saved workers are stood on them
WorkerInventory.start() -- after PlotService, so restored workers have a plot to go to
