-- Studio location: StarterPlayer.StarterPlayerScripts.Notifications (LocalScript)
-- Notifications
-- Feedback for the core loop. Display only: everything shown is a real server result.
--   * toasts: failed steals, inventory actions (title "Creatures"), placement on a base (title "Base").
--     UIKit.toast stacks at most 3 and folds repeats together, so rapid failures don't spam.
--   * steal pop: "STOLEN!" over the NPC the moment the server reserves it for this player
--     (read from the NPC's replicated ClaimedBy / ClaimPhase attributes; no extra remote).
--   * place pop: "+$X/s" over the station when one of this player's workers starts working there
--     (seen as a change in the server's inventory snapshot; no extra remote).
-- In Studio only, UIKit.Signals.DebugFx previews these (see WorkerRevealCard's FX panel).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CashFormat = require(ReplicatedStorage:WaitForChild("CashFormat"))
local UIKit = require(ReplicatedStorage:WaitForChild("UIKit"))
local UIStyle = require(ReplicatedStorage:WaitForChild("UIStyle"))
local WorkerCatalogue = require(ReplicatedStorage:WaitForChild("WorkerCatalogue"))
local WorkerState = require(ReplicatedStorage:WaitForChild("WorkerState"))

local player = Players.LocalPlayer
local C = UIStyle.Colors
local feedbackEvent = ReplicatedStorage:WaitForChild("ClaimFeedback") :: RemoteEvent

-- Toasts ---------------------------------------------------------------------------------------------
local DENY_SOUND_GAP = 0.5 -- seconds; repeated refusals refresh the toast and stay quiet
local lastDeny = 0
local function onFeedback(success: boolean, message: string, title: string?)
	UIKit.toast(if success then "success" else "error", title or (if success then "Stolen!" else "Can't steal"), message)
	if not success and os.clock() - lastDeny >= DENY_SOUND_GAP then
		lastDeny = os.clock()
		UIKit.sound("deny")
	end
end
feedbackEvent.OnClientEvent:Connect(onFeedback)

-- The zone whose boundary contains this point (for zone-specific sounds), if any.
local function zoneAt(position: Vector3): string?
	local zones = workspace:FindFirstChild("Zones")
	for _, zone in (zones and zones:GetChildren() or {}) do
		local boundary = zone:FindFirstChild("ZoneBoundary")
		if boundary and boundary:IsA("BasePart") then
			local p = boundary.CFrame:PointToObjectSpace(position)
			if math.abs(p.X) <= boundary.Size.X / 2 + 6 and math.abs(p.Z) <= boundary.Size.Z / 2 + 6 then
				return zone.Name
			end
		end
	end
	return nil
end

-- Steal pop ------------------------------------------------------------------------------------------
local popped: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local function stealPop(npc: Instance)
	if popped[npc] then
		return
	end
	popped[npc] = true
	local root = npc:FindFirstChild("HumanoidRootPart")
	UIKit.worldPop(root, "STOLEN!", C.Gold, 4)
	UIKit.sound("steal", if root and root:IsA("BasePart") then zoneAt(root.Position) else nil)
end
task.spawn(function()
	local claimed = workspace:WaitForChild("ClaimedNPCs")
	claimed.ChildAdded:Connect(function(npc)
		if npc:GetAttribute("ClaimedBy") == player.UserId and npc:GetAttribute("ClaimPhase") == "Spinning" then
			stealPop(npc)
		end
	end)
end)

-- Place pop ------------------------------------------------------------------------------------------
local function stationPart(index: number?): BasePart?
	local hub = workspace:FindFirstChild("Hub")
	local plots = hub and hub:FindFirstChild("Plots")
	local plotId = player:GetAttribute("PlotId")
	local plot = plots and plotId and plots:FindFirstChild("Plot" .. tostring(plotId))
	local stations = plot and plot:FindFirstChild("Stations")
	if stations then
		for _, station in stations:GetChildren() do
			if station:IsA("BasePart") and station:GetAttribute("StationIndex") == index then
				return station
			end
		end
	end
	return nil
end

-- The server's own income change is shown when it has just arrived; otherwise the catalogue value.
local lastIncome = player:GetAttribute("Income") or 0
local incomeDelta, incomeDeltaAt = 0, 0
player:GetAttributeChangedSignal("Income"):Connect(function()
	local value = player:GetAttribute("Income") or 0
	incomeDelta, incomeDeltaAt = value - lastIncome, os.clock()
	lastIncome = value
end)

local function placePop(entry)
	local worker = WorkerCatalogue.get(entry.id)
	local amount = if incomeDelta > 0 and os.clock() - incomeDeltaAt < 1 then incomeDelta else (worker and worker.income or 0)
	incomeDelta = 0
	UIKit.worldPop(stationPart(entry.station), "+" .. CashFormat.format(amount) .. "/s", C.Cash, 7)
	UIKit.sound("place", worker and worker.zone)
end

local function locations(snap): { [string]: string }
	local map = {}
	for _, e in snap.workers do
		map[e.uid] = e.loc
	end
	return map
end
local lastLoc: { [string]: string }? = if WorkerState.loaded then locations(WorkerState.snapshot) else nil
WorkerState.Changed:Connect(function(snap)
	local previous = lastLoc
	lastLoc = locations(snap)
	if not previous then
		return -- first snapshot: workers restored on join don't pop
	end
	for _, e in snap.workers do
		if e.loc == "station" and previous[e.uid] ~= nil and previous[e.uid] ~= "station" then
			placePop(e)
		end
	end
end)

-- Studio-only preview of the feedback above (inactive in live servers).
if RunService:IsStudio() then
	UIKit.Signals.DebugFx.Event:Connect(function(kind)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if kind == "steal" then
			UIKit.worldPop(root, "STOLEN!", C.Gold, 4)
			UIKit.sound("steal", "MainStreet")
		elseif kind == "place" then
			UIKit.worldPop(stationPart(1) or root, "+" .. CashFormat.format(125) .. "/s", C.Cash, 7)
			UIKit.sound("place", "MainStreet")
		elseif kind == "refuse" then
			onFeedback(false, "You have no room (26/26). Store or free up space first.")
		end
	end)
end
