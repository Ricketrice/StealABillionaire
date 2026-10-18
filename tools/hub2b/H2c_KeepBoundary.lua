-- H2c_KeepBoundary.lua (Hub 2b, part 5 fix): the Keep's ZoneBoundary (48 x 20 x 78) was a quarter turn off its courtyard
-- before Hub 2b (78 across, 48 along); the rigid move kept that. Turned in place so its 78-stud side runs along the
-- courtyard (east-west now). Run once (attr Pre2bTurned guards it); Undo.lua restores Pre2bCFrame (the original).
local b = workspace.Zones.MainStreet.ZoneBoundary
if b:GetAttribute("Pre2bTurned") == nil then
	b:SetAttribute("Pre2bTurned", b.CFrame)
	b.CFrame = b.CFrame * CFrame.Angles(0, math.pi / 2, 0)
end
return "Keep ZoneBoundary look " .. tostring(b.CFrame.LookVector)
