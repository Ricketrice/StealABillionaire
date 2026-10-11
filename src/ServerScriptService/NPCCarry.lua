-- Studio location: ServerScriptService.NPCCarry (ModuleScript)
-- NPCCarry
-- Server-side shoulder carrying. NPCCarry.start is used as NPCClaim's claim handler: after the
-- steal spin it welds the stolen NPC over the player's right shoulder in a fireman's-carry pose
-- and slows the player down while they carry it.
--
-- The NPCClaim reservation stays held for the whole carry, so the player can't steal another NPC.
-- Carrying ends in one of two ways, and both release the reservation and restore walk speed:
--   NPCCarry.detach(player)  stops carrying and hands the NPC back (restored to its normal pose and
--                            physics, anchored where it is) for later systems such as delivery
--                            or a PvP drop to take over.
--   NPCCarry.cancel(player)  stops carrying and removes the NPC. Called automatically when the
--                            player dies, respawns or leaves, or the carried NPC is destroyed.
--
-- The carried NPC stays in Workspace.ClaimedNPCs. It is welded to the player's torso, so it moves
-- with the player's own physics: no per-frame repositioning.

local Players = game:GetService("Players")

local NPCClaim = require(script.Parent:WaitForChild("NPCClaim"))

local NPCCarry = {}

local CARRY_SPEED_MULTIPLIER = 0.85 -- 15% slower while carrying
local WELD_NAME = "CarryWeld"

-- Carry pose, all in the carrier's torso space (+X right, +Y up, -Z forward).
-- The NPC lies face-down across the right shoulder: belly on the shoulder, head down the
-- player's back, legs hanging down the front.
local SHOULDER_SIDE_OFFSET = 2.0 -- studs to the right of the torso centre; keeps the NPC clear of the carrier's head
local WAIST_FORWARD_OFFSET = -0.05 -- studs the NPC's waist sits in front of the shoulder line (negative = behind)
local CARRY_NUDGE = Vector3.new(0, -0.15, 0) -- final hand-tuning of the whole pose (here: settled slightly lower)
local CARRY_ROTATION = CFrame.fromMatrix(
	Vector3.zero,
	Vector3.new(-1, 0, 0), -- NPC's right points to the carrier's left
	Vector3.new(0, 0, 1), -- NPC's head points down the carrier's back
	Vector3.new(0, 1, 0) -- NPC faces the ground
)
-- Joints bent so the legs hang straight down the front and the arms dangle down and away from
-- the carrier's back.
local BENT_JOINTS = {
	LeftHip = math.rad(90),
	RightHip = math.rad(90),
	LeftShoulder = math.rad(135),
	RightShoulder = math.rad(135),
}

type SavedPart = { CanCollide: boolean, CanTouch: boolean, CanQuery: boolean, Massless: boolean }

type Carry = {
	npc: Model,
	weld: Weld,
	carrierHumanoid: Humanoid,
	originalSpeed: number,
	slowedSpeed: number,
	savedParts: { [BasePart]: SavedPart },
	savedJoints: { [Instance]: CFrame }, -- rig Attachment (CFrame) or Motor6D (C0) -> original
	connections: { RBXScriptConnection },
}

local carries: { [Player]: Carry } = {}

