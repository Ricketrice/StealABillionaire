-- Studio location: ServerStorage._DevOnly.AvatarBuilder019R (ModuleScript)
-- AvatarBuilder019R  (Milestone 019R) -- Edit-mode tool, never required by the game.
-- Builds every look in ServerStorage.CustomWorkerLooks as a real Roblox avatar (a standard R15 body
-- from a HumanoidDescription, exactly like a player's avatar), adds the worker's 019 prop meshes,
-- and stores the rig in ServerStorage.WorkerRigs019R and a static copy for UI previews in
-- ReplicatedStorage.WorkerPreviews019R. Run it again after editing CustomWorkerLooks (command bar):
--   print(require(game.ServerStorage._DevOnly.AvatarBuilder019R:Clone()).buildAll())
--   print(require(game.ServerStorage._DevOnly.AvatarBuilder019R:Clone()).buildAll({ "broke_bob" }))

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local B = {}

local RIGS_FOLDER, PREVIEWS_FOLDER = "WorkerRigs019R", "WorkerPreviews019R"
-- Each Velocity Royale worker's one emissive accent (export/019/manifest.json glow_color).
local GLOW = {
	butler_barnaby = "FFB02E", caddie_gus = "FFE45A", polo_pro_penny = "FFF3C4", chef_pierre = "28D6CC",
	bodyguard_boris = "28D6CC", hedge_fund_hank = "FF8A2A", oil_baron_oswald = "FFC24A", the_trillionaire = "FF6A1E",
}

local A = Enum.AccessoryType
-- slot -> { accessory type, layering order (none = rigid accessory) }
local ACCESSORY = {
	Hair = { A.Hair }, Hat = { A.Hat }, Face = { A.Face }, Neck = { A.Neck }, Shoulder = { A.Shoulder },
	Front = { A.Front }, Back = { A.Back }, Waist = { A.Waist },
	Pants = { A.Pants, 1 }, Shorts = { A.Shorts, 1 }, Skirt = { A.DressSkirt, 2 },
	LeftShoe = { A.LeftShoe, 3 }, RightShoe = { A.RightShoe, 3 },
	TShirt = { A.TShirt, 4 }, Shirt = { A.Shirt, 5 }, Sweater = { A.Sweater, 6 }, Jacket = { A.Jacket, 7 },
}
local TOPS = { TShirt = true, Shirt = true, Sweater = true, Jacket = true }
local HUMANOID_SETTINGS = { "DisplayDistanceType", "HealthDisplayType", "NameDisplayDistance", "HealthDisplayDistance", "NameOcclusion", "RequiresNeck", "BreakJointsOnDeath", "WalkSpeed" }

local function describe(look, items): (HumanoidDescription, number)
	local d = Instance.new("HumanoidDescription")
	d.HeightScale, d.WidthScale, d.DepthScale = look.height, look.width, (1 + look.width) / 2
	d.HeadScale, d.BodyTypeScale, d.ProportionScale = 1, 0, 0
	local skin = Color3.fromHex(look.skin)
	d.HeadColor, d.TorsoColor, d.LeftArmColor, d.RightArmColor, d.LeftLegColor, d.RightLegColor = skin, skin, skin, skin, skin, skin
	local accessories = {}
	for _, item in items do
		local slot, id = item[1], item[2]
		if slot == "Head" then
			d.Head = id
		elseif slot == "ClassicShirt" then
			d.Shirt = id
		elseif slot == "ClassicPants" then
			d.Pants = id
		else
			local kind = assert(ACCESSORY[slot], "unknown slot " .. tostring(slot))
			-- Order is for layered clothing only: a rigid accessory given an Order is silently dropped.
			table.insert(accessories, { AssetId = id, AccessoryType = kind[1], Order = kind[2], IsLayered = kind[2] ~= nil })
		end
	end
	d:SetAccessories(accessories, true)
	return d, #accessories
end

local function create(look, items): (boolean, any, number)
	local d, count = describe(look, items)
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(d, Enum.HumanoidRigType.R15)
	end)
	d:Destroy()
	return ok, model, count
end

local function countAccessories(model: Model): number
	local n = 0
	for _, c in model:GetChildren() do
		if c:IsA("Accessory") then
			n += 1
		end
	end
	return n
