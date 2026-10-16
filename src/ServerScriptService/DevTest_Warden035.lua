-- Studio location: ServerScriptService.DevTest_Warden035 (Script)
-- DevTest_Warden035  (035 roster) -- STUDIO-ONLY, ISOLATED playability test of the AI-generated Gatehouse Warden (15 rigid MeshParts on a hidden R15 rig).
-- Inert unless Studio started the session with StudioTestService and the argument "warden035" (1 client). Launch from Edit with
--   task.spawn(function() game:GetService("StudioTestService"):ExecuteMultiplayerTestAsync(1, "warden035") end)
-- Needs the owner's manual FBX import: ServerStorage.Imports035.GatehouseWarden (assets/export/035/warden/GatehouseWarden.fbx). Optional texture
-- ids (uploaded PNGs) as string attributes on that import: ColorMap, NormalMap, MetalnessMap, RoughnessMap -> a SurfaceAppearance per part.
-- It builds a hidden R15 proxy (from ServerStorage.NPCModels.MysteryNPC, with its OWN copy of the builder's re-proportion code, on the WARDEN joint
-- table written by tools/blender/ai/gw_parts.py) inside a throw-away folder far from the game, welds the imported parts like CreatureBuilder.makeKitParts
-- does, measures, and destroys everything. Never touches live workers, plots, saves, CreatureModels, CreatureSpecs (KIT_B1 stays false) or any game script.
-- Results: "@@TWARDEN|".
--   import   all 15 parts + anchor/axis markers, scale factor, model size
--   stand    HipHeight read at run time, feet-to-floor gap after settling
--   pad      the NPCPlacement formula (stationTop + HipHeight + root.Size.Y/2) puts the feet on the pad
--   idle     NPCAnimation idle: feet stay put, the arms really move (joint angles sampled)
--   walk     NPCAnimation walk: feet never sink, limbs swing, every mesh still follows its rig part
--   carry    the NPCCarry offset inputs (numbers only; the live carry path is not exercised) and a lying-down bounding box
--   preview  framing numbers for a reveal viewport (bounding box -> camera distance); the viewport itself is client-side and not rendered here
--   perf     MeshPart / texture memory and Heartbeat time for 1 and 20 copies (desktop Studio under Wine: NOT a phone measurement)

local RunService = game:GetService("RunService")
if not RunService:IsStudio() then
	return
end
local StudioTestService = game:GetService("StudioTestService")
local okArgs, args = pcall(function()
	return StudioTestService:GetTestArgs()
end)
if not (okArgs and args == "warden035") then
	return
end

local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local Stats = game:GetService("Stats")

local lines, passed, failed = {}, 0, 0
local section = "setup"
local function note(kind: string, name: string, detail: any?)
	local line = ("%s | %s: %s | %s"):format(kind, section, name, tostring(detail or ""))
	table.insert(lines, line)
	print("@@TWARDEN|" .. line)
end
local function expect(name: string, condition: any, detail: any?)
	if condition then
		passed += 1
	else
		failed += 1
		note("FAIL", name, detail)
	end
end
local function info(name: string, detail: any)
	note("INFO", name, detail)
end
local function finish(state: string)
	local summary = ("%s passed=%d failed=%d"):format(state, passed, failed)
	print("@@TWARDEN|SUMMARY " .. summary)
	StudioTestService:EndTest(summary .. "\n" .. table.concat(lines, "\n"))
end

local MODEL = "GatehouseWarden"
local GROUPS = {
	"Head",
	"UpperTorso",
	"LowerTorso",
	"LeftUpperArm",
	"LeftLowerArm",
	"LeftHand",
	"RightUpperArm",
	"RightLowerArm",
	"RightHand",
	"LeftUpperLeg",
	"LeftLowerLeg",
	"LeftFoot",
	"RightUpperLeg",
	"RightLowerLeg",
	"RightFoot",
}
-- joint heights above the ground, studs (tools/blender/ai/gw_parts.py -> warden_rig.json; model 6.4 studs tall incl. crest)
local WARDEN = {
	ankle = 0.48,
	knee = 1.216,
	hip = 1.824,
	waist = 2.464,
	shoulder_y = 4.096,
	neck = 4.2752,
	elbow = 2.88,
	wrist = 1.984,
	hand_end = 1.536,
	arm_x = 1.6,
	leg_x = 0.768,
	head_h = 1.28,
	foot_h = 0.48,
}

