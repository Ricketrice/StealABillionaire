-- Studio location: ServerScriptService.HubShops (ModuleScript)
-- HubShops  (Milestone 026)
-- The three shops on Shopping Row, in-game cash only. Every purchase is checked and made on the
-- server: flag on, the player near that shop, the item in HubConfig, not owned yet, enough cash.
-- Cash and ownership are in the same save, so they are always saved together.
--   Bat Boutique   bat looks (the 022 locker then only offers what is owned) and swing-trail colours
--   Lot & Decor    decorations for the five decor spots on the player's own lot (looks only)
--   Upgrade Office (own flag, UPGRADES_ENABLED) storage slots, arena training and extra stations
-- Nothing in the PvP or worker scripts is edited: the locker request is wrapped through
-- PvPBase.onAction, storage uses WorkerInventory.setSlotBonus, extra stations use
-- WorkerInventory.setStationBonus and NPCPlacement.start, trails are a player attribute.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage:WaitForChild("HubConfig"))
local CashService = require(script.Parent:WaitForChild("CashService"))
local HubBase = require(script.Parent:WaitForChild("HubBase"))
local InventoryConfig = require(ReplicatedStorage:WaitForChild("InventoryConfig"))
local NPCPlacement = require(script.Parent:WaitForChild("NPCPlacement"))
local PlayerData = require(script.Parent:WaitForChild("PlayerData"))
local PlotService = require(script.Parent:WaitForChild("PlotService"))
local PvPBase = require(script.Parent:WaitForChild("PvPBase"))
local PvPCombat = require(script.Parent:WaitForChild("PvPCombat"))
local WorkerInventory = require(script.Parent:WaitForChild("WorkerInventory"))

local HubShops = {}
HubShops.stats = { bought = 0, refused = 0 }

local items: { [string]: any } = {}
for shopName, shop in HubConfig.Shops do
	for _, item in shop.items do
		item.shop = shopName
		items[item.id] = item
	end
end

local function shopOpen(shopName: string): boolean
	local shop = HubConfig.Shops[shopName]
	return shop ~= nil and HubBase.flag("SHOPS_ENABLED") and (shop.flag == nil or HubBase.flag(shop.flag))
end
local function nearShop(player: Player, shopName: string): boolean
	local venues = workspace:FindFirstChild("Venues")
	local shops = venues and venues:FindFirstChild("Shops")
	local folder = shops and shops:FindFirstChild(shopName)
	local counter = folder and folder:FindFirstChild("Counter")
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	return counter ~= nil and root ~= nil and counter:IsA("BasePart") and root:IsA("BasePart") and (counter.Position - root.Position).Magnitude <= HubConfig.SHOP_REACH
end

