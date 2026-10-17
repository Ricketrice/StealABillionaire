-- Studio location: ServerStorage.VaultWizardTest.RuntimeSrc.Probe (ModuleScript)
-- Probe: read-only measurements on a Vault wizard model; works on the server AND on any client (the model carries it). Used by the in-engine tests only.

local HttpService = game:GetService("HttpService")

local Probe = {}

-- Pivot (authored joint frame) positions relative to the root, compared with the expected table the server wrote into attribute VW_Expect.
function Probe.measure(model: Model): (number, string, number)
	local hrp = model:FindFirstChild("HumanoidRootPart") :: BasePart
	local raw = model:GetAttribute("VW_Expect")
	if not (hrp and typeof(raw) == "string") then
		return -1, "no VW_Expect", 0
	end
	local expect = HttpService:JSONDecode(raw)
	local worst, worstPart, n = 0, "", 0
	for partName, p in expect do
		local part = model:FindFirstChild(partName)
		if part and part:IsA("BasePart") then
			local rel = hrp.CFrame:PointToObjectSpace(part:GetPivot().Position)
			local err = (rel - Vector3.new(p[1], p[2], p[3])).Magnitude
			n += 1
			if err ~= err then
				err = math.huge -- NaN must fail, never read as zero error
			end
			if err > worst then
				worst, worstPart = err, partName
			end
		end
	end
	return worst, worstPart, n
end

-- Motor6D.Transform of every joint, as a compact string (to compare what two machines see).
function Probe.transforms(model: Model): { [string]: { number } }
	local out = {}
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") then
			local x, y, z = d.Transform:ToEulerAnglesXYZ()
			out[d.Name] = { math.round(x * 1000) / 1000, math.round(y * 1000) / 1000, math.round(z * 1000) / 1000, math.round(d.Transform.Position.Y * 1000) / 1000 }
		end
	end
	return out
end

function Probe.vfx(model: Model)
	local c = { emitters = 0, enabled = 0, beams = 0, vwfxParts = 0, vwfxAny = 0, particleRate = 0 }
	for _, d in model:GetDescendants() do
		if d.Name:sub(1, 5) == "VWFX_" then
			c.vwfxAny += 1
		end
		if d:IsA("ParticleEmitter") then
			c.emitters += 1
			if d.Enabled then
				c.enabled += 1
				c.particleRate += d.Rate
			end
		elseif d:IsA("Beam") then
			c.beams += 1
		elseif d:IsA("BasePart") and d.Name:sub(1, 5) == "VWFX_" then
			c.vwfxParts += 1
		end
	end
	return c
end

return Probe
