-- Studio location: ServerScriptService.DevTest_HeroRig035 (Script)
-- DevTest_HeroRig035  (035 roster) -- STUDIO-ONLY, ISOLATED compatibility test of the heroic hidden rig (HERO: legs 2.75 studs, ~6.5 tall).
-- Inert unless Studio started the session with StudioTestService and the argument "hero035" (1 client). Launch from Edit with
--   task.spawn(function() game:GetService("StudioTestService"):ExecuteMultiplayerTestAsync(1, "hero035") end)
-- It builds a NOOB control rig and a HERO proxy rig (plain blocks, from ServerStorage.NPCModels.MysteryNPC, with its OWN copy of the builder's
-- re-proportion code) inside a throw-away folder far from the game, measures them, and destroys everything. It never touches live workers, plots,
-- saves, CreatureModels or any game script. Results: "@@THERO|".
--   stand     HipHeight as read at run time, feet-to-floor gap after settling (noob vs hero)
--   pad       the NPCPlacement formula (stationTop + HipHeight + root.Size.Y/2) puts the feet on the pad
--   walk      NPCAnimation walk + idle on the hero rig: feet stay on the floor (no sinking, no skating through)
--   scale     ScaleTo 0.95 / 1.3 (CreatureScaler path) keeps the feet on the floor
--   carry     the NPCCarry offset inputs and the carried length (numbers only; the live carry path is not exercised here)

local RunService = game:GetService("RunService")
if not RunService:IsStudio() then
	return
end
local StudioTestService = game:GetService("StudioTestService")
local okArgs, args = pcall(function()
	return StudioTestService:GetTestArgs()
end)
if not (okArgs and args == "hero035") then
	return
end

local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local lines, passed, failed = {}, 0, 0
local section = "setup"
local function note(kind: string, name: string, detail: any?)
	local line = ("%s | %s: %s | %s"):format(kind, section, name, tostring(detail or ""))
	table.insert(lines, line)
	print("@@THERO|" .. line)
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
	print("@@THERO|SUMMARY " .. summary)
	StudioTestService:EndTest(summary .. "\n" .. table.concat(lines, "\n"))
end

-- joint heights above the ground (same table as CreatureBuilder.RIG_NOOB / body.HERO in Blender)
local RIGS = {
	noob = {
		ankle = 0.35,
		knee = 1.1,
		hip = 2.0,
		waist = 2.4,
		shoulder_y = 3.7,
		neck = 4.0,
		elbow = 3.1,
		wrist = 2.3,
		hand_end = 2.0,
		arm_x = 1.5,
		leg_x = 0.5,
		head_h = 1.2,
		foot_h = 0.35,
	},
	hero = {
		ankle = 0.4,
		knee = 1.55,
		hip = 2.75,
		waist = 3.1,
		shoulder_y = 4.4,
		neck = 4.7,
		elbow = 3.5,
		wrist = 2.6,
		hand_end = 2.2,
		arm_x = 1.68,
		leg_x = 0.5,
		head_h = 1.3,
		foot_h = 0.4,
	},
}

-- A copy of the builder's rig re-proportion (MysteryNPC -> noob-style blocks on the given joint heights), blocks visible and coloured.
local function buildProxy(name: string, sk: any, color: Color3): Model
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
			p.Color = color
			p.Material = Enum.Material.SmoothPlastic
		end
	end
	return model
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

local floorTop = 0
local folder = Instance.new("Folder")
folder.Name = "TestHeroRig035"
folder.Parent = workspace
local origin = Vector3.new(6000, 0, 6000)
local floor = Instance.new("Part")
floor.Name = "Floor"
floor.Anchored = true
floor.Size = Vector3.new(400, 4, 400)
floor.Position = origin - Vector3.new(0, 2, 0) -- top at y = 0
floor.Parent = folder

local function stand(name: string, sk: any, color: Color3, x: number): Model
	local m = buildProxy(name, sk, color)
	m.Parent = folder
	local root = m:FindFirstChild("HumanoidRootPart") :: BasePart
	m:PivotTo(CFrame.new(origin + Vector3.new(x, 0, 0)) * root.CFrame:ToObjectSpace(m:GetPivot()))
	-- put the root where the engine should stand it: well above the floor, then let it fall and settle
	local lift = 12 - (root.Position.Y - 0)
	m:PivotTo(m:GetPivot() + Vector3.new(0, lift, 0))
	return m
end

