-- Z4_Undo.lua: undoes Z4_SideZone3.lua (run before Z3_Undo). Run in Studio Edit via tools/hub2b/run_file.py.
-- Puts parked items back (ServerStorage._ParkedSpellRun, _Parked2b.Zone3Side; attr ParkedFrom), moves MovedZ4 items back
-- (PreZ4CFrame), restores sizes/properties (PreZ4Size / PreZ4Transparency / PreZ4CanCollide / PreZ4CanQuery) and turned
-- attributes (PreZ4Inward / PreZ4Axis), deletes Workspace.HubMap2b.Zone3Side and everything with attr CreatedZ4.
local SS = game:GetService("ServerStorage")
local CS = game:GetService("CollectionService")
local map = workspace.HubMap2b
assert(map:GetAttribute("Zone3Side") == true, "Z4_SideZone3 was not run")

local function resolve(path: string?): Instance?
	local at: Instance? = game
	for name in string.gmatch(path or "", "[^%.]+") do
		at = at and at:FindFirstChild(name)
	end
	return at
end
local back = 0
local function unpark(folder: Instance?)
	if not folder then
		return
	end
	for _, c in folder:GetChildren() do
		local from = c:GetAttribute("ParkedFrom")
		if from then
			local parent = resolve(from)
			if parent then
				c:SetAttribute("ParkedFrom", nil)
				c.Parent = parent
				back += 1
			else
				warn("Z4_Undo: no parent for " .. c:GetFullName() .. " (" .. tostring(from) .. ")")
			end
		end
	end
end
local sr = SS:FindFirstChild("_ParkedSpellRun")
unpark(sr and sr:FindFirstChild("Plaza"))
unpark(sr)
unpark(SS._Parked2b:FindFirstChild("Zone3Side"))
if sr and #sr:GetChildren() <= 1 then
	sr:Destroy()
end
local zs = SS._Parked2b:FindFirstChild("Zone3Side")
if zs and #zs:GetChildren() == 0 then
	zs:Destroy()
end

local moved = 0
for _, inst in CS:GetTagged("MovedZ4") do
	local cf = inst:GetAttribute("PreZ4CFrame")
	if typeof(cf) == "CFrame" then
		if inst:IsA("BasePart") then
			inst.CFrame = cf
		elseif inst:IsA("Model") then
			inst:PivotTo(cf)
		end
		moved += 1
	end
	inst:SetAttribute("PreZ4CFrame", nil)
	CS:RemoveTag(inst, "MovedZ4")
end
local PROPS = { Size = true, Transparency = true, CanCollide = true, CanQuery = true }
local restored, removed = 0, 0
for _, root in { workspace, SS } do
	for _, d in root:GetDescendants() do
		if d:GetAttribute("CreatedZ4") then
			d:Destroy()
			removed += 1
			continue
		end
		for k, v in d:GetAttributes() do
			if k:sub(1, 5) == "PreZ4" and k ~= "PreZ4CFrame" then
				local name = k:sub(6)
				if PROPS[name] then
					(d :: any)[name] = v
				else
					d:SetAttribute(name, v)
				end
				d:SetAttribute(k, nil)
				restored += 1
			end
		end
	end
end
local made = map:FindFirstChild("Zone3Side")
if made then
	made:Destroy()
end
map:SetAttribute("Zone3Side", nil)
map:SetAttribute("Zone3Move4", nil)
return ("Z4 undo: %d unparked, %d moved back, %d values restored, %d created removed"):format(back, moved, restored, removed)
