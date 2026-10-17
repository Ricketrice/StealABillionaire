-- Studio location: ServerStorage.BossRigs.Shared.Client (Script)
-- Client driver for a boss rig model (any character: reads its own Data / Vfx from the Runtime folder) (RunContext = Client, set by Builder). Lives INSIDE the model: it only exists while a boss is in the Workspace.
-- Plays the clip the server announced through the model's attributes (Driver) and the matching cosmetic effects (Vfx) on this client.
-- Follow mode (attribute BossFollow, set by CreatureBuilder when the rig is welded to a creature): the base loop follows the creature's own movement (Walk while it moves, Idle otherwise);
-- one-shot clips can still come from the attributes. Bosses farther than FAR studs from the camera are not stepped; Low effects (player attribute LowEffects) trims the particles.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local FAR = 160 -- studs from the camera: beyond this the pose and the effects are frozen (nobody can see them)
local MOVE_ON, MOVE_OFF = 2.2, 0.9 -- studs/s of the creature's root: start / stop walking (hysteresis)

local model = script.Parent
local runtime = model:WaitForChild("Runtime")
local data = require(runtime:WaitForChild("Data"))
local assets = require(runtime:WaitForChild("Assets"))
local Driver = require(runtime:WaitForChild("Driver"))
local Vfx = require(runtime:WaitForChild("Vfx"))

local clips = {}
for _, m in runtime:WaitForChild("Clips"):GetChildren() do
	clips[m.Name] = require(m)
end
for jointName, j in data.joints do
	local part = model:WaitForChild(j.p1, 10)
	if part then
		part:WaitForChild(jointName, 10)
	end
end

local function now(): number
	return workspace:GetServerTimeNow()
end

local hrp = model:WaitForChild("HumanoidRootPart") :: BasePart
local driver = Driver.new(model, data, clips)
local vfx = Vfx.new(model, data, assets, { lowFx = Players.LocalPlayer:GetAttribute("LowEffects") == true })
driver:onClipStart(function(name: string, elapsed: number)
	vfx:onClip(name, elapsed)
end)
driver:bind(now)
model:SetAttribute("VW_ClientReady", true) -- visible to the server only if set there; clients read their own copy through the DataModel

local follow = model:GetAttribute("BossFollow") == true
local walking = false

local conn = RunService.PreRender:Connect(function(dt: number)
	local camera = workspace.CurrentCamera
	if camera and (camera.CFrame.Position - hrp.Position).Magnitude > FAR then
		return
	end
	local t = now()
	if follow then
		local creature = model.Parent
		local root = creature and creature:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			local v = root.AssemblyLinearVelocity
			local speed = Vector3.new(v.X, 0, v.Z).Magnitude
			if walking then
				walking = speed > MOVE_OFF
			else
				walking = speed > MOVE_ON
			end
			driver:setBase(if walking then "Walk" else "Idle", t)
		end
	end
	driver:step(t)
	vfx:step(t, dt)
end)

model.Destroying:Once(function()
	conn:Disconnect()
	driver:destroy()
	vfx:destroy()
end)
