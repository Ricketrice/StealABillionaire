-- Studio location: StarterPlayer.StarterPlayerScripts.StoreClient (LocalScript)
-- StoreClient  (Milestone 029) -- the Store screen (ReplicatedStorage.StoreOn), built through UITheme.
-- Tabs: Passes (2x Cash, Extra Slots, VIP), Cash packs, Starter Pack (one-time). Items come from
-- ReplicatedStorage.ProductConfig. Purchases are wired in Milestone 031: until then every card says
-- "Coming soon" and its button can't be pressed. No pressure wording, no timers, no "only X left".
-- Opened from the HUD (Store button, or the cash pill's "+" which opens the Cash tab).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProductConfig = require(ReplicatedStorage:WaitForChild("ProductConfig"))
local UITheme = require(ReplicatedStorage:WaitForChild("UITheme"))

local T = UITheme.Colors
local gui, root = UITheme.gui("Store029", 5)

local win = UITheme.window({ Name = "Store", Title = "Store", Icon = "shop", Size = Vector2.new(800, 350), Parent = root })
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

local function showTab(key: string)
	for _, child in grid:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	for order, def in ProductConfig.ITEMS[key] or {} do
		item(def, order)
	end
	grid.CanvasPosition = Vector2.zero
	gui:SetAttribute("Tab", key)
end
local tabRow, selectTab =
	UITheme.tabs({ Name = "Tabs", Tabs = ProductConfig.TABS, Size = UDim2.new(1, -60, 0, 58), Position = UDim2.fromOffset(0, 14), Parent = win.content, OnSelect = showTab })
tabRow.ZIndex = 13
selectTab(ProductConfig.TABS[1].key)

UITheme.registerScreen("Store", function(tab: any?)
	if ReplicatedStorage:GetAttribute("StoreOn") ~= true then
		UITheme.screenClosed("Store")
		return
	end
	if type(tab) == "string" and ProductConfig.ITEMS[tab] then
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
