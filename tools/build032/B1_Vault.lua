-- Studio location: ServerStorage.Build032.B1_Vault (ModuleScript)
-- Milestone 032 build step (Edit mode, run from the command bar / MCP; re-runnable):
-- builds ServerStorage.HeistVault032, the Boss Heist template read by HeistService, from the Blender imports
-- in ServerStorage.Heist032Imports (SecurityBot, VaultDoor, BossCapsule; imported at 100 studs per Blender
-- unit, front = -Z). Nothing goes into the world here: HeistService clones the visible parts into
-- Workspace.World.SkyCity.Heist while the heist is on.
-- Place: the far (uphill) end of the T1 Main Street terrace (floor y 12), both corners beside the ramp up to
-- T2 (ramp x -169..-145 from z -342), behind the last two shopfronts (they end at z -330):
--   Vault (west corner, x -195..-170, z -349..-332): round vault door facing east onto the ramp mouth, a
--     glowing chamber with a capsule pile behind it, BOSS VAULT signs (south over the shop roofs + east above
--     the door), two siren beacons. Door (Door/DoorStar/Hinges) swings on the client about the Hinge
--     attribute; Wheel spins. HoleBlock keeps players out of the chamber.
--   Bay (east corner, x -140.5..-118): the robot's charging pad, back wall with gold stripes, canopy, sign.
--   Robot: the security robot (~22 studs), every part anchored and non-colliding; attributes per part:
--     Group (Body/Head/ArmL/ArmR/LegL/LegR/Light), Rest (CFrame in robot space: feet centre, facing -Z),
--     Pivot (Vector3 in robot space). The clients move it (HeistClient); the server never does.
--   GrabSpot (invisible, gets the ProximityPrompt), DockSpot / GuardSpot (invisible markers, facing = the
--   robot's facing there), CapsuleMaster (the carried capsule, PrimaryPart Base).
--   Server only (stay in ServerStorage): RobotArea = boxes the robot may stand in (apron + bay, the street,
--   the ramp down to the safe line).

local ServerStorage = game:GetService("ServerStorage")

local FLOOR = 12.0 -- terrace top in both corners (Island4)
local S_ROBOT, S_DOOR, S_CAP = 3.6, 3.5, 1.9 -- studs per Blender unit
local DOOR_X, DOOR_Z = -171.9, -340.5 -- vault door origin (frame bottom centre), faces +X
local DOCK = CFrame.lookAt(Vector3.new(-130, 12.6, -341), Vector3.new(-200, 12.6, -341))
local GUARD = CFrame.lookAt(Vector3.new(-157, 12.3, -336), Vector3.new(-157, 12.3, -200))

local C = {
	navy = Color3.fromRGB(40, 52, 92),
	navyDark = Color3.fromRGB(28, 36, 66),
	gold = Color3.fromRGB(240, 186, 58),
	goldDark = Color3.fromRGB(214, 140, 30),
	cream = Color3.fromRGB(250, 240, 215),
	plaster = Color3.fromRGB(236, 224, 200),
	sandstone = Color3.fromRGB(204, 184, 150),
	steel = Color3.fromRGB(170, 178, 192),
	steelDark = Color3.fromRGB(88, 96, 112),
	ink = Color3.fromRGB(26, 24, 34),
	cyan = Color3.fromRGB(80, 230, 255),
	amber = Color3.fromRGB(255, 160, 40),
	white = Color3.fromRGB(248, 248, 252),
	pink = Color3.fromRGB(255, 140, 166),
	purple = Color3.fromRGB(155, 90, 240),
	glass = Color3.fromRGB(190, 230, 255),
}
local NEON = { cyan = true, amber = true }

-- Blender colour key of every imported part (assets/export/032/heist/parts.json)
local COLOUR = {
	Torso = "navy",
	Chest = "cream",
	Badge = "gold",
	Belt = "gold",
	Hips = "steelDark",
	Neck = "steelDark",
	Head = "cream",
	Visor = "ink",
	EyeL = "cyan",
	EyeR = "cyan",
	EarL = "gold",
	EarR = "gold",
	Smile = "cyan",
	SirenBase = "steelDark",
	Siren = "amber",
	ShoulderL = "gold",
	ArmL = "steelDark",
	HandL = "cream",
	ShoulderR = "gold",
	ArmR = "steelDark",
	HandR = "cream",
	LegL = "steelDark",
	FootL = "navy",
	ToeL = "gold",
	LegR = "steelDark",
	FootR = "navy",
	ToeR = "gold",
	LightMount = "steelDark",
	Searchlight = "steel",
	Lens = "gold",
	Pack = "steel",
	Charge = "cyan",
	Frame = "steelDark",
	Trim = "gold",
	Rivets = "gold",
	Door = "steel",
	DoorStar = "gold",
	Hinges = "steelDark",
	Wheel = "gold",
	Base = "gold",
	Dome = "glass",
	Band = "purple",
	Star = "cream",
}
-- Robot animation groups: Blender pivot (x, y, z) per group; parts not listed are Body (pivot = hips).
local GROUPS = {
	Head = { pivot = Vector3.new(0, 0, 4.4), parts = { "Neck", "Head", "Visor", "EyeL", "EyeR", "EarL", "EarR", "Smile", "SirenBase", "Siren" } },
	ArmL = { pivot = Vector3.new(-1.4, 0, 3.75), parts = { "ShoulderL", "ArmL", "HandL" } },
	ArmR = { pivot = Vector3.new(1.4, 0, 3.75), parts = { "ShoulderR", "ArmR", "HandR" } },
	LegL = { pivot = Vector3.new(-0.55, 0, 1.9), parts = { "LegL", "FootL", "ToeL" } },
	LegR = { pivot = Vector3.new(0.55, 0, 1.9), parts = { "LegR", "FootR", "ToeR" } },
	Light = { pivot = Vector3.new(1.4, 0, 4.25), parts = { "LightMount", "Searchlight", "Lens" } },
}
local BODY_PIVOT = Vector3.new(0, 0, 2.2)

-- Blender point -> robot/door/capsule space in studs (import: x flipped, Blender z up = Roblox y, Blender y = Roblox z)
local function fromBlender(b: Vector3, s: number): Vector3
	return Vector3.new(-b.X, b.Z, b.Y) * s
end

local function part(o: any): BasePart
	local p: BasePart
	if o.shape == "Cylinder" or o.shape == "Ball" then
		p = Instance.new("Part");
		(p :: Part).Shape = Enum.PartType[o.shape]
	else
		p = Instance.new("Part")
	end
	p.Name = o.name or "Part"
	p.Anchored = true
	p.Size = o.size
	p.CFrame = o.cf or CFrame.new(o.pos)
	p.Color = o.color or C.plaster
	p.Material = o.mat or Enum.Material.SmoothPlastic
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Transparency = o.transparency or 0
	if o.deco or o.ghost then
		p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
	end
	if o.ghost then
		p.Transparency = 1
		p.CastShadow = false
	end
	if o.shadow == false then
		p.CastShadow = false
	end
	p.Parent = o.parent
	return p
end

-- Clones an imported model, scales it to `s` studs per Blender unit about its Blender origin, colours it and
-- places it at `place`. Returns the clone; every MeshPart gets attribute Local (Vector3 in model space).
local function fit(source: Model, s: number, origin: Vector3, place: CFrame, name: string): Model
	local model = source:Clone()
	model.Name = name
	for _, p in model:GetDescendants() do
		if p:IsA("MeshPart") then
			local key = p.Name:match("_(.+)$") or p.Name
			local rel = (p.Position - origin) * (s / 100)
			p.Size = p.Size * (s / 100)
			p.CFrame = place * CFrame.new(rel)
			p.Name = key
			p.Anchored = true
			local colour = COLOUR[key] or "steel"
			p.Color = C[colour]
			p.Material = if NEON[colour] then Enum.Material.Neon elseif colour == "steelDark" then Enum.Material.Metal else Enum.Material.SmoothPlastic
			p.Transparency = if colour == "glass" then 0.35 else 0
			p:SetAttribute("Local", rel)
		elseif not p:IsA("Model") then
			p:Destroy() -- (importer extras)
		end
	end
	return model
end

local function deco(model: Instance)
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
		end
	end
end

local function folder(parent: Instance, name: string): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

return function()
	local imports = ServerStorage:FindFirstChild("Heist032Imports")
	assert(imports, "ServerStorage.Heist032Imports is missing (import the 032 FBX files first)")
	local botSrc, doorSrc, capSrc = imports:FindFirstChild("SecurityBot"), imports:FindFirstChild("VaultDoor"), imports:FindFirstChild("BossCapsule")
	assert(botSrc and doorSrc and capSrc, "need SecurityBot, VaultDoor and BossCapsule in Heist032Imports")

	local old = ServerStorage:FindFirstChild("HeistVault032")
	if old then
		old:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "HeistVault032"

	-- Vault ------------------------------------------------------------------------------------------------
	local vault = Instance.new("Model")
	vault.Name = "Vault"
	vault.Parent = root
	local shell = folder(vault, "Shell")
	-- main building (x -195..-179.5, between the two corner trees and the chamber; its south face stays behind
	-- the COMIC CORNER shop, which ends at z -332.9): base trim, plaster body, navy band + pilasters, gold cornice
	local BX, BZ, BW, BD = -187.25, -341.05, 15.5, 15.7
	part({ name = "Plinth", size = Vector3.new(BW + 0.6, 1, BD + 0.3), pos = Vector3.new(BX, FLOOR + 0.5, BZ), color = C.sandstone, mat = Enum.Material.Sandstone, parent = shell })
	part({ name = "Body", size = Vector3.new(BW, 20, BD - 0.3), pos = Vector3.new(BX, FLOOR + 11, BZ), color = C.plaster, parent = shell })
	part({ name = "Band", size = Vector3.new(BW + 0.3, 1.6, BD), pos = Vector3.new(BX, FLOOR + 10, BZ), color = C.navy, mat = Enum.Material.Metal, parent = shell })
	for _, x in { BX - BW / 2 + 0.6, BX + BW / 2 - 0.6 } do
		for _, z in { BZ - BD / 2 + 0.6, BZ + BD / 2 - 0.6 } do
			part({ name = "Pilaster", size = Vector3.new(1.4, 20, 1.4), pos = Vector3.new(x, FLOOR + 11, z), color = C.navy, mat = Enum.Material.Metal, parent = shell })
		end
	end
	part({ name = "Cornice", size = Vector3.new(BW + 0.9, 1.1, BD + 0.3), pos = Vector3.new(BX, FLOOR + 21.55, BZ), color = C.gold, parent = shell })
	part({ name = "RoofCap", size = Vector3.new(BW - 3, 1.4, BD - 3), pos = Vector3.new(BX, FLOOR + 22.8, BZ), color = C.navy, mat = Enum.Material.Metal, parent = shell })
	-- chamber between the building and the door frame: side walls, roof, glowing back, pedestal + capsules
	part({
		name = "ChamberWallS",
		size = Vector3.new(6.2, 17.4, 0.8),
		pos = Vector3.new(-176.5, FLOOR + 8.7, -332.4),
		color = C.steelDark,
		mat = Enum.Material.Metal,
		parent = shell,
	})
	part({
		name = "ChamberWallN",
		size = Vector3.new(6.2, 17.4, 0.8),
		pos = Vector3.new(-176.5, FLOOR + 8.7, -348.6),
		color = C.steelDark,
		mat = Enum.Material.Metal,
		parent = shell,
	})
	part({ name = "ChamberRoof", size = Vector3.new(6.6, 1, 17.6), pos = Vector3.new(-176.4, FLOOR + 17.6, -340.5), color = C.navy, mat = Enum.Material.Metal, parent = shell })
	part({ name = "ChamberFloor", size = Vector3.new(5.8, 0.4, 15.4), pos = Vector3.new(-176.5, FLOOR + 0.2, -340.5), color = C.navyDark, parent = shell })
	part({
		name = "Glow",
		shape = "Cylinder",
		size = Vector3.new(0.3, 12, 12),
		cf = CFrame.new(-179.35, FLOOR + 8.4, DOOR_Z),
		color = C.gold,
		mat = Enum.Material.Neon,
		transparency = 0.15,
		deco = true,
		shadow = false,
		parent = shell,
	})
	part({
		name = "Pedestal",
		shape = "Cylinder",
		size = Vector3.new(2.2, 5, 5),
		cf = CFrame.new(-176.8, FLOOR + 1.1, DOOR_Z) * CFrame.Angles(0, 0, math.rad(90)),
		color = C.navy,
		mat = Enum.Material.Metal,
		parent = shell,
	})
	-- door frame + door + wheel (the door swings out toward +X about the Hinge, on the client)
	local doorOrigin = doorSrc:FindFirstChild("VaultDoor_Frame") :: BasePart
	local dO = doorOrigin.Position - Vector3.new(0, 240, 15) -- Blender (0, 0.15, 2.4) is the frame's centre
	local doorPlace = CFrame.new(DOOR_X, FLOOR, DOOR_Z) * CFrame.Angles(0, math.rad(-90), 0)
	local door = fit(doorSrc, S_DOOR, dO, doorPlace, "Door")
	door.Parent = vault
	local hinge = doorPlace * fromBlender(Vector3.new(-1.85, 0, 2.4), S_DOOR)
	local wheelCentre = doorPlace * fromBlender(Vector3.new(0, -0.5, 2.4), S_DOOR)
	for _, p in door:GetChildren() do
		if p:IsA("BasePart") then
			p.CastShadow = p.Name == "Frame" or p.Name == "Door"
			if p.Name == "Door" or p.Name == "DoorStar" or p.Name == "Hinges" or p.Name == "Wheel" then
				p.CanCollide, p.CanQuery, p.CanTouch = false, false, false -- (moved on the client)
				p:SetAttribute("Swing", true)
			end
		end
	end
	door:SetAttribute("Hinge", hinge)
	door:SetAttribute("WheelCentre", wheelCentre)
	door:SetAttribute("Axis", doorPlace.LookVector) -- the wheel spins about the door's facing (+X)
	part({ name = "HoleBlock", shape = "Cylinder", size = Vector3.new(1, 13.4, 13.4), cf = CFrame.new(DOOR_X - 0.8, FLOOR + 8.4, DOOR_Z), ghost = true, parent = vault }).CanCollide =
		true
	-- signs: BOSS VAULT over the shop roofs (south) and above the door (east); HeistService adds the text
	for _, x in { BX - 6.5, BX + 6.5 } do
		part({ name = "SignPost", size = Vector3.new(0.8, 6, 0.8), pos = Vector3.new(x, FLOOR + 25.5, -334.2), color = C.navy, mat = Enum.Material.Metal, parent = shell })
	end
	local sign = part({
		name = "Sign",
		size = Vector3.new(18, 8, 0.6),
		cf = CFrame.lookAt(Vector3.new(BX, FLOOR + 27.4, -333.5), Vector3.new(BX, FLOOR + 27.4, -300)),
		color = C.navyDark,
		parent = vault,
	})
	part({ name = "SignTrim", size = Vector3.new(18.8, 8.8, 0.4), cf = sign.CFrame * CFrame.new(0, 0, 0.4), color = C.gold, parent = shell })
	local doorSign = part({
		name = "DoorSign",
		size = Vector3.new(13, 4.6, 0.5),
		cf = CFrame.lookAt(Vector3.new(-173.4, FLOOR + 20.6, DOOR_Z), Vector3.new(-100, FLOOR + 20.6, DOOR_Z)),
		color = C.navyDark,
		parent = vault,
	})
	part({ name = "DoorSignTrim", size = Vector3.new(13.8, 5.4, 0.3), cf = doorSign.CFrame * CFrame.new(0, 0, 0.35), color = C.gold, parent = shell })
	-- siren beacons on the chamber roof (the client flashes them while the vault is open)
	for i, z in { -333.6, -347.4 } do
		part({
			name = "BeaconBase",
			shape = "Cylinder",
			size = Vector3.new(0.6, 2.6, 2.6),
			cf = CFrame.new(-176.4, FLOOR + 18.4, z) * CFrame.Angles(0, 0, math.rad(90)),
			color = C.steelDark,
			parent = shell,
		})
		local b = part({
			name = "Beacon" .. i,
			shape = "Ball",
			size = Vector3.new(2.2, 2.2, 2.2),
			pos = Vector3.new(-176.4, FLOOR + 19.4, z),
			color = C.amber,
			mat = Enum.Material.Neon,
			deco = true,
			parent = vault,
		})
		local light = Instance.new("PointLight")
		light.Name = "Flash"
		light.Color = C.amber
		light.Range = 24
		light.Brightness = 3
		light.Enabled = false
		light.Parent = b
	end
	-- capsule master + the pile on the pedestal
	local capO = (capSrc:FindFirstChild("BossCapsule_Base") :: BasePart).Position
	local master = fit(capSrc, S_CAP, capO, CFrame.new(), "CapsuleMaster")
	master.PrimaryPart = master:FindFirstChild("Base") :: BasePart
	deco(master)
	master.Parent = root
	local pile = folder(vault, "Pile")
	for i, off in { Vector3.new(0, 0, -1.6), Vector3.new(0, 0, 1.6), Vector3.new(0, 2.4, 0) } do
		local c = master:Clone()
		c.Name = "Capsule" .. i
		c:PivotTo(CFrame.new(-176.8 + off.X, FLOOR + 3.4 + off.Y, DOOR_Z + off.Z) * CFrame.Angles(0, math.rad(-90 + i * 25), 0))
		c.Parent = pile
	end
	part({ name = "GrabSpot", size = Vector3.new(4, 5, 9), pos = Vector3.new(-168.6, FLOOR + 2.8, DOOR_Z), ghost = true, parent = root })

	-- Bay --------------------------------------------------------------------------------------------------
	local bay = Instance.new("Model")
	bay.Name = "Bay"
	bay.Parent = root
	-- (x -140.5..-118, in front of the three corner trees; north of BIKE BARN, which ends at z -332.9)
	local by, PX, PZ = 12.3, -130, -341
	part({ name = "PadTrim", size = Vector3.new(21, 0.4, 15), pos = Vector3.new(PX, by - 0.1, PZ), color = C.gold, parent = bay })
	part({ name = "Pad", size = Vector3.new(20, 0.6, 14), pos = Vector3.new(PX, by + 0.1, PZ), color = C.navy, mat = Enum.Material.Metal, parent = bay })
	part({
		name = "Ring",
		shape = "Cylinder",
		size = Vector3.new(0.12, 12, 12),
		cf = CFrame.new(PX, by + 0.43, PZ) * CFrame.Angles(0, 0, math.rad(90)),
		color = C.cyan,
		mat = Enum.Material.Neon,
		deco = true,
		shadow = false,
		parent = bay,
	})
	part({
		name = "RingInner",
		shape = "Cylinder",
		size = Vector3.new(0.14, 10, 10),
		cf = CFrame.new(PX, by + 0.44, PZ) * CFrame.Angles(0, 0, math.rad(90)),
		color = C.navyDark,
		deco = true,
		shadow = false,
		parent = bay,
	})
	part({ name = "BackWall", size = Vector3.new(1.6, 18, 15), pos = Vector3.new(-118.8, by + 9, PZ), color = C.steelDark, mat = Enum.Material.Metal, parent = bay })
	for i, y in { 3, 7, 11 } do
		part({ name = "Stripe" .. i, size = Vector3.new(0.3, 1.4, 14.4), pos = Vector3.new(-119.75, by + y, PZ), color = C.gold, deco = true, parent = bay })
	end
	part({ name = "Charger", size = Vector3.new(1.2, 6, 4), pos = Vector3.new(-120.2, by + 7.5, PZ), color = C.navy, mat = Enum.Material.Metal, parent = bay })
	part({ name = "ChargerLight", size = Vector3.new(0.2, 4.4, 0.8), pos = Vector3.new(-120.85, by + 7.5, PZ), color = C.cyan, mat = Enum.Material.Neon, deco = true, parent = bay })
	for _, z in { PZ + 6.8, PZ - 6.8 } do
		part({ name = "Post", size = Vector3.new(1.1, 18, 1.1), pos = Vector3.new(-139.4, by + 9, z), color = C.steel, mat = Enum.Material.Metal, parent = bay })
		part({ name = "PostFoot", size = Vector3.new(1.8, 0.8, 1.8), pos = Vector3.new(-139.4, by + 0.4, z), color = C.gold, parent = bay })
	end
	part({ name = "Canopy", size = Vector3.new(21.5, 1, 15.5), pos = Vector3.new(-129.4, by + 18.5, PZ), color = C.navy, mat = Enum.Material.Metal, parent = bay })
	part({ name = "CanopyEdge", size = Vector3.new(0.5, 1.4, 15.9), pos = Vector3.new(-140.3, by + 18.5, PZ), color = C.gold, parent = bay })
	local baySign = part({
		name = "BaySign",
		size = Vector3.new(12, 2.4, 0.4),
		cf = CFrame.lookAt(Vector3.new(-140.6, by + 16.6, PZ), Vector3.new(-200, by + 16.6, PZ)),
		color = C.navyDark,
		parent = bay,
	})
	baySign.CanCollide = false
	part({
		name = "Lamp",
		shape = "Ball",
		size = Vector3.new(1.6, 1.6, 1.6),
		pos = Vector3.new(-129.4, by + 19.6, PZ),
		color = C.amber,
		mat = Enum.Material.Neon,
		deco = true,
		parent = bay,
	})
	part({ name = "DockSpot", size = Vector3.new(2, 1, 2), cf = DOCK, ghost = true, parent = root })
	part({ name = "GuardSpot", size = Vector3.new(2, 1, 2), cf = GUARD, ghost = true, parent = root })

	-- Robot ------------------------------------------------------------------------------------------------
	local torso = botSrc:FindFirstChild("SecurityBot_Torso") :: BasePart
	local minY = math.huge
	for _, p in botSrc:GetDescendants() do
		if p:IsA("BasePart") then
			minY = math.min(minY, p.Position.Y - p.Size.Y / 2)
		end
	end
	local rO = Vector3.new(torso.Position.X, minY, torso.Position.Z) -- Blender origin = between the feet, on the ground
	local robot = fit(botSrc, S_ROBOT, rO, DOCK, "Robot")
	local groupOf = {}
	for g, def in GROUPS do
		for _, n in def.parts do
			groupOf[n] = g
		end
	end
	for _, p in robot:GetChildren() do
		if p:IsA("BasePart") then
			local g = groupOf[p.Name] or "Body"
			p:SetAttribute("Group", g)
			p:SetAttribute("Rest", CFrame.new(p:GetAttribute("Local") :: Vector3))
			p:SetAttribute("Pivot", fromBlender(if GROUPS[g] then GROUPS[g].pivot else BODY_PIVOT, S_ROBOT))
			p:SetAttribute("Local", nil)
			p.CastShadow = p.Size.Magnitude > 3
		end
	end
	robot.PrimaryPart = robot:FindFirstChild("Torso") :: BasePart
	robot.WorldPivot = DOCK
	deco(robot)
	robot.Parent = root

	-- Robot area (server only) ------------------------------------------------------------------------------
	local area = folder(root, "RobotArea")
	part({ name = "Apron", size = Vector3.new(40, 1, 13), pos = Vector3.new(-148, 12, -340.5), ghost = true, parent = area })
	part({ name = "Street", size = Vector3.new(36, 1, 170), pos = Vector3.new(-157, 12, -249), ghost = true, parent = area })
	part({ name = "Ramp", size = Vector3.new(16, 1, 46), pos = Vector3.new(-157, 6, -141), ghost = true, parent = area })

	for _, p in root:GetDescendants() do
		if p:IsA("BasePart") and p.Parent ~= area and p.Name ~= "GrabSpot" and p.Name ~= "DockSpot" and p.Name ~= "GuardSpot" and p.Transparency < 1 then
			p.Anchored = true
		end
	end
	-- StreamingEnabled: the vault, bay and robot are always on every client (~100 parts), so the door, signs
	-- and the chasing robot never go missing; Parts = how many parts the client should wait for.
	for _, m in { vault, bay, robot } do
		m.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	end
	robot:SetAttribute("Parts", #robot:GetChildren())
	local swingCount = 0
	for _, p in door:GetChildren() do
		if p:GetAttribute("Swing") then
			swingCount += 1
		end
	end
	door:SetAttribute("Parts", swingCount)
	root.Parent = ServerStorage
	local count = 0
	for _, p in root:GetDescendants() do
		if p:IsA("BasePart") and p.Parent ~= area then
			count += 1
		end
	end
	return ("HeistVault032 built: %d parts (robot %d)"):format(count, #robot:GetChildren())
end