-- the same checks as CreatureBuilder.kitSource: scale from the 1-stud axis marker, axes must be +X right, +Y up, -Z front
local function kitSource(): (Instance?, number?, string?)
	local imports = ServerStorage:FindFirstChild("Imports035")
	local src = imports and imports:FindFirstChild(MODEL, true)
	if not src then
		return nil, nil, "ServerStorage.Imports035." .. MODEL .. " missing (manual FBX import not done)"
	end
	local anchor = src:FindFirstChild(MODEL .. "_Anchor", true) :: BasePart?
	local ax, ay, af =
		src:FindFirstChild(MODEL .. "_AxisX", true) :: BasePart?,
		src:FindFirstChild(MODEL .. "_AxisY", true) :: BasePart?,
		src:FindFirstChild(MODEL .. "_AxisFront", true) :: BasePart?
	if not (anchor and ax and ay and af) then
		return nil, nil, "import has no anchor / axis markers"
	end
	local dx = anchor.CFrame:PointToObjectSpace(ax.Position)
	local s = 1 / dx.Magnitude
	local dy, df = anchor.CFrame:PointToObjectSpace(ay.Position) * s, anchor.CFrame:PointToObjectSpace(af.Position) * s
	dx = dx * s
	if not (dx.X > 0.98 and dy.Y > 0.98 and df.Z < -0.98) then
		return nil, nil, ("wrong axes: right %s up %s front %s (want +X, +Y, -Z)"):format(tostring(dx), tostring(dy), tostring(df))
	end
	return src, s, nil
end