-- Runs when a carry is cancelled, just before the NPC is removed, so an owner of the NPC's data
-- can keep it (e.g. send the worker back to the player's inventory). Must not yield.
local dropHandler: ((player: Player, npc: Model) -> ())? = nil
function NPCCarry.setDropHandler(handler: (player: Player, npc: Model) -> ())
	dropHandler = handler
end

-- The NPC this player is carrying, if any.
function NPCCarry.getCarried(player: Player): Model?
	local carry = carries[player]
	return carry and carry.npc
end

local function getCarrierPart(character: Model): BasePart?
	local part = character:FindFirstChild("UpperTorso") -- R15
		or character:FindFirstChild("Torso") -- R6
		or character:FindFirstChild("HumanoidRootPart")
	return if part and part:IsA("BasePart") then part else nil
end

local function getCarryOffset(carrierPart: BasePart, npc: Model): CFrame
	local npcTorso = npc:FindFirstChild("UpperTorso") or npc:FindFirstChild("Torso")
	local npcHalfDepth = if npcTorso and npcTorso:IsA("BasePart") then npcTorso.Size.Z / 2 else 0.5
	local position = Vector3.new(
		SHOULDER_SIDE_OFFSET,
		carrierPart.Size.Y / 2 + npcHalfDepth, -- belly resting on top of the shoulder
		-WAIST_FORWARD_OFFSET
	) + CARRY_NUDGE
	return CFrame.new(position) * CARRY_ROTATION
end

-- Bends the rig's hips and shoulders into the carry pose, remembering the originals.
-- Works for constraint-based R15 rigs (AnimationConstraint) and classic Motor6D rigs.
local function bendJoints(npc: Model, saved: { [Instance]: CFrame })
	for _, joint in npc:GetDescendants() do
		local angle = BENT_JOINTS[joint.Name]
		if not angle then
			continue
		end
		local bend = CFrame.Angles(angle, 0, 0)
		if joint:IsA("AnimationConstraint") and joint.Attachment0 then
			saved[joint.Attachment0] = joint.Attachment0.CFrame
			joint.Attachment0.CFrame *= bend
		elseif joint:IsA("Motor6D") then
			saved[joint] = joint.C0
			joint.C0 *= bend
		end
	end
end

local function restoreJoints(saved: { [Instance]: CFrame })
	for joint, original in saved do
		if joint:IsA("Attachment") then
			joint.CFrame = original
		elseif joint:IsA("Motor6D") then
			joint.C0 = original
		end
	end
end

-- Makes the NPC a weightless, non-solid passenger that the player's physics carries along.
-- CanQuery is off too, so it never blocks the camera, raycasts or the player's floor checks.
local function makePassenger(npc: Model, saved: { [BasePart]: SavedPart })
	for _, part in npc:GetDescendants() do
		if part:IsA("BasePart") then
			saved[part] = { CanCollide = part.CanCollide, CanTouch = part.CanTouch, CanQuery = part.CanQuery, Massless = part.Massless }
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
			part.Massless = true
		end
	end

	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	if humanoid then
		-- Stop the NPC's humanoid from trying to stand, walk or turn while it is carried.
		humanoid.EvaluateStateMachine = false
		humanoid.PlatformStand = true
		local animator = humanoid:FindFirstChildOfClass("Animator")
		if animator then
			for _, track in animator:GetPlayingAnimationTracks() do
				track:Stop(0)
			end
		end
	end
end

local function restorePassenger(npc: Model, saved: { [BasePart]: SavedPart })
	for part, original in saved do
		if part.Parent then
			part.CanCollide = original.CanCollide
			part.CanTouch = original.CanTouch
			part.CanQuery = original.CanQuery
			part.Massless = original.Massless
		end
	end

	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.PlatformStand = false
		humanoid.EvaluateStateMachine = true
	end
end

-- Ends a carry's effects on the player: disconnects listeners, restores walk speed and releases
-- the steal reservation. Leaves the NPC itself to the caller.
local function endCarry(player: Player, carry: Carry)
	carries[player] = nil
	player:SetAttribute("CarryingNPC", nil)
	for _, connection in carry.connections do
		connection:Disconnect()
	end

	-- Only undo our slowdown if nothing else has changed the speed since.
	local humanoid = carry.carrierHumanoid
	if humanoid.Parent and humanoid.WalkSpeed == carry.slowedSpeed then
		humanoid.WalkSpeed = carry.originalSpeed
	end

	NPCClaim.release(player, carry.npc)
end

-- Stops carrying and removes the NPC.
function NPCCarry.cancel(player: Player)
	local carry = carries[player]
	if not carry then
		return
	end
	endCarry(player, carry)
	if dropHandler then
		local ok, err = pcall(dropHandler, player, carry.npc)
		if not ok then
			warn("[NPCCarry] drop handler failed:", err)
		end
	end
	carry.npc:Destroy()
end

-- Stops carrying and returns the NPC, restored to its normal pose and physics and anchored where it
-- is, for another system (e.g. delivery or a PvP drop) to place. Returns nil if not carrying.
function NPCCarry.detach(player: Player): Model?
	local carry = carries[player]
	if not carry then
		return nil
	end
	endCarry(player, carry)

	local npc = carry.npc
	local root = carry.weld.Part1
	if root then
		root.Anchored = true
	end
	carry.weld:Destroy()
	restoreJoints(carry.savedJoints)
	restorePassenger(npc, carry.savedParts)
	npc:SetAttribute("ClaimPhase", "Claimed")
	return npc
end

-- Claim handler: puts a freshly stolen NPC (anchored, reserved for `player`) on their shoulder.
function NPCCarry.start(player: Player, npc: Model)
	local character = player.Character
	local carrierHumanoid = character and character:FindFirstChildOfClass("Humanoid")
	local carrierPart = character and getCarrierPart(character)
	local npcRoot = npc:FindFirstChild("HumanoidRootPart")
	if carries[player] or not (carrierHumanoid and carrierHumanoid.Health > 0 and carrierPart and npcRoot and npcRoot:IsA("BasePart")) then
		-- Can't carry it (shouldn't happen: the reservation and spin checks prevent it).
		npc:Destroy()
		NPCClaim.release(player, npc)
		return
	end

	local carry: Carry = {
		npc = npc,
		weld = Instance.new("Weld"),
		carrierHumanoid = carrierHumanoid,
		originalSpeed = carrierHumanoid.WalkSpeed,
		slowedSpeed = carrierHumanoid.WalkSpeed * CARRY_SPEED_MULTIPLIER,
		savedParts = {},
		savedJoints = {},
		connections = {},
	}
	carries[player] = carry

	makePassenger(npc, carry.savedParts)
	bendJoints(npc, carry.savedJoints)

	-- Weld the NPC to the shoulder, then let it move with the player.
	local weld = carry.weld
	weld.Name = WELD_NAME
	weld.Part0 = carrierPart
	weld.Part1 = npcRoot
	weld.C0 = getCarryOffset(carrierPart, npc)
	weld.C1 = CFrame.identity
	weld.Parent = npcRoot -- removed together with the NPC
	npcRoot.Anchored = false

	carrierHumanoid.WalkSpeed = carry.slowedSpeed
	-- WalkSpeed is stored as a 32-bit float; remember the value it actually holds so the
	-- "has anything else changed it?" check in endCarry compares like with like.
	carry.slowedSpeed = carrierHumanoid.WalkSpeed
	npc:SetAttribute("ClaimPhase", "Carrying")
	player:SetAttribute("CarryingNPC", true) -- lets clients show carry-only prompts (e.g. Place)

	local function cancel()
		NPCCarry.cancel(player)
	end
	table.insert(carry.connections, carrierHumanoid.Died:Connect(cancel))
	table.insert(carry.connections, player.CharacterRemoving:Connect(cancel))
	table.insert(carry.connections, npc.AncestryChanged:Connect(function()
		if not npc:IsDescendantOf(workspace) then
			cancel()
		end
	end))
	table.insert(carry.connections, weld.AncestryChanged:Connect(function()
		if not weld:IsDescendantOf(workspace) then
			cancel() -- something removed the weld; don't leave the NPC loose
		end
	end))
end

Players.PlayerRemoving:Connect(function(player)
	NPCCarry.cancel(player)
end)

return NPCCarry