end

-- Builds the items that load; returns the avatar and the items that didn't ("Slot id").
local function createAvatar(look): (Model?, { string })
	local items, failed = table.clone(look.items), {}
	local ok, model, count = create(look, items)
	if not ok or countAccessories(model) ~= count then
		if ok then
			model:Destroy()
		end
		for i = #items, 1, -1 do -- try each item alone, drop the ones that don't load
			local slot = items[i][1]
			local okOne, one, n = create(look, { items[i] })
			local loaded = okOne and countAccessories(one) == n
			if okOne then
				one:Destroy()
			end
			if not loaded then
				table.insert(failed, ("%s %d"):format(slot, items[i][2]))
				table.remove(items, i)
			end
			task.wait(0.2)
		end
		ok, model = create(look, items)
		if not ok then
			table.insert(failed, "avatar could not be built: " .. tostring(model))
			return nil, failed
		end
	end
	for _, item in look.items do
		if (item[1] == "ClassicShirt" and not model:FindFirstChildOfClass("Shirt")) or (item[1] == "ClassicPants" and not model:FindFirstChildOfClass("Pants")) then
			table.insert(failed, ("%s %d"):format(item[1], item[2]))
		elseif item[1] == "Head" and not (model:FindFirstChild("Head") and model.Head:FindFirstChildOfClass("FaceControls")) then
			table.insert(failed, ("%s %d"):format(item[1], item[2]))
		end
	end
	return model, failed
end

-- Welds a 019 prop mesh to the avatar where the 019 figure held it.
local function addProp(model: Model, import: Model, propName: string, wearsTop: boolean, glow: Color3?): BasePart?
	local source = import:FindFirstChild(propName, true)
	local hostName = propName:match("^Acc_(%a+)_")
	local host = hostName and model:FindFirstChild(hostName)
	if not (source and source:IsA("MeshPart") and host and host:IsA("BasePart")) then
		return nil
	end
	local toLocal = import:GetPivot():Inverse()
	local cf = toLocal * source.CFrame
	local target: CFrame
	local side = hostName:match("^(%a+)Hand$")
	if side then
		-- Hand to hand, turned from the 019 figure's angled forearm onto the avatar's straight one.
		local hand0 = (toLocal * (import :: any)[side .. "Hand"].CFrame).Position
		local elbow0 = (toLocal * (import :: any)[side .. "LowerArm"]:GetPivot()).Position
		local wrist0 = (toLocal * (import :: any)[side .. "Hand"]:GetPivot()).Position
		local lowerArm = (model :: any)[side .. "LowerArm"]
		local wrist1 = (host.CFrame * (host :: any)[side .. "WristRigAttachment"].CFrame).Position
		local elbow1 = (lowerArm.CFrame * lowerArm[side .. "ElbowRigAttachment"].CFrame).Position
		local from, to = (wrist0 - elbow0).Unit, (wrist1 - elbow1).Unit
		local axis = from:Cross(to)
		local turn = if axis.Magnitude > 1e-4 then CFrame.fromAxisAngle(axis.Unit, math.acos(math.clamp(from:Dot(to), -1, 1))) else CFrame.new()
		target = CFrame.new(host.Position) * turn * CFrame.new(-hand0) * cf
	else
		-- Chest props hang from the neck, just in front of whatever the avatar wears.
		local torso0 = (import :: any).UpperTorso
		local neck0 = (toLocal * (import :: any).Head:GetPivot()).Position
		local front0 = (toLocal * torso0.CFrame).Position.Z - torso0.Size.Z / 2
		local neck1 = (host.CFrame * (host :: any).NeckRigAttachment.CFrame).Position
		local front1 = host.Position.Z - host.Size.Z / 2 - (if wearsTop then 0.12 else 0)
		target = cf + Vector3.new(neck1.X - neck0.X, neck1.Y - neck0.Y, front1 - front0)
	end
	local prop = source:Clone()
	prop:ClearAllChildren()
	prop.CFrame = target
	prop.Anchored, prop.CanCollide, prop.CanTouch, prop.CanQuery, prop.Massless = false, false, false, false, true
	prop.Material = Enum.Material.SmoothPlastic
	if propName:match("_Glow$") and glow then
		prop.Material = Enum.Material.Neon
		prop.Color = glow
		prop.TextureID = ""
	end
	local weld = Instance.new("Weld")
	weld.Name = "PropWeld"
	weld.Part0, weld.Part1 = host, prop
	weld.C0 = host.CFrame:ToObjectSpace(target)
	weld.Parent = prop
	return prop
