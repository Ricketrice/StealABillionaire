-- Studio location: ServerScriptService.CreatureScaler (Script)
-- CreatureScaler  (Milestone 035)
-- Keeps big creatures from getting in the way: a carried creature shows at most CARRY_CAP x normal size and a
-- creature on a pad at most PAD_CAP x (so giants never reach the neighbouring pads). It only rescales the model
-- when NPCCarry / NPCPlacement change its ClaimPhase attribute; those scripts are untouched. Index and reveal
-- previews are clones of the template and show full size. Wild creatures stand at full size.

local CollectionService = game:GetService("CollectionService")

local CARRY_CAP = 1.3
local PAD_CAP = 1.6

local watched: { [Model]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function targetScale(npc: Model): number
	local built = npc:GetAttribute("CreatureBuiltScale") or 1
	local phase = npc:GetAttribute("ClaimPhase")
	if phase == "Carrying" then
		return math.min(built, CARRY_CAP)
	elseif phase == "Placed" then
		return math.min(built, PAD_CAP)
	end
	return built
end

local function feetY(npc: Model): number?
	local root = npc:FindFirstChild("HumanoidRootPart")
	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	if root and root:IsA("BasePart") and humanoid then
		return root.Position.Y - root.Size.Y / 2 - humanoid.HipHeight
	end
	return nil
end

local function refresh(npc: Model)
	local want = targetScale(npc)
	local current = npc:GetAttribute("CreatureScale") or want -- the model's own scale factor stays 1 (its children were moved in)
	if math.abs(current - want) < 0.001 then
		return
	end
	local root = npc:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	local before = if root and root.Anchored then feetY(npc) else nil
	npc:ScaleTo(npc:GetScale() * want / current)
	npc:SetAttribute("CreatureScale", want)
	if before and root and humanoid then
		local after = feetY(npc) :: number
		npc:PivotTo(npc:GetPivot() + Vector3.new(0, before - after, 0)) -- feet stay on the pad
	end
end

local function watch(npc: Instance)
	if not npc:IsA("Model") or watched[npc] or not npc:IsDescendantOf(workspace) then -- never the templates in ReplicatedStorage
		return
	end
	watched[npc] = true
	npc:GetAttributeChangedSignal("ClaimPhase"):Connect(function()
		refresh(npc)
	end)
	refresh(npc)
end

CollectionService:GetInstanceAddedSignal("Creature"):Connect(watch)
for _, npc in CollectionService:GetTagged("Creature") do
	watch(npc)
end
