-- Studio location: ServerScriptService.DevTest_Creature035.ClientHelper (LocalScript)
-- Client half of ServerScriptService.DevTest_Creature035 (cloned into PlayerGui during that Studio test only): measures the pose each creature
-- really renders (sampled at the end of the render step, after a rig's own Driver and the Animator have run). The server asks through
-- ReplicatedStorage.Test035Bridge: "probe" { mode = "wild" | "carried" | "pad", ids = { id }, secs, near = Vector3? } -> reply { [id] = result };
-- "tp" CFrame -> teleports this client's character.
-- Creatures are found by their attribute _Probe035 = id. Wild / pad: world Y and the root's world up. Carried (NPCCarry lies them across the
-- shoulder on purpose): Y in the creature root's own frame and the root's up against the carrier's back (-LookVector of the carrier torso).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local bridge = ReplicatedStorage:WaitForChild("Test035Bridge") :: RemoteEvent

local FEET = { "LeftFoot", "RightFoot", "Left Leg", "Right Leg" }

local function part(src: Instance, name: string): BasePart?
	local p = src:FindFirstChild(name) or src:FindFirstChild(name, true)
	return if p and p:IsA("BasePart") then p else nil
end

local function find(ids: { string }): { [string]: Model }
	local found = {}
	local want = {}
	for _, id in ids do
		want[id] = true
	end
	for _, d in workspace:GetDescendants() do
		local id = d:IsA("Model") and d:GetAttribute("_Probe035")
		if id and want[id] then
			found[id] = d
		end
	end
	return found
end

local function probe(arg: any): { [string]: any }
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if arg.near and hrp then
		hrp.CFrame = CFrame.new(arg.near)
		hrp.AssemblyLinearVelocity = Vector3.zero
	end
	local models = {}
	local deadline = os.clock() + 6 -- streaming: wait for every model (and its rig) to arrive
	repeat
		models = find(arg.ids)
		local complete = true
		for _, id in arg.ids do
			local m = models[id]
			if not (m and part(m, "Head") and m:FindFirstChild("HumanoidRootPart")) then
				complete = false
			end
		end
		if complete then
			break
		end
		task.wait(0.2)
	until os.clock() > deadline
	task.wait(0.3)
	local carrier = character and (character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")) :: BasePart?
	local carried = arg.mode == "carried"
	local res = {}
	for id, m in models do
		res[id] = { n = 0, moving = 0, headTorso = math.huge, torsoFeet = math.huge, up = math.huge, tilt = math.huge, rig = m:FindFirstChild("BossRig") ~= nil }
	end
	RunService:BindToRenderStep("Test035Probe", Enum.RenderPriority.Last.Value + 50, function()
		for id, m in models do
			local r = res[id]
			local src = m:FindFirstChild("BossRig") or m
			local root, head = part(src, "HumanoidRootPart"), part(src, "Head")
			local torso = part(src, "Torso") or part(src, "UpperTorso")
			if not (root and head and torso) then
				continue
			end
			local feetY = math.huge
			local function y(p: BasePart): number
				return if carried then root.CFrame:PointToObjectSpace(p.Position).Y else p.Position.Y
			end
			for _, n in FEET do
				local f = part(src, n)
				if f then
					feetY = math.min(feetY, y(f))
				end
			end
			r.n += 1
			local v = (m:FindFirstChild("HumanoidRootPart") :: BasePart).AssemblyLinearVelocity
			if Vector3.new(v.X, 0, v.Z).Magnitude > 1 then
				r.moving += 1
			end
			r.headTorso = math.min(r.headTorso, y(head) - y(torso))
			if feetY < math.huge then
				r.torsoFeet = math.min(r.torsoFeet, y(torso) - feetY)
			end
			local up = if carried and carrier then root.CFrame.UpVector:Dot(-carrier.CFrame.LookVector) else root.CFrame.UpVector.Y
			r.up = math.min(r.up, up)
			r.tilt = math.min(r.tilt, head.CFrame.UpVector:Dot(torso.CFrame.UpVector))
		end
	end)
	task.wait(arg.secs or 2)
	RunService:UnbindFromRenderStep("Test035Probe")
	for id in models do
		local r = res[id]
		for k, v in r do
			if v == math.huge then
				r[k] = -99
			end
		end
	end
	return res
end

bridge.OnClientEvent:Connect(function(kind, id, arg)
	if kind == "probe" then
		local ok, value = pcall(probe, arg)
		bridge:FireServer("reply", id, if ok then value else { error = tostring(value) })
	elseif kind == "tp" then -- the character is client-owned: a teleport sticks when the client sets it
		local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if hrp and typeof(arg) == "CFrame" then
			hrp.CFrame = arg
			hrp.AssemblyLinearVelocity = Vector3.zero
		end
		bridge:FireServer("reply", id, { done = hrp ~= nil })
	end
end)
bridge:FireServer("ready")
