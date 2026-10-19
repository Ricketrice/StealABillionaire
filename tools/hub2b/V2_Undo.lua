-- V2_Undo.lua (Hub 2b visual review 2): puts the map back the way it was before V2_Review2.lua (run in Studio Edit).
-- Run it BEFORE V_Undo.lua / R_Undo.lua / Undo.lua. Nothing is deleted: Workspace.HubMap2b.Review2 -> ServerStorage._UndoneV2,
-- ServerStorage._Parked2b.Review2 back to ParkedFrom, tag MovedV2 back to PreV2CFrame / PreV2Size / PreV2<attr> / PreV2Value.
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
local pk = SS:FindFirstChild("_Parked2b")
local f = pk and pk:FindFirstChild("Review2")
if f then
	for _, item in f:GetChildren() do
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
local moved = 0
for _, d in CS:GetTagged("MovedV2") do
	local cf = d:GetAttribute("PreV2CFrame")
	if typeof(cf) == "CFrame" then
		if d:IsA("BasePart") then
			local size = d:GetAttribute("PreV2Size")
			if typeof(size) == "Vector3" then
				d.Size = size
			end
			d.CFrame = cf
		elseif d:IsA("Model") then
			d:PivotTo(cf)
		end
	end
	for _, k in { "Hinge", "WheelCentre" } do
		local v = d:GetAttribute("PreV2" .. k)
		if v ~= nil then
			d:SetAttribute(k, v)
			d:SetAttribute("PreV2" .. k, nil)
		end
	end
	local pv = d:GetAttribute("PreV2Value")
	if pv ~= nil and (d:IsA("Vector3Value") or d:IsA("CFrameValue")) then
		(d :: any).Value = pv
		d:SetAttribute("PreV2Value", nil)
	end
	d:SetAttribute("PreV2CFrame", nil)
	d:SetAttribute("PreV2Size", nil)
	CS:RemoveTag(d, "MovedV2")
	moved += 1
end
-- (a resized part that was only resized, not tagged: the Sign / SafeLineWide carry PreV2Size with their CFrame record)
table.insert(out, ("moved back %d"):format(moved))
local map = workspace:FindFirstChild("HubMap2b")
if map then
	local km = map:GetAttribute("PreV2KeepMove2b")
	if km ~= nil then
		map:SetAttribute("KeepMove2b", km)
		map:SetAttribute("PreV2KeepMove2b", nil)
	end
	local made = map:FindFirstChild("Review2")
	if made then
		local undone = SS:FindFirstChild("_UndoneV2") or Instance.new("Folder")
		undone.Name = "_UndoneV2"
		undone.Parent = SS
		made.Parent = undone
	end
	map:SetAttribute("Review2", nil)
end
return table.concat(out, "\n")
