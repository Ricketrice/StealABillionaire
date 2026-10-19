-- V_Undo.lua (Hub 2b visual review fixes): puts the map back the way it was before V1_VisualFix.lua (run in Studio Edit).
-- Run it BEFORE R_Undo.lua / Undo.lua. Nothing is deleted: Workspace.HubMap2b.VisualFix2b goes to ServerStorage._UndoneV1;
-- everything in ServerStorage._Parked2b.VisualFix goes back to its ParkedFrom parent.
local SS = game:GetService("ServerStorage")
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
local parked = SS:FindFirstChild("_Parked2b")
local vf = parked and parked:FindFirstChild("VisualFix")
if vf then
	for _, item in vf:GetChildren() do
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
table.insert(out, ("unparked %d; could not place %d %s"):format(back, #lost, table.concat(lost, ", ")))
local map = workspace:FindFirstChild("HubMap2b")
local made = map and map:FindFirstChild("VisualFix2b")
if made then
	local undone = SS:FindFirstChild("_UndoneV1") or Instance.new("Folder")
	undone.Name = "_UndoneV1"
	undone.Parent = SS
	made.Parent = undone
	table.insert(out, "VisualFix2b -> ServerStorage._UndoneV1")
end
if map then
	map:SetAttribute("VisualFix2b", nil)
end
return table.concat(out, "\n")
