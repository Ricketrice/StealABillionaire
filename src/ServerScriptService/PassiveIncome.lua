-- Studio location: ServerScriptService.PassiveIncome (ModuleScript)
-- PassiveIncome
-- Pays each player for the workers placed on their plot's stations: every placed worker adds its
-- own catalogue income per second (WorkerService.getIncome) to its owner's cash, independently of
-- the others, including duplicates. Only placed workers earn (carried NPCs don't), and only while
-- the owner is online: plots are released when their owner leaves. (Offline earnings, Milestone 029,
-- are paid by RewardsService when the player comes back.)
--
-- One server loop pays everyone each EARN_INTERVAL; there is no per-station loop.
-- Each player's current income per second is kept on their "Income" attribute for the HUD,
-- updated as soon as a worker is placed on or removed from their plot.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EconomyConfig = require(ReplicatedStorage:WaitForChild("EconomyConfig"))
local CashService = require(script.Parent:WaitForChild("CashService"))
local PlotService = require(script.Parent:WaitForChild("PlotService"))
local WorkerService = require(script.Parent:WaitForChild("WorkerService"))

local PassiveIncome = {}

local INCOME_ATTRIBUTE = "Income"

-- Optional income multiplier per player (Milestone 029: the index completion bonus, D15). nil = 1.
local multiplier: ((Player) -> number)? = nil
function PassiveIncome.setMultiplier(fn: ((Player) -> number)?)
	multiplier = fn
end

-- Whole dollars per second this player's placed workers earn.
function PassiveIncome.getIncome(player: Player): number
	local plot = PlotService.getPlot(player)
	local placed = plot and plot:FindFirstChild("PlacedNPCs")
	if not placed then
		return 0
	end
	local income = 0
	for _, worker in placed:GetChildren() do
		income += WorkerService.getIncome(worker)
	end
	local factor = if multiplier then multiplier(player) else 1
	if factor ~= 1 then
		income = math.floor(income * factor + 1e-9)
	end
	return income
end

local function refreshIncome(player: Player): number
	local income = PassiveIncome.getIncome(player)
	if player:GetAttribute(INCOME_ATTRIBUTE) ~= income then
		player:SetAttribute(INCOME_ATTRIBUTE, income)
	end
	return income
end

-- Recomputes a player's displayed income now (e.g. after their multiplier changed).
function PassiveIncome.refresh(player: Player)
	refreshIncome(player)
end

local function pay()
	for _, player in Players:GetPlayers() do
		local income = refreshIncome(player)
		CashService.add(player, math.floor(income * EconomyConfig.EARN_INTERVAL))
	end
end

-- Starts paying for workers on the stations of plots under `plotsFolder` (Workspace.Hub.Plots).
function PassiveIncome.start(plotsFolder: Instance)
	-- Update the owner's displayed income the moment a worker is placed or removed.
	for _, plot in plotsFolder:GetChildren() do
		local placed = plot:FindFirstChild("PlacedNPCs")
		if not placed then
			continue
		end
		local function onChanged()
			local owner = Players:GetPlayerByUserId(plot:GetAttribute("OwnerUserId") or 0)
			if owner then
				refreshIncome(owner)
			end
		end
		placed.ChildAdded:Connect(onChanged)
		placed.ChildRemoved:Connect(onChanged)
	end
	for _, player in Players:GetPlayers() do
		refreshIncome(player)
	end
	Players.PlayerAdded:Connect(refreshIncome)

	task.spawn(function()
		local elapsed = 0
		while true do
			-- Carry over task.wait's overshoot so payouts don't drift below the configured rate.
			elapsed += task.wait(EconomyConfig.EARN_INTERVAL - elapsed)
			while elapsed >= EconomyConfig.EARN_INTERVAL do
				elapsed -= EconomyConfig.EARN_INTERVAL
				pay()
			end
		end
	end)
end

return PassiveIncome
