-- Studio location: StarterPlayer.StarterPlayerScripts.PlotPrompts (LocalScript)
-- PlotPrompts
-- Controls which station "Place" prompt this player sees. Display only: the server re-checks placement.
--
-- Only ONE Place prompt is ever enabled at a time: the nearest empty station on this player's own
-- plot, and only while they are carrying an NPC. All station prompts share the E key, and Roblox
-- shows just one prompt per key, choosing among competing prompts in a way that is not simply the
-- nearest. With several enabled, a player standing at a station could get no prompt or another
-- station's prompt, so placing failed and they stayed carrying.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WorkerState = require(ReplicatedStorage:WaitForChild("WorkerState"))

local player = Players.LocalPlayer
local plots = workspace:WaitForChild("Hub"):WaitForChild("Plots")

local UPDATE_INTERVAL = 0.15 -- seconds between nearest-station checks
local PLACE_BACKUP_AFTER = 3 -- seconds: still carrying after a Place press -> ask again by remote

-- All station PlacePrompts in the hub (they are added by the server after this script starts).
local placePrompts: { ProximityPrompt } = {}
local function track(instance: Instance)
	if instance:IsA("ProximityPrompt") and instance.Name == "PlacePrompt" then
		table.insert(placePrompts, instance)
	end
end
for _, d in plots:GetDescendants() do
	track(d)
end
plots.DescendantAdded:Connect(track)

local function getOwnPlot(): Instance?
	local plotId = player:GetAttribute("PlotId")
	return plotId and plots:FindFirstChild("Plot" .. plotId)
end

-- The PlacePrompt of the nearest empty station on this player's plot, if they are carrying.
local function getTargetPrompt(): ProximityPrompt?
	if player:GetAttribute("CarryingNPC") ~= true then
		return nil
	end
	local plot = getOwnPlot()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local stations = plot and plot:FindFirstChild("Stations")
	if not (root and stations) then
		return nil
	end

	local best, bestDistance = nil, math.huge
	for _, station in stations:GetChildren() do
		local prompt = station:FindFirstChild("PlacePrompt")
		if prompt and station:IsA("BasePart") and station:GetAttribute("Occupied") ~= true then
			local distance = (station.Position - root.Position).Magnitude
			if distance < bestDistance then
				best, bestDistance = prompt, distance
			end
		end
	end
	return best
end

local function update()
	local target = getTargetPrompt()
	for _, prompt in placePrompts do
		local shouldEnable = prompt == target
		if prompt.Enabled ~= shouldEnable then
			prompt.Enabled = shouldEnable
		end
	end
end

-- A Place press that got no result (the message was lost or the client stalled): if this player is
-- still carrying a few seconds later and that station is still free, ask again through WorkerState
-- (sent until answered; the server runs the same checks as the prompt and never places twice).
ProximityPromptService.PromptTriggered:Connect(function(prompt)
	local station = prompt.Name == "PlacePrompt" and prompt.Parent
	if not (station and station:IsA("BasePart")) then
		return
	end
	local index = station:GetAttribute("StationIndex")
	task.delay(PLACE_BACKUP_AFTER, function()
		if player:GetAttribute("CarryingNPC") == true and station.Parent and station:GetAttribute("Occupied") ~= true and type(index) == "number" then
			WorkerState.request("Place", index)
		end
	end)
end)

while true do
	update()
	task.wait(UPDATE_INTERVAL)
end
