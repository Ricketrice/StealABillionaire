-- Studio location: ServerStorage.VaultWizardTest.Builder (ModuleScript)
-- Builder: assembles the Vault wizard from the meshes the owner imported with Import 3D (tools/blender/vault -> assets/export/vault/VaultWizard.fbx).
-- Run in Edit mode through the MCP / command bar:
--   local B = require(game.ServerStorage.VaultWizardTest.Builder)
--   local report = B.build(game.ServerStorage.VaultWizardTest.Imported:FindFirstChildWhichIsA("Model"))
-- Nothing here touches gameplay: the result is a Model in ServerStorage.VaultWizardTest.Template (never in the Workspace until the test Harness clones it).
-- Method: the converter wrote joint frames in the AUTHORED frame (translation-only part frames at the joints, studs, Roblox axes). Import 3D keeps the FBX rest layout, so
-- for each imported MeshPart the offset between its CFrame and its authored frame is measured against the imported "Anchor" marker ("pivot"), checked against the
-- three axis markers, and Motor6D.C0/C1 are built as pivot * C0_authored. Part1.CFrame = Part0.CFrame * C0 * Transform * C1^-1 then reproduces the converter's chain.

local ServerStorage = game:GetService("ServerStorage")

local Builder = {}

local ROOT = ServerStorage:WaitForChild("VaultWizardTest")

local function cf(t: { number }): CFrame
	return CFrame.new(t[1], t[2], t[3], t[4], t[5], t[6], t[7], t[8], t[9], t[10], t[11], t[12])
end

-- Import 3D may append ".001" to the mesh names (seen on the first import): accept both spellings.
local function find(container: Instance, name: string): BasePart?
	local f = container:FindFirstChild(name, true) or container:FindFirstChild(name .. ".001", true)
	return if f and f:IsA("BasePart") then f else nil
end

