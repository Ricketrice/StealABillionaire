-- Z1_Undo.lua: reverts Z1_NecroZone3.lua in Studio Edit. Ember's pieces come back from ServerStorage._ParkedEmber,
-- the path guards get their old size/CFrame, Zones.BillionaireHills its old boundary/post/spawn points, and the map
-- goes back to Workspace.necromap as imported (from ServerStorage._Backups.PreZ1_Zone3). _ParkedNecro is removed.
local SS = game:GetService("ServerStorage")
local World = workspace.World
local E = World.EmberAcademy
local pre = SS._Backups:FindFirstChild("PreZ1_Zone3")
assert(pre, "no PreZ1_Zone3 backup")

local map = E:FindFirstChild("Zone3Map")
if map then
	map:Destroy()
end
local parkedNecro = SS:FindFirstChild("_ParkedNecro")
if parkedNecro then
	parkedNecro:Destroy()
end
local back = 0
local pe = SS:FindFirstChild("_ParkedEmber")
for _, item in (if pe then pe:GetChildren() else {}) do
	local from = item:GetAttribute("ParkedFrom")
	local parent = if from == "World.EmberAcademy"
		then E
		elseif from and from:find("VisualFix2b") then workspace.HubMap2b.VisualFix2b.Guards
		elseif from and from:find("BridgeGuards") then World.BridgeGuards
		else nil
	if parent then
		item:SetAttribute("ParkedFrom", nil)
		item.Parent = parent
		back += 1
	end
end
if pe and #pe:GetChildren() == 0 then
	pe:Destroy()
end
for _, g in { workspace.HubMap2b.VisualFix2b.Guards, World.BridgeGuards } do
	for _, p in g:GetChildren() do
		local cf, size = p:GetAttribute("PreZ1CFrame"), p:GetAttribute("PreZ1Size")
		if typeof(cf) == "CFrame" and typeof(size) == "Vector3" then
			p.Size, p.CFrame = size, cf
			p:SetAttribute("PreZ1CFrame", nil)
			p:SetAttribute("PreZ1Size", nil)
		end
	end
end
local zone = workspace.Zones.BillionaireHills
local old = pre:FindFirstChild("BillionaireHills")
for _, name in { "ZoneBoundary", "GuardianPost", "SpawnPoints" } do
	local cur, was = zone:FindFirstChild(name), old and old:FindFirstChild(name)
	if was then
		if cur then
			cur:Destroy()
		end
		was:Clone().Parent = zone
	end
end
local imported = pre:FindFirstChild("necromap")
if imported and not workspace:FindFirstChild("necromap") then
	imported:Clone().Parent = workspace
end
return ("Z1 undone: %d Ember/guard items back"):format(back)
