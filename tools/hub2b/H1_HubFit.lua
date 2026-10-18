-- H1_HubFit.lua (Hub 2b, part 1): fit the owner's Import 3D of steal-a-billionaire-hub-2b.glb (Workspace.HubMap2b)
-- as the new hub and move the hub's game pieces into it. Run once in Studio Edit (MCP execute_luau / command bar).
-- Undo: tools/hub2b/Undo.lua (reads what this script records).
--
-- Frame: hub-local studs = GLB metres x 3.5714 (north = -Z, floor top y 0), placed at H. Import 3D gave a half
-- turn about Y at metre scale: undone here (ScaleTo, half turn, translate by Base1's centre).
-- Records: every moved instance gets attr Pre2bCFrame (+ Pre2bSize when resized) and tag Moved2b; parked
-- instances go to ServerStorage._Parked2b with attr ParkedFrom; hidden plot fence parts keep Pre2bTransparency /
-- Pre2bCanCollide (tag Hidden2b). Everything new lives inside HubMap2b (Collision2b, Ext2b, extra bases).
local SS = game:GetService("ServerStorage")
local CS = game:GetService("CollectionService")

local H = Vector3.new(0, 0, 700) -- world position of hub-local (0, 0, 0)
local S = 3.5714

local map = workspace:FindFirstChild("HubMap2b")
assert(map and map:IsA("Model"), "Workspace.HubMap2b missing")
assert(map:GetAttribute("Fit2b") == nil, "already fitted (run Undo.lua first)")
local root = map:FindFirstChild("Hub2b")
assert(root, "HubMap2b.Hub2b missing")
local World = workspace.World
local City = World.SkyCity

local function folder(parent: Instance, name: string): Instance
	local f = parent:FindFirstChild(name)
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = parent
	end
	return f
end
local backups = folder(folder(SS, "_Backups"), "Pre2b")
local parked = folder(SS, "_Parked2b")
local log = {}
local function say(s)
	table.insert(log, s)
end
local function L(x, y, z): Vector3
	return H + Vector3.new(x, y, z)
end

local function moveTo(inst: Instance, cf: CFrame)
	if inst:GetAttribute("Pre2bCFrame") == nil then
		inst:SetAttribute("Pre2bCFrame", if inst:IsA("BasePart") then inst.CFrame else (inst :: Model):GetPivot())
		CS:AddTag(inst, "Moved2b")
	end
	if inst:IsA("BasePart") then
		inst.CFrame = cf
	else
		(inst :: Model):PivotTo(cf)
	end
end
local function resize(part: BasePart, size: Vector3)
	if part:GetAttribute("Pre2bSize") == nil then
		part:SetAttribute("Pre2bSize", part.Size)
	end
	part.Size = size
end
local function park(inst: Instance, sub: string)
	inst:SetAttribute("ParkedFrom", inst.Parent:GetFullName())
	inst.Parent = folder(parked, sub)
end
local function centre(inst: Instance): Vector3?
	if inst:IsA("BasePart") then
		return inst.Position
	elseif inst:IsA("Model") then
		return inst:GetBoundingBox().Position
	end
	local lo, hi, n = Vector3.one * 1e9, -Vector3.one * 1e9, 0
	for _, d in inst:GetDescendants() do
		if d:IsA("BasePart") then
			lo, hi, n = lo:Min(d.Position), hi:Max(d.Position), n + 1
		end
	end
	return if n > 0 then (lo + hi) / 2 else nil
end

-- 0. backup of the map as imported --------------------------------------------------------------------------------
if not backups:FindFirstChild("HubMap2b_AsImported") then
	local copy = map:Clone()
	copy.Name = "HubMap2b_AsImported"
	copy.Parent = backups
end
task.wait()

-- 1. place: x3.5714, half turn, Base1 centre -> its hub-local spot ------------------------------------------------
map:ScaleTo(map:GetScale() * S)
map:PivotTo(map:GetPivot() * CFrame.Angles(0, math.pi, 0))
local function bbc(name: string): Vector3
	return (root:FindFirstChild(name) :: Model):GetBoundingBox().Position
end
local shift = L(-148, 18.5, -16.2) - bbc("Base1")
map:PivotTo(map:GetPivot() + shift)
for name, want in { Base8 = Vector3.new(148, 18.5, -16.2), TeleportHall = Vector3.new(0, 33.5, 29.3), NorthGate = Vector3.new(0, 25, -40) } do
	local err = (bbc(name) - (H + want)).Magnitude
	say(("check %s off by %.2f studs"):format(name, err))
	assert(err < 1.5, name .. " landed in the wrong place")
end
task.wait()

-- 2. look: anchored, GLB colours, no mesh collision (boxes below), shadows only on buildings ------------------------
local RGB = {
	board_ink = { 43, 42, 46 }, fabric_blue = { 61, 123, 217 }, foliage = { 63, 163, 77 }, foliage_light = { 124, 207, 79 },
	glass_window = { 159, 212, 245 }, glow_arcane = { 167, 123, 255 }, glow_warm = { 255, 207, 115 }, gold_trim = { 242, 182, 50 },
	grass = { 108, 198, 68 }, grass_bed = { 91, 181, 58 }, iron = { 90, 92, 102 }, island_rock = { 154, 128, 102 },
	lane_contested = { 217, 54, 28 }, path_warm = { 233, 200, 145 }, portal_ember = { 125, 76, 207 }, portal_knight = { 224, 163, 58 },
	portal_sunken = { 34, 163, 160 }, rebirth_beam = { 217, 194, 255 }, roof_red = { 226, 65, 45 }, stone_dark = { 163, 152, 136 },
	stone_light = { 242, 235, 220 }, stone_worn = { 217, 207, 187 }, timber_beam = { 110, 74, 44 }, water = { 10, 106, 146 },
	water_flow = { 10, 106, 146 }, water_ripple = { 255, 255, 255 }, wood = { 154, 106, 62 }, zone_unchanged = { 186, 182, 182 },
}
local KEYS = {}
for k in RGB do
	table.insert(KEYS, k)
end
table.sort(KEYS, function(a, b)
	return #a > #b
end)
local function special(group: string, n: string): string?
	if n:match("^Slot%d") then return "gold_trim" end
	if n == "OwnerSign" then return "fabric_blue" end
	if n:match("FrontDoor_Threshold") then return "lane_contested" end
	if n:match("Threshold") then return "gold_trim" end
	if n:match("Sealed_Future") then return "stone_dark" end
	if n:match("^Portal_.*_Pad") then return "gold_trim" end
	if n:match("^Portal_EmberAcademy") then return "portal_ember" end
	if n:match("^Portal_SunkenKingdom") then return "portal_sunken" end
	if n:match("^Portal_KnightsKeep") then return "portal_knight" end
	if n:match("Ripple") then return "water_ripple" end
	if n:match("Curtain") then return "water_flow" end
	if n:match("Water") or n:match("Splash") then return "water" end
	if n:match("^Trim") or n == "Cap" or n:match("ToMarket") then return "gold_trim" end
	if n:match("^Board") then
		return ({ UpgradeForge = "roof_red", IndexHall = "gold_trim", RebirthAltar = "glow_arcane" })[group] or "fabric_blue"
	end
	if n:match("Arm_ToForge") or n:match("Monument_Gem") then return "roof_red" end
	if n:match("Arm_To") then return "fabric_blue" end
	if n == "Post" then return if group == "RebirthAltar" then "stone_dark" else "wood" end
	if n == "Crystal" or n:match("^Halo") then return "glow_arcane" end
	if n == "LightBeam" then return "rebirth_beam" end
	if n:match("Leaderboard_.*_Face") then return "board_ink" end
	if n:match("ArenaGate_Doors") then return "wood" end
	return nil
end
local function matKey(group: string, part: BasePart): string?
	local node = part.Parent.Name:gsub("_Node$", "")
	for _, n in { node, part.Name } do
		for _, k in KEYS do
			if n:sub(-#k - 1) == "_" .. k then
				return k
			end
		end
	end
	return special(group, node) or special(group, (node:gsub("%d+$", "")))
end
local SHADOW_GROUPS = {
	KingdomWall = true, NorthGate = true, TeleportHall = true, CosmeticShop = true, UpgradeForge = true, IndexHall = true,
	RebirthAltar = true, TradingPlaza = true, EventStage = true, Gardens = true,
}
local unknown, painted = {}, 0
for _, group in root:GetChildren() do
	local gname = group.Name
	for _, d in group:GetDescendants() do
		if d:IsA("MeshPart") then
			local k = matKey(gname, d)
			d.Anchored = true
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
			d.Material = Enum.Material.Plastic
			d.Transparency = 0
			d.Reflectance = 0
			pcall(function()
				d.CollisionFidelity = Enum.CollisionFidelity.Box
			end)
			pcall(function()
				d.RenderFidelity = Enum.RenderFidelity.Automatic
			end)
			local glow = false
			if k then
				local c = RGB[k] or RGB.water_ripple
				d.Color = Color3.fromRGB(c[1], c[2], c[3])
				if k == "wood" or k == "timber_beam" then
					d.Material = Enum.Material.Wood
				elseif k == "iron" then
					d.Material = Enum.Material.CorrodedMetal
				elseif k == "fabric_blue" then
					d.Material = Enum.Material.Fabric
				elseif k:match("^glow") or k:match("^portal") or k == "rebirth_beam" then
					d.Material, glow = Enum.Material.Neon, true
					d.Transparency = if k == "rebirth_beam" then 0.55 else 0
				elseif k == "water" or k == "water_flow" then
					d.Material, glow = Enum.Material.Glass, true
					d.Transparency = 0.25
				elseif k:match("^water_ripple") then
					d.Material, glow = Enum.Material.SmoothPlastic, true
					d.Transparency = 0.55
				elseif k == "glass_window" then
					d.Material = Enum.Material.Glass
					d.Transparency = 0.2
				end
				painted += 1
			else
				table.insert(unknown, gname .. "/" .. d.Parent.Name)
			end
			d.CastShadow = (SHADOW_GROUPS[gname] == true or gname:match("^Base%d") ~= nil) and not glow
		end
	end
end
say(("painted %d meshes, unknown %d: %s"):format(painted, #unknown, table.concat(unknown, ", ")))
task.wait()

-- 3. four more bases so the row is 6 + 6 (copies of Base4 at x -184, 184, -220, 220) --------------------------------
local base4 = root:FindFirstChild("Base4") :: Model
local EXTRA = { Base9 = -184, Base10 = 184, Base11 = -220, Base12 = 220 }
for name, x in EXTRA do
	local b = base4:Clone()
	b.Name = name
	b:PivotTo(b:GetPivot() + Vector3.new(x - (-40), 0, 0))
	b:SetAttribute("Created2b", true)
	b.Parent = root
end
task.wait()

-- 4. the map's own gold slot pads would sit under/next to the plot's pads: parked (the plot's stations are the pads)
local slots = 0
for _, b in root:GetChildren() do
	if b.Name:match("^Base%d+$") then
		for _, c in b:GetChildren() do
			if c.Name:match("^Slot%d") then
				c:SetAttribute("Base2b", b.Name)
				park(c, "MapSlots")
				slots += 1
			end
		end
	end
end
say("parked map slot pads: " .. slots)

-- 5. extension under the 4 extra bases: base-row floor, red band, rock (look parts) ---------------------------------
local ext = folder(map, "Ext2b")
local function block(parent: Instance, name: string, c: Vector3, s: Vector3, rgb: { number }, mat: Enum.Material, collide: boolean): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = s
	p.CFrame = CFrame.new(H + c)
	p.Color = Color3.fromRGB(rgb[1], rgb[2], rgb[3])
	p.Material = mat
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = collide
	p.CanQuery = collide
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = parent
	return p
end
for _, sx in { -1, 1 } do
	local tag = if sx < 0 then "W" else "E"
	block(ext, "BaseRowFloor_" .. tag, Vector3.new(sx * 204, -2, -14), Vector3.new(68, 4, 52), RGB.path_warm, Enum.Material.Plastic, false)
	block(ext, "RedBand_" .. tag, Vector3.new(sx * 204, -2, -67.5), Vector3.new(68, 4, 55), RGB.lane_contested, Enum.Material.Plastic, false)
	block(ext, "Rock_" .. tag, Vector3.new(sx * 203, -17, -41.5), Vector3.new(62, 26, 103), RGB.island_rock, Enum.Material.Rock, false)
end

-- 6. collision: the GLB's 101 COL boxes + the field, branches, platforms, gate posts, extra bases, edge guards -------
local COL = {
	{ "COL_Lobby_Floor", 0, -2, 105, 340, 4, 190 }, { "COL_BaseRow_Floor", 0, -2, -15, 340, 4, 50 },
	{ "COL_ReturnPlaza", 0, -2, -55, 340, 4, 30 }, { "COL_Spine_T1", 0, -2, -167.5, 40, 4, 135 },
	{ "COL_South_W", -93.5, 5, 200, 153, 10, 3 }, { "COL_South_E", 93.5, 5, 200, 153, 10, 3 },
	{ "COL_West", -170, 5, 105, 3, 10, 190 }, { "COL_East", 170, 5, 105, 3, 10, 190 },
	{ "COL_EndWall_W", -168, 7, -15, 4, 14, 50 }, { "COL_EndWall_E", 168, 7, -15, 4, 14, 50 },
	{ "COL_TH_WingW_Back", -32, 9, 27, 4, 18, 34 }, { "COL_TH_WingW_N", -21, 9, 12, 18, 18, 4 },
	{ "COL_TH_WingW_Mid", -21, 9, 28, 18, 18, 4 }, { "COL_TH_WingW_S", -21, 9, 43, 18, 18, 2 },
	{ "COL_TH_WingE_Back", 32, 9, 27, 4, 18, 34 }, { "COL_TH_WingE_N", 21, 9, 12, 18, 18, 4 },
	{ "COL_TH_WingE_Mid", 21, 9, 28, 18, 18, 4 }, { "COL_TH_WingE_S", 21, 9, 43, 18, 18, 2 },
	{ "COL_Fountain", 0, 1.5, 80, 28, 3, 28 }, { "COL_Workshop", 141, 13, 79, 48, 26, 46 },
	{ "COL_Furnace", 110, 5, 66, 12, 10, 10 }, { "COL_RebirthDais", 120, 2.25, 165, 48, 4.5, 48 },
	{ "COL_Stalls_W", -52, 5, 130, 6, 10, 34 }, { "COL_Stalls_E", 52, 5, 130, 6, 10, 34 },
	{ "COL_Stage", 0, 2, 182, 56, 4, 20 }, { "COL_Backdrop_W", -18, 11, 194, 20, 22, 3 },
	{ "COL_Backdrop_E", 18, 11, 194, 20, 22, 3 }, { "COL_Leaderboard_W", -44, 12, 176, 20, 24, 2 },
	{ "COL_Leaderboard_E", 44, 12, 176, 20, 24, 2 }, { "COL_ArenaGate", 0, 8, 200, 14, 16, 2 },
	{ "COL_GardenFountain_W", -138, 1.25, 117, 10, 2.5, 10 }, { "COL_GardenFountain_E", 128, 1.25, 117, 10, 2.5, 10 },
	{ "COL_CS_Plinth", -122, 1, 79, 77, 2, 47 }, { "COL_CS_Wall_N", -122, 11, 57, 76, 18, 2 },
	{ "COL_CS_Wall_S", -122, 11, 101, 76, 18, 2 }, { "COL_CS_Wall_W", -159, 11, 79, 2, 18, 46 },
	{ "COL_CS_Partition", -128, 11, 79, 2, 18, 42 }, { "COL_CS_Pier1", -85, 6.5, 58, 2.5, 9, 4 },
	{ "COL_CS_Pier2", -85, 6.5, 71, 2.5, 9, 4 }, { "COL_CS_Pier3", -85, 6.5, 87, 2.5, 9, 4 },
	{ "COL_CS_Pier4", -85, 6.5, 100, 2.5, 9, 4 }, { "COL_CS_FrontUpper", -85, 15.5, 79, 2, 9, 46 },
	{ "COL_CS_Roof", -122, 23, 79, 78, 6, 48 }, { "COL_IH_Wall_N", -128, 9, 138, 70, 18, 2 },
	{ "COL_IH_Wall_S", -128, 9, 192, 70, 18, 2 }, { "COL_IH_Wall_W", -162, 9, 165, 2, 18, 56 },
	{ "COL_IH_Partition", -130, 9, 165, 2, 18, 52 }, { "COL_IH_Front_S", -94, 9, 185, 2, 18, 16 },
	{ "COL_IH_Front_N", -94, 9, 145, 2, 18, 16 }, { "COL_IH_Lintel", -94, 15.5, 165, 2, 5, 24 },
	{ "COL_IH_Floor", -128, 0.75, 165, 68, 1.5, 54 }, { "COL_IH_Stylobate", -88, 0.75, 165, 11, 1.5, 58 },
	{ "COL_IH_Roof", -125, 22.5, 165, 82, 13, 58 },
	-- added (the export has none here)
	{ "COL_RedBand_Far", 0, -2, -82.5, 340, 4, 25 },
	{ "COL_Branch_W", -35, -2, -160, 30, 4, 12 }, { "COL_Branch_E", 35, -2, -160, 30, 4, 12 },
	{ "COL_Platform_W", -130, -2, -160, 160, 4, 130 }, { "COL_Platform_E", 130, -2, -160, 160, 4, 130 },
	{ "COL_NorthGate_W", -20, 15, -40, 9, 30, 9 }, { "COL_NorthGate_E", 20, 15, -40, 9, 30, 9 },
	{ "COL_Ext_BaseRow_W", -204, -2, -14, 68, 4, 52 }, { "COL_Ext_BaseRow_E", 204, -2, -14, 68, 4, 52 },
	{ "COL_Ext_RedBand_W", -204, -2, -67.5, 68, 4, 55 }, { "COL_Ext_RedBand_E", 204, -2, -67.5, 68, 4, 55 },
}
-- each base (8 from the GLB + the 4 copies): side walls, front towers, back posts, at its centre x
local BASES = { Base1 = -148, Base2 = -112, Base3 = -76, Base4 = -40, Base5 = 40, Base6 = 76, Base7 = 112, Base8 = 148 }
for name, x in EXTRA do
	BASES[name] = x
end
for name, x in BASES do
	for _, r in {
		{ "Wall_W", -16, 7, -15, 4, 14, 50 }, { "Wall_E", 16, 7, -15, 4, 14, 50 },
		{ "FrontTower_W", -11, 10, -38, 7, 20, 4 }, { "FrontTower_E", 11, 10, -38, 7, 20, 4 },
		{ "Back_W", -10, 6, 8, 8, 12, 4 }, { "Back_E", 10, 6, 8, 8, 12, 4 },
	} do
		table.insert(COL, { "COL_" .. name .. "_" .. r[1], x + r[2], r[3], r[4], r[5], r[6], r[7] })
	end
end
-- edge guards (invisible, 6 tall) where a walkway meets the void
local GUARD = {
	{ "Band_N_W", -34.75, 3, -95.5, 30.5, 6, 1 }, { "Band_N_E", 34.75, 3, -95.5, 30.5, 6, 1 },
	{ "Band_N_WW", -224, 3, -95.5, 28, 6, 1 }, { "Band_N_EE", 224, 3, -95.5, 28, 6, 1 },
	{ "Ext_End_W", -238.5, 3, -41.5, 1, 6, 107 }, { "Ext_End_E", 238.5, 3, -41.5, 1, 6, 107 },
	{ "Ext_Back_W", -204, 3, 12.5, 68, 6, 1 }, { "Ext_Back_E", 204, 3, 12.5, 68, 6, 1 },
	{ "Spine_W_A", -20.5, 3, -124.5, 1, 6, 59 }, { "Spine_E_A", 20.5, 3, -124.5, 1, 6, 59 },
	{ "Spine_W_B", -20.5, 3, -200.5, 1, 6, 69 }, { "Spine_E_B", 20.5, 3, -200.5, 1, 6, 69 },
	{ "Spine_End", 0, 3, -235.5, 42, 6, 1 },
	{ "Branch_W_N", -35, 3, -153.5, 29, 6, 1 }, { "Branch_W_S", -35, 3, -166.5, 29, 6, 1 },
	{ "Branch_E_N", 35, 3, -153.5, 29, 6, 1 }, { "Branch_E_S", 35, 3, -166.5, 29, 6, 1 },
	{ "Plat_W_InnerN", -49.5, 3, -124.5, 1, 6, 59 }, { "Plat_W_InnerS", -49.5, 3, -195.5, 1, 6, 59 },
	{ "Plat_E_InnerN", 49.5, 3, -124.5, 1, 6, 59 }, { "Plat_E_InnerS", 49.5, 3, -195.5, 1, 6, 59 },
	{ "Plat_W_Far", -130, 3, -225.5, 160, 6, 1 }, { "Plat_E_Far", 130, 3, -225.5, 160, 6, 1 },
}
local colFolder = folder(map, "Collision2b")
local nCol = 0
local function colPart(name: string, c: Vector3, s: Vector3)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = s
	p.CFrame = CFrame.new(H + c)
	p.Transparency = 1
	p.CanCollide = true
	p.CanQuery = true
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = colFolder
	nCol += 1
end
for _, r in COL do
	colPart(r[1], Vector3.new(r[2], r[3], r[4]), Vector3.new(r[5], r[6], r[7]))
end
for _, r in GUARD do
	colPart("GUARD_" .. r[1], Vector3.new(r[2], r[3], r[4]), Vector3.new(r[5], r[6], r[7]))
end
say("collision parts: " .. nCol)
task.wait()

-- 7. plots into the bases (front = north = the red band). Plot1/2 next to the gate, then outwards. ------------------
local PLOT_BASE = { "Base4", "Base5", "Base3", "Base6", "Base2", "Base7", "Base1", "Base8", "Base9", "Base10", "Base11", "Base12" }
local FLOOR_Y = 0.25 -- plot Floor centre: top 0.35, just over the base floor (0.3)
for i, bname in PLOT_BASE do
	local plot = workspace.Hub.Plots:FindFirstChild("Plot" .. i) :: Model
	assert(plot and plot.PrimaryPart, "Plot" .. i)
	local target = CFrame.new(L(BASES[bname], FLOOR_Y, -14))
	moveTo(plot, target * plot.PrimaryPart.CFrame:ToObjectSpace(plot:GetPivot()))
	plot:SetAttribute("Base2b", bname)
	for _, f in (plot:FindFirstChild("Fence") :: Instance):GetChildren() do
		if f:IsA("BasePart") then
			f:SetAttribute("Pre2bTransparency", f.Transparency)
			f:SetAttribute("Pre2bCanCollide", f.CanCollide)
			f.Transparency = 1
			f.CanCollide = false
			f.CanQuery = false
			CS:AddTag(f, "Hidden2b")
		end
	end
end
say("plots moved: 12")

-- 8. spawn, safe volume, home anchor, parade lane, venues, clouds --------------------------------------------------
moveTo(workspace.SpawnLocation, CFrame.new(L(0, 0.5, 56))) -- in the arrival plaza, facing the bases (-Z)
local safe = City.Ground.SafeHubVolume :: BasePart
moveTo(safe, CFrame.new(L(0, 10, 65)))
resize(safe, Vector3.new(100, 24, 110))
local homeFloor = workspace.Hub.Floor :: BasePart
moveTo(homeFloor, CFrame.new(L(0, homeFloor.Position.Y, 80)))

local paradeFolder = City.Ground.ParadeLane
local lane = paradeFolder.Lane :: BasePart
-- along the red spine, junction (z -166) -> gate (z -44); LookVector exactly +Z so walkers walk towards the gate
moveTo(lane, CFrame.fromMatrix(L(0, -0.2, -105), Vector3.new(-1, 0, 0), Vector3.new(0, 1, 0), Vector3.new(0, 0, -1)))
resize(lane, Vector3.new(16, 0.5, 122))
lane:SetAttribute("Pre2bTransparency", lane.Transparency)
lane:SetAttribute("Pre2bCanCollide", lane.CanCollide)
lane.Transparency = 1
lane.CanCollide = false
for _, c in paradeFolder:GetChildren() do
	if c ~= lane then
		park(c, "ParadeLaneDressing")
	end
end

local function moveGroup(container: Instance, newRef: CFrame, oldRef: CFrame)
	for _, d in container:GetDescendants() do
		if d:IsA("BasePart") then
			moveTo(d, newRef * oldRef:Inverse() * d.CFrame)
		end
	end
end
local V = workspace.Venues
local function keeperRef(shop: Instance): CFrame
	local k = shop:FindFirstChild("KeeperSpot") :: BasePart
	return CFrame.new(k.Position.X, 0, k.Position.Z)
end
-- old LotAndDecor/BatBoutique face -Z, UpgradeOffice faces +Z; a quarter turn makes them face the avenue
moveGroup(V.Shops.LotAndDecor, CFrame.new(L(-80, 0, 79)) * CFrame.Angles(0, -math.pi / 2, 0), keeperRef(V.Shops.LotAndDecor))
moveGroup(V.Shops.UpgradeOffice, CFrame.new(L(99, 0, 79)) * CFrame.Angles(0, -math.pi / 2, 0), keeperRef(V.Shops.UpgradeOffice))
moveGroup(V.Shops.BatBoutique, CFrame.new(L(-45, 0, 130)) * CFrame.Angles(0, -math.pi / 2, 0), keeperRef(V.Shops.BatBoutique))
local guide = V.NPCs.Guide :: BasePart
moveTo(guide, CFrame.lookAt(L(16, guide.Position.Y, 50), L(0, guide.Position.Y, 56)))
local board = V.NPCs.QuestBoard :: BasePart
moveTo(board, CFrame.lookAt(L(-16, board.Position.Y, 50), L(0, board.Position.Y, 56)))
moveTo(V.Leaderboards.TopBillionaires, CFrame.new(L(-44, 16, 174.6))) -- on the EventStage's west board, GUI faces north
-- hub clouds follow the hub (old hub centre (-15, 0, -4) -> new (0, 0, 80))
local cloudShift = L(0, 0, 80) - Vector3.new(-15, 0, -4)
for _, c in City.HubClouds048:GetDescendants() do
	if c:IsA("BasePart") then
		moveTo(c, c.CFrame + cloudShift)
	end
end
task.wait()

-- 9. park the old hub (not the plaza/arena east of x 107, not anything north of the lane mouth z -112) -------------
local function oldHub(inst: Instance): boolean
	local c = centre(inst)
	return c ~= nil and c.Z > -112 and c.X <= 107 and c.Z < 400
end
local counts = {}
local function parkIf(list: { Instance }, sub: string, test: (Instance) -> boolean)
	for _, c in list do
		if test(c) then
			park(c, sub)
			counts[sub] = (counts[sub] or 0) + 1
		end
	end
end
parkIf({ City.LotBases, City.ReservedPlots, World.HideoutCamp }, "OldHub", function()
	return true
end)
parkIf(City.Hub:GetChildren(), "SkyCity.Hub", oldHub)
parkIf(City.Dressing:GetChildren(), "SkyCity.Dressing", oldHub)
parkIf(City.Ground:GetChildren(), "SkyCity.Ground", function(c)
	return c ~= paradeFolder and c ~= safe and oldHub(c)
end)
parkIf(World.Islands:GetChildren(), "Islands", oldHub)
parkIf(City.Lane:GetChildren(), "LaneMouth", function(c)
	return c.Name == "Tile" or c.Name == "Border" and (c :: BasePart).Position.Z > -120 or c.Name == "MouthCurb" or c.Name == "MouthPaving" or c.Name == "Edge"
end)
for _, sub in { "Rocks", "Clouds" } do
	parkIf(City.Lane[sub]:GetChildren(), "Lane." .. sub, oldHub)
end
-- folders that span hub and zones: their hub-side children one by one
for _, f in { City.Ground.Rocks, City.Ground.Edge, City.Dressing.Trees } do
	parkIf(f:GetChildren(), "SkyCity." .. f.Parent.Name .. "." .. f.Name, oldHub)
end
for k, v in counts do
	say(("parked %s: %d"):format(k, v))
end

map:SetAttribute("Fit2b", true)
map:SetAttribute("HubOrigin", H)
return table.concat(log, "\n")
