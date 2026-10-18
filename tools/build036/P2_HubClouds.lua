-- tools/build036/P2_HubClouds.lua (D48 step 4): soft cloud banks below and around the hub where the sea plane was, in the lane
-- clouds' style (big white SmoothPlastic blocks, Transparency 0.12). No collision / query / touch, no shadows. Re-runnable;
-- UNDO = true removes them. Hub island x -176..140, z -70..62; plaza island x 123..220; the sea was x 112..1024.
local UNDO = false

local sky = workspace:WaitForChild("World").SkyCity
local old = sky:FindFirstChild("HubClouds048")
if old then
	old:Destroy()
end
if UNDO then
	return "P2 undone: no hub clouds"
end
local folder = Instance.new("Folder")
folder.Name = "HubClouds048"
local n = 0
local function cloud(center: Vector3, size: Vector3, turn: number)
	for i, off in { Vector3.zero, Vector3.new(size.X * 0.35, size.Y * 0.25, size.Z * 0.2) } do
		local p = Instance.new("Part")
		p.Name = "Cloud"
		p.Anchored = true
		p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = false, false, false, false
		p.Material = Enum.Material.SmoothPlastic
		p.Color = Color3.new(1, 1, 1)
		p.Transparency = 0.12
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.Size = if i == 1 then size else size * Vector3.new(0.6, 0.7, 0.65)
		p.CFrame = CFrame.new(center) * CFrame.Angles(0, math.rad(turn), 0) * CFrame.new(off)
		p.Parent = folder
		n += 1
	end
end
-- east, where the sea was
cloud(Vector3.new(250, -22, -40), Vector3.new(90, 22, 70), 10)
cloud(Vector3.new(260, -30, 70), Vector3.new(80, 20, 64), -14)
cloud(Vector3.new(360, -26, -10), Vector3.new(96, 24, 70), 22)
cloud(Vector3.new(330, -34, 140), Vector3.new(78, 20, 60), -6)
cloud(Vector3.new(310, -28, -150), Vector3.new(86, 22, 66), 30)
cloud(Vector3.new(190, -40, 150), Vector3.new(70, 18, 56), 4)
cloud(Vector3.new(180, -38, -140), Vector3.new(72, 18, 56), -20)
-- under and beside the hub island
cloud(Vector3.new(-60, -34, -4), Vector3.new(110, 20, 80), 0)
cloud(Vector3.new(80, -42, 20), Vector3.new(90, 20, 70), 12)
cloud(Vector3.new(-30, -30, 120), Vector3.new(96, 22, 64), -8)
cloud(Vector3.new(60, -32, -120), Vector3.new(90, 22, 64), 16)
cloud(Vector3.new(-240, -30, 20), Vector3.new(80, 20, 70), -18)
folder.Parent = sky
return ("P2: %d cloud parts in SkyCity.HubClouds048"):format(n)
