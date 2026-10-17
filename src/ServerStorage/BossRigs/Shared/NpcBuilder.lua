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

function NpcBuilder.build(charName: string, imported: Instance)
	local charRoot = ROOT:WaitForChild(charName)
	local shared = ROOT:WaitForChild("Shared")
	local data = require(charRoot.Data) :: any
	local assets = require(charRoot.Assets) :: any
	local report = { errors = {} :: { string }, parts = 0, tris = 0, maxRotation = 0, sizeRatio = {} :: { [string]: number }, textures = false }

	-- 1. every part is there, in the right size (Import 3D with file units = studs) and the right place relative to the torso
	local src: { [string]: BasePart } = {}
	for name in data.parts do
		local p = find(imported, name)
		if p then
			src[name] = p
		else
			table.insert(report.errors, "missing imported part " .. name)
		end
	end
	if #report.errors == 0 then
		local torso = src.Torso
		local t0 = Vector3.new(table.unpack(data.parts.Torso.center))
		for name, info in data.parts do
			local want = Vector3.new(table.unpack(info.size))
			local ratio = src[name].Size.Magnitude / want.Magnitude
			report.sizeRatio[name] = ratio
			if math.abs(ratio - 1) > 0.03 then
				table.insert(report.errors, ("%s is x%.3f of its expected size (Import 3D units must be studs)"):format(name, ratio))
			end
			local off = (src[name].Position - torso.Position) - (Vector3.new(table.unpack(info.center)) - t0)
			if off.Magnitude > 0.25 then
				table.insert(report.errors, ("%s is %.2f studs from its expected place (the importer moved or rotated it)"):format(name, off.Magnitude))
			end
			local rx, ry, rz = src[name].CFrame:ToOrientation()
			report.maxRotation = math.max(report.maxRotation, math.abs(math.deg(rx)), math.abs(math.deg(ry)), math.abs(math.deg(rz)))
		end
	end
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
	for name, info in data.parts do
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
		part.CFrame = CFrame.new(Vector3.new(table.unpack(info.center)))
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
		m.C0, m.C1 = cf(j.c0), cf(j.c1)
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