-- A copy of the builder's rig re-proportion (MysteryNPC -> noob-style blocks on the given joint heights). Blocks are hidden (the meshes are the look).
local function buildProxy(name: string, sk: any): (Model, CFrame)
	local model = (ServerStorage:WaitForChild("NPCModels"):WaitForChild("MysteryNPC") :: Model):Clone()
	model.Name = name
	for _, child in model:GetChildren() do
		if child:IsA("Accessory") or child:IsA("Clothing") or child:IsA("ShirtGraphic") or child:IsA("BodyColors") or child:IsA("HumanoidDescription") then
			child:Destroy()
		end
	end
	local joints = {}
	for _, d in model:GetDescendants() do
		if d:IsA("JointInstance") and d.Part0 and d.Part1 then
			table.insert(joints, { d, d.Part0.Name, d.Part1.Name })
		end
	end
	for _, old in model:GetChildren() do
		if old:IsA("MeshPart") and old.Name ~= "Head" and old.Name ~= "HumanoidRootPart" then
			local p = Instance.new("Part")
			p.Name, p.Size, p.CFrame = old.Name, old.Size, old.CFrame
			p.CanCollide, p.CanTouch, p.CanQuery, p.Massless, p.Anchored = old.CanCollide, old.CanTouch, old.CanQuery, old.Massless, old.Anchored
			for _, c in old:GetChildren() do
				if c:IsA("BaseWrap") or c:IsA("WrapTarget") then
					c:Destroy()
				else
					c.Parent = p
				end
			end
			p.Parent = model
			old:Destroy()
		end
	end
	for _, j in joints do
		local a, b = model:FindFirstChild(j[2]), model:FindFirstChild(j[3])
		if a and b then
			j[1].Part0, j[1].Part1 = a, b
		end
	end
	local function part(n: string): BasePart
		return model:FindFirstChild(n) :: BasePart
	end
	local lt, ut = part("LowerTorso"), part("UpperTorso")
	local ltC = lt.Position
	local sign = {} :: { [string]: number }
	for _, side in { "Left", "Right" } do
		sign[side] = if part(side .. "UpperArm").Position.X >= ut.Position.X then 1 else -1
	end
	local function put(n: string, size: Vector3, center: Vector3)
		local pt = part(n)
		pt.Size = size
		pt.CFrame = CFrame.new(center) * pt.CFrame.Rotation
	end
	local groundY = ltC.Y - (sk.hip + sk.waist) / 2
	local function Y(h: number): number
		return groundY + h
	end
	local utC = Vector3.new(ltC.X, Y((sk.waist + sk.neck) / 2), ltC.Z)
	local kitCF = CFrame.new(Vector3.new(ltC.X, groundY, ltC.Z)) * lt.CFrame.Rotation
	put("LowerTorso", Vector3.new(2, sk.waist - sk.hip, 1), Vector3.new(ltC.X, Y((sk.hip + sk.waist) / 2), ltC.Z))
	put("UpperTorso", Vector3.new(2, sk.neck - sk.waist, 1), utC)
	put("Head", Vector3.new(1.32 * sk.head_h / 1.2, sk.head_h, sk.head_h), Vector3.new(utC.X, Y(sk.neck + sk.head_h / 2), utC.Z))
	local joint = {} :: { [string]: Vector3 }
	joint.Waist = Vector3.new(utC.X, Y(sk.waist), utC.Z)
	joint.Neck = Vector3.new(utC.X, Y(sk.neck), utC.Z)
	for _, side in { "Left", "Right" } do
		local sx = utC.X + sign[side] * sk.arm_x
		local lx = utC.X + sign[side] * sk.leg_x
		put(side .. "UpperArm", Vector3.new(1, sk.neck - sk.elbow, 1), Vector3.new(sx, Y((sk.neck + sk.elbow) / 2), utC.Z))
		put(side .. "LowerArm", Vector3.new(1, sk.elbow - sk.wrist, 1), Vector3.new(sx, Y((sk.elbow + sk.wrist) / 2), utC.Z))
		put(side .. "Hand", Vector3.new(1, sk.wrist - sk.hand_end, 1), Vector3.new(sx, Y((sk.wrist + sk.hand_end) / 2), utC.Z))
		joint[side .. "Shoulder"] = Vector3.new(sx, Y(sk.shoulder_y), utC.Z)
		joint[side .. "Elbow"] = Vector3.new(sx, Y(sk.elbow), utC.Z)
		joint[side .. "Wrist"] = Vector3.new(sx, Y(sk.wrist), utC.Z)
		put(side .. "UpperLeg", Vector3.new(1, sk.hip - sk.knee, 1), Vector3.new(lx, Y((sk.hip + sk.knee) / 2), utC.Z))
		put(side .. "LowerLeg", Vector3.new(1, sk.knee - sk.ankle, 1), Vector3.new(lx, Y((sk.knee + sk.ankle) / 2), utC.Z))
		put(side .. "Foot", Vector3.new(1, sk.foot_h, 1.2), Vector3.new(lx, Y(sk.foot_h / 2), utC.Z - 0.1))
		joint[side .. "Hip"] = Vector3.new(lx, Y(sk.hip), utC.Z)
		joint[side .. "Knee"] = Vector3.new(lx, Y(sk.knee), utC.Z)
		joint[side .. "Ankle"] = Vector3.new(lx, Y(sk.ankle), utC.Z)
	end
	for _, c in model:GetDescendants() do
		if c:IsA("AnimationConstraint") and c.Attachment0 and c.Attachment1 then
			local at0, at1 = c.Attachment0, c.Attachment1
			local world = joint[c.Name]
			if c.Name == "Root" then
				world = at0.WorldPosition
			end
			if world then
				local p0, p1 = at0.Parent :: BasePart, at1.Parent :: BasePart
				at0.Position = p0.CFrame:PointToObjectSpace(world)
				at1.Position = p1.CFrame:PointToObjectSpace(world)
			end
		end
	end
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
			p.Transparency = 1
			p.CastShadow = false
		end
	end
	return model, kitCF
end

