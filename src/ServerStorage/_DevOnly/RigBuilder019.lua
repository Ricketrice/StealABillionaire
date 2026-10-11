-- Studio location: ServerStorage._DevOnly.RigBuilder019 (ModuleScript)
-- RigBuilder019  (Milestone 019) -- Edit-mode tool, never required by the game.
-- Turns a raw FBX import from assets/blender/characters/export/019 (15 R15 MeshParts plus
-- Acc_<R15 part>_<Name> accessories, every mesh origin on its joint, facing -Z) into a worker rig
-- built like Prototypes.BrokeBob_018B4: that prototype's Humanoid, Animate, HumanoidRootPart and
-- joint constraints, with the new meshes swapped in and the rig attachments moved to the new joints.
--   local B = require(game.ServerStorage._DevOnly.RigBuilder019)
--   local rig, report = B.build(importModel, "broke_bob", glowColor3OrNil)
--   local preview = B.preview(rig) -- static copy for ReplicatedStorage.WorkerPreviews019

local ServerStorage = game:GetService("ServerStorage")

local B = {}

local R15 = {
	"LowerTorso", "UpperTorso", "Head",
	"LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand",
	"LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot",
}
-- joint -> the part that hangs from it (that part's mesh origin is the joint)
local JOINT_CHILD = { Root = "LowerTorso", Waist = "UpperTorso", Neck = "Head" }
for _, side in { "Left", "Right" } do
	JOINT_CHILD[side .. "Shoulder"] = side .. "UpperArm"
	JOINT_CHILD[side .. "Elbow"] = side .. "LowerArm"
	JOINT_CHILD[side .. "Wrist"] = side .. "Hand"
	JOINT_CHILD[side .. "Hip"] = side .. "UpperLeg"
	JOINT_CHILD[side .. "Knee"] = side .. "LowerLeg"
	JOINT_CHILD[side .. "Ankle"] = side .. "Foot"
end

function B.build(import: Model, id: string, glow: Color3?): (Model, string)
	local donor = ServerStorage.Prototypes.BrokeBob_018B4
	local src = import:Clone()
	local toLocal = src:GetPivot():Inverse() -- the import's origin is on the ground between the feet
	local body, accessories = {}, {}
	for _, d in src:GetDescendants() do
		if d:IsA("MeshPart") then
			d.CFrame = toLocal * d.CFrame
			if table.find(R15, d.Name) then
				body[d.Name] = d
			else
				table.insert(accessories, d)
			end
		end
	end
	local joints, checksum = {}, 0
	for joint, partName in JOINT_CHILD do
		local p = assert(body[partName], id .. " is missing " .. partName):GetPivot().Position
		joints[joint] = p
		checksum += math.abs(p.X) + math.abs(p.Y) + math.abs(p.Z)
	end

	local rig = donor:Clone()
	rig.Name = id
	local root = rig.HumanoidRootPart
	local swapped = {}
	for _, name in R15 do
		local old, new = rig[name], body[name]
		for _, child in old:GetChildren() do
			child.Parent = new -- rig attachments, joint constraints, no-collision constraints
		end
		for _, a in new:GetChildren() do
			local joint = a:IsA("Attachment") and a.Name:match("^(%a+)RigAttachment$")
			if joint then
				a.CFrame = new.CFrame:ToObjectSpace(CFrame.new(joints[joint]))
			end
		end
		new.Anchored, new.CanCollide, new.Massless = false, old.CanCollide, false
		new.Material = Enum.Material.SmoothPlastic
		swapped[old] = new
	end
	for _, name in R15 do
		body[name].Parent = rig
	end
	for _, d in rig:GetDescendants() do
		if d:IsA("NoCollisionConstraint") then
			d.Part0, d.Part1 = swapped[d.Part0] or d.Part0, swapped[d.Part1] or d.Part1
		end
	end
	for old in swapped do
		old:Destroy()
	end
	-- The engine keeps the root part's bottom level with the hip joints: it rewrites this attachment
	-- when a rig enters Workspace. Built that way here, nothing moves afterwards, so HipHeight is the
	-- same before and after parenting (a worker stood on a station before parenting would float).
	local rootAttachment = root.RootRigAttachment
	local hipY = (joints.LeftHip.Y + joints.RightHip.Y) / 2
	rootAttachment.Position = Vector3.new(0, joints.Root.Y - hipY - root.Size.Y / 2, 0)
	root.CFrame = CFrame.new(joints.Root - rootAttachment.Position)
	root.PivotOffset = root.CFrame:ToObjectSpace(CFrame.new()) -- model pivot on the ground between the feet

	local folder = Instance.new("Folder")
	folder.Name = "Accessories"
	for _, acc in accessories do
		local hostName = acc.Name:match("^Acc_(%a+)_")
		local host = assert(hostName and body[hostName], id .. ": no body part for " .. acc.Name)
		acc.Anchored, acc.CanCollide, acc.CanTouch, acc.CanQuery, acc.Massless = false, false, false, false, true
		acc.Material = Enum.Material.SmoothPlastic
		if acc.Name:match("_Glow$") and glow then -- the worker's one emissive accent
			acc.Material = Enum.Material.Neon
			acc.Color = glow
			acc.TextureID = ""
		end
		local weld = Instance.new("Weld")
		weld.Name = "AccessoryWeld"
		weld.Part0, weld.Part1 = host, acc
		weld.C0 = host.CFrame:ToObjectSpace(acc.CFrame)
		weld.Parent = acc
		acc.Parent = folder
	end
	folder.Parent = rig

	local feet = math.min(rig.LeftFoot.Position.Y - rig.LeftFoot.Size.Y / 2, rig.RightFoot.Position.Y - rig.RightFoot.Size.Y / 2)
	rig.Humanoid.HipHeight = (root.Position.Y - root.Size.Y / 2) - feet
	rig.PrimaryPart = root
	rig:SetAttribute("Prototype", nil) -- the donor's own label (its RBX_ReimportId can't be cleared by scripts)
	rig:SetAttribute("WorkerId", id)
	rig:SetAttribute("Rig", "019")

	local gap, top = 0, -math.huge
	for _, d in rig:GetDescendants() do
		if d:IsA("AnimationConstraint") then
			local a0, a1 = d.Attachment0, d.Attachment1
			gap = math.max(gap, ((a0.Parent.CFrame * a0.CFrame).Position - (a1.Parent.CFrame * a1.CFrame).Position).Magnitude)
		elseif d:IsA("MeshPart") then
			top = math.max(top, d.Position.Y + d.Size.Y / 2)
		end
	end
	local report = ("%s: accessories %d, hip %.3f, feet %.3f, height %.2f, joint gap %.4f, joint checksum %.3f"):format(id, #accessories, rig.Humanoid.HipHeight, feet, top - feet, gap, checksum)
	return rig, report
end

-- A static, script-free copy for UI previews: feet on the origin, facing -Z, like WorkerPreviews.
function B.preview(rig: Model): Model
	local root = rig.HumanoidRootPart
	local base = root.CFrame * CFrame.new(0, -(root.Size.Y / 2 + rig.Humanoid.HipHeight), 0)
	local model = Instance.new("Model")
	model.Name = rig.Name
	for _, d in rig:GetDescendants() do
		if d:IsA("MeshPart") then
			local p = d:Clone()
			p:ClearAllChildren()
			p.CFrame = base:ToObjectSpace(d.CFrame)
			p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false
			p.Parent = model
		end
	end
	model.WorldPivot = CFrame.new()
	return model
end

return B
