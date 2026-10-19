-- R_Undo.lua (Hub 2b layout repair): puts the map back the way it was before R1_LayoutRepair.lua (run in Studio Edit).
-- Run it BEFORE tools/hub2b/Undo.lua if both are wanted. Nothing is deleted: Workspace.HubMap2b.Repair2b goes to
-- ServerStorage._UndoneR2; parked pieces (ServerStorage._ParkedR2, attr ParkedFrom) go back; moved/resized parts
-- (tag MovedR2, attrs PreR2CFrame / PreR2Size) get their old CFrame / size.
local SS = game:GetService("ServerStorage")
local CS = game:GetService("CollectionService")
local out = {}
local function resolve(path: string): Instance?
	local segs = string.split(path, ".")
	local cur: Instance? = game:GetService(segs[1])
	for i = 2, #segs do
		cur = cur and cur:FindFirstChild(segs[i])
	end
	return cur
end

local back, lost = 0, {}
local parked = SS:FindFirstChild("_ParkedR2")
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

local moved = 0
for _, p in CS:GetTagged("MovedR2") do
	if p:IsA("BasePart") then
		local size = p:GetAttribute("PreR2Size")
		if typeof(size) == "Vector3" then
			p.Size = size
		end
		local cf = p:GetAttribute("PreR2CFrame")
		if typeof(cf) == "CFrame" then
			p.CFrame = cf
		end
		p:SetAttribute("PreR2Size", nil)
		p:SetAttribute("PreR2CFrame", nil)
		CS:RemoveTag(p, "MovedR2")
		moved += 1
	end
end
table.insert(out, ("moved back %d"):format(moved))

local map = workspace:FindFirstChild("HubMap2b")
local rep = map and map:FindFirstChild("Repair2b")
if rep then
	local undone = SS:FindFirstChild("_UndoneR2") or Instance.new("Folder")
	undone.Name = "_UndoneR2"
	undone.Parent = SS
	rep.Parent = undone
	table.insert(out, "Repair2b -> ServerStorage._UndoneR2")
end
if map then
	map:SetAttribute("Repair2b", nil)
end
return table.concat(out, "\n")
