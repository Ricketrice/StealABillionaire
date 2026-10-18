-- H2b_Portals.lua (Hub 2b, part 2): makes the TeleportHall's three zone portals work. Each gets an invisible
-- PortalTrigger (attr ZoneId, ProximityPrompt "Travel", tag LanePortal): LaneService.hookPortal sends it through the
-- normal Zones teleport (same checks: unlocked, not carrying, not hurt, cooldown). The Sealed_Future portal stays
-- decoration. Re-runnable. Also moves photo spot 4 (Plot 1) with Plot 1. Undo.lua parks HubMap2b.Portals2b.
local CS = game:GetService("CollectionService")
local map = workspace.HubMap2b
local H = map:GetAttribute("HubOrigin")
local ZoneConfig = require(game.ReplicatedStorage.ZoneConfig)
local LaneConfig = require(game.ReplicatedStorage.LaneConfig)
local f = map:FindFirstChild("Portals2b") or Instance.new("Folder")
f.Name = "Portals2b"
f.Parent = map
-- portal markers (Hub2b_Markers.glb): Ember (-21, 20), Sunken (-21, 36), Keep (21, 20), Sealed (21, 36)
for _, row in { { "MainStreet", 21, 20 }, { "SunkenKingdom", -21, 36 }, { "BillionaireHills", -21, 20 } } do
	local id, x, z = row[1], row[2], row[3]
	local zone = ZoneConfig.get(id)
	local p = f:FindFirstChild("PortalTrigger_" .. id) or Instance.new("Part")
	p.Name = "PortalTrigger_" .. id
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.new(4, 6, 4)
	p.CFrame = CFrame.new(H + Vector3.new(x, 3, z))
	p:SetAttribute("ZoneId", id)
	local pr = p:FindFirstChildOfClass("ProximityPrompt") or Instance.new("ProximityPrompt")
	pr.ActionText = "Travel"
	pr.ObjectText = zone and zone.name or id
	pr.HoldDuration = 0
	pr.MaxActivationDistance = 9
	pr.RequiresLineOfSight = false
	pr.Parent = p
	p.Parent = f
	CS:AddTag(p, LaneConfig.PORTAL_TAG)
end
-- photo spot 4 = Plot 1: follow the plot
local spots = game.ServerStorage:FindFirstChild("PhotoSpotsDev")
local plot = workspace.Hub.Plots.Plot1
local was: CFrame? = plot:GetAttribute("Pre2bCFrame")
if spots and was then
	for _, s in spots:GetChildren() do
		if s:IsA("BasePart") and s:GetAttribute("Pre2bCFrame") == nil and (s.Position - was.Position).Magnitude < 80 then
			s:SetAttribute("Pre2bCFrame", s.CFrame)
			CS:AddTag(s, "Moved2b")
			s.CFrame = plot:GetPivot() * was:Inverse() * s.CFrame
		end
	end
end
return "portals: " .. #f:GetChildren()
