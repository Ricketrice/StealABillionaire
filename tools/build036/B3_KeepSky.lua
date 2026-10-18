-- tools/build036/B3_KeepSky.lua (036 Knight's Keep polish, step 3): the ghost volume that switches on the Keep sky on the client
-- (StarterPlayerScripts.ZoneAmbience, Ambience = "KeepSky"). Covers the Keep's island and the air above it, from just in front of the
-- gate (z -187) to behind the castle (z -337); the Sunken Kingdom starts at z -407. Re-runnable; UNDO = true removes it.
local UNDO = false

local kk = workspace:WaitForChild("World").KnightsKeep
local old = kk:FindFirstChild("KeepSkyVolume036")
if old then
	old:Destroy()
end
if UNDO then
	return "B3 undone: no Keep sky volume"
end
local v = Instance.new("Part")
v.Name = "KeepSkyVolume036"
v.Anchored = true
v.CanCollide, v.CanQuery, v.CanTouch, v.CastShadow = false, false, false, false
v.Transparency = 1
v.Size = Vector3.new(120, 160, 150)
v.CFrame = CFrame.new(-157.5, 40, -262)
v:SetAttribute("Ambience", "KeepSky")
v.Parent = kk
return "B3: KeepSkyVolume036 placed (x -217.5..-97.5, y -40..120, z -187..-337)"
