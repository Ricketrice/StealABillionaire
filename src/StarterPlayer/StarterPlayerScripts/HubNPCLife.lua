-- Studio location: StarterPlayer.StarterPlayerScripts.HubNPCLife (LocalScript)
-- HubNPCLife  (Milestone 027): makes the City Guide and the shopkeepers feel alive, on this client only.
--   * the default R15 idle, looped
--   * turns toward the nearest player within LOOK_RANGE studs (at most MAX_TURN degrees from its post)
--   * waves once when this player walks up (again only after leaving and coming back)
-- Display only: nothing is sent to the server, and other players' copies are untouched. The NPCs are
-- the models HubQuests stands on the venue anchors (tag "HubNPC", child "Body", root anchored).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local IDLE = "rbxassetid://507766388" -- Roblox's default R15 idle
local WAVE = "rbxassetid://507770239" -- Roblox's default R15 wave
local LOOK_RANGE = 15
local WAVE_RANGE = 10
local MAX_TURN = math.rad(75)
local TURN_SPEED = 4 -- per second, as a lerp factor
local CHECK_EVERY = 0.25 -- seconds between nearest-player checks

local player = Players.LocalPlayer
local npcs: { [Model]: any } = {}

local function setUp(holder: Instance)
	if npcs[holder :: Model] or not holder:IsA("Model") then
		return
	end
	local body = holder:FindFirstChild("Body")
	local root = body and body:FindFirstChild("HumanoidRootPart")
	local humanoid = body and body:FindFirstChildOfClass("Humanoid")
	if not (root and root:IsA("BasePart") and humanoid) then
		return -- not streamed in yet; tried again by the loop below
	end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end
	local function load(id: string, priority: Enum.AnimationPriority, looped: boolean): AnimationTrack?
		local animation = Instance.new("Animation")
		animation.AnimationId = id
		local ok, track = pcall(animator.LoadAnimation, animator, animation)
		if not ok then
			return nil
		end
		track.Priority, track.Looped = priority, looped
		return track
	end
	local idle = load(IDLE, Enum.AnimationPriority.Idle, true)
	if idle then
		idle:Play(0.3)
	end
	npcs[holder :: Model] = {
		root = root,
		home = root.CFrame, -- facing at its post
		yaw = 0,
		target = 0,
		wave = load(WAVE, Enum.AnimationPriority.Action, false),
		near = false,
	}
end

local function tearDown(holder: Instance)
	npcs[holder :: Model] = nil
end

CollectionService:GetInstanceRemovedSignal("HubNPC"):Connect(tearDown)

-- Nearest-player check, a few times a second.
task.spawn(function()
	while true do
		for _, holder in CollectionService:GetTagged("HubNPC") do
			setUp(holder)
		end
		for holder, npc in npcs do
			if not (holder.Parent and npc.root.Parent) then
				npcs[holder] = nil
				continue
			end
			local home = npc.home.Position
			local best, bestDistance = nil, LOOK_RANGE
			for _, other in Players:GetPlayers() do
				local hrp = other.Character and other.Character:FindFirstChild("HumanoidRootPart")
				if hrp then
					local d = (hrp.Position - home).Magnitude
					if d <= bestDistance then
						best, bestDistance = hrp, d
					end
				end
			end
			if best then
				local flat = npc.home:PointToObjectSpace(best.Position)
				-- the NPC faces its own -Z
				npc.target = math.clamp(math.atan2(-flat.X, -flat.Z), -MAX_TURN, MAX_TURN)
			else
				npc.target = 0
			end
			local mine = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			local close = mine ~= nil and (mine.Position - home).Magnitude <= WAVE_RANGE
			if close and not npc.near and npc.wave then
				npc.wave:Play(0.2)
			end
			if mine and (mine.Position - home).Magnitude > LOOK_RANGE then
				npc.near = false -- has walked away: wave again next time
			elseif close then
				npc.near = true
			end
		end
		task.wait(CHECK_EVERY)
	end
end)

-- Smooth turning, only while some NPC is still turning.
RunService.Heartbeat:Connect(function(dt)
	for _, npc in npcs do
		local diff = npc.target - npc.yaw
		if math.abs(diff) > 0.002 then
			npc.yaw += diff * math.min(1, TURN_SPEED * dt)
			npc.root.CFrame = npc.home * CFrame.Angles(0, npc.yaw, 0)
		end
	end
end)
