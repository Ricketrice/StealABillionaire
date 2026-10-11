-- Studio location: ServerScriptService.NPCAnimation (ModuleScript)
-- NPCAnimation
-- Plays walk and idle animations on server-controlled NPCs through the Humanoid's Animator.
-- A rig's default Animate LocalScript never runs on a server-owned NPC, so this takes its place.
-- It reuses the animation IDs stored in that Animate script, so each NPC model keeps its own animations.

local NPCAnimation = {}

local MOVING_THRESHOLD = 0.75 -- studs/s; slower than this counts as standing still (same as default Animate)
local WALK_ANIM_NATIVE_SPEED = 6.4 -- studs/s at which the default R15 walk plays at 1x without foot sliding
local REFERENCE_HIP_HEIGHT = 2 -- HipHeight the default animations were authored for
local FADE_TIME = 0.2

-- Each animated NPC's idle track, so it can be resumed after something else stopped it (e.g. carrying).
local idleTracks: { [Model]: AnimationTrack } = setmetatable({}, { __mode = "k" }) :: any

-- Returns the highest-weighted Animation in one of the Animate script's sets (e.g. "walk", "idle").
local function findAnimation(animate: Instance, setName: string): Animation?
	local set = animate:FindFirstChild(setName)
	if not set then
		return nil
	end

	local best: Animation? = nil
	local bestWeight = -math.huge
	for _, child in set:GetChildren() do
		if child:IsA("Animation") then
			local weight = child:FindFirstChild("Weight")
			local value = if weight and weight:IsA("NumberValue") then weight.Value else 1
			if value > bestWeight then
				best, bestWeight = child, value
			end
		end
	end
	return best
end

-- Starts animating an NPC. Call once, after the NPC is parented to the workspace.
-- Animations stop automatically when the NPC dies or is destroyed.
function NPCAnimation.attach(npc: Model)
	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	local animate = npc:FindFirstChild("Animate")
	if not (humanoid and animator and animate) then
		warn("[NPCAnimation]", npc.Name, "needs a Humanoid, an Animator and an Animate script")
		return
	end

	local walkAnimation = findAnimation(animate, "walk")
	local idleAnimation = findAnimation(animate, "idle")
	if not (walkAnimation and idleAnimation) then
		warn("[NPCAnimation]", npc.Name, "is missing walk or idle animations in its Animate script")
		return
	end

	-- Keep the client-side Animate script from ever starting a second set of tracks.
	if animate:IsA("BaseScript") then
		animate.Enabled = false
	end

	local walkTrack = animator:LoadAnimation(walkAnimation)
	local idleTrack = animator:LoadAnimation(idleAnimation)
	walkTrack.Priority = Enum.AnimationPriority.Movement
	idleTrack.Priority = Enum.AnimationPriority.Idle
	idleTracks[npc] = idleTrack

	-- Taller rigs take longer strides, so their walk plays slightly slower.
	local heightScale = humanoid.HipHeight / REFERENCE_HIP_HEIGHT

	local function onRunning(speed: number)
		if speed > MOVING_THRESHOLD then
			if not walkTrack.IsPlaying then
				idleTrack:Stop(FADE_TIME)
				walkTrack:Play(FADE_TIME)
			end
			walkTrack:AdjustSpeed(speed / (WALK_ANIM_NATIVE_SPEED * heightScale))
		elseif not idleTrack.IsPlaying then
			walkTrack:Stop(FADE_TIME)
			idleTrack:Play(FADE_TIME)
		end
	end

	local runningConnection = humanoid.Running:Connect(onRunning)
	humanoid.Died:Once(function()
		runningConnection:Disconnect()
		walkTrack:Stop()
		idleTrack:Stop()
	end)

	idleTrack:Play()
end

-- Plays the NPC's idle again, e.g. once it is standing on a station. Attaches animations first if
-- the NPC never had them (a worker rebuilt straight onto a station). The NPC must be in the workspace.
function NPCAnimation.resumeIdle(npc: Model)
	local idleTrack = idleTracks[npc]
	if not idleTrack then
		NPCAnimation.attach(npc) -- starts the idle itself
	elseif not idleTrack.IsPlaying then
		idleTrack:Play(FADE_TIME)
	end
end

return NPCAnimation
