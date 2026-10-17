-- Studio location: ServerScriptService.DevTest_Vault035.ClientHelper (LocalScript)
-- Client side of DevTest_Vault035: answers the server's questions about what THIS client sees (read-only measurements through the wizard's own Probe module).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local bridge = ReplicatedStorage:WaitForChild("VW_Bridge")

local function wizard(name: string): Model?
	local f = workspace:FindFirstChild("_VaultWizardTest")
	return f and f:FindFirstChild(name) :: Model?
end

bridge.OnClientEvent:Connect(function(id: string, kind: string, arg: any)
	local reply = {}
	local m = wizard("VaultWizard")
	if kind == "hello" then
		reply.sees = m ~= nil
		if m then
			local parts, motors = 0, 0
			for _, d in m:GetDescendants() do
				if d:IsA("MeshPart") then
					parts += 1
				elseif d:IsA("Motor6D") then
					motors += 1
				end
			end
			reply.parts, reply.motors, reply.driver = parts, motors, m:FindFirstChild("Client") ~= nil
		end
	elseif kind == "measure" and m then
		local probe = require(m.Runtime.Probe)
		local err, part = probe.measure(m)
		reply.err, reply.part, reply.halo = err, part, (m:FindFirstChild("VaultHalo") :: BasePart).Size.X
	elseif kind == "watch" and m then
		local probe = require(m.Runtime.Probe)
		local base = probe.vfx(m)
		reply.baseEnabled, reply.maxTemps, reply.maxBeams, reply.first = base.enabled, 0, 0, -1
		local t0 = os.clock()
		while os.clock() - t0 < arg do
			local s = probe.vfx(m)
			local temps = s.vwfxAny - base.vwfxAny
			if temps > reply.maxTemps then
				reply.maxTemps = temps
			end
			if temps > 0 and reply.first < 0 then
				reply.first = os.clock() - t0
			end
			reply.maxBeams = math.max(reply.maxBeams, s.beams)
			task.wait(0.05)
		end
		local s = probe.vfx(m)
		reply.finalTemps, reply.finalEnabled = s.vwfxAny - base.vwfxAny, s.enabled
	elseif kind == "probe" then
		local p = wizard("ProbeNoClient")
		reply.deg = if p then math.deg((p.LeftUpperArm.LeftShoulder :: Motor6D).Transform:ToEulerAnglesXYZ()) else 999
	end
	bridge:FireServer(id, reply)
end)
bridge:FireServer("ready")
