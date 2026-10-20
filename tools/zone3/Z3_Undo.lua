-- Z3_Undo.lua: undoes Z3_Access.lua (run before Z2/Z1/Z0 undo). Run in Studio Edit via tools/hub2b/run_file.py.
-- Moves every MovedZ3-tagged item back (attr PreZ3CFrame), restores turned attrs (PreZ3<name>), deletes
-- Workspace.HubMap2b.Zone3Access and puts ServerStorage._Parked2b.Zone3Access items back where they were (ParkedFrom).
local SS = game:GetService("ServerStorage")
local CS = game:GetService("CollectionService")
local map = workspace.HubMap2b
assert(map:GetAttribute("Zone3Access") == true, "Z3_Access was not run")

local moved = 0
for _, inst in CS:GetTagged("MovedZ3") do
	local cf = inst:GetAttribute("PreZ3CFrame")
	if typeof(cf) == "CFrame" then
		if inst:IsA("BasePart") then
			inst.CFrame = cf
		elseif inst:IsA("Model") then
			inst:PivotTo(cf)
		end
		moved += 1
	end
	inst:SetAttribute("PreZ3CFrame", nil)
	CS:RemoveTag(inst, "MovedZ3")
end
local attrs = 0
for _, root in { workspace, SS } do
	for _, d in root:GetDescendants() do
		for k, v in d:GetAttributes() do
			if k:sub(1, 5) == "PreZ3" and k ~= "PreZ3CFrame" then
				d:SetAttribute(k:sub(6), v)
				d:SetAttribute(k, nil)
				attrs += 1
			end
		end
	end
end
local made = map:FindFirstChild("Zone3Access")
if made then
	made:Destroy()
end
local back = 0
local park = SS:FindFirstChild("_Parked2b") and SS._Parked2b:FindFirstChild("Zone3Access")
if park then
	for _, c in park:GetChildren() do
		local from = c:GetAttribute("ParkedFrom")
		local parent: Instance? = game
		for name in string.gmatch(from or "", "[^%.]+") do
			parent = parent and parent:FindFirstChild(name)
		end
		if parent then
			c:SetAttribute("ParkedFrom", nil)
			c.Parent = parent
			back += 1
		else
			warn("Z3_Undo: no parent for " .. c.Name .. " (" .. tostring(from) .. ")")
		end
	end
	if #park:GetChildren() == 0 then
		park:Destroy()
	end
end
map:SetAttribute("Zone3Access", nil)
map:SetAttribute("Zone3Move", nil)
return ("Z3 undo: %d moved back, %d attrs restored, %d unparked"):format(moved, attrs, back)
