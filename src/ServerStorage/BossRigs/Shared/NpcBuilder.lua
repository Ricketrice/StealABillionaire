-- Studio location: ServerStorage.BossRigs.Shared.NpcBuilder (ModuleScript)
-- NpcBuilder: assembles a Knight's Keep NPC (Peasant, Squire, Guard, Archer, Crusader; R6 part names) from the meshes the owner imported with Import 3D from <Name>_R6.glb.
-- Data / Clips / Assets come from tools/keep_rigs.py (the owner's exported SPEC). Run in Edit mode:
--   local B = require(game.ServerStorage.BossRigs.Shared.NpcBuilder)
--   local model, report = B.build("Crusader", game.ServerStorage.BossRigs.Crusader.Imported:FindFirstChildWhichIsA("Model"))
-- The result goes to ServerStorage.BossRigs.<Name>.Template (named "Template"); the game attaches it exactly like a boss rig (CreatureBuilder.attachBossRig, client BossRigs.Shared.Client).
-- Same method as the owner's <Name>_BuildNPC.lua (find the parts by name, check scale and layout, rest frames from the SPEC, Motor6D from the SPEC joints), but: no Humanoid / controller
-- (the creature's hidden R15 body walks it), clips run through Shared.Driver (Motor6D.Transform) instead of KeyframeSequences, parts never collide, the report lists what it found.

local ServerStorage = game:GetService("ServerStorage")

local NpcBuilder = {}

local ROOT = ServerStorage:WaitForChild("BossRigs")

local function cf(t: { number }): CFrame
	return CFrame.new(t[1], t[2], t[3], t[4], t[5], t[6], t[7], t[8], t[9], t[10], t[11], t[12])
end

local function find(container: Instance, name: string): BasePart?
	local f = container:FindFirstChild(name, true) or container:FindFirstChild(name .. ".001", true)
	return if f and f:IsA("BasePart") then f else nil
end

-- Import 3D drops the rotation of a GLB node and keeps the mesh upright (only Crusader has two): { degrees about X, pivot as a Y offset from the part centre }.
-- Read from Crusader_R6.glb: Longsword node -90 deg (grip at the node origin, 1.973 below the mesh centre), Cape node -6.9 deg (hung from its top edge, 2.068 above the centre).
local NODE_ROT_X: { [string]: { [string]: { number } } } = {
	Crusader = { Longsword = { -90, -1.973 }, Cape = { -6.876, 2.068 } },
}

function NpcBuilder.build(charName: string, imported: Instance)
	local charRoot = ROOT:WaitForChild(charName)
	local shared = ROOT:WaitForChild("Shared")
	local data = require(charRoot.Data) :: any
	local assets = require(charRoot.Assets) :: any
	local report = {
		errors = {} :: { string },
		parts = 0,
		tris = 0,
		maxRotation = 0,
		sizeRatio = {} :: { [string]: number },
		moved = {} :: { [string]: number },
		flipped = false,
		textures = false,
	}

	-- 1. every part is there, in the right size (Import 3D with file units = studs) and the right place relative to the torso.
	-- Import 3D turns the whole model half a turn about Y (X and Z of every offset are negated, the meshes are turned with it): `flipped` undoes it.
	-- A part whose pose differs from the SPEC (Crusader's sword is upright in the GLB, forward in the SPEC) keeps the GLB pose: listed in report.moved, its joint C1 is derived below.
	local src: { [string]: BasePart } = {}
	for name in data.parts do
		local p = find(imported, name)
		if p then
			src[name] = p
		else
			table.insert(report.errors, "missing imported part " .. name)
		end
	end
	local t0 = Vector3.new(table.unpack(data.parts.Torso.center))
	local flipped = false
	local target: { [string]: Vector3 } = {}
	local rotX: { [string]: number } = {}
	if #report.errors == 0 then
		local torso = src.Torso
		local plainErr, flipErr = 0, 0
		for name, info in data.parts do
			local want = Vector3.new(table.unpack(info.center)) - t0
			local rel = src[name].Position - torso.Position
			plainErr += (rel - want).Magnitude
			flipErr += (Vector3.new(-rel.X, rel.Y, -rel.Z) - want).Magnitude
		end
		flipped = flipErr < plainErr
		for name, info in data.parts do
			local want = Vector3.new(table.unpack(info.size))
			local ratio = src[name].Size.Magnitude / want.Magnitude
			report.sizeRatio[name] = ratio
			if math.abs(ratio - 1) > 0.03 then
				table.insert(report.errors, ("%s is x%.3f of its expected size (Import 3D units must be studs)"):format(name, ratio))
			end
			local rel = src[name].Position - torso.Position
			if flipped then
				rel = Vector3.new(-rel.X, rel.Y, -rel.Z)
			end
			target[name] = t0 + rel
			local nr = NODE_ROT_X[charName] and NODE_ROT_X[charName][name]
			if nr then
				rotX[name] = math.rad(nr[1])
				local pivot = Vector3.new(0, nr[2], 0)
				target[name] = target[name] + pivot - CFrame.Angles(rotX[name], 0, 0):VectorToWorldSpace(pivot)
			end
			local off = (target[name] - Vector3.new(table.unpack(info.center))).Magnitude
			if off > 0.25 then
				report.moved[name] = off
				if off > 4 then
					table.insert(report.errors, ("%s is %.2f studs from its expected place (the importer moved or rotated it)"):format(name, off))
				end
			end
			local rx, ry, rz = src[name].CFrame:ToOrientation()
			report.maxRotation = math.max(report.maxRotation, math.abs(math.deg(rx)), math.abs(math.deg(ry)), math.abs(math.deg(rz)))
		end
	end
	report.flipped = flipped
	if #report.errors > 0 then
		return nil, report
	end

	-- 2. the model: feet on y = 0, root at hrpFrame (like the boss Template: the HumanoidRootPart is anchored here, attachBossRig un-anchors and welds it)
	local model = Instance.new("Model")
	model.Name = data.prefix
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local hrp = Instance.new("Part")
	hrp.Name = "HumanoidRootPart"
	hrp.Size = Vector3.new(table.unpack(data.hrpSize))
	hrp.Transparency = 1
	hrp.CanCollide, hrp.CanQuery, hrp.CanTouch = false, false, false
	hrp.Anchored = true
	hrp.CFrame = cf(data.hrpFrame)
	hrp.Parent = model
	model.PrimaryPart = hrp

	local built: { [string]: BasePart } = { HumanoidRootPart = hrp }
	for name in data.parts do
		local part = src[name]:Clone()
		part.Name = name
		for _, c in part:GetChildren() do
			c:Destroy()
		end
		part.Anchored = false
		part.CanCollide, part.CanQuery, part.CanTouch = false, false, false
		part.Massless = true
		part.CastShadow = true
		part.CollisionFidelity = Enum.CollisionFidelity.Box
		part.TextureID = ""
		part.CFrame = CFrame.new(target[name]) * CFrame.Angles(rotX[name] or 0, 0, 0) * (if flipped then CFrame.Angles(0, math.pi, 0) else CFrame.identity)
		part.Material = Enum.Material.SmoothPlastic
		part.Color = Color3.new(1, 1, 1)
		local sa = Instance.new("SurfaceAppearance") -- the owner's exported maps (Color / Metalness / Roughness), uploaded by the MCP
		if assets.Color then
			sa.ColorMap = assets.Color
			sa.MetalnessMap = assets.Metalness or ""
			sa.RoughnessMap = assets.Roughness or ""
			sa.Parent = part
			report.textures = true
		else
			sa:Destroy()
			for _, old in src[name]:GetChildren() do -- no uploaded ids: keep whatever material Import 3D made
				if old:IsA("SurfaceAppearance") then
					old:Clone().Parent = part
					report.textures = true
				end
			end
		end
		part.Parent = model
		built[name] = part
		report.parts += 1
	end

	-- 3. joints (Motor6D under Part1, rest frames exactly as exported)
	for _, jn in data.order do
		local j = data.joints[jn]
		local m = Instance.new("Motor6D")
		m.Name = jn
		m.Part0, m.Part1 = built[j.p0], built[j.p1]
		m.C0 = cf(j.c0)
		m.C1 = m.Part1.CFrame:Inverse() * m.Part0.CFrame * m.C0 -- rest = the pose the parts were built in (the SPEC c1 when nothing was turned or moved)
		m.Parent = built[j.p1]
	end

	-- 4. runtime: the scripts travel inside the model (as for the boss rigs), the client Script runs on every client
	local runtime = Instance.new("Folder")
	runtime.Name = "Runtime"
	for _, mod in { charRoot.Data, charRoot.Assets, shared.Driver } do
		mod:Clone().Parent = runtime
	end
	local vfx = shared.NullVfx:Clone()
	vfx.Name = "Vfx"
	vfx.Parent = runtime
	charRoot.Clips:Clone().Parent = runtime
	runtime.Parent = model
	local client = shared.Client:Clone()
	client.RunContext = Enum.RunContext.Client
	client.Parent = model

	model:SetAttribute("BossRig", charName)
	model:SetAttribute("VW_Version", 1)
	model:SetAttribute("VW_Base", "Idle")
	report.model = model
	return model, report
end

return NpcBuilder
