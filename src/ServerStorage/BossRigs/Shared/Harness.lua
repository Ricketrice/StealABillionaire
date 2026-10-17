-- Studio location: ServerStorage.BossRigs.Shared.Harness (ModuleScript)
-- Harness: server-side test driver for the boss rigs (any character). Nothing runs by itself: call it from Studio's MCP / command bar during a Play session.
-- It clones ServerStorage.BossRigs.<Char>.Template into an isolated, temporary platform high above the map (never touches gameplay) and sets the replicated attributes
-- that every client's Driver follows. Cleanup removes everything it created.

local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Harness = {}

local AREA_NAME = "_BossRigTest"
local ORIGIN = Vector3.new(0, 900, 0)

local function area(): Folder
	local f = workspace:FindFirstChild(AREA_NAME)
	if f then
		return f :: Folder
	end
	f = Instance.new("Folder")
	f.Name = AREA_NAME
	f.Parent = workspace
	local plat = Instance.new("Part")
	plat.Name = "Platform"
	plat.Size = Vector3.new(120, 2, 120)
	plat.Anchored = true
	plat.Material = Enum.Material.SmoothPlastic
	plat.Color = Color3.fromRGB(70, 70, 82)
	plat.CFrame = CFrame.new(ORIGIN - Vector3.new(0, 1, 0))
	plat.Parent = f
	return f
end

-- Spawns one boss (clone of the character's template) on the platform; returns the model.
function Harness.spawn(charName: string, offset: Vector3?): Model
	local template = ServerStorage.BossRigs[charName]:FindFirstChild("Template")
	assert(template, "no ServerStorage.BossRigs." .. charName .. ".Template (run Builder.build first)")
	local m = template:Clone()
	m.Name = charName
	local data = require(m.Runtime.Data)
	m:PivotTo(CFrame.new(ORIGIN + (offset or Vector3.zero) + Vector3.new(0, data.hrpHeight, 0)))
	m.Parent = area()
	Harness.setBase(m, "Idle")
	return m
end

function Harness.setBase(m: Model, name: string)
	m:SetAttribute("VW_Base", name)
	m:SetAttribute("VW_BaseT0", workspace:GetServerTimeNow())
end

-- One-shot (or looping) clip; the T0 attribute is written last because clients react to it.
function Harness.play(m: Model, clip: string)
	m:SetAttribute("VW_Clip", clip)
	m:SetAttribute("VW_ClipT0", workspace:GetServerTimeNow())
end

-- Walks the (anchored) root from a to b at `speed` studs/s with the Walk loop, then back to Idle. Returns when done.
function Harness.walk(m: Model, to: Vector3, speed: number)
	local hrp = m.PrimaryPart :: BasePart
	local from = hrp.Position
	local dist = (to - from).Magnitude
	local dir = (to - from).Unit
	Harness.setBase(m, "Walk")
	local rot = CFrame.lookAt(Vector3.zero, dir)
	local t = 0
	while t < dist / speed and m.Parent do
		t += RunService.Heartbeat:Wait()
		hrp.CFrame = CFrame.new(from + dir * math.min(t * speed, dist)) * rot.Rotation
	end
	Harness.setBase(m, "Idle")
end

-- Teleports every player's character next to the wizard (so StreamingEnabled streams it in and the camera sees the area).
function Harness.bringPlayers(m: Model)
	local at = (m.PrimaryPart :: BasePart).Position + Vector3.new(0, 4, -22)
	for i, p in Players:GetPlayers() do
		if p.Character then
			p.Character:PivotTo(CFrame.lookAt(at + Vector3.new(i * 4, 0, 0), (m.PrimaryPart :: BasePart).Position))
		end
	end
end

function Harness.cleanup()
	local f = workspace:FindFirstChild(AREA_NAME)
	if f then
		f:Destroy()
	end
end

return Harness
