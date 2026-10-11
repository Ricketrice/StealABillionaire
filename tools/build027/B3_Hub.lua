-- Studio location: ServerStorage.Build027.B3_Hub (ModuleScript)
-- The centre strip's landmarks: spawn medallion, the three shop stalls and the quest board on the spawn
-- square, the Top Billionaires gantry over the lane, the Zone 1 arch, the Golden Vault in the plaza,
-- the battle arena in the plaza's north-west, and the coloured lines from the avenue to each gate.
-- Venue anchors keep their names (Venues/Arena/*, Venues/Shops/*, Venues/NPCs/*); only their
-- positions change.

local K = require(script.Parent.Kit)
local C, L = K.C, K.L

local function anchor(parent: Instance, name: string, cf: CFrame, size: Vector3?): BasePart
	local a = parent:FindFirstChild(name)
	if not (a and a:IsA("BasePart")) then
		a = K.part({ name = name, parent = parent, ghost = true, size = size or Vector3.new(4, 1, 4), cf = cf })
	end
	a.CFrame = cf
	return a :: BasePart
end

return function(): string
	local root = K.folder(K.root(), "Hub", true)
	local venues = workspace.Venues
	local top = L.pavingTop

	-- Spawn: facing down the lane (+X), on a gold medallion.
	local spawn = workspace.SpawnLocation :: SpawnLocation
	spawn.CFrame = CFrame.lookAt(Vector3.new(L.spawn.X, top + 0.2, L.spawn.Z), Vector3.new(L.spawn.X + 10, top + 0.2, L.spawn.Z))
	spawn.Size = Vector3.new(8, 0.4, 8)
	spawn.Transparency = 1
	spawn.CanCollide = false -- players land on the lane; the pad itself must not be a step
	for _, d in spawn:GetChildren() do
		if d:IsA("Decal") then
			d:Destroy()
		end
	end
	local med = K.folder(root, "SpawnMedallion")
	local function disc(name, r, t, color, mat)
		return K.part({ name = name, parent = med, shape = "Cylinder", size = Vector3.new(0.2, r * 2, r * 2), cf = CFrame.new(L.spawn.X, t - 0.1, L.spawn.Z) * CFrame.Angles(0, 0, math.rad(90)), color = color, mat = mat, deco = true })
	end
	-- the spawn sits on the parade lane, so the medallion lies on the carpet
	disc("Ring", 7, L.laneTop + 0.06, C.Trim)
	disc("Inner", 6, L.laneTop + 0.08, C.Curb)
	local coin = disc("Coin", 3, L.laneTop + 0.1, C.Trim, Enum.Material.Neon)
	K.tag(coin, "Fx027Coins")

	-- Stalls (front faces the lane). id, x, north?, awning colour, title
	local shops = venues:WaitForChild("Shops")
	local stalls = K.folder(root, "Stalls")
	local defs = {
		{ "BatBoutique", -167, true, C.Carpet, "BAT BOUTIQUE" },
		{ "LotAndDecor", -146, true, C.Mint, "LOT & DECOR" },
		{ "UpgradeOffice", -167, false, C.Sky, "UPGRADE OFFICE" },
	}
	for _, d in defs do
		local id, x, north, accent, title = d[1], d[2], d[3], d[4], d[5]
		local z = if north then 46 else -54
		local cf = CFrame.new(x, top, z) * (if north then CFrame.new() else CFrame.Angles(0, math.pi, 0))
		local stall = K.place("M_Stall", cf, stalls)
		stall.Name = id
		for _, p in stall:GetDescendants() do
			if p:IsA("BasePart") and p.Name == "AwningB" then
				p.Color = accent
			end
		end
		local sign = K.part({ name = "Sign", parent = stall, size = Vector3.new(11.6, 2.8, 0.5), cf = cf * CFrame.new(0, 10.0, -3.4), color = C.Curb })
		K.part({ name = "SignTrim", parent = stall, size = Vector3.new(12.2, 3.4, 0.4), cf = cf * CFrame.new(0, 10.0, -3.15), color = C.Trim, deco = true })
		K.text(sign, Enum.NormalId.Front, title, C.Navy)
		local light = Instance.new("PointLight")
		light.Range, light.Brightness, light.Color, light.Shadows = 14, 0.9, C.Glow, false
		light.Parent = sign
		local folder = K.folder(shops, id)
		anchor(folder, "Counter", cf * CFrame.new(0, 4.4, -2.3), Vector3.new(9.6, 1, 2.6))
		anchor(folder, "KeeperSpot", cf * CFrame.new(0, 0.9, 0.9))
		anchor(folder, "Display", cf * CFrame.new(0, 3.2, -6))
	end

	-- Quest board (south side of the square) and the Guide (beside the spawn, turned to face it).
	local npcs = venues:WaitForChild("NPCs")
	do
		local cf = CFrame.new(-146, top, -54) * CFrame.Angles(0, math.pi, 0)
		local qb = Instance.new("Model")
		qb.Name = "QuestBoardStand"
		for _, sx in { -4.2, 4.2 } do
			K.part({ name = "Post", parent = qb, size = Vector3.new(0.8, 9, 0.8), cf = cf * CFrame.new(sx, 4.5, 0), color = C.Trim })
		end
		local board = K.part({ name = "Board", parent = qb, size = Vector3.new(8, 5, 0.5), cf = cf * CFrame.new(0, 5.6, 0), color = C.Navy })
		K.part({ name = "BoardTrim", parent = qb, size = Vector3.new(8.6, 5.6, 0.4), cf = cf * CFrame.new(0, 5.6, 0.15), color = C.Trim, deco = true })
		K.part({ name = "Roof", parent = qb, shape = "Wedge", size = Vector3.new(9.6, 1.4, 1.6), cf = cf * CFrame.new(0, 9.4, 0), color = C.Coral, deco = true })
		K.text(board, Enum.NormalId.Front, "DAILY QUESTS", C.Trim)
		qb.Parent = root
		anchor(npcs, "QuestBoard", cf * CFrame.new(0, 0.6, -3.5))
		anchor(npcs, "Guide", CFrame.lookAt(Vector3.new(-146, top + 0.3, 12), Vector3.new(L.spawn.X, top + 0.3, L.spawn.Z)))
	end

	-- Top Billionaires gantry over the lane at the avenue entrance, readable from the spawn.
	do
		local g = K.folder(root, "TopBoardGantry")
		local x = -124 -- 33 studs from the spawn, between the first lamps; the board sits above the eye line
		for _, z in { L.laneZ - 11, L.laneZ + 11 } do
			K.part({ name = "Post", parent = g, size = Vector3.new(1.4, 26, 1.4), pos = Vector3.new(x, top + 13, z), color = C.Trim })
			K.part({ name = "PostBase", parent = g, size = Vector3.new(2.4, 1, 2.4), pos = Vector3.new(x, top + 0.5, z), color = C.Navy })
		end
		K.part({ name = "Beam", parent = g, size = Vector3.new(1.2, 1.2, 23.4), pos = Vector3.new(x, top + 25.6, L.laneZ), color = C.Trim })
		local lb = K.folder(venues, "Leaderboards")
		local board = lb:FindFirstChild("TopBillionaires") or K.part({ name = "TopBillionaires", parent = lb, size = Vector3.new(15, 7, 0.5), pos = Vector3.new(x, top + 19.9, L.laneZ) })
		board.CFrame = CFrame.lookAt(Vector3.new(x, top + 19.9, L.laneZ), Vector3.new(x - 10, top + 17.9, L.laneZ)) -- tilted a little toward the spawn
		board.Size = Vector3.new(15, 6, 0.5)
		board.Color, board.Material = C.Navy, Enum.Material.SmoothPlastic
		board.CanCollide, board.CanQuery, board.CanTouch = false, false, false
		board:ClearAllChildren()
		K.part({ name = "BoardTrim", parent = g, size = Vector3.new(15.8, 6.8, 0.4), cf = board.CFrame * CFrame.new(0, 0, 0.3), color = C.Trim, deco = true })
		local gui = Instance.new("SurfaceGui")
		gui.Name = "Board"
		gui.Face = Enum.NormalId.Front
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 36
		gui.LightInfluence = 0
		gui.MaxDistance = 260
		local title = Instance.new("TextLabel")
		title.Name = "Title"
		title.BackgroundTransparency = 1
		title.Size = UDim2.fromScale(1, 0.26)
		title.Font = Enum.Font.FredokaOne
		title.TextScaled = true
		title.Text = "TOP BILLIONAIRES"
		title.TextColor3 = C.Trim
		title.Parent = gui
		for i = 1, 5 do
			local row = Instance.new("TextLabel")
			row.Name = "Row" .. i
			row.BackgroundTransparency = 1
			row.Position = UDim2.fromScale(0.06, 0.27 + (i - 1) * 0.142)
			row.Size = UDim2.fromScale(0.88, 0.13)
			row.Font = Enum.Font.GothamBold
			row.TextScaled = true
			row.TextXAlignment = Enum.TextXAlignment.Left
			row.TextColor3 = if i == 1 then C.Trim else C.Curb
			row.Text = ("%d.  —"):format(i)
			row.Parent = gui
		end
		gui.Parent = board
	end

	-- Zone 1 arch: where Main Street starts.
	do
		local a = K.folder(root, "Zone1Arch")
		local x = L.zone1GateX
		for _, z in { L.laneZ - 12.5, L.laneZ + 12.5 } do
			K.part({ name = "Pillar", parent = a, size = Vector3.new(2.6, 15, 2.6), pos = Vector3.new(x, top + 7.5, z), color = C.Curb })
			K.part({ name = "PillarCap", parent = a, size = Vector3.new(3.2, 1, 3.2), pos = Vector3.new(x, top + 15.5, z), color = C.Trim })
			K.part({ name = "PillarFoot", parent = a, size = Vector3.new(3.4, 1.2, 3.4), pos = Vector3.new(x, top + 0.6, z), color = C.Trim })
		end
		local beam = K.part({ name = "Beam", parent = a, size = Vector3.new(2.2, 3.6, 27.6), pos = Vector3.new(x, top + 17.6, L.laneZ), color = C.Mint })
		K.part({ name = "BeamTrim", parent = a, size = Vector3.new(2.4, 0.6, 28.2), pos = Vector3.new(x, top + 19.6, L.laneZ), color = C.Trim, deco = true })
		K.text(beam, Enum.NormalId.Left, "MAIN STREET", C.Curb)
		K.text(beam, Enum.NormalId.Right, "MAIN STREET", C.Curb)
	end

	-- Golden Vault at the plaza centre, door facing the lane.
	do
		local v = Instance.new("Model")
		v.Name = "Vault"
		v.ModelStreamingMode = Enum.ModelStreamingMode.Persistent -- the landmark at the end of the lane, 330 studs from the spawn
		v.Parent = root
		local p = L.plaza
		local base = 0.28 -- plaza floor top
		local function ring(name, r, t, color, mat)
			return K.part({ name = name, parent = v, shape = "Cylinder", size = Vector3.new(t - base + 0.2, r * 2, r * 2), cf = CFrame.new(p.X, (t + base - 0.2) / 2, p.Z) * CFrame.Angles(0, 0, math.rad(90)), color = color, mat = mat })
		end
		ring("PlinthTrim", 22, base + 0.8, C.Trim)
		ring("Plinth", 21, base + 1.2, C.Curb)
		local cf = CFrame.lookAt(Vector3.new(p.X, base + 1.2, p.Z), Vector3.new(p.X - 10, base + 1.2, p.Z))
		local vault = K.place("M_Vault", cf, v, 1.3)
		vault.Name = "GoldenVault"
		local doorCf = cf * CFrame.new(0, 6.6, -18.4)
		K.part({ name = "DoorFrame", parent = v, size = Vector3.new(9.4, 11.4, 1.2), cf = doorCf, color = C.Trim })
		local door = K.part({ name = "Door", parent = v, size = Vector3.new(7.4, 9.6, 1.0), cf = doorCf * CFrame.new(0, -0.5, -0.2), color = C.Navy })
		local emblem = K.part({ name = "Emblem", parent = v, shape = "Cylinder", size = Vector3.new(0.4, 4.4, 4.4), cf = doorCf * CFrame.new(0, 0.2, -0.8) * CFrame.Angles(0, math.rad(90), 0), color = C.Trim, mat = Enum.Material.Neon, deco = true })
		K.tag(emblem, "Fx027Sparkle")
		-- one step in front of the trim ring (floor 0.28 -> step 0.68 -> trim 1.08 -> plinth 1.48)
		K.part({ name = "Step", parent = v, size = Vector3.new(12, 0.4, 2), cf = cf * CFrame.new(0, -1.0, -23), color = C.Curb })
		local lantern
		for _, d in vault:GetDescendants() do
			if d:IsA("BasePart") and d.Name == "Lantern" and d.Material == Enum.Material.Neon then
				lantern = d
			end
		end
		if lantern then
			K.tag(lantern, "Fx027Sparkle")
			local light = Instance.new("PointLight")
			light.Range, light.Brightness, light.Color, light.Shadows = 40, 2, C.Glow, false
			light.Parent = lantern
		end
		local sign = K.part({ name = "VaultSign", parent = v, size = Vector3.new(14, 2.6, 0.5), cf = cf * CFrame.new(0, 14.2, -18.9) * CFrame.Angles(math.rad(-8), 0, 0), color = C.Navy })
		K.text(sign, Enum.NormalId.Front, "GOLDEN VAULT", C.Trim)
	end

	-- Arena in the plaza's north-west quadrant (anchors: Venues/Arena/*).
	do
		local ar = K.folder(root, "Arena")
		local arena = venues:WaitForChild("Arena")
		local c = Vector3.new(146, 0.28, 26)
		local function disc(name, r, t, color, mat)
			return K.part({ name = name, parent = ar, shape = "Cylinder", size = Vector3.new(t - c.Y, r * 2, r * 2), cf = CFrame.new(c.X, (t + c.Y) / 2, c.Z) * CFrame.Angles(0, 0, math.rad(90)), color = color, mat = mat })
		end
		disc("RingTrim", 12.5, 0.8, C.Trim)
		disc("Ring", 11.5, 1.0, C.Curb)
		disc("RingInner", 8, 1.05, C.Sky)
		for i = 0, 7 do -- short gold posts round the ring
			local a = i * math.pi / 4 + math.pi / 8
			K.part({ name = "RopePost", parent = ar, size = Vector3.new(0.8, 3.2, 0.8), pos = Vector3.new(c.X + math.cos(a) * 11.6, 2.6, c.Z + math.sin(a) * 11.6), color = C.Trim })
		end
		for _, side in { { "PlatformA", -5.5, C.Coral }, { "PlatformB", 5.5, C.Sky } } do
			local px = c.X + side[2]
			K.part({ name = side[1] .. "Pedestal", parent = ar, shape = "Cylinder", size = Vector3.new(0.8, 6, 6), cf = CFrame.new(px, 1.45, c.Z) * CFrame.Angles(0, 0, math.rad(90)), color = side[3] })
			anchor(arena, side[1], CFrame.new(px, 2.3, c.Z), Vector3.new(6, 1, 6))
		end
		local pads = arena:WaitForChild("QueuePads")
		for i = 1, 4 do
			local pad = pads:FindFirstChild("Pad" .. i) :: BasePart
			if pad then
				pad.CFrame = CFrame.new(c.X - 7.5 + (i - 1) * 5, 0.45, c.Z - 16.5) * CFrame.Angles(0, 0, math.rad(90))
				pad.Color = C.Trim
				pad.Material = Enum.Material.SmoothPlastic
			end
		end
		-- scoreboard behind the ring, facing the lane (HubArena writes to its "Label")
		local sb = anchor(arena, "Scoreboard", CFrame.lookAt(Vector3.new(c.X, 10.5, c.Z + 15), Vector3.new(c.X, 10.5, c.Z)), Vector3.new(20.6, 6.8, 0.2))
		sb.Transparency = 0
		sb.Size = Vector3.new(20.6, 6.8, 0.4)
		sb.Color = C.Navy
		sb:ClearAllChildren()
		K.text(sb, Enum.NormalId.Front, "BATTLE ARENA", C.Trim)
		K.part({ name = "ScoreTrim", parent = ar, size = Vector3.new(21.4, 7.6, 0.4), cf = sb.CFrame * CFrame.new(0, 0, 0.3), color = C.Trim, deco = true })
		for _, sx in { -9.6, 9.6 } do
			K.part({ name = "ScorePost", parent = ar, size = Vector3.new(1, 14, 1), cf = sb.CFrame * CFrame.new(sx, -3.2, 0.6), color = C.Trim })
		end
	end

	-- Coloured lines from the avenue end to each district gate, curving round the Vault.
	do
		local lines = K.folder(root, "GateLines")
		local fz = workspace.World.FutureZones
		local ZONES = {
			{ "Zone2_FoodCourt", Color3.fromRGB(255, 150, 60), 1 }, { "Zone4_ToyTown", Color3.fromRGB(255, 120, 190), 1 },
			{ "Zone5_NeonDowntown", Color3.fromRGB(150, 110, 240), -1 }, { "Zone6_BillionaireHills", C.Trim, -1 },
		}
		local slot = { [1] = 0, [-1] = 0 }
		for _, zdef in ZONES do
			local folder = fz:FindFirstChild(zdef[1])
			local barrier = folder and folder:FindFirstChild("Gate") and folder.Gate:FindFirstChild("Barrier")
			if barrier then
				local side = zdef[3]
				slot[side] += 1
				local off = (slot[side] - 1) * 1.6 * side
				local out = (Vector3.new(barrier.Position.X, 0, barrier.Position.Z) - Vector3.new(L.plaza.X, 0, L.plaza.Z)).Unit
				local finish = Vector3.new(barrier.Position.X, 0, barrier.Position.Z) - out * 7
				local a = Vector3.new(L.avenueX[2] - 2, 0, L.laneZ + side * (10 + off))
				local bend = Vector3.new(140, 0, L.laneZ + side * (34 + off))
				K.bar(lines, zdef[1], a, bend, 0.9, 0.42, 0.2, zdef[2], Enum.Material.Neon, true)
				K.bar(lines, zdef[1], bend, finish, 0.9, 0.42, 0.2, zdef[2], Enum.Material.Neon, true)
			end
		end
	end
	return ("hub: %d parts"):format(K.count(root))
end
