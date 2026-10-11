-- Studio location: ServerStorage.Build027.B4_MainStreet (ModuleScript)
-- Zone 1 Main Street at the west end of the strip: the NPC area (Workspace.Zones.MainStreet: its
-- ZoneBoundary and SpawnPoints move together, unchanged in size) ringed by simple, colourful
-- shopfronts that stay outside the boundary + 4-stud wander margin (NPCs never meet a prop).

local K = require(script.Parent.Kit)
local C, L = K.C, K.L

local SHOPS = { -- name, colour, roof style
	{ "PENNY'S COFFEE", K.rgb(255, 196, 140), "flat" }, { "BOB'S BARGAINS", K.rgb(150, 206, 255), "peak" },
	{ "COURIER CO.", K.rgb(176, 230, 150), "flat" }, { "MALL MART", K.rgb(255, 170, 190), "peak" },
	{ "GADGET HUT", K.rgb(200, 170, 255), "flat" }, { "SWEET SHOP", K.rgb(255, 222, 120), "peak" },
	{ "COMIC CORNER", K.rgb(130, 220, 210), "flat" }, { "BIKE BARN", K.rgb(255, 160, 120), "peak" },
}

-- One shopfront, front facing the street (-Z of cf), base on the ground.
local function shop(parent: Instance, cf: CFrame, w: number, d: number, h: number, def)
	local m = Instance.new("Model")
	m.Name = def[1]
	local body = def[2]
	K.part({ name = "Body", parent = m, size = Vector3.new(w, h, d), cf = cf * CFrame.new(0, h / 2, 0), color = body })
	K.part({ name = "Plinth", parent = m, size = Vector3.new(w + 0.4, 1, d + 0.4), cf = cf * CFrame.new(0, 0.5, 0), color = C.Stone })
	K.part({ name = "Cornice", parent = m, size = Vector3.new(w + 0.8, 0.8, d + 0.8), cf = cf * CFrame.new(0, h + 0.4, 0), color = C.Trim })
	if def[3] == "peak" then
		K.part({ name = "Roof", parent = m, shape = "Wedge", size = Vector3.new(w, 3.2, d / 2), cf = cf * CFrame.new(0, h + 2.4, -d / 4), color = C.Coral, deco = true })
		K.part({ name = "Roof", parent = m, shape = "Wedge", size = Vector3.new(w, 3.2, d / 2), cf = cf * CFrame.new(0, h + 2.4, d / 4) * CFrame.Angles(0, math.pi, 0), color = C.Coral, deco = true })
	else
		K.part({ name = "Parapet", parent = m, size = Vector3.new(w - 2, 1.4, 0.8), cf = cf * CFrame.new(0, h + 1.5, -d / 2 + 0.6), color = body:Lerp(Color3.new(1, 1, 1), 0.4), deco = true })
	end
	K.part({ name = "Door", parent = m, size = Vector3.new(3.6, 6.4, 0.4), cf = cf * CFrame.new(0, 4.2, -d / 2 - 0.15), color = C.Navy, deco = true })
	for _, sx in { -w / 2 + 3.6, w / 2 - 3.6 } do
		K.part({ name = "Window", parent = m, size = Vector3.new(4.2, 3.8, 0.4), cf = cf * CFrame.new(sx, 4.8, -d / 2 - 0.15), color = K.rgb(200, 236, 255), mat = Enum.Material.Glass, transparency = 0.15, deco = true })
	end
	K.part({ name = "Awning", parent = m, shape = "Wedge", size = Vector3.new(w - 1, 1.2, 2.6), cf = cf * CFrame.new(0, 8.4, -d / 2 - 1.3) * CFrame.Angles(0, math.pi, 0), color = C.Carpet, deco = true })
	local sign = K.part({ name = "Sign", parent = m, size = Vector3.new(w - 3, 2.2, 0.4), cf = cf * CFrame.new(0, 10.4, -d / 2 - 0.25), color = C.Curb, deco = true })
	K.text(sign, Enum.NormalId.Front, def[1], C.Navy)
	m.Parent = parent
	return m
end

return function(): string
	local root = K.folder(K.root(), "MainStreet", true)
	-- Move the NPC area (boundary + spawn points) so its centre is at L.mainStreet.
	local zone = workspace.Zones.MainStreet
	local boundary = zone.ZoneBoundary :: BasePart
	if boundary:GetAttribute("Pre027Position") == nil then
		boundary:SetAttribute("Pre027Position", boundary.Position)
	end
	local delta = Vector3.new(L.mainStreet.X - boundary.Position.X, 0, L.mainStreet.Z - boundary.Position.Z)
	boundary.Position += delta
	for _, sp in zone.SpawnPoints:GetChildren() do
		if sp:IsA("BasePart") then
			sp.Position = Vector3.new(sp.Position.X + delta.X, L.pavingTop + sp.Size.Y / 2, sp.Position.Z + delta.Z)
		end
	end
	local half = boundary.Size / 2
	local bx0, bx1 = boundary.Position.X - half.X, boundary.Position.X + half.X
	local bz0, bz1 = boundary.Position.Z - half.Z, boundary.Position.Z + half.Z

	-- North and south rows (3 shops each) face the street; the west end has 2 facing east.
	local fronts = K.folder(root, "Shopfronts")
	local i = 0
	local top = L.pavingTop
	for col = 0, 2 do
		local x = bx0 + 11 + col * 21
		i += 1
		shop(fronts, CFrame.new(x, top, bz1 + 4 + 6.5), 19, 13, 11 + (col % 2) * 2, SHOPS[i])
		i += 1
		shop(fronts, CFrame.new(x, top, bz0 - 4 - 6.5) * CFrame.Angles(0, math.pi, 0), 19, 13, 12 - (col % 2) * 1.5, SHOPS[i])
	end
	for _, z in { L.mainStreet.Z - 13, L.mainStreet.Z + 13 } do
		i += 1
		shop(fronts, CFrame.new(bx0 - 4 - 6.5, top, z) * CFrame.Angles(0, -math.pi / 2, 0), 22, 13, 12, SHOPS[i])
	end

	-- A few lamps at the corners of the street (two with lights).
	local lamps = K.folder(root, "Lamps")
	for k, p in { Vector2.new(bx0 - 1.5, bz1 + 2), Vector2.new(bx0 - 1.5, bz0 - 2), Vector2.new(bx1 + 1, bz1 + 2), Vector2.new(bx1 + 1, bz0 - 2) } do
		local lamp = K.place("M_Lamp", CFrame.new(p.X, top, p.Y), lamps)
		if k > 2 then
			local glass = lamp:FindFirstChild("Glass", true)
			local light = Instance.new("PointLight")
			light.Range, light.Brightness, light.Color, light.Shadows = 18, 1.1, C.Glow, false
			light.Parent = glass
		end
	end
	return ("main street: boundary now x %.0f..%.0f z %.0f..%.0f; %d parts"):format(bx0, bx1, bz0, bz1, K.count(root))
end
