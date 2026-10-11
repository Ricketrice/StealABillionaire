-- Studio location: ServerScriptService.NPCPlacement (ModuleScript)
-- NPCPlacement
-- Lets a player place the NPC they are carrying onto an empty station in their own plot.
-- Every station gets a "Place" ProximityPrompt. Clients only show it on their own empty stations
-- while carrying (StarterPlayerScripts.PlotPrompts), but the server re-checks everything.
--
-- A placed NPC is handed over by NPCCarry.detach (which restores the player's speed and releases
-- the steal reservation), stood on the station facing the plot gate, and kept anchored in the
-- plot's PlacedNPCs folder. The station is marked Occupied (which PassiveIncome pays for) until the
-- worker leaves that folder for any reason, e.g. the plot being cleared when its owner leaves.

local NPCAnimation = require(script.Parent:WaitForChild("NPCAnimation"))
local NPCCarry = require(script.Parent:WaitForChild("NPCCarry"))
local NPCClaim = require(script.Parent:WaitForChild("NPCClaim"))
local PlotService = require(script.Parent:WaitForChild("PlotService"))

local NPCPlacement = {}

export type PlacedHandler = (player: Player, npc: Model, station: BasePart) -> ()
local placedHandler: PlacedHandler? = nil

-- Sets what runs after a player places their carried NPC (e.g. recording it as on that station).
function NPCPlacement.setPlacedHandler(handler: PlacedHandler)
	placedHandler = handler
end

local PROMPT_NAME = "PlacePrompt"
local PROMPT_DISTANCE = 8
local DISTANCE_TOLERANCE = 4 -- extra studs the server allows for latency
local TITLE = "Base"

local function getLivingRoot(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return root
	end
	return nil
end

-- Stands the NPC on the station, facing the plot's gate, anchored in place.
local function standOnStation(npc: Model, station: BasePart, plot: Model)
	local root = npc:FindFirstChild("HumanoidRootPart") :: BasePart
	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	local hipHeight = if humanoid then humanoid.HipHeight else 2
	local stationTop = station.Position.Y + station.Size.X / 2 -- cylinder pad: its height is along X
	local facing = (plot.PrimaryPart :: BasePart).CFrame.LookVector -- towards the gate
	local position = Vector3.new(station.Position.X, stationTop + hipHeight + root.Size.Y / 2, station.Position.Z)
	local rootCFrame = CFrame.lookAt(position, position + facing)
	root.Anchored = true
	npc:PivotTo(rootCFrame * root.CFrame:ToObjectSpace(npc:GetPivot()))
end

-- Puts an NPC (detached from carrying, or freshly built) onto an empty station of `plot`: stands
-- it there, marks the station Occupied, and frees the station again if the NPC ever leaves the
-- plot's PlacedNPCs folder. No ownership checks: callers do those.
function NPCPlacement.placeOnStation(npc: Model, station: BasePart, plot: Model)
	station:SetAttribute("Occupied", true)
	standOnStation(npc, station, plot)
	npc:SetAttribute("ClaimPhase", "Placed")
	npc:SetAttribute("StationIndex", station:GetAttribute("StationIndex"))
	local placedFolder = plot:FindFirstChild("PlacedNPCs") or plot
	npc.Parent = placedFolder
	NPCAnimation.resumeIdle(npc) -- generic idle while it works the station

	local removedConnection: RBXScriptConnection
	removedConnection = npc.AncestryChanged:Connect(function()
		if npc.Parent ~= placedFolder then
			removedConnection:Disconnect()
			station:SetAttribute("Occupied", false)
		end
	end)
end

-- Validates and performs a placement. Returns true, or false and a message for the player.
function NPCPlacement.tryPlace(player: Player, station: BasePart): (boolean, string?)
	local plot = station.Parent and station.Parent.Parent
	if not (plot and plot:IsA("Model")) or PlotService.getPlot(player) ~= plot then
		return false, "This isn't your base."
	end
	if station:GetAttribute("Occupied") == true then
		return false, "That station is taken."
	end
	if not NPCCarry.getCarried(player) then
		return false, "You're not carrying anyone."
	end
	local playerRoot = getLivingRoot(player)
	if not playerRoot then
		return false, "You can't place right now."
	end
	if (playerRoot.Position - station.Position).Magnitude > PROMPT_DISTANCE + DISTANCE_TOLERANCE then
		return false, "Get closer to the station."
	end

	-- Commit (no yields above, so a station can't be filled twice).
	local npc = NPCCarry.detach(player)
	if not npc then
		return false, "You're not carrying anyone."
	end
	NPCPlacement.placeOnStation(npc, station, plot)
	if placedHandler then
		placedHandler(player, npc, station)
	end
	return true
end

local function addPrompt(station: BasePart)
	if station:FindFirstChild(PROMPT_NAME) then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = PROMPT_NAME
	prompt.ActionText = "Place"
	prompt.ObjectText = "Station " .. tostring(station:GetAttribute("StationIndex"))
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = PROMPT_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.ClickablePrompt = true
	prompt.UIOffset = Vector2.new(0, 0)
	prompt.Parent = station
	prompt.Triggered:Connect(function(player)
		local ok, message = NPCPlacement.tryPlace(player, station)
		if ok then
			NPCClaim.notify(player, true, "Placed on station " .. tostring(station:GetAttribute("StationIndex")) .. ".", TITLE)
		elseif message then
			NPCClaim.notify(player, false, message, TITLE)
		end
	end)
end

-- Adds Place prompts to every station in every plot under `plotsFolder`.
function NPCPlacement.start(plotsFolder: Instance)
	for _, plot in plotsFolder:GetChildren() do
		local stations = plot:FindFirstChild("Stations")
		if stations then
			for _, station in stations:GetChildren() do
				if station:IsA("BasePart") then
					addPrompt(station)
				end
			end
		end
	end
end

return NPCPlacement
