-- Z5_Undo.lua: undoes Z5_MainRoad.lua (run before Z4_Undo). Run in Studio Edit via tools/hub2b/run_file.py.
-- Puts parked items back (ServerStorage._Parked2b.Zone3West / .MainRoad; attr ParkedFrom), moves MovedZ5 items back
-- (PreZ5CFrame), restores turned attributes (PreZ5Inward / PreZ5Axis), deletes Workspace.HubMap2b.MainRoad and
-- everything with attr CreatedZ5.
local SS = game:GetService("ServerStorage")
local CS = game:GetService("CollectionService")
local map = workspace.HubMap2b
assert(map:GetAttribute("MainRoad") == true, "Z5_MainRoad was not run")

local function resolve(path: string?): Instance?
	local at: Instance? = game
	for name in string.gmatch(path or "", "[^%.]+") do
		at = at and at:FindFirstChild(name)
	end
	return at
end
local back = 0
for _, n in { "Zone3West", "MainRoad" } do
	local folder = SS._Parked2b:FindFirstChild(n)
	if folder then
		for _, c in folder:GetChildren() do
			local parent = resolve(c:GetAttribute("ParkedFrom"))
			if parent then
				c:SetAttribute("ParkedFrom", nil)
				c.Parent = parent
				back += 1
			else
				warn("Z5_Undo: no parent for " .. c:GetFullName())
			end
		end
		if #folder:GetChildren() == 0 then
			folder:Destroy()
		end
	end
end

local moved = 0
for _, inst in CS:GetTagged("MovedZ5") do
	local cf = inst:GetAttribute("PreZ5CFrame")
	if typeof(cf) == "CFrame" then
		if inst:IsA("BasePart") then
			inst.CFrame = cf
		elseif inst:IsA("Model") then
			inst:PivotTo(cf)
		end
		moved += 1
	end
	inst:SetAttribute("PreZ5CFrame", nil)
	CS:RemoveTag(inst, "MovedZ5")
end
local restored, removed = 0, 0
for _, root in { workspace, SS } do
	for _, d in root:GetDescendants() do
		if d:GetAttribute("CreatedZ5") then
			d:Destroy()
			removed += 1
			continue
		end
		for k, v in d:GetAttributes() do
			if k:sub(1, 5) == "PreZ5" and k ~= "PreZ5CFrame" then
				d:SetAttribute(k:sub(6), v)
				d:SetAttribute(k, nil)
				restored += 1
			end
		end
	end
end
local made = map:FindFirstChild("MainRoad")
if made then
	made:Destroy()
end
map:SetAttribute("MainRoad", nil)
map:SetAttribute("Zone3Move5", nil)
return ("Z5 undo: %d unparked, %d moved back, %d values restored, %d created removed"):format(back, moved, restored, removed)
