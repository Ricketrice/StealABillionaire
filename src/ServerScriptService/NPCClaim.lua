-- Studio location: ServerScriptService.NPCClaim (ModuleScript)
-- NPCClaim
-- Adds a "Steal" ProximityPrompt to a zone's NPC and runs the steal on the server.
--
-- A steal has two phases:
--   1. Reserve: the first valid Steal press reserves the NPC for that player. Validation and
--      reservation happen in one step with no yields, so only one player can ever win an NPC,
--      and each player can hold only one reservation at a time. Reserving removes the prompt for
--      everyone and moves the NPC out of the zone's NPCs folder, which stops its wandering,
--      skips its despawn timer and frees its spawn slot. The reserve handler (if set, see
--      NPCClaim.setReserveHandler) then runs once, e.g. to roll what the NPC will turn out to be.
--   2. Spin: the NPC is anchored upright where it stands and spun for SPIN_DURATION seconds.
--      If the player is still alive and in the game and the NPC still exists, the claim
--      completes and the claim handler takes over (see NPCClaim.setClaimHandler).
--
-- Cancellation: if the player dies or leaves, or the NPC is destroyed, during the spin, the
-- NPC is removed (it does not go back to the zone), the reservation is released and the player
-- (if still in the game) is told the steal was cancelled. The zone spawns a replacement as usual.
--
-- The reservation stays held after the spin until the claim handler calls NPCClaim.release, so a
-- later carrying phase can keep the player from stealing a second NPC.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ZoneArea = require(script.Parent:WaitForChild("ZoneArea"))

type ZoneArea = ZoneArea.ZoneArea
export type ClaimHandler = (player: Player, npc: Model) -> ()
export type ReserveHandler = (player: Player, npc: Model, zone: ZoneArea) -> ()
export type ReserveCheck = (player: Player, npc: Model, zone: ZoneArea) -> (boolean, string?)

local NPCClaim = {}

local PROMPT_NAME = "StealPrompt"
local PROMPT_DISTANCE = 8 -- studs
local DISTANCE_TOLERANCE = 4 -- extra studs the server allows for latency and NPC movement
local SPIN_DURATION = 0.7 -- seconds
local SPIN_TURNS = 2 -- full turns during the spin; whole turns so it ends facing the way it started
local CLAIMED_FOLDER_NAME = "ClaimedNPCs"
local FEEDBACK_EVENT_NAME = "ClaimFeedback"

local MESSAGE_ALREADY_CLAIMED = "Someone else already stole this one!"
local MESSAGE_UNAVAILABLE = "This NPC is no longer available."
local MESSAGE_NOT_ALIVE = "You can't steal right now."
local MESSAGE_TOO_FAR = "Get closer to steal it."
local MESSAGE_BUSY = "You already have a worker in hand. Place or store it first."
local MESSAGE_CANCELLED = "Steal cancelled."

local function getOrCreate(parent: Instance, className: string, name: string): Instance
	local existing = parent:FindFirstChild(name)
	if existing then
		return existing
	end
	local instance = Instance.new(className)
	instance.Name = name
	instance.Parent = parent
	return instance
end

-- Fired to a player with (success: boolean, message: string, title: string?); shown by StarterPlayerScripts.ClaimFeedback.
local feedbackEvent = getOrCreate(ReplicatedStorage, "RemoteEvent", FEEDBACK_EVENT_NAME) :: RemoteEvent
-- Reserved and claimed NPCs live here until the claim handler decides what to do with them.
local claimedFolder = getOrCreate(workspace, "Folder", CLAIMED_FOLDER_NAME)

-- Each player's current reservation (the NPC they are spinning now, or later carrying).
local reservations: { [Player]: Model } = {}

local function sendFeedback(player: Player, success: boolean, message: string, title: string?)
	if player.Parent then
		feedbackEvent:FireClient(player, success, message, title)
	end
end

-- Shows a notification to the player (used by claim handlers and base placement). `title` is optional.
NPCClaim.notify = sendFeedback

-- The NPC this player currently has reserved, if any.
function NPCClaim.getReservation(player: Player): Model?
	return reservations[player]
end

-- Ends a player's reservation so they can steal again. Only releases it if it is still for `npc`.
function NPCClaim.release(player: Player, npc: Model)
	if reservations[player] == npc then
		reservations[player] = nil
	end
end

-- TEMPORARY placeholder until carrying is implemented: removes the NPC and tells the player.
local function placeholderClaimHandler(player: Player, npc: Model)
	npc:Destroy()
	NPCClaim.release(player, npc)
	sendFeedback(player, true, "You stole a Mystery NPC!")
end

local claimHandler: ClaimHandler = placeholderClaimHandler
local reserveHandler: ReserveHandler? = nil
local reserveCheck: ReserveCheck? = nil

-- Replaces what happens after a completed claim (e.g. rarity reveal, carrying). The handler
-- receives the NPC anchored and still reserved, and must call NPCClaim.release when done.
function NPCClaim.setClaimHandler(handler: ClaimHandler)
	claimHandler = handler
end

-- Sets an extra condition a player must meet before they may start a steal, e.g. having their data
-- loaded, room for another worker and access to the NPC's zone. It receives the player, the NPC
-- and the server's own zone for it. Returns ok, or false and a message. It must not yield.
function NPCClaim.setReserveCheck(check: ReserveCheck)
	reserveCheck = check