end

-- Prop fit rules (Milestone 027): a hand prop's nearest surface is at most GRIP_MAX studs from the
-- hand's centre, every prop stands upright and none of it is inside the body. The glow accent on the
-- same body part moves with its prop.
local GRIP_MAX, GRIP_AIM = 0.3, 0.12
local BODY = { "Head", "UpperTorso", "LowerTorso", "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg", "LeftFoot", "RightFoot" }

local function grid(cf: CFrame, size: Vector3, shrink: number): { Vector3 }
	local points, half = {}, size / 2 - Vector3.one * shrink
	for _, x in { -1, 0, 1 } do for _, y in { -1, 0, 1 } do for _, z in { -1, 0, 1 } do
		table.insert(points, cf * Vector3.new(half.X * x, half.Y * y, half.Z * z))
	end end end
	return points
end

local function inBox(point: Vector3, cf: CFrame, size: Vector3): boolean
	local l, h = cf:PointToObjectSpace(point), size / 2
	return math.abs(l.X) < h.X and math.abs(l.Y) < h.Y and math.abs(l.Z) < h.Z
end

-- How far the hand's centre is from the prop's nearest surface (0 = inside the prop).
function B.gripDistance(prop: BasePart, cf: CFrame?, hand: BasePart): number
	local l, h = (cf or prop.CFrame):PointToObjectSpace(hand.Position), prop.Size / 2
	local c = Vector3.new(math.clamp(l.X, -h.X, h.X), math.clamp(l.Y, -h.Y, h.Y), math.clamp(l.Z, -h.Z, h.Z))
	return (l - c).Magnitude
end

-- Sample points of the prop inside the body, plus body sample points inside the prop.
function B.bodyOverlap(model: Model, prop: BasePart, cf: CFrame?): number
	local at, n = cf or prop.CFrame, 0
	local mine = grid(at, prop.Size, 0.03)
	for _, name in BODY do
		local part = model:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			for _, p in mine do
				if inBox(p, part.CFrame, part.Size) then n += 1 end
			end
			for _, p in grid(part.CFrame, part.Size, 0.03) do
				if inBox(p, at, prop.Size) then n += 1 end
			end
		end
	end
	return n
end

local function upright(cf: CFrame): CFrame
	local look = cf.LookVector * Vector3.new(1, 0, 1)
	if look.Magnitude < 0.2 then
		look = -cf.UpVector * Vector3.new(1, 0, 1) -- lying flat: keep its heading
	end
	return CFrame.lookAt(cf.Position, cf.Position + look.Unit)
end

