-- Studio location: StarterPlayer.StarterPlayerScripts.CreatureClient (LocalScript)
-- CreatureClient  (Milestone 035)
-- Plays the code-driven idles (CreatureAnim) and aura particles of every creature near the camera. Creatures
-- farther than NEAR studs stop animating and their auras switch off, so a full server costs almost nothing.
-- Low effects (player attribute LowEffects) turns the auras off for good.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local CreatureAnim = require(game:GetService("ReplicatedStorage"):WaitForChild("CreatureAnim"))

local NEAR = 70 -- studs from the camera
local STEP = 1 / 24

local player = Players.LocalPlayer
local states: { [Model]: CreatureAnim.State } = setmetatable({}, { __mode = "k" }) :: any
local awake: { [Model]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function root(model: Model): BasePart?
	local r = model:FindFirstChild("HumanoidRootPart")
	return if r and r:IsA("BasePart") then r else nil
end

local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < STEP then
		return
	end
	acc = 0
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local origin = camera.CFrame.Position
	local low = player:GetAttribute("LowEffects") == true
	local t = os.clock()
	for _, model in CollectionService:GetTagged("Creature") do
		local r = if model:IsDescendantOf(workspace) then root(model) else nil
		if r then
			local near = (r.Position - origin).Magnitude <= NEAR * math.max(1, (model:GetAttribute("CreatureScale") or 1) * 0.7)
			local state = states[model]
			if near and (not state or state.scale ~= (model:GetAttribute("CreatureScale") or 1)) then
				state = CreatureAnim.bind(model)
				states[model] = state
			end
			if state then
				if near then
					CreatureAnim.step(state, t)
					-- wild = full (World) effects, carried / on a pad = subtle (Captured); Low effects = none
					local tier = if low then nil elseif model:GetAttribute("ClaimPhase") then "Captured" else "World"
					CreatureAnim.setAura(state, not low, tier)
					CreatureAnim.setFx(state, tier)
					awake[model] = true
				elseif awake[model] then
					CreatureAnim.setAura(state, false)
					CreatureAnim.setFx(state, nil)
					awake[model] = nil
				end
			end
		end
	end
end)