-- A copy of CreatureBuilder.makeKitParts without the palette / chain animation: every imported mesh welds to the rig part named like its group.
local function attachMeshes(model: Model, kitCF: CFrame, src: Instance, k: number, folder: Folder): number
	local anchor = src:FindFirstChild(MODEL .. "_Anchor", true) :: BasePart
	local tex = {
		ColorMap = src:GetAttribute("ColorMap"),
		NormalMap = src:GetAttribute("NormalMap"),
		MetalnessMap = src:GetAttribute("MetalnessMap"),
		RoughnessMap = src:GetAttribute("RoughnessMap"),
	}
	local n = 0
	for _, m in src:GetDescendants() do
		if not m:IsA("MeshPart") then
			continue
		end
		local group = m.Name:gsub("%.%d+$", ""):match("^" .. MODEL .. "_([^_]+)_.+$")
		if not (group and table.find(GROUPS, group)) then
			continue
		end
		local body = model:FindFirstChild(group)
		if not (body and body:IsA("BasePart")) then
			continue
		end
		local part = m:Clone()
		for _, c in part:GetChildren() do
			if not (c:IsA("SpecialMesh") or c:IsA("SurfaceAppearance")) then
				c:Destroy()
			end
		end
		part.Name = group .. "_Mesh"
		part.Size = m.Size * k
		part.CFrame = kitCF * CFrame.new(anchor.CFrame:PointToObjectSpace(m.Position) * k)
		part.Color = Color3.fromRGB(120, 128, 145)
		part.Material = Enum.Material.SmoothPlastic
		part.TextureID = ""
		part.Transparency = 0
		part.CanCollide, part.CanTouch, part.CanQuery, part.Massless, part.Anchored = false, false, false, true, false
		part.CastShadow = true
		part.RenderFidelity = Enum.RenderFidelity.Automatic
		if tex.ColorMap and not part:FindFirstChildOfClass("SurfaceAppearance") then
			local sa = Instance.new("SurfaceAppearance")
			sa.ColorMap = tostring(tex.ColorMap)
			sa.NormalMap = if tex.NormalMap then tostring(tex.NormalMap) else ""
			sa.MetalnessMap = if tex.MetalnessMap then tostring(tex.MetalnessMap) else ""
			sa.RoughnessMap = if tex.RoughnessMap then tostring(tex.RoughnessMap) else ""
			sa.Parent = part
		end
		local weld = Instance.new("Weld")
		weld.Part0, weld.Part1, weld.C0 = body :: BasePart, part, body.CFrame:ToObjectSpace(part.CFrame)
		weld.Parent = part
		part:SetAttribute("Group", group)
		part.Parent = folder
		n += 1
	end
	return n
end

local function lowest(model: Model): number -- the lowest visible part bottom (feet)
	local low = math.huge
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 1 and d.Name ~= "HumanoidRootPart" then
			low = math.min(low, d.Position.Y - d.Size.Y / 2)
		end
	end
	return low
end

local function angleBetween(a: CFrame, b: CFrame): number -- degrees between two orientations
	local _, angle = (a:ToObjectSpace(b)):ToAxisAngle()
	return math.deg(angle)
end

local folder = Instance.new("Folder")
folder.Name = "TestWarden035"
folder.Parent = workspace
local origin = Vector3.new(6200, 0, 6200)
local floorTop = 0
local floor = Instance.new("Part")
floor.Name = "Floor"
floor.Anchored = true
floor.Size = Vector3.new(400, 4, 400)
floor.Position = origin - Vector3.new(0, 2, 0)
floor.Parent = folder