-- Lot decor ---------------------------------------------------------------------------------------
local rgb = Color3.fromRGB
local function part(model: Model, cf: CFrame, size: Vector3, color: Color3, material: Enum.Material, shape: Enum.PartType?, solid: boolean?): Part
	local p = Instance.new("Part")
	p.Size, p.Color, p.Material = size, color, material
	if shape then
		p.Shape = shape
	end
	p.CFrame = if shape == Enum.PartType.Cylinder then cf * CFrame.Angles(0, 0, math.rad(90)) else cf
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, solid == true, false, solid == true
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end
local CYL, BALL = Enum.PartType.Cylinder, Enum.PartType.Ball
local builders: { [string]: (Model, CFrame) -> () } = {
	["decor:planter"] = function(m, o)
		part(m, o * CFrame.new(0, 0.8, 0), Vector3.new(1.6, 3.4, 3.4), rgb(178, 150, 110), Enum.Material.Concrete, CYL, true)
		part(m, o * CFrame.new(-0.6, 2, 0.3), Vector3.new(1.4, 1.4, 1.4), rgb(236, 120, 150), Enum.Material.Grass, BALL)
		part(m, o * CFrame.new(0.6, 2, -0.3), Vector3.new(1.4, 1.4, 1.4), rgb(250, 208, 70), Enum.Material.Grass, BALL)
	end,
	["decor:topiary"] = function(m, o)
		part(m, o * CFrame.new(0, 0.6, 0), Vector3.new(1.2, 2.4, 2.4), rgb(196, 110, 72), Enum.Material.Concrete, CYL, true)
		part(m, o * CFrame.new(0, 2.6, 0), Vector3.new(2.8, 0.5, 0.5), rgb(100, 68, 44), Enum.Material.Wood, CYL)
		part(m, o * CFrame.new(0, 4.6, 0), Vector3.new(3, 3, 3), rgb(70, 138, 72), Enum.Material.Grass, BALL)
	end,
	["decor:lamp"] = function(m, o)
		part(m, o * CFrame.new(0, 0.3, 0), Vector3.new(0.6, 1.2, 1.2), rgb(36, 38, 46), Enum.Material.Metal, CYL, true)
		part(m, o * CFrame.new(0, 4, 0), Vector3.new(7.4, 0.35, 0.35), rgb(56, 60, 70), Enum.Material.Metal, CYL, true)
		local globe = part(m, o * CFrame.new(0, 8, 0), Vector3.new(1.3, 1.3, 1.3), rgb(255, 224, 160), Enum.Material.Neon, BALL)
		local light = Instance.new("PointLight")
		light.Color, light.Range, light.Brightness, light.Shadows = rgb(255, 214, 150), 16, 1, false
		light.Parent = globe
	end,
	["decor:sign"] = function(m, o)
		part(m, o * CFrame.new(0, 2.5, 0), Vector3.new(0.3, 5, 0.3), rgb(56, 60, 70), Enum.Material.Metal, nil, true)
		local board = part(m, o * CFrame.new(0, 5.6, 0), Vector3.new(4.4, 1.8, 0.3), rgb(36, 38, 46), Enum.Material.Metal)
		part(m, o * CFrame.new(0, 5.6, -0.2), Vector3.new(4, 1.4, 0.1), rgb(255, 96, 150), Enum.Material.Neon)
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		local text = Instance.new("TextLabel")
		text.Name = "DecorText" -- (never "Label": PlotService looks for that name)
		text.Size, text.BackgroundTransparency, text.TextScaled = UDim2.fromScale(1, 1), 1, true
		text.Font, text.Text, text.TextColor3 = Enum.Font.FredokaOne, "OPEN", rgb(255, 240, 220)
		text.Parent = gui
		gui.Parent = board
	end,
	["decor:fountain"] = function(m, o)
		part(m, o * CFrame.new(0, 0.6, 0), Vector3.new(1.2, 4.4, 4.4), rgb(238, 233, 224), Enum.Material.Marble, CYL, true)
		part(m, o * CFrame.new(0, 1.15, 0), Vector3.new(0.2, 3.8, 3.8), rgb(84, 176, 216), Enum.Material.Glass, CYL)
		part(m, o * CFrame.new(0, 1.9, 0), Vector3.new(1.6, 0.9, 0.9), rgb(238, 233, 224), Enum.Material.Marble, CYL)
		part(m, o * CFrame.new(0, 3, 0), Vector3.new(1, 1, 1), rgb(236, 186, 70), Enum.Material.Metal, BALL)
	end,
	["decor:statue"] = function(m, o)
		part(m, o * CFrame.new(0, 0.8, 0), Vector3.new(2.6, 1.6, 2.6), rgb(238, 233, 224), Enum.Material.Marble, nil, true)
		part(m, o * CFrame.new(0, 3.6, 0) * CFrame.Angles(0, 0, math.rad(-90)), Vector3.new(0.5, 4, 4), rgb(236, 186, 70), Enum.Material.Metal, CYL, true)
		part(m, o * CFrame.new(0, 3.6, 0) * CFrame.Angles(0, 0, math.rad(-90)), Vector3.new(0.7, 2.8, 2.8), rgb(190, 140, 44), Enum.Material.Metal, CYL)
	end,
}
local function decorFolder(create: boolean?): Instance?
	local world = workspace:FindFirstChild("World")
	local city = world and world:FindFirstChild("BillionaireCity")
	local parent = city or world or workspace
	local folder = parent:FindFirstChild("LotDecor")
	if not folder and create then
		folder = Instance.new("Folder")
		folder.Name = "LotDecor"
		folder.Parent = parent
	end
	return folder