-- Moves each body part's main prop (and its glow) to obey the rules. Returns the props it couldn't fit.
local function fitProps(model: Model, root: BasePart, props: Folder): { string }
	local problems, byHost = {}, {}
	for _, prop in props:GetChildren() do
		local weld = prop:FindFirstChild("PropWeld") :: Weld
		local host = weld and weld.Part0
		if host then
			byHost[host] = byHost[host] or { glow = {} }
			if prop.Name:match("_Glow$") then
				table.insert(byHost[host].glow, prop)
			else
				byHost[host].main = prop
			end
		end
	end
	for host, group in byHost do
		local prop: BasePart = group.main
		if not prop then
			continue
		end
		local isHand = host.Name:match("Hand$") ~= nil
		local start = upright(prop.CFrame)
		if isHand then
			-- Slide toward the hand until the hand's centre is just at the prop's surface.
			local d = B.gripDistance(prop, start, host)
			if d > GRIP_AIM then
				local l = start:PointToObjectSpace(host.Position)
				local h = prop.Size / 2
				local c = Vector3.new(math.clamp(l.X, -h.X, h.X), math.clamp(l.Y, -h.Y, h.Y), math.clamp(l.Z, -h.Z, h.Z))
				local towardHand = start:VectorToWorldSpace(l - c).Unit
				start += towardHand * (d - GRIP_AIM)
			end
		end
		-- Then the smallest shift (outward, forward or back) that clears the body and keeps the grip.
		local outward = root.CFrame.RightVector * (if host.Name:match("^Left") then -1 else 1)
		local forward = root.CFrame.LookVector
		local best, bestCost = nil, math.huge
		for o = 0, 10 do
			for f = -10, 12 do
				local shift = outward * (o * 0.08) + forward * (f * 0.08)
				local cost = shift.Magnitude
				if cost < bestCost and (isHand or o == 0) then
					local cf = start + shift
					if B.bodyOverlap(model, prop, cf) == 0 and (not isHand or B.gripDistance(prop, cf, host) <= GRIP_MAX) then
						best, bestCost = cf, cost
					end
				end
			end
		end
		if not best then
			table.insert(problems, prop.Name .. " (no spot clear of the body)")
			best = start
		end
		local move = best * prop.CFrame:Inverse()
		for _, part in { prop, table.unpack(group.glow) } do
			part.CFrame = move * part.CFrame
			local weld = part:FindFirstChild("PropWeld") :: Weld
			weld.C0 = host.CFrame:ToObjectSpace(part.CFrame)
		end
	end
	return problems
end

local function spanY(model: Model): (number, number, number)
	local low, high, feet = math.huge, -math.huge, math.huge
	for _, p in model:GetDescendants() do
		if p:IsA("MeshPart") then
			local half = p.Size / 2
			for _, sx in { -1, 1 } do for _, sy in { -1, 1 } do for _, sz in { -1, 1 } do
				local y = (p.CFrame * Vector3.new(half.X * sx, half.Y * sy, half.Z * sz)).Y
				low, high = math.min(low, y), math.max(high, y)
				if p.Name == "LeftFoot" or p.Name == "RightFoot" then
					feet = math.min(feet, y)
				end
			end end end
		end
	end
	return low, high, feet
end

-- Outside Workspace nothing solves the joints, so the parts of a freshly built avatar are not where
-- its (scaled) joints put them. Walk out from the root part and seat every body part on its joint,
-- so the rig at rest is what the engine makes of it in Workspace: HipHeight measured from it is right
-- before the rig is ever parented, and the anchored preview copy has no gaps.
local function seatBody(model: Model, root: BasePart)
	local joints = {}
	for _, d in model:GetDescendants() do
		if d:IsA("AnimationConstraint") and d.Attachment0 and d.Attachment1 then
			table.insert(joints, { d.Attachment0.Parent, d.Attachment1.Parent, d.Attachment0.CFrame, d.Attachment1.CFrame })
		elseif d:IsA("Motor6D") and d.Part0 and d.Part1 then
			table.insert(joints, { d.Part0, d.Part1, d.C0, d.C1 })
		end
	end
	local seated = { [root] = true }
	local progressed = true
	while progressed do
		progressed = false
		for _, joint in joints do
			local part0, part1, c0, c1 = joint[1], joint[2], joint[3], joint[4]
			if seated[part0] and not seated[part1] then
				part1.CFrame = part0.CFrame * c0 * c1:Inverse()
				seated[part1], progressed = true, true
			elseif seated[part1] and not seated[part0] then
				part0.CFrame = part1.CFrame * c1 * c0:Inverse()
				seated[part0], progressed = true, true
			end
		end
	end
end

-- An avatar built outside Workspace keeps its accessories where they were loaded. Seat every handle
-- on its weld, so the measured height, the props and the anchored preview copy are right. An item
-- that arrives without a weld can't be worn at all: it is removed and returned by name.
local function seatAccessories(model: Model): { string }
	local unattached = {}
	for _, accessory in model:GetChildren() do
		if accessory:IsA("Accessory") then
			local handle = accessory:FindFirstChild("Handle")
			local weld = handle and handle:FindFirstChildWhichIsA("Weld")
			if handle and handle:IsA("BasePart") and weld and weld.Part0 and weld.Part1 then
				if weld.Part1 == handle then
					handle.CFrame = weld.Part0.CFrame * weld.C0 * weld.C1:Inverse()
				else
					handle.CFrame = weld.Part1.CFrame * weld.C1 * weld.C0:Inverse()
				end
			else
				table.insert(unattached, accessory.Name)
				accessory:Destroy()
			end
		end
	end
	return unattached
