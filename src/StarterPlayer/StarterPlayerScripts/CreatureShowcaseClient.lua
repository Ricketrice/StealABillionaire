-- Studio location: StarterPlayer.StarterPlayerScripts.CreatureShowcaseClient (LocalScript)
-- CreatureShowcaseClient  (Milestone 031, D26): code-driven idles for the Studio-only creature showcase
-- (ServerScriptService.CreatureShowcase). Slime Rookie bounces and wobbles, Dragon Pup hovers and flaps its
-- wings, Mech Beast bobs in servo steps and turns its head. Local only (each client moves its own copy of the
-- anchored root; welded pieces follow), skipped beyond 120 studs. Does nothing when there is no showcase.

local RunService = game:GetService("RunService")

local RANGE = 120

type Joint = { weld: Weld, base: CFrame, hinge: Vector3 }
type Rig = { model: Model, root: BasePart, base: CFrame, joints: { [string]: Joint }, phase: number }
local rigs: { [Model]: Rig } = {}

-- A joint that turns around the edge of the piece nearest the body (a wing root, a neck).
local function joint(model: Model, name: string): Joint?
	local p = model:FindFirstChild(model.Name .. "_" .. name)
	local weld = p and p:FindFirstChild("Joint")
	if not (weld and weld:IsA("Weld") and p:IsA("BasePart")) then
		return nil
	end
	local offset = weld.C0.Position
	local toward = -offset.Unit
	local half = p.Size / 2
	local edge = Vector3.new(toward.X * half.X, toward.Y * half.Y, toward.Z * half.Z)
	return { weld = weld, base = weld.C0, hinge = offset + edge }
end

local function track(model: Model)
	if rigs[model] or not model:GetAttribute("Creature") then
		return
	end
	local root = model.PrimaryPart
	if not root then
		return
	end
	local joints = {}
	for _, name in { "WingL", "WingR", "Tail1", "Head", "Antenna", "Leaf", "Tail", "EarL", "EarR" } do
		joints[name] = joint(model, name)
	end
	rigs[model] = { model = model, root = root, base = root.CFrame, joints = joints, phase = math.random() * 6 }
	model.Destroying:Connect(function()
		rigs[model] = nil
	end)
end

local function turn(j: Joint?, rotation: CFrame)
	if j then
		j.weld.C0 = CFrame.new(j.hinge) * rotation * CFrame.new(-j.hinge) * j.base
	end
end

local function animate(r: Rig, t: number)
	local kind = r.model:GetAttribute("Creature")
	local j = r.joints
	if kind == "SlimeRookie" then
		local hop = math.abs(math.sin(t * 3))
		r.root.CFrame = r.base * CFrame.new(0, hop * 0.7, 0) * CFrame.Angles(0, 0, math.rad(math.sin(t * 3) * 5))
		turn(j.Antenna, CFrame.Angles(math.rad(math.sin(t * 6) * 18), 0, 0))
		turn(j.Leaf, CFrame.Angles(0, 0, math.rad(math.sin(t * 4) * 12)))
	elseif kind == "DragonPup" then
		r.root.CFrame = r.base * CFrame.new(0, 0.3 + math.sin(t * 2) * 0.35, 0)
		local flap = math.rad(math.sin(t * 9) * 28)
		local sideL = if j.WingL and j.WingL.hinge.X < 0 then 1 else -1
		turn(j.WingL, CFrame.Angles(0, 0, flap * sideL))
		turn(j.WingR, CFrame.Angles(0, 0, -flap * sideL))
		turn(j.Tail1, CFrame.Angles(0, math.rad(math.sin(t * 3) * 15), 0))
	elseif kind == "MechBeast" then
		-- servo: the bob snaps between two heights, the head turns in 10-degree steps
		local bob = if math.sin(t * 2.5) > 0 then 0.25 else 0
		r.root.CFrame = r.base * CFrame.new(0, bob, 0)
		local yaw = math.floor(math.sin(t * 0.8) * 3 + 0.5) * 10
		turn(j.Head, CFrame.Angles(0, math.rad(yaw), 0))
		turn(j.Tail, CFrame.Angles(0, math.rad(math.sin(t * 2) * 20), 0))
		turn(j.EarL, CFrame.Angles(math.rad(if math.sin(t * 3) > 0.6 then 20 else 0), 0, 0))
		turn(j.EarR, CFrame.Angles(math.rad(if math.sin(t * 3 + 1) > 0.6 then 20 else 0), 0, 0))
	end
end

local function scan()
	local world = workspace:FindFirstChild("World")
	local royale = world and world:FindFirstChild("EmberAcademy")
	local showcase = royale and royale:FindFirstChild("CreatureShowcase")
	if showcase then
		for _, m in showcase:GetChildren() do
			if m:IsA("Model") then
				track(m)
			end
		end
	end
end

task.spawn(function()
	while true do
		scan()
		task.wait(2)
	end
end)

RunService.Heartbeat:Connect(function()
	if next(rigs) == nil then
		return
	end
	local camera = workspace.CurrentCamera
	local t = os.clock()
	for model, r in rigs do
		if not model.Parent then
			rigs[model] = nil
		elseif camera and (camera.CFrame.Position - r.base.Position).Magnitude < RANGE then
			animate(r, t + r.phase)
		end
	end
end)