end
-- Rebuilds the decorations on a player's lot from their saved choices.
function HubShops.buildDecor(player: Player)
	local plot = PlotService.getPlot(player)
	local floor = plot and plot.PrimaryPart
	if not (plot and floor) then
		return
	end
	local existing = decorFolder(false)
	local old = existing and existing:FindFirstChild(plot.Name)
	if old then
		old:Destroy()
	end
	if not HubBase.flag("SHOPS_ENABLED") then
		return
	end
	local hub = HubBase.data(player)
	if not hub then
		return
	end
	local folder = decorFolder(true) :: Instance
	local mine = Instance.new("Folder")
	mine.Name = plot.Name
	local base = CFrame.new(floor.Position.X, floor.Position.Y + floor.Size.Y / 2, floor.Position.Z) * (floor.CFrame - floor.CFrame.Position)
	for index, spot in HubConfig.DECOR_SPOTS do
		local id = hub.decor[tostring(index)]
		local build = if hub.owned[id] then builders[id] else nil
		if build then
			local model = Instance.new("Model")
			model.Name = "Spot" .. index
			model:SetAttribute("Decor", id)
			build(model, base * CFrame.new(spot[1], 0, spot[2]))
			model.Parent = mine
		end
	end
	mine.Parent = folder
end
local function clearDecor(plotName: string)
	local folder = decorFolder(false)
	local old = folder and folder:FindFirstChild(plotName)
	if old then
		old:Destroy()
	end
end

-- Extra stations (Upgrade Office) -------------------------------------------------------------------
-- A bought station is one more pad on the owner's lot: a copy of the lot's first pad, put up when
-- the owner's data loads and taken away when they leave, so a lot nobody upgraded stays as built.
-- Workers on it earn like any placed worker; no income formula is involved.
local function upgradesOpen(): boolean
	return HubBase.flag("SHOPS_ENABLED") and HubBase.flag("UPGRADES_ENABLED")
end
local function upgradeLevel(player: Player, key: string): number
	local data = PlayerData.get(player) :: any
	local level = data and type(data.hub) == "table" and type(data.hub.upgrades) == "table" and tonumber(data.hub.upgrades[key]) or 0
	return if level == level then math.max(0, math.floor(level)) else 0
