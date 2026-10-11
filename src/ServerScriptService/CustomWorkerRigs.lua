-- Studio location: ServerScriptService.CustomWorkerRigs (ModuleScript)
-- CustomWorkerRigs  (Milestone 019)
-- Gives a revealed worker its custom character model. WorkerAppearance.apply calls this first; when
-- it returns false the worker gets its original recoloured look instead, so ReplicatedStorage.
-- CustomWorkers is the only switch (per worker, or all at once).
--
-- The NPC keeps its Model instance, name and identity attributes: only its children are swapped for
-- a clone of ServerStorage.WorkerRigs019.<workerId>, standing where the mystery rig stood. Carrying,
-- placement, income and saving work on the Model and look its parts up by name, so they don't change.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local CustomWorkers = require(ReplicatedStorage:WaitForChild("CustomWorkers"))
local NPCAnimation = require(script.Parent:WaitForChild("NPCAnimation"))
local NPCWanderer = require(script.Parent:WaitForChild("NPCWanderer"))

local CustomWorkerRigs = {}

local RIGS_FOLDER = "WorkerRigs019" -- Milestone 019 Blender models: the fallback
local AVATAR_RIGS_FOLDER = "WorkerRigs019R" -- real Roblox avatars, for workers mapped with rig = "avatar"

-- The rig template for a worker, or nil if it has no custom model (or it is switched off).
function CustomWorkerRigs.getTemplate(workerId: string): Model?
	local custom = CustomWorkers.get(workerId)
	if not custom then
		return nil
	end
	for _, folderName in { if custom.rig == "avatar" then AVATAR_RIGS_FOLDER else RIGS_FOLDER, RIGS_FOLDER } do
		local folder = ServerStorage:FindFirstChild(folderName)
		local template = folder and folder:FindFirstChild(workerId)
		if template and template:IsA("Model") then
			return template
		end
	end
	return nil
end

-- Swaps `npc`'s rig for the worker's custom one. Returns false (npc untouched) if there is none.
function CustomWorkerRigs.apply(npc: Model, workerId: string): boolean
	local template = CustomWorkerRigs.getTemplate(workerId)
	local oldRoot = npc:FindFirstChild("HumanoidRootPart")
	local oldHumanoid = npc:FindFirstChildOfClass("Humanoid")
	if not (template and oldRoot and oldRoot:IsA("BasePart") and oldHumanoid) then
		return false
	end
	local ok, fresh = pcall(NPCWanderer.cloneRig, template)
	if not ok then
		warn("[CustomWorkerRigs] couldn't build", workerId, "-", fresh)
		return false
	end
	local root = fresh:FindFirstChild("HumanoidRootPart") :: BasePart
	local humanoid = fresh:FindFirstChildOfClass("Humanoid") :: Humanoid

	-- Stand the new rig where the old one stood: same heading, feet at the same height.
	local lift = (humanoid.HipHeight + root.Size.Y / 2) - (oldHumanoid.HipHeight + oldRoot.Size.Y / 2)
	local rootCFrame = oldRoot.CFrame * CFrame.new(0, lift, 0)
	fresh:PivotTo(rootCFrame * root.CFrame:ToObjectSpace(fresh:GetPivot()))
	root.Anchored = oldRoot.Anchored
	humanoid.WalkSpeed = oldHumanoid.WalkSpeed

	for _, child in npc:GetChildren() do
		child:Destroy()
	end
	for _, child in fresh:GetChildren() do
		if child ~= humanoid then
			child.Parent = npc
		end
	end
	humanoid.Parent = npc -- last, so it never sees a half-built body
	npc.PrimaryPart = root
	fresh:Destroy()

	if npc:IsDescendantOf(workspace) then
		NPCAnimation.attach(npc) -- the old rig's animation tracks went with its Humanoid
	end
	return true
end

return CustomWorkerRigs
