-- Studio location: StarterPlayer.StarterPlayerScripts.StoreClient (LocalScript)
-- StoreClient  (Milestone 029) -- the Store screen (ReplicatedStorage.StoreOn), built through UITheme.
-- Tabs: Passes (2x Cash, Extra Slots, VIP), Cash packs, Starter Pack (one-time). Items come from
-- ReplicatedStorage.ProductConfig. Purchases are wired in Milestone 031: until then every card says
-- "Coming soon" and its button can't be pressed. No pressure wording, no timers, no "only X left".
-- Opened from the HUD (Store button, or the cash pill's "+" which opens the Cash tab).
-- 032: a Trails tab (cash only, while ReplicatedStorage.SpeedOn): the 6 speed trails from SpeedConfig with their
-- boost and price; Buy / Equip go to the server (SpeedRequest), which checks and charges. One equipped at a time.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Players = game:GetService("Players")

local CashFormat = require(ReplicatedStorage:WaitForChild("CashFormat"))
local ProductConfig = require(ReplicatedStorage:WaitForChild("ProductConfig"))
local SpeedConfig = require(ReplicatedStorage:WaitForChild("SpeedConfig"))
local UITheme = require(ReplicatedStorage:WaitForChild("UITheme"))

local player = Players.LocalPlayer
local speedRequest = ReplicatedStorage:WaitForChild("SpeedRequest", 30) :: RemoteFunction?

local T = UITheme.Colors
local gui, root = UITheme.gui("Store029", 5)

local win = UITheme.window({ Name = "Store", Title = "Store", Icon = "shop", Theme = "Shop", Size = Vector2.new(800, 350), Parent = root })
local grid = UITheme.make("ScrollingFrame", {
	Name = "Items",
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	Position = UDim2.fromOffset(0, 76),
	Size = UDim2.new(1, 0, 1, -76),
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollingDirection = Enum.ScrollingDirection.Y,
	ScrollBarThickness = 6,
	ZIndex = 13,
	Parent = win.content,
})
UITheme.make("UIGridLayout", { CellSize = UDim2.new(1 / 3, -10, 0, 222), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
UITheme.make("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 8), Parent = grid })

local function item(def: any, order: number)
	local available = ProductConfig.available(def) and false -- (029: purchases are not wired yet)
	local card = UITheme.card({ Name = def.key, LayoutOrder = order, ZIndex = 13, Parent = grid })
	if def.oneTime then -- the featured one-time pack gets rays behind its icon (once the texture is uploaded)
		card.ClipsDescendants = true
		UITheme.sunburst({ Position = UDim2.fromOffset(45, 43), Size = UDim2.fromScale(0.75, 0.75), ZIndex = 13, Parent = card })
	end
	UITheme.image({ Icon = def.icon, Size = UDim2.fromOffset(74, 74), Position = UDim2.fromOffset(8, 6), ZIndex = 14, Parent = card })
	UITheme.text({
		Name = "ItemName",
		Text = def.name,
		Role = "Title",
		TextSize = 24,
		Align = "Left",
		Size = UDim2.new(1, -96, 0, 30),
		Position = UDim2.fromOffset(88, 24),
		ZIndex = 14,
		Parent = card,
	})
	UITheme.text({
		Name = "About",
		Text = def.text,
		Role = "Body",
		TextSize = 15,
		Color = T.TextMuted,
		TextWrapped = true,
		Size = UDim2.new(1, -16, 0, 54),
		Position = UDim2.fromOffset(8, 86),
		ZIndex = 14,
		Parent = card,
	}).TextYAlignment =
		Enum.TextYAlignment.Top
	if def.oneTime then
		UITheme.text({
			Name = "OneTime",
			Text = "One per player",
			Role = "Small",
			TextSize = 13,
			Color = T.Accent,
			Size = UDim2.new(1, -96, 0, 16),
			Position = UDim2.fromOffset(88, 56),
			ZIndex = 14,
			Parent = card,
		})
	end
	local button = UITheme.button({
		Name = "Buy",
		Kind = "Gold",
		Text = "Coming soon",
		TextSize = 19,
		Size = UDim2.new(1, -16, 0, 56),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		ZIndex = 14,
		Parent = card,
	})
	UITheme.setEnabled(button, available, "Coming soon")
	card:SetAttribute("Available", available)
end

-- Trails (032) --------------------------------------------------------------------------------------------
local TRAILS = "trails"
local function speedOn(): boolean
	return ReplicatedStorage:GetAttribute(SpeedConfig.PUBLISHED) == true
end
local showTab: (string) -> ()
local busy = false
local function refreshTrails()
	if gui:GetAttribute("Tab") == TRAILS then
		showTab(TRAILS)
	end
end
local function ask(actionName: string, id: string, button: TextButton)
	if busy or not speedRequest then
		return
	end
	busy = true
	task.spawn(function()
		local ok, result = pcall(function()
			return (speedRequest :: RemoteFunction):InvokeServer(actionName, id)
		end)
		busy = false
		if ok and type(result) == "table" and not result.ok and result.text and button.Parent then
			button.Text = result.text -- e.g. "Not enough cash yet"; the card comes back after a moment
			task.delay(1.6, refreshTrails)
			return
		end
		task.defer(refreshTrails)
	end)
end

local function trailCard(def: any, order: number)
	local owned = table.find(string.split(player:GetAttribute("SpeedOwned") or "", ","), def.id) ~= nil
	local equipped = player:GetAttribute("SpeedTrail") == def.id
	local card = UITheme.card({ Name = def.id, LayoutOrder = order, ZIndex = 13, Parent = grid })
	UITheme.image({ Icon = def.icon, Size = UDim2.fromOffset(74, 74), Position = UDim2.fromOffset(8, 6), ZIndex = 14, Parent = card })
	UITheme.text({
		Name = "ItemName",
		Text = def.name,
		Role = "Title",
		TextSize = 22,
		Align = "Left",
		Size = UDim2.new(1, -96, 0, 30),
		Position = UDim2.fromOffset(88, 14),
		ZIndex = 14,
		Parent = card,
	})
	UITheme.text({
		Name = "Boost",
		Text = ("+%d%% speed"):format(math.floor(def.boost * 100 + 0.5)),
		Role = "Display",
		TextSize = 20,
		Color = T.Cash,
		Align = "Left",
		Size = UDim2.new(1, -96, 0, 26),
		Position = UDim2.fromOffset(88, 46),
		ZIndex = 14,
		Parent = card,
	})
	UITheme.text({
		Name = "About",
		Text = "Walk faster (half the boost while carrying). Races stay the same for everyone.",
		Role = "Body",
		TextSize = 14,
		Color = T.TextMuted,
		TextWrapped = true,
		Size = UDim2.new(1, -16, 0, 44),
		Position = UDim2.fromOffset(8, 88),
		ZIndex = 14,
		Parent = card,
	}).TextYAlignment =
		Enum.TextYAlignment.Top
	local text = if equipped then "Equipped" elseif owned then "Equip" else "Buy " .. CashFormat.format(def.price)
	local button = UITheme.button({
		Name = "Buy",
		Kind = if owned then "Primary" else "Gold",
		Text = text,
		TextSize = 19,
		Size = UDim2.new(1, -16, 0, 56),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		ZIndex = 14,
		Parent = card,
		OnActivated = function()
			if not equipped then
				ask(if owned then "Equip" else "Buy", def.id, card:FindFirstChild("Buy") :: TextButton)
			end
		end,
	})
	UITheme.setEnabled(button, not equipped, text)
	card:SetAttribute("Owned", owned)
	card:SetAttribute("Equipped", equipped)
end

function showTab(key: string)
	for _, child in grid:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	if key == TRAILS then
		for order, def in SpeedConfig.TRAILS do
			trailCard(def, order)
		end
	else
		for order, def in ProductConfig.ITEMS[key] or {} do
			item(def, order)
		end
	end
	grid.CanvasPosition = Vector2.zero
	gui:SetAttribute("Tab", key)
end

-- The tab row; rebuilt when the Trails tab comes or goes (SpeedOn).
local tabRow: Instance? = nil
local selectTab: (string) -> () = function(_key: string) end
local function tabList(): { any }
	local list = table.clone(ProductConfig.TABS)
	if speedOn() then
		table.insert(list, { key = TRAILS, title = "Trails", icon = "shoe" })
	end
	return list
end
local function buildTabs()
	local keep = gui:GetAttribute("Tab")
	if tabRow then
		tabRow:Destroy()
	end
	local list = tabList()
	local row, choose = UITheme.tabs({ Name = "Tabs", Tabs = list, Size = UDim2.new(1, -60, 0, 58), Position = UDim2.fromOffset(0, 14), Parent = win.content, OnSelect = showTab })
	row.ZIndex = 13
	tabRow, selectTab = row, choose
	local found = false
	for _, tab in list do
		found = found or tab.key == keep
	end
	selectTab(if found then keep else list[1].key)
end
buildTabs()
ReplicatedStorage:GetAttributeChangedSignal(SpeedConfig.PUBLISHED):Connect(buildTabs)
for _, name in { "SpeedOwned", "SpeedTrail" } do
	player:GetAttributeChangedSignal(name):Connect(refreshTrails)
end

UITheme.registerScreen("Store", function(tab: any?)
	if ReplicatedStorage:GetAttribute("StoreOn") ~= true then
		UITheme.screenClosed("Store")
		return
	end
	if type(tab) == "string" and (ProductConfig.ITEMS[tab] or (tab == TRAILS and speedOn())) then
		selectTab(tab)
	end
	win.open()
end, win.close)
ReplicatedStorage:GetAttributeChangedSignal("StoreOn"):Connect(function()
	if ReplicatedStorage:GetAttribute("StoreOn") ~= true then
		win.close()
	end
end)

-- Studio test hook (DevTest_V1029): open a tab as a tap would.
if game:GetService("RunService"):IsStudio() then
	gui:GetAttributeChangedSignal("TestOpen"):Connect(function()
		local tab = gui:GetAttribute("TestOpen")
		if type(tab) == "string" and tab ~= "" then
			UITheme.openScreen("Store", tab)
		else
			win.close()
		end
	end)
end