local ok, err = pcall(function()
	section = "import"
	local src, k, why = kitSource()
	expect("imported model found with correct axes", src ~= nil, why)
	if not (src and k) then
		return
	end
	local meshes = {}
	for _, m in src:GetDescendants() do
		if m:IsA("MeshPart") then
			table.insert(meshes, m)
		end
	end
	info("import", ("scale factor k=%.4f, %d MeshParts (15 parts + 4 markers expected)"):format(k, #meshes))
	for _, g in GROUPS do
		expect("part present: " .. g, src:FindFirstChild(MODEL .. "_" .. g .. "_Atlas", true) ~= nil)
	end
	info(
		"textures",
		("ColorMap=%s NormalMap=%s MetalnessMap=%s RoughnessMap=%s"):format(
			tostring(src:GetAttribute("ColorMap")),
			tostring(src:GetAttribute("NormalMap")),
			tostring(src:GetAttribute("MetalnessMap")),
			tostring(src:GetAttribute("RoughnessMap"))
		)
	)

	section = "stand"
	local function spawnKnight(name: string, x: number, z: number): (Model, Folder)
		local proxy, kitCF = buildProxy(name, WARDEN)
		local visible = Instance.new("Folder")
		visible.Name = "Meshes"
		attachMeshes(proxy, kitCF, src, k, visible)
		visible.Parent = proxy
		proxy.Parent = folder
		local root = proxy:FindFirstChild("HumanoidRootPart") :: BasePart
		proxy:PivotTo(CFrame.new(origin + Vector3.new(x, 0, z)) * root.CFrame:ToObjectSpace(proxy:GetPivot()))
		proxy:PivotTo(proxy:GetPivot() + Vector3.new(0, 10 - root.Position.Y, 0))
		return proxy, visible
	end
	local knight = spawnKnight("Warden", 0, 0)
	task.wait(4)
	local hum = knight:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = knight:FindFirstChild("HumanoidRootPart") :: BasePart
	local gap = lowest(knight) - floorTop
	local _, size = knight:GetBoundingBox()
	info(
		"stand",
		("HipHeight=%.3f feet-to-floor gap=%.3f root Y=%.3f root.Size.Y=%.2f state=%s bbox=%s"):format(
			hum.HipHeight,
			gap,
			root.Position.Y,
			root.Size.Y,
			tostring(hum:GetState()),
			tostring(size)
		)
	)
	expect("model height between 5.8 and 7.0 studs", size.Y > 5.8 and size.Y < 7.0, size.Y)
	expect("knight stands on the floor (gap within 0.35)", math.abs(gap) < 0.35, gap)

	section = "pad"
	local station = Instance.new("Part")
	station.Name = "FakeStation"
	station.Anchored = true
	station.Size = Vector3.new(6, 1, 6)
	station.Position = origin + Vector3.new(0, 0.5, 40)
	station.Parent = folder
	root.Anchored = true
	local stationTop = station.Position.Y + station.Size.Y / 2
	knight:PivotTo(CFrame.new(Vector3.new(station.Position.X, stationTop + hum.HipHeight + root.Size.Y / 2, station.Position.Z)) * root.CFrame:ToObjectSpace(knight:GetPivot()))
	task.wait(0.3)
	local padGap = lowest(knight) - stationTop
	info("pad (NPCPlacement formula)", ("feet-to-pad gap=%.3f"):format(padGap))
	expect("feet on the pad within 0.4", math.abs(padGap) < 0.4, padGap)
	root.Anchored = false

	section = "idle"
	local NPCAnimation = require(ServerScriptService:WaitForChild("NPCAnimation")) :: any
	knight:PivotTo(CFrame.new(origin + Vector3.new(0, 8, -30)))
	task.wait(2)
	local okAttach, aerr = pcall(NPCAnimation.attach, knight)
	expect("NPCAnimation.attach works on the Warden rig", okAttach, aerr)
	local ut = knight:FindFirstChild("UpperTorso") :: BasePart
	local rua = knight:FindFirstChild("RightUpperArm") :: BasePart
	local idleMin, idleMax, idleFeetMin, idleFeetMax = math.huge, -math.huge, math.huge, -math.huge
	for _ = 1, 30 do
		task.wait(0.1)
		local a = angleBetween(ut.CFrame, rua.CFrame)
		idleMin, idleMax = math.min(idleMin, a), math.max(idleMax, a)
		local g = lowest(knight) - floorTop
		idleFeetMin, idleFeetMax = math.min(idleFeetMin, g), math.max(idleFeetMax, g)
	end
	info("idle", ("RightUpperArm angle to torso %.1f..%.1f deg; feet gap %.3f..%.3f"):format(idleMin, idleMax, idleFeetMin, idleFeetMax))
	expect("idle keeps the feet on the floor (|gap| < 0.35)", math.abs(idleFeetMin) < 0.35 and math.abs(idleFeetMax) < 0.35, ("%.3f..%.3f"):format(idleFeetMin, idleFeetMax))

	section = "walk"
	hum.WalkSpeed = 12
	local rootK = knight:FindFirstChild("HumanoidRootPart") :: BasePart
	hum:MoveTo(rootK.Position + Vector3.new(40, 0, 0))
	local minGap, maxGap, armMin, armMax, legMin, legMax, airborne, samples = math.huge, -math.huge, math.huge, -math.huge, math.huge, -math.huge, 0, 0
	local lul = knight:FindFirstChild("LeftUpperLeg") :: BasePart
	local worstMeshDrift = 0
	for _ = 1, 40 do
		task.wait(0.1)
		local g = lowest(knight) - floorTop
		minGap, maxGap, samples = math.min(minGap, g), math.max(maxGap, g), samples + 1
		local a = angleBetween(ut.CFrame, rua.CFrame)
		armMin, armMax = math.min(armMin, a), math.max(armMax, a)
		local l = angleBetween(ut.CFrame, lul.CFrame)
		legMin, legMax = math.min(legMin, l), math.max(legMax, l)
		if hum.FloorMaterial == Enum.Material.Air then
			airborne += 1
		end
		-- every mesh must still sit exactly where its weld says relative to its rig part
		for _, m in (knight:FindFirstChild("Meshes") :: Folder):GetChildren() do
			local w = m:FindFirstChildOfClass("Weld")
			if w and w.Part0 then
				local want = w.Part0.CFrame * w.C0
				worstMeshDrift = math.max(worstMeshDrift, ((m :: BasePart).Position - want.Position).Magnitude)
			end
		end
	end
	info(
		"walk",
		("feet gap %.3f..%.3f over %d samples, airborne %d, speed %.1f; arm swing %.1f..%.1f deg, leg swing %.1f..%.1f deg; worst mesh-to-rig drift %.4f"):format(
			minGap,
			maxGap,
			samples,
			airborne,
			rootK.AssemblyLinearVelocity.Magnitude,
			armMin,
			armMax,
			legMin,
			legMax,
			worstMeshDrift
		)
	)
	expect("walking feet never sink below the floor (min gap > -0.35)", minGap > -0.35, minGap)
	expect("walking feet stay near the floor (max gap < 1.6)", maxGap < 1.6, maxGap)
	expect("the arm really swings (> 10 deg range)", armMax - armMin > 10, armMax - armMin)
	expect("the leg really swings (> 10 deg range)", legMax - legMin > 10, legMax - legMin)
	expect("meshes follow their rig parts (drift < 0.05)", worstMeshDrift < 0.05, worstMeshDrift)

	section = "carry"
	local _, bb = knight:GetBoundingBox()
	info(
		"carry inputs",
		("UpperTorso.Size=%s half depth=%.2f bounding box=%s; carried length=%.2f studs (existing range: Golden Paladin 6.5, boss cap 1.3x)"):format(
			tostring(ut.Size),
			ut.Size.Z / 2,
			tostring(bb),
			bb.Y * 0.95
		)
	)
	-- lying across a carrier's shoulder: rotate the whole model 90 degrees about Z and check how far it sticks out
	local pivot = knight:GetPivot()
	knight:PivotTo(pivot * CFrame.Angles(0, 0, math.rad(90)))
	local _, lying = knight:GetBoundingBox()
	info("carry lying down", ("bounding box when carried across the shoulder: %s"):format(tostring(lying)))
	knight:PivotTo(pivot)

	section = "preview"
	local _, pb = knight:GetBoundingBox()
	local fov = 35
	local dist = (math.max(pb.X, pb.Y) / 2) / math.tan(math.rad(fov / 2)) * 1.15
	info(
		"reveal preview framing",
		("bbox %s -> camera distance %.1f studs at FOV %d (WorkerPreview.frame fits any bounding box, so no code change needed)"):format(tostring(pb), dist, fov)
	)
	expect("preview bounding box is finite and sane", pb.Y > 5 and pb.X > 2 and pb.X < 8, tostring(pb))

	section = "perf"
	local function sample(label: string)
		local dts, n = 0, 0
		local conn = RunService.Heartbeat:Connect(function(dt)
			dts += dt
			n += 1
		end)
		task.wait(3)
		conn:Disconnect()
		local meshMb, texMb = -1, -1
		pcall(function()
			meshMb = Stats:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.GraphicsMeshParts)
			texMb = Stats:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.GraphicsTexture)
		end)
		info(
			"perf " .. label,
			("avg Heartbeat %.2f ms over %d frames; GraphicsMeshParts %.1f MB; GraphicsTexture %.1f MB"):format(if n > 0 then dts / n * 1000 else -1, n, meshMb, texMb)
		)
	end
	sample("1 knight")
	local extra = {}
	for i = 1, 19 do
		local m = spawnKnight("WardenExtra" .. i, -60 + (i % 10) * 12, 60 + math.floor(i / 10) * 14)
		local r = m:FindFirstChild("HumanoidRootPart") :: BasePart
		r.Anchored = true
		table.insert(extra, m)
	end
	task.wait(1)
	sample("20 knights (19 anchored)")
	for _, m in extra do
		m:Destroy()
	end
end)
if not ok then
	failed += 1
	note("ERROR", "test stopped", err)
end
folder:Destroy()
finish(if failed == 0 then "PASS" else "FAIL")