end
local function extraStations(player: Player): number
	if not upgradesOpen() then
		return 0
	end
	return math.min(upgradeLevel(player, "stations"), #items["upgrade:stations"].levels, #HubConfig.EXTRA_STATION_SPOTS)
end
local padLot: { [Player]: Model } = setmetatable({}, { __mode = "k" }) :: any
-- Moves the worker on station `index` (if any) to storage, or to a free station if storage is full.
local function vacate(player: Player, plot: Model, index: number)
	local placed = plot:FindFirstChild("PlacedNPCs")
	for _, npc in (if placed then placed:GetChildren() else {}) do
		local uid = npc:GetAttribute("WorkerUid")
		if npc:GetAttribute("StationIndex") == index and type(uid) == "string" then
			local record = WorkerInventory.take(player, uid)
			if record then
				record.loc, record.station = "carried", nil
				WorkerInventory.give(player, record, true)
				WorkerInventory.putAway(player, uid)
			end
		end
	end
end
-- Makes the lot's pads match what the player owns. Does not yield.
local function buildStations(player: Player, plot: Model?)
	plot = plot or PlotService.getPlot(player)
	local stations = plot and plot:FindFirstChild("Stations")
	local floor = plot and plot.PrimaryPart
	if not (plot and stations and floor) then
		return
	end
	local template
	for _, station in stations:GetChildren() do
		if station:IsA("BasePart") and station:GetAttribute("StationIndex") == 1 then
			template = station
		end
	end
	local want, added = extraStations(player), false
	for n, spot in HubConfig.EXTRA_STATION_SPOTS do
		local index = InventoryConfig.STATION_SLOTS + n
		local pad = stations:FindFirstChild("Station" .. index)
		if n <= want and not pad and template then
			pad = template:Clone()
			for _, child in pad:GetChildren() do
				if not child:IsA("BasePart") then
					child:Destroy() -- its Place prompt is added (and wired) by NPCPlacement below
				end
			end
			local at = floor.CFrame * CFrame.new(spot[1], 0, spot[2])
			local move = CFrame.new(at.Position.X - template.Position.X, 0, at.Position.Z - template.Position.Z)
			local targets = {}
			for _, piece in pad:GetDescendants() do
				if piece:IsA("BasePart") then
					targets[piece] = move * piece.CFrame
				end
			end
			pad.CFrame = move * template.CFrame
			for piece, cf in targets do
				piece.CFrame = cf
			end
			pad.Name = "Station" .. index
			pad:SetAttribute("StationIndex", index)
			pad:SetAttribute("Occupied", false)
			pad:SetAttribute("HubExtra", true)
			pad.Parent = stations
			padLot[player] = plot
			added = true
		elseif n > want and pad and pad:GetAttribute("HubExtra") == true then
			vacate(player, plot, index)
			pad:Destroy()
		end
	end
	if added and plot.Parent then
		NPCPlacement.start(plot.Parent) -- only adds prompts to pads that have none
	end
end
local function clearStations(plot: Model?)
	local stations = plot and plot:FindFirstChild("Stations")
	for _, pad in (if stations then stations:GetChildren() else {}) do
		if pad:GetAttribute("HubExtra") == true then
			pad:Destroy()
		end
	end
end

-- Cosmetics in use ----------------------------------------------------------------------------------
local function applyLook(player: Player)
	if not HubBase.flag("SHOPS_ENABLED") then
		if player:GetAttribute("BatTrail") ~= nil then
			player:SetAttribute("BatTrail", nil)
		end
		return
	end
	local hub = HubBase.data(player)
	if not hub then
		return
	end
	local shops = true
	local trail = if shops and hub.trail and hub.owned[hub.trail] then items[hub.trail] else nil
	player:SetAttribute("BatTrail", if trail then ("%d,%d,%d"):format(trail.color[1], trail.color[2], trail.color[3]) else nil)
	if shops and hub.skin and (hub.skin == "Starter" or hub.owned["skin:" .. hub.skin]) and PvPBase.combat() then
		PvPCombat.setLoadout(player, "skin", hub.skin)
	end
end

-- Buying and using ----------------------------------------------------------------------------------
-- Returns (bought, message).
function HubShops.buy(player: Player, itemId: any, arg: any): (boolean, string?)
	local item = if type(itemId) == "string" then items[itemId] else nil
	if not (item and shopOpen(item.shop)) then
		return false, nil
	end
	local hub = HubBase.data(player)
	if not hub then
		return false, nil
	end
	if not nearShop(player, item.shop) then
		return false, "Come to the shop to buy that."
	end
	local price, apply
	if item.kind == "upgrade" then
		local level
		if item.perWorker then
			if not (type(arg) == "string" and WorkerInventory.getRecord(player, arg)) then
				return false, "Pick one of your workers to train."
			end
			level = tonumber(hub.upgrades.training[arg]) or 0
			apply = function()
				hub.upgrades.training[arg] = level + 1
			end
		else
			local key = item.key
			level = tonumber(hub.upgrades[key]) or 0
			apply = function()
				hub.upgrades[key] = level + 1
			end
		end
		price = item.levels[level + 1]
		if not price then
			return false, item.name .. " is already at its top level."
		end
	else
		if hub.owned[item.id] then
			return false, "You already own the " .. item.name .. "."
		end
		price = item.price
		apply = function()
			hub.owned[item.id] = true
		end
	end
	if not CashService.trySpend(player, price) then
		return false, ("You need $%d for the %s."):format(price, item.name)
	end
	apply() -- no yield between paying and owning
	HubShops.stats.bought += 1
	if item.kind == "upgrade" then
		buildStations(player)
		WorkerInventory.refresh(player)
	end
	HubBase.changed(player)
	return true, ("You bought the %s!"):format(item.name)
end

-- Puts an owned cosmetic to use: a bat look, a trail (itemId or "" for none), or a decoration on a
-- decor spot (arg = spot number; itemId "" clears the spot). Returns (done, message).
function HubShops.use(player: Player, itemId: any, arg: any): (boolean, string?)
	if not (HubBase.flag("SHOPS_ENABLED") and type(itemId) == "string") then
		return false, nil
	end
	local hub = HubBase.data(player)
	if not hub then
		return false, nil
	end
	local spot = if type(arg) == "number" and arg % 1 == 0 and arg >= 1 and arg <= #HubConfig.DECOR_SPOTS then arg else nil
	if spot and itemId == "" then
		hub.decor[tostring(spot)] = nil
	elseif itemId == "" then
		hub.trail = nil
	else
		local item = items[itemId]
		if not (item and (hub.owned[itemId] or itemId == "skin:Starter")) then
			return false, "You don't own that yet."
		end
		if item.kind == "decor" then
			if not spot then
				return false, nil
			end
			for key, placed in hub.decor do -- one of each: placing it somewhere else moves it
				if placed == itemId then
					hub.decor[key] = nil
				end
			end
			hub.decor[tostring(spot)] = itemId
		elseif item.kind == "trail" then
			hub.trail = itemId
		elseif item.kind == "skin" then
			hub.skin = item.value
		else
			return false, nil
		end
	end
	applyLook(player)
	HubShops.buildDecor(player)
	HubBase.changed(player)
	return true, nil
end

local started = false
function HubShops.start()
	if started then
		return
	end
	started = true
	items["skin:Starter"] = { id = "skin:Starter", name = "Starter Bat", kind = "skin", value = "Starter", shop = "BatBoutique" }
	HubBase.onAction("ShopBuy", function(player, itemId, arg)
		local ok, message = HubShops.buy(player, itemId, arg)
		if message then
			HubBase.notify(player, ok, message, "Shop")
		end
		if not ok then
			HubShops.stats.refused += 1
		end
	end)
	HubBase.onAction("ShopUse", function(player, itemId, arg)
		local ok, message = HubShops.use(player, itemId, arg)
		if message then
			HubBase.notify(player, ok, message, "Shop")
		end
	end)
	-- Storage slots bought at the Upgrade Office.
	WorkerInventory.setSlotBonus(function(player)
		return if upgradesOpen() then upgradeLevel(player, "storage") * items["upgrade:storage"].slots else 0
	end)
	-- Stations bought at the Upgrade Office (their pads go up before saved workers are put on them).
	WorkerInventory.setStationBonus(extraStations, buildStations)
	-- The 022 locker only hands out bat looks the player owns while the shops are open. PvPCombat
	-- registers its own handler when it starts; this one replaces it a moment later and calls it.
	task.delay(2, function()
		PvPBase.onAction("Loadout", function(player, what, value)
			if what == "skin" and value ~= "Starter" and HubBase.flag("SHOPS_ENABLED") then
				local hub = HubBase.data(player)
				if not (hub and type(value) == "string" and hub.owned["skin:" .. value]) then
					HubBase.notify(player, false, "Buy that bat at the Bat Boutique first.", "Shop")
					return
				end
				hub.skin = value
				HubBase.changed(player)
			end
			PvPCombat.setLoadout(player, what, value)
		end)
	end)
	local function refresh(player: Player, slots: boolean?)
		if PlayerData.isLoaded(player) then
			applyLook(player)
			HubShops.buildDecor(player)
			if slots then
				buildStations(player)
				WorkerInventory.refresh(player) -- storage slots and stations may have changed
			end
		end
	end
	PlayerData.onLoaded(function(player)
		local waited = 0
		while not PlotService.getPlot(player) and player.Parent and waited < 10 do
			waited += task.wait(0.25)
		end
		if player.Parent then
			buildStations(player) -- (already done if the lot was there when the workers were rebuilt)
			refresh(player)
		end
	end)
	HubBase.FlagsChanged:Connect(function()
		for _, player in Players:GetPlayers() do
			refresh(player, true)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		local plotId = player:GetAttribute("PlotId")
		if plotId then
			clearDecor("Plot" .. tostring(plotId))
		end
		clearStations(padLot[player])
		padLot[player] = nil
	end)
end

return HubShops