-- imported: the Model (or Folder) produced by Import 3D. Returns the assembled Model and a report table.
function Builder.build(imported: Instance, opts: { assets: { [string]: string }?, name: string? }?)
	local options = opts or {}
	local data = require(ROOT.RuntimeSrc.VaultData)
	local assets = options.assets or require(ROOT.RuntimeSrc.Assets)
	local report = { errors = {} :: { string }, parts = 0, pivots = {} :: { [string]: Vector3 } }

	-- 1. calibrate against the markers
	local anchor = find(imported, "VaultWizard_Anchor")
	local ax, ay, af = find(imported, "VaultWizard_AxisX"), find(imported, "VaultWizard_AxisY"), find(imported, "VaultWizard_AxisFront")
	if not (anchor and ax and ay and af) then
		error("Builder: the import has no VaultWizard_Anchor / AxisX / AxisY / AxisFront markers")
	end
	local anchorCF = anchor.CFrame
	local function off(p: BasePart): Vector3
		return anchorCF:PointToObjectSpace(p.Position)
	end
	local ex, ey, ef = off(ax), off(ay), off(af)
	report.axes = { x = ex, y = ey, front = ef }
	local function near(v: Vector3, w: Vector3): boolean
		return (v - w).Magnitude < 0.05
	end
	if not (near(ex, Vector3.new(2, 0, 0)) and near(ey, Vector3.new(0, 2, 0)) and near(ef, Vector3.new(0, 0, -2))) then
		table.insert(report.errors, ("axis markers off: x=%s y=%s front=%s (expected 2,0,0 / 0,2,0 / 0,0,-2)"):format(tostring(ex), tostring(ey), tostring(ef)))
	end

	-- 2. authored rest frames by forward kinematics at rest (Transform = identity)
	local frames: { [string]: CFrame } = { HumanoidRootPart = cf(data.hrpFrame) }
	for _, jn in data.order do
		local j = data.joints[jn]
		frames[j.p1] = frames[j.p0] * cf(j.c0) * cf(j.c1):Inverse()
	end
	for _, w in data.welds do
		frames[w.p1] = frames[w.p0] * cf(w.c0) * cf(w.c1):Inverse()
	end

	-- 3. parts
	local model = Instance.new("Model")
	model.Name = options.name or "VaultWizard"
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local hrp = Instance.new("Part")
	hrp.Name = "HumanoidRootPart"
	hrp.Size = Vector3.new(2, 2, 1)
	hrp.Transparency = 1
	hrp.CanCollide = false
	hrp.CanQuery = false
	hrp.CanTouch = false
	hrp.Anchored = true
	hrp.CFrame = frames.HumanoidRootPart
	hrp.Parent = model
	model.PrimaryPart = hrp

	local pivots: { [string]: CFrame } = { HumanoidRootPart = CFrame.identity }
	local built: { [string]: MeshPart } = {}
	for name, info in data.parts do
		local src = find(imported, name)
		if not src or not src:IsA("MeshPart") then
			table.insert(report.errors, "missing imported MeshPart " .. name)
			continue
		end
		local part = src:Clone()
		part.Name = name -- drop Import 3D's ".001" suffix
		for _, c in part:GetChildren() do
			c:Destroy()
		end
		part.Anchored = false
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Massless = true
		part.CastShadow = true
		part.CollisionFidelity = Enum.CollisionFidelity.Box
		part.TextureID = ""
		if info.neon then
			part.Material = Enum.Material.Neon
			part.Color = Color3.new(data.neonColor[1], data.neonColor[2], data.neonColor[3])
		else
			part.Material = Enum.Material.SmoothPlastic
			part.Color = Color3.new(1, 1, 1)
			local sa = Instance.new("SurfaceAppearance")
			sa.ColorMap = assets.Color
			sa.MetalnessMap = assets.Metalness
			sa.RoughnessMap = assets.Roughness
			sa.Parent = part
		end
		-- authored frame in the imported part's own space (against the anchor): the part's "pivot"
		pivots[name] = src.CFrame:ToObjectSpace(anchorCF * frames[name])
		part.PivotOffset = pivots[name]
		report.pivots[name] = pivots[name].Position
		part.Parent = model
		built[name] = part
		report.parts += 1
	end

	-- 4. joints in parent-first order, positioned by the same chain
	local function place(p0name: string, p1name: string, c0: { number }, c1: { number })
		local p0 = if p0name == "HumanoidRootPart" then hrp else built[p0name]
		local p1 = built[p1name]
		if not (p0 and p1) then
			return nil
		end
		local C0, C1 = pivots[p0name] * cf(c0), pivots[p1name] * cf(c1)
		p1.CFrame = p0.CFrame * C0 * C1:Inverse()
		return p0, p1, C0, C1
	end
	for _, jn in data.order do
		local j = data.joints[jn]
		local p0, p1, C0, C1 = place(j.p0, j.p1, j.c0, j.c1)
		if p0 then
			local m = Instance.new("Motor6D")
			m.Name = jn
			m.Part0, m.Part1, m.C0, m.C1 = p0, p1, C0, C1
			m.Parent = p1
		end
	end
	for _, w in data.welds do
		local p0, p1, C0, C1 = place(w.p0, w.p1, w.c0, w.c1)
		if p0 then
			local weld = Instance.new("Weld")
			weld.Name = "NeonTrim"
			weld.Part0, weld.Part1, weld.C0, weld.C1 = p0, p1, C0, C1
			weld.Parent = p1
		end
	end

	-- 5. attachments for the effects (authored FX nodes), parented to the part the node hangs from
	for fxName, fx in data.fx do
		local parent = if fx.parent == "HumanoidRootPart" then hrp else built[fx.parent]
		if parent then
			local a = Instance.new("Attachment")
			a.Name = fxName
			a.CFrame = pivots[fx.parent] * cf(fx.localFrame)
			a.Parent = parent
		end
	end

	-- 6. runtime: scripts travel inside the model (nothing is installed anywhere else), the client Script runs on every client
	local runtime = Instance.new("Folder")
	runtime.Name = "Runtime"
	for _, name in { "VaultData", "Assets", "Driver", "Vfx", "Probe" } do
		ROOT.RuntimeSrc[name]:Clone().Parent = runtime
	end
	ROOT.RuntimeSrc.Clips:Clone().Parent = runtime
	runtime.Parent = model
	local client = ROOT.RuntimeSrc.Client:Clone()
	client.RunContext = Enum.RunContext.Client
	client.Parent = model

	-- 7. an AnimationController + Animator for the standard-Animator comparison test (not used by the code-driven path)
	local ctrl = Instance.new("AnimationController")
	ctrl.Name = "AnimationController"
	Instance.new("Animator").Parent = ctrl
	ctrl.Parent = model

	model:SetAttribute("VW_Version", 1)
	model:SetAttribute("VW_Base", "Idle")
	report.model = model
	return model, report
end

return Builder
