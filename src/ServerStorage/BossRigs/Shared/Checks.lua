-- Studio location: ServerStorage.BossRigs.Shared.Checks (ModuleScript)
-- Checks: server-side in-engine checks for a boss rig (Edit mode for structure, Play mode for poses). Every function returns plain tables (no printing).

local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local Checks = {}

local ROOT = ServerStorage.BossRigs
local function expectedOf(model: Instance): any
	return require(ROOT[model:GetAttribute("BossRig")].Expected)
end

local function counts(model: Instance)
	local c = { meshParts = 0, neon = 0, motors = 0, welds = 0, surfaceAppearance = 0, attachments = 0, scripts = 0 }
	for _, d in model:GetDescendants() do
		if d:IsA("MeshPart") then
			c.meshParts += 1
			if d.Material == Enum.Material.Neon then
				c.neon += 1
			end
		elseif d:IsA("Motor6D") then
			c.motors += 1
		elseif d:IsA("Weld") then
			c.welds += 1
		elseif d:IsA("SurfaceAppearance") then
			c.surfaceAppearance += 1
		elseif d:IsA("Attachment") then
			c.attachments += 1
		elseif d:IsA("LuaSourceContainer") then
			c.scripts += 1
		end
	end
	return c
end

-- Structure at rest: counts, joint validity, connectivity from the root, extents against the authored model, pivot error against glTF forward kinematics.
function Checks.structure(model: Model)
	local hrp = model.PrimaryPart :: BasePart
	local data = require(model.Runtime.Data)
	local Expected = expectedOf(model)
	local r = { counts = counts(model), errors = {} :: { string } }
	-- connectivity from the root through the Motor6D / Weld graph (Part0/Part1; GetJoints only works inside the Workspace)
	local edges: { [BasePart]: { BasePart } } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("JointInstance") and d.Part0 and d.Part1 then
			edges[d.Part0] = edges[d.Part0] or {}
			table.insert(edges[d.Part0], d.Part1)
		end
	end
	local reach, queue = { [hrp] = true }, { hrp }
	while #queue > 0 do
		local p = table.remove(queue) :: BasePart
		for _, q in edges[p] or {} do
			if not reach[q] then
				reach[q] = true
				table.insert(queue, q)
			end
		end
	end
	local loose = {}
	for _, d in model:GetChildren() do
		if d:IsA("BasePart") and not reach[d] then
			table.insert(loose, d.Name)
		end
	end
	r.disconnected = loose
	local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
	local worst, worstPart = 0, ""
	for _, d in model:GetChildren() do
		if d:IsA("MeshPart") and not (Expected.skipExtents and Expected.skipExtents[d.Name]) then
			local rel = hrp.CFrame:ToObjectSpace(d.CFrame)
			for _, sx in { -0.5, 0.5 } do
				for _, sy in { -0.5, 0.5 } do
					for _, sz in { -0.5, 0.5 } do
						local pt = (rel * CFrame.new(d.Size.X * sx, d.Size.Y * sy, d.Size.Z * sz)).Position
						lo, hi = lo:Min(pt), hi:Max(pt)
					end
				end
			end
		end
		if d:IsA("MeshPart") then
			local e = Expected.rest[d.Name]
			if e then
				local rel = hrp.CFrame:PointToObjectSpace(d:GetPivot().Position)
				local err = (rel - Vector3.new(e[1], e[2], e[3])).Magnitude
				if err > worst then
					worst, worstPart = err, d.Name
				end
			end
		end
	end
	r.extents = { min = lo, max = hi }
	local em, eM = Expected.restExtents.min, Expected.restExtents.max
	r.extentsExpected = { min = Vector3.new(em[1], em[2], em[3]), max = Vector3.new(eM[1], eM[2], eM[3]) }
	r.extentsErr = math.max((lo - r.extentsExpected.min).Magnitude, (hi - r.extentsExpected.max).Magnitude)
	r.pivotErrAtRest, r.pivotWorst = worst, worstPart
	r.expectedParts = 0
	for _ in data.parts do
		r.expectedParts += 1
	end
	return r
end

-- Play mode, server only: apply a clip pose to the Transforms from the tables and compare pivots with glTF forward kinematics at sample index idx (1..4).
function Checks.poseOnServer(model: Model, clip: string, idx: number)
	local row = expectedOf(model).samples[clip][idx]
	local driver = require(model.Runtime.Driver)
	local clipData = require(model.Runtime.Clips[clip])
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") then
			d.Transform = CFrame.identity
		end
	end
	for jn, tf in driver.samplePose(clipData, row.t) do
		local m = model:FindFirstChild(jn, true)
		if m and m:IsA("Motor6D") then
			m.Transform = tf
		end
	end
	RunService.Heartbeat:Wait()
	RunService.Heartbeat:Wait()
	local hrp = model.PrimaryPart :: BasePart
	local worst, worstPart = 0, ""
	for partName, p in row.pos do
		local part = model:FindFirstChild(partName)
		if part and part:IsA("BasePart") then
			local err = (hrp.CFrame:PointToObjectSpace(part:GetPivot().Position) - Vector3.new(p[1], p[2], p[3])).Magnitude
			if err ~= err then
				err = math.huge -- NaN must fail, never read as zero error
			end
			if err > worst then
				worst, worstPart = err, partName
			end
		end
	end
	return { clip = clip, t = row.t, maxErr = worst, worst = worstPart }
end

-- Server side of the multi-client pose test: freeze the clip at sample idx for every client and publish the expected positions.
function Checks.freeze(model: Model, clip: string, idx: number)
	local row = expectedOf(model).samples[clip][idx]
	model:SetAttribute("VW_Expect", HttpService:JSONEncode(row.pos))
	model:SetAttribute("VW_Clip", clip)
	model:SetAttribute("VW_ClipT0", workspace:GetServerTimeNow())
	model:SetAttribute("VW_Freeze", row.t)
	return row.t
end

function Checks.unfreeze(model: Model)
	model:SetAttribute("VW_Freeze", nil)
	model:SetAttribute("VW_Expect", nil)
end

Checks.expectedOf = expectedOf

return Checks
