-- Undo.lua (Hub 2b): puts the open place's MAP back the way it was before tools/hub2b/H1-H4 (run in Studio Edit).
-- Nothing is deleted: what Hub 2b made goes to ServerStorage._Undone2b. Order:
--   1. everything parked by Hub 2b (ServerStorage._Parked2b, attr ParkedFrom) goes back to where it was
--   2. everything moved (tag Moved2b, attr Pre2bCFrame / Pre2bSize) goes back; turned direction/point attributes
--      (Pre2b<Axis|Inward|HomeSide|Hinge|WheelCentre>), value objects (Pre2bValue) and attributes Hub 2b added
--      (Pre2bHad<Name> = false: Inward, HalfWidth, HomeSide) are restored / removed
--   3. hidden parts (tag Hidden2b: plot fences) and the parade lane get their look back
--   4. what Hub 2b created (attr Created2b: guardian posts, extra spawn points, KnightsKeep.Access2b) -> _Undone2b;
--      the fitted Workspace.HubMap2b -> _Undone2b and the copy as imported (_Backups.Pre2b.HubMap2b_AsImported) back
--      into Workspace as HubMap2b
-- Code is NOT undone here: the code changes are safe with the map back (the attributes they read are gone, so the old
-- north-only behaviour is back), and the guardians are switched with GuardianConfig.ENABLED / ServerStorage attribute
-- StudioGuardian = false. For the old scripts: git (branch art-skin) or backups/pre_hub2b_20261019_scripts.
local SS = game:GetService("ServerStorage")
local CS = game:GetService("CollectionService")
local out = {}
local undone = SS:FindFirstChild("_Undone2b") or Instance.new("Folder")
undone.Name = "_Undone2b"
undone.Parent = SS

local function resolve(path: string): Instance?
	local segs = string.split(path, ".")
	local cur: Instance? = game:GetService(segs[1])
	for i = 2, #segs do
		cur = cur and cur:FindFirstChild(segs[i])
	end
	return cur
end

-- 1. unpark
local parked = SS:FindFirstChild("_Parked2b")
local back, lost = 0, {}
if parked then
	for _, sub in parked:GetChildren() do
		for _, item in sub:GetChildren() do
			local from = item:GetAttribute("ParkedFrom")
			local parent = type(from) == "string" and resolve(from)
			if parent then
				item:SetAttribute("ParkedFrom", nil)
				item.Parent = parent
				back += 1
			else
				table.insert(lost, item:GetFullName() .. " <- " .. tostring(from))
			end
		end
	end
end
table.insert(out, ("unparked %d; could not place %d %s"):format(back, #lost, table.concat(lost, ", ")))
task.wait()

-- 2. moved
local moved = 0
for _, inst in CS:GetTagged("Moved2b") do
	local cf = inst:GetAttribute("Pre2bCFrame")
	if typeof(cf) == "CFrame" then
		if inst:IsA("BasePart") then
			inst.CFrame = cf
		elseif inst:IsA("Model") then
			inst:PivotTo(cf)
		end
	end
	local size = inst:GetAttribute("Pre2bSize")
	if typeof(size) == "Vector3" and inst:IsA("BasePart") then
		inst.Size = size
	end
	for _, k in { "Pre2bCFrame", "Pre2bSize", "Pre2bTurned" } do
		inst:SetAttribute(k, nil)
	end
	CS:RemoveTag(inst, "Moved2b")
	moved += 1
end
local attrs = 0
for _, root in { workspace, SS } do
	for _, d in root:GetDescendants() do
		for k, v in d:GetAttributes() do
			local name = k:match("^Pre2bHad(.+)$")
			if name then
				if v == false then
					d:SetAttribute(name, nil)
				end
				d:SetAttribute(k, nil)
				attrs += 1
			end
			name = k:match("^Pre2b(.+)$")
			if name and (name == "Axis" or name == "Inward" or name == "HomeSide" or name == "Hinge" or name == "WheelCentre") then
				d:SetAttribute(name, v)
				d:SetAttribute(k, nil)
				attrs += 1
			end
		end
		if (d:IsA("CFrameValue") or d:IsA("Vector3Value")) and d:GetAttribute("Pre2bValue") ~= nil then
			(d :: any).Value = d:GetAttribute("Pre2bValue")
			d:SetAttribute("Pre2bValue", nil)
			attrs += 1
		end
	end
end
table.insert(out, ("moved back %d; attributes restored %d"):format(moved, attrs))
task.wait()

-- 3. looks
local shown = 0
for _, p in CS:GetTagged("Hidden2b") do
	if p:IsA("BasePart") then
		p.Transparency = p:GetAttribute("Pre2bTransparency") or 0
		p.CanCollide = p:GetAttribute("Pre2bCanCollide") ~= false
		p.CanQuery = true
		p:SetAttribute("Pre2bTransparency", nil)
		p:SetAttribute("Pre2bCanCollide", nil)
		CS:RemoveTag(p, "Hidden2b")
		shown += 1
	end
end
local lane = workspace.World.SkyCity.Ground.ParadeLane:FindFirstChild("Lane")
if lane and lane:GetAttribute("Pre2bTransparency") ~= nil then
	lane.Transparency = lane:GetAttribute("Pre2bTransparency")
	lane.CanCollide = lane:GetAttribute("Pre2bCanCollide") ~= false
	lane:SetAttribute("Pre2bTransparency", nil)
	lane:SetAttribute("Pre2bCanCollide", nil)
	shown += 1
end
table.insert(out, "looks restored: " .. shown)

-- 4. created things and the map
local created = 0
for _, d in workspace:GetDescendants() do
	if d:GetAttribute("Created2b") and not d:IsDescendantOf(workspace:FindFirstChild("HubMap2b") or undone) then
		d.Parent = undone
		created += 1
	end
end
local map = workspace:FindFirstChild("HubMap2b")
if map and map:GetAttribute("Fit2b") then
	map.Name = "HubMap2b_Fitted"
	map.Parent = undone
	local asImported = SS:FindFirstChild("_Backups") and SS._Backups:FindFirstChild("Pre2b") and SS._Backups.Pre2b:FindFirstChild("HubMap2b_AsImported")
	if asImported then
		local copy = asImported:Clone()
		copy.Name = "HubMap2b"
		copy.Parent = workspace
	end
end
table.insert(out, ("created things put away: %d; fitted map -> ServerStorage._Undone2b, the as-imported copy is back in Workspace"):format(created))
return table.concat(out, "\n")