end

-- Builds one worker's rig. Returns the rig (nil if it couldn't be built) and the items that failed.
function B.build(id: string): (Model?, { string })
	local Looks = require(ServerStorage.CustomWorkerLooks:Clone()) :: any
	local look = assert(Looks.WORKERS[id], "no look for " .. id)
	local model, failed = createAvatar(look)
	if not model then
		return nil, failed
	end
	model.Name = id
	model:PivotTo(CFrame.new(0, 10, 0)) -- upright, facing -Z
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	seatBody(model, root)
	for _, name in seatAccessories(model) do
		table.insert(failed, "can't be worn (no attachment): " .. name)
	end

	-- Same scripts and Humanoid settings as the mystery NPC, so NPCAnimation and the HUD treat it alike.
	local mystery = ServerStorage.NPCModels.MysteryNPC
	for _, d in model:GetDescendants() do
		if d:IsA("LuaSourceContainer") then
			d:Destroy()
		end
	end
	mystery.Animate:Clone().Parent = model
	for _, name in HUMANOID_SETTINGS do
		(humanoid :: any)[name] = (mystery.Humanoid :: any)[name]
	end

	local wearsTop = false
	for _, item in look.items do
		wearsTop = wearsTop or TOPS[item[1]] == true
	end
	local import = ServerStorage.WorkerImports019:FindFirstChild(id)
	local props = Instance.new("Folder")
	props.Name = "Props"
	for _, propName in look.props do
		local prop = import and addProp(model, import, propName, wearsTop, GLOW[id] and Color3.fromHex(GLOW[id]))
		if prop then
			prop.Parent = props
		else
			table.insert(failed, "prop " .. propName)
		end
	end
	props.Parent = model
	for _, problem in fitProps(model, root, props) do
		table.insert(failed, "prop fit: " .. problem)
	end

	local _, high, feet = spanY(model)
	humanoid.HipHeight = (root.Position.Y - root.Size.Y / 2) - feet
	model.PrimaryPart = root
	model:SetAttribute("WorkerId", id)
	model:SetAttribute("Rig", "019R")
	model:SetAttribute("Height", high - feet)
	return model, failed
end

-- A static, script-free copy for UI previews. It keeps its Humanoid: classic clothing and body
-- colours only show on a model that has one.
function B.preview(rig: Model): Model
	local model = rig:Clone()
	for _, d in model:GetDescendants() do
		if d:IsA("LuaSourceContainer") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored, d.CanCollide, d.CanTouch, d.CanQuery = true, false, false, false
		end
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.EvaluateStateMachine = false
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	return model
end

local function folder(parent: Instance, name: string): Instance
	local f = parent:FindFirstChild(name)
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = parent
	end
	return f :: Instance
end

-- Builds the given workers (default: all of them) and returns a short report.
function B.buildAll(ids: { string }?): string
	local Looks = require(ServerStorage.CustomWorkerLooks:Clone()) :: any
	local list = ids or {}
	if not ids then
		for id in Looks.WORKERS do
			table.insert(list, id)
		end
		table.sort(list)
	end
	local rigs, previews = folder(ServerStorage, RIGS_FOLDER), folder(ReplicatedStorage, PREVIEWS_FOLDER)
	local built, lines = 0, {}
	for _, id in list do
		local ok, rig, failed = pcall(B.build, id)
		if not ok then
			table.insert(lines, id .. ": ERROR " .. tostring(rig))
		else
			if rig then
				for _, f in { rigs, previews } do
					local old = f:FindFirstChild(id)
					if old then
						old:Destroy()
					end
				end
				rig.Parent = rigs
				B.preview(rig).Parent = previews
				built += 1
			end
			if #failed > 0 then
				table.insert(lines, id .. ": failed to load: " .. table.concat(failed, ", "))
			end
		end
		task.wait(0.3)
	end
	table.insert(lines, 1, ("built %d/%d"):format(built, #list))
	return table.concat(lines, "\n")
end

return B
