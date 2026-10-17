-- Studio location: ServerStorage.BossRigs.Shared.Client (Script)
-- Client driver for a boss rig model (any character: reads its own Data / Vfx from the Runtime folder) (RunContext = Client, set by Builder). Lives INSIDE the model: it only exists while a wizard is in the Workspace.
-- Plays the clip the server announced through the model's attributes (Driver) and the matching cosmetic effects (Vfx) on this client.

local RunService = game:GetService("RunService")

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

local driver = Driver.new(model, data, clips)
local vfx = Vfx.new(model, data, assets)
driver:onClipStart(function(name: string, elapsed: number)
	vfx:onClip(name, elapsed)
end)
driver:bind(now)
model:SetAttribute("VW_ClientReady", true) -- visible to the server only if set there; clients read their own copy through the DataModel

local conn = RunService.PreRender:Connect(function(dt: number)
	local t = now()
	driver:step(t)
	vfx:step(t, dt)
end)

model.Destroying:Once(function()
	conn:Disconnect()
	driver:destroy()
	vfx:destroy()
end)