end

-- Sets what runs once, straight after an NPC is reserved and before its spin. It must not yield.
function NPCClaim.setReserveHandler(handler: ReserveHandler)
	reserveHandler = handler
end

local function getLivingRoot(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return root
	end
	return nil
end

-- The steal can only continue while the player is alive and in the game and the NPC still exists.
local function canContinue(player: Player, npc: Model, npcRoot: BasePart): boolean
	return player.Parent ~= nil and getLivingRoot(player) ~= nil and npc.Parent == claimedFolder and npcRoot.Parent == npc
end

local function cancel(player: Player, npc: Model)
	npc:Destroy()
	NPCClaim.release(player, npc)
	sendFeedback(player, false, MESSAGE_CANCELLED)
end

-- Spins the reserved NPC in place, then completes the claim or cancels it.
local function spinThenClaim(player: Player, npc: Model, npcRoot: BasePart)
	-- Keep only the NPC's heading so it stays upright, and hold it where it stands.
	local _, yaw, _ = npcRoot.CFrame:ToOrientation()
	local baseCFrame = CFrame.new(npcRoot.Position) * CFrame.Angles(0, yaw, 0)
	npcRoot.AssemblyLinearVelocity = Vector3.zero
	npcRoot.AssemblyAngularVelocity = Vector3.zero
	npcRoot.Anchored = true

	local start = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function()
		if not canContinue(player, npc, npcRoot) then
			connection:Disconnect()
			cancel(player, npc)
			return
		end

		local progress = math.min((os.clock() - start) / SPIN_DURATION, 1)
		if progress < 1 then
			npcRoot.CFrame = baseCFrame * CFrame.Angles(0, progress * SPIN_TURNS * 2 * math.pi, 0)
			return
		end

		connection:Disconnect()
		npcRoot.CFrame = baseCFrame -- finish exactly as it started, with no leftover rotation
		npc:SetAttribute("ClaimPhase", "Claimed")
		task.spawn(claimHandler, player, npc)
	end)
end

-- Validates and reserves an NPC for a player, then starts the spin. Returns true on success, or
-- false and a message for the player. Everything up to the reservation runs without yielding,
-- so two players can never both reserve the same NPC.
function NPCClaim.tryReserve(player: Player, npc: Model, zone: ZoneArea): (boolean, string?)
	if reservations[player] then
		return false, MESSAGE_BUSY
	end
	if reserveCheck then
		local allowed, message = reserveCheck(player, npc, zone)
		if not allowed then
			return false, message or MESSAGE_NOT_ALIVE
		end
	end
	if npc:GetAttribute("Claimed") == true then
		return false, MESSAGE_ALREADY_CLAIMED
	end
	local npcRoot = npc:FindFirstChild("HumanoidRootPart")
	if npc.Parent ~= zone.npcFolder or not (npcRoot and npcRoot:IsA("BasePart")) then
		return false, MESSAGE_UNAVAILABLE
	end

	local playerRoot = getLivingRoot(player)
	if not playerRoot then
		return false, MESSAGE_NOT_ALIVE
	end
	if (playerRoot.Position - npcRoot.Position).Magnitude > PROMPT_DISTANCE + DISTANCE_TOLERANCE then
		return false, MESSAGE_TOO_FAR
	end

	-- Reserve.
	reservations[player] = npc
	npc:SetAttribute("Claimed", true)
	npc:SetAttribute("ClaimedBy", player.UserId)
	npc:SetAttribute("ClaimPhase", "Spinning")
	local prompt = npcRoot:FindFirstChild(PROMPT_NAME)
	if prompt then
		prompt:Destroy()
	end
	npc.Parent = claimedFolder
	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:MoveTo(npcRoot.Position) -- stop the walk it was on
	end
	if reserveHandler then
		-- An error here must not leave the reservation stuck: the spin and claim handler still run.
		local ok, err = pcall(reserveHandler, player, npc, zone)
		if not ok then
			warn("[NPCClaim] reserve handler failed:", err)
		end
	end

	spinThenClaim(player, npc, npcRoot)
	return true
end

-- Gives an NPC its Steal prompt. Safe to call more than once; only one prompt is ever added.
function NPCClaim.attach(npc: Model, zone: ZoneArea)
	local root = npc:FindFirstChild("HumanoidRootPart")
	if not root or root:FindFirstChild(PROMPT_NAME) then
		return
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = PROMPT_NAME
	prompt.ActionText = "Steal"
	prompt.ObjectText = npc.Name:gsub("(%l)(%u)", "%1 %2") -- "MysteryNPC" -> "Mystery NPC"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = PROMPT_DISTANCE
	prompt.RequiresLineOfSight = false -- the NPC's own accessories would otherwise block it
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.ClickablePrompt = true -- tap on touch screens, click on desktop
	prompt.Parent = root

	-- The connection is cleaned up with the prompt when the NPC is reserved or destroyed.
	prompt.Triggered:Connect(function(player)
		local ok, message = NPCClaim.tryReserve(player, npc, zone)
		if not ok and message then
			sendFeedback(player, false, message)
		end
	end)
end

-- Safety net for reservations that outlive the spin (e.g. a future carrying phase).
Players.PlayerRemoving:Connect(function(player)
	reservations[player] = nil
end)

return NPCClaim