local ok, err = pcall(function()
	section = "stand"
	local noob, hero = stand("ProxyNoob", RIGS.noob, Color3.fromRGB(245, 205, 48), -10), stand("ProxyHero", RIGS.hero, Color3.fromRGB(120, 130, 150), 10)
	task.wait(4)
	local out = {}
	for _, m in { noob, hero } do
		local h = m:FindFirstChildOfClass("Humanoid") :: Humanoid
		local root = m:FindFirstChild("HumanoidRootPart") :: BasePart
		local gap = lowest(m) - floorTop
		out[m.Name] = { hip = h.HipHeight, gap = gap, rootY = root.Position.Y - floorTop, state = h:GetState() }
		info(
			m.Name,
			("HipHeight=%.3f  feet-to-floor gap=%.3f  root Y above floor=%.3f  root.Size.Y=%.2f  state=%s"):format(
				h.HipHeight,
				gap,
				root.Position.Y - floorTop,
				root.Size.Y,
				tostring(h:GetState())
			)
		)
	end
	expect("control (noob rig) stands on the floor (gap within 0.35)", math.abs(out.ProxyNoob.gap) < 0.35, out.ProxyNoob.gap)
	expect("HERO rig stands on the floor (gap within 0.35)", math.abs(out.ProxyHero.gap) < 0.35, out.ProxyHero.gap)
	info("HipHeight change noob -> hero (expected ~ +0.75 if the engine follows the legs)", out.ProxyHero.hip - out.ProxyNoob.hip)

	section = "pad"
	local station = Instance.new("Part")
	station.Name = "FakeStation"
	station.Anchored = true
	station.Size = Vector3.new(6, 1, 6)
	station.Position = origin + Vector3.new(0, 0.5, 40) -- top at y = 1
	station.Parent = folder
	for _, m in { noob, hero } do
		local h = m:FindFirstChildOfClass("Humanoid") :: Humanoid
		local root = m:FindFirstChild("HumanoidRootPart") :: BasePart
		root.Anchored = true
		local stationTop = station.Position.Y + station.Size.Y / 2
		local position = Vector3.new(station.Position.X, stationTop + h.HipHeight + root.Size.Y / 2, station.Position.Z) -- NPCPlacement.placeOnStation
		m:PivotTo(CFrame.new(position) * root.CFrame:ToObjectSpace(m:GetPivot()))
		task.wait(0.3)
		local gap = lowest(m) - stationTop
		info(m.Name .. " on the pad (NPCPlacement formula)", ("feet-to-pad gap=%.3f"):format(gap))
		expect(m.Name .. " feet on the pad within 0.4", math.abs(gap) < 0.4, gap)
		root.Anchored = false
	end

	section = "walk"
	local NPCAnimation = require(ServerScriptService:WaitForChild("NPCAnimation")) :: any
	local hh = hero:FindFirstChildOfClass("Humanoid") :: Humanoid
	hero:PivotTo(CFrame.new(origin + Vector3.new(10, 8, -30)))
	task.wait(2)
	local okAttach, aerr = pcall(NPCAnimation.attach, hero)
	expect("NPCAnimation.attach works on the hero rig", okAttach, aerr)
	hh.WalkSpeed = 12
	local rootH = hero:FindFirstChild("HumanoidRootPart") :: BasePart
	hh:MoveTo(rootH.Position + Vector3.new(40, 0, 0))
	local minGap, maxGap, samples, airborne = math.huge, -math.huge, 0, 0
	for _ = 1, 40 do
		task.wait(0.1)
		local g = lowest(hero) - floorTop
		minGap, maxGap, samples = math.min(minGap, g), math.max(maxGap, g), samples + 1
		if hh.FloorMaterial == Enum.Material.Air then
			airborne += 1
		end
	end
	info("hero walking", ("feet gap min=%.3f max=%.3f over %d samples, airborne %d, speed %.1f"):format(minGap, maxGap, samples, airborne, rootH.AssemblyLinearVelocity.Magnitude))
	expect("walking feet never sink below the floor (min gap > -0.35)", minGap > -0.35, minGap)
	expect("walking feet stay near the floor (max gap < 1.6)", maxGap < 1.6, maxGap)
	task.wait(1.5)
	local idleGap = lowest(hero) - floorTop
	info("hero idle after the walk", ("feet gap=%.3f"):format(idleGap))
	expect("idle feet on the floor (within 0.35)", math.abs(idleGap) < 0.35, idleGap)

	section = "scale"
	for _, s in { 0.95, 1.3, 1.0 } do
		hero:ScaleTo(s)
		task.wait(2.5)
		local g = lowest(hero) - floorTop
		info("hero ScaleTo " .. s, ("HipHeight=%.3f feet gap=%.3f"):format(hh.HipHeight, g))
		expect("ScaleTo " .. s .. " keeps the feet on the floor (within 0.5)", math.abs(g) < 0.5, g)
	end

	section = "carry"
	for _, m in { noob, hero } do
		local ut = m:FindFirstChild("UpperTorso") :: BasePart
		local _, size = m:GetBoundingBox()
		info(
			m.Name .. " carry inputs",
			("UpperTorso.Size=%s  half depth=%.2f  bounding box=%s (a carried creature lies across the shoulder: its length is the height)"):format(
				tostring(ut.Size),
				ut.Size.Z / 2,
				tostring(size)
			)
		)
	end
end)
if not ok then
	failed += 1
	note("ERROR", "test stopped", err)
end
folder:Destroy()
finish(if failed == 0 then "PASS" else "FAIL")
