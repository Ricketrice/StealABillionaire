-- Studio location: ServerScriptService.PlotService (ModuleScript)
-- PlotService
-- Assigns each player one base plot in the hub for as long as they stay in the server.
-- Ownership is tracked on both sides with attributes:
--   plot   OwnerUserId (number) / OwnerName (string)   - nil when free
--   player PlotId (number)                             - nil until assigned
-- No persistence yet: plots are freed (and their placed NPCs removed) when the owner leaves.
-- Players spawn at the hub's SpawnLocation (see SPAWN_AT_PLOT for spawning inside their own plot).

local Players = game:GetService("Players")

local PlotService = {}

-- Milestone 027 (D6): everyone spawns at the hub's SpawnLocation (036: beside the parade lane, facing it), and a
-- client marker (StarterPlayerScripts.SkyCityLife) points them to their base. Set true to go back
-- to spawning inside the player's own plot.
local SPAWN_AT_PLOT = false
-- Where a player spawns when SPAWN_AT_PLOT is on, in the plot floor's space (-Z points towards the
-- gate): just inside the gate, in the lane between the two rows of stations, facing the gate.
local SPAWN_OFFSET = CFrame.new(0, 3.5, -12)

local plotsFolder: Instance
local plotByPlayer: { [Player]: Model } = {}
local spawnConnections: { [Player]: RBXScriptConnection } = {}

local function setSign(plot: Model, text: string)
	local label = plot:FindFirstChild("Label", true)
	if label and label:IsA("TextLabel") then
		label.Text = text
	end
end

-- Plots in PlotId order, so players fill them from the one nearest Main Street.
local function getPlotsInOrder(): { Model }
	local plots = {}
	for _, plot in plotsFolder:GetChildren() do
		if plot:IsA("Model") and plot:GetAttribute("PlotId") then
			table.insert(plots, plot)
		end
	end
	table.sort(plots, function(a, b)
		return a:GetAttribute("PlotId") < b:GetAttribute("PlotId")
	end)
	return plots
end

local function clearPlacedNPCs(plot: Model)
	local placed = plot:FindFirstChild("PlacedNPCs")
	if placed then
		placed:ClearAllChildren()
	end
	for _, station in plot.Stations:GetChildren() do
		station:SetAttribute("Occupied", false)
	end
end

-- Moves the player's character to their plot's spawn point.
local function moveToPlot(player: Player, character: Model, plot: Model)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	task.wait() -- let Roblox finish placing a new character at the SpawnLocation first
	if not root or character ~= player.Character or plotByPlayer[player] ~= plot then
		return
	end
	local target = (plot.PrimaryPart :: BasePart).CFrame * SPAWN_OFFSET
	pcall(player.RequestStreamAroundAsync, player, target.Position) -- so the floor exists on the client before they land
	if character == player.Character and plotByPlayer[player] == plot then
		character:PivotTo(target)
	end
end

local function assign(player: Player)
	if plotByPlayer[player] or not player.Parent then
		return
	end
	for _, plot in getPlotsInOrder() do
		if plot:GetAttribute("OwnerUserId") == nil then
			plotByPlayer[player] = plot
			plot:SetAttribute("OwnerUserId", player.UserId)
			plot:SetAttribute("OwnerName", player.DisplayName)
			player:SetAttribute("PlotId", plot:GetAttribute("PlotId"))
			setSign(plot, player.DisplayName .. "'s Base")

			if SPAWN_AT_PLOT then
				spawnConnections[player] = player.CharacterAdded:Connect(function(character)
					moveToPlot(player, character, plot)
				end)
				if player.Character then -- joined before this ran: send the current character home too
					task.spawn(moveToPlot, player, player.Character, plot)
				end
			end
			return
		end
	end
	warn("[PlotService] No free plot for", player.Name)
end

local function release(player: Player)
	local plot = plotByPlayer[player]
	if not plot then
		return
	end
	plotByPlayer[player] = nil
	if spawnConnections[player] then
		spawnConnections[player]:Disconnect()
		spawnConnections[player] = nil
	end
	clearPlacedNPCs(plot)
	plot:SetAttribute("OwnerUserId", nil)
	plot:SetAttribute("OwnerName", nil)
	setSign(plot, ("Plot %d — Free"):format(plot:GetAttribute("PlotId")))
end

-- The plot assigned to this player, if any.
function PlotService.getPlot(player: Player): Model?
	return plotByPlayer[player]
end

-- Where this player's character stands when sent home (their plot's spawn point), if they have a plot.
function PlotService.homeCFrame(player: Player): CFrame?
	local plot = plotByPlayer[player]
	if plot and plot.PrimaryPart then
		return plot.PrimaryPart.CFrame * SPAWN_OFFSET
	end
	return nil
end

-- Starts assigning plots from `folder` (Workspace.Hub.Plots) to joining players.
function PlotService.start(folder: Instance)
	plotsFolder = folder
	Players.PlayerAdded:Connect(assign)
	Players.PlayerRemoving:Connect(release)
	for _, player in Players:GetPlayers() do
		assign(player)
	end
end

return PlotService
