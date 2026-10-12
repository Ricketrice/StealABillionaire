-- Studio location: StarterPlayer.StarterPlayerScripts.HudV1 (LocalScript)
-- HudV1  (Milestone 029) -- the HUD in the V1 look (V1Flags.UI_V1_ENABLED; the old Hud runs otherwise).
-- Layout (029 layout fix), all sizes from the one HUD rule (UITheme.hudScale / touchSize):
--   * top-left, under the Roblox top bar: cash pill (rolls up; the green "+" opens the Store's cash
--     tab while the Store is on) and the income per second under it (+ the index bonus chip)
--   * left side, vertically centred: menu buttons Store, Workers, Index, Daily, Gifts, Settings (each
--     only while its feature is on) in 2 columns; on short screens 3 columns (or one row) so they stay
--     clear of the cash pill and, on touch screens, of the thumbstick; red "!" badges when ready
--   * bottom centre (only while carrying): the worker's rarity + name and a Store button
--   * this script also keeps the shared top piece (Golden timer + goal) clear of the cash pill
-- Display and requests only: cash/income are server-written attributes; rewards come from
-- RewardsState; the buttons open the other screens through UITheme.openScreen.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UITheme = require(ReplicatedStorage:WaitForChild("UITheme"))
if not UITheme.v1 then
	return
end
local CashFormat = require(ReplicatedStorage:WaitForChild("CashFormat"))
local InventoryConfig = require(ReplicatedStorage:WaitForChild("InventoryConfig"))
local UIKit = require(ReplicatedStorage:WaitForChild("UIKit"))
local WorkerCatalogue = require(ReplicatedStorage:WaitForChild("WorkerCatalogue"))
local WorkerState = require(ReplicatedStorage:WaitForChild("WorkerState"))

local player = Players.LocalPlayer
local T = UITheme.Colors
local CAPACITY = InventoryConfig.INVENTORY_SLOTS + InventoryConfig.STATION_SLOTS
local rewardsState = ReplicatedStorage:WaitForChild("RewardsState") :: RemoteEvent
local rewardsAction = ReplicatedStorage:WaitForChild("RewardsAction") :: RemoteEvent

local function on(attribute: string): boolean
	return ReplicatedStorage:GetAttribute(attribute) == true
end

local gui, root = UITheme.gui("HudV1", 2)

-- Left column ------------------------------------------------------------------------------------------
local HUD = UITheme.HUD
local left = UITheme.make("Frame", { Name = "Left", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = root })
-- top-left block: pill + income, scaled as one (the pill's own "Bump" UIScale is separate)
local topLeft = UITheme.make("Frame", {
	Name = "Top",
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(HUD.MARGIN, 8),
	Size = UDim2.fromOffset(260, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	Parent = left,
})
UITheme.make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = topLeft })
local topScale = UITheme.make("UIScale", { Parent = topLeft })
local PILL_W, PILL_H = 260, 62

local pill, cashLabel = UITheme.pill({
	Name = "CashPill",
	Icon = "cash",
	Text = "$0",
	Width = PILL_W,
	Height = PILL_H,
	LayoutOrder = 1,
	Parent = topLeft,
	OnPlus = function()
		UITheme.openScreen("Store", "cash")
	end,
})
UITheme.make("UIScale", { Name = "Bump", Parent = pill })
UITheme.setCashTarget(pill)
local plus = pill:FindFirstChild("Plus") :: TextButton

local incomeRow = UITheme.make("Frame", { Name = "IncomeRow", BackgroundTransparency = 1, Size = UDim2.fromOffset(PILL_W, 26), LayoutOrder = 2, Parent = topLeft })
UITheme.make("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	VerticalAlignment = Enum.VerticalAlignment.Center,
	Padding = UDim.new(0, 6),
	SortOrder = Enum.SortOrder.LayoutOrder,
	Parent = incomeRow,
})
UITheme.make("UIPadding", { PaddingLeft = UDim.new(0, 8), Parent = incomeRow })
local incomeLabel = UITheme.text({
	Name = "Income",
	Text = "+$0/s",
	Role = "Display",
	TextSize = 19,
	Color = T.Cash,
	Align = "Left",
	Size = UDim2.fromOffset(0, 26),
	AutomaticSize = Enum.AutomaticSize.X,
	LayoutOrder = 1,
	Parent = incomeRow,
})
incomeLabel.TextTruncate = Enum.TextTruncate.None
local bonusChip = UITheme.make(
	"Frame",
	{ Name = "Bonus", BackgroundColor3 = T.Accent, Size = UDim2.fromOffset(0, 24), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 2, Visible = false, Parent = incomeRow }
)
UITheme.corner(bonusChip, UITheme.PillRadius)
UITheme.stroke(bonusChip, T.Stroke, 2)
UITheme.make("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = bonusChip })
local bonusLabel = UITheme.text({
	Text = "",
	Role = "Small",
	Font = UITheme.Fonts.Display,
	TextSize = 15,
	Color = Color3.new(1, 1, 1),
	Size = UDim2.fromScale(0, 1),
	AutomaticSize = Enum.AutomaticSize.X,
	Parent = bonusChip,
})
bonusLabel.TextTruncate = Enum.TextTruncate.None

-- menu buttons: positioned and sized by layout() below
local CELL, CELL_GAP = 88, 10
local grid = UITheme.make("Frame", { Name = "Buttons", BackgroundTransparency = 1, Size = UDim2.fromOffset(0, 0), Parent = left })
local gridLayout = UITheme.make(
	"UIGridLayout",
	{ CellSize = UDim2.fromOffset(CELL, CELL), CellPadding = UDim2.fromOffset(CELL_GAP, CELL_GAP), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid }
)
local gridScale = UITheme.make("UIScale", { Parent = grid })

local buttons, badges = {}, {}
local relayout: (() -> ())? = nil -- set once the carry card exists (layout section below)
local function addButton(key: string, icon: string, label: string, order: number, action: () -> ())
	local b = UITheme.iconButton({ Name = key, Icon = icon, Label = label, LayoutOrder = order, Size = UDim2.fromOffset(CELL, CELL), Parent = grid, OnActivated = action })
	local _, set = UITheme.badge(b)
	buttons[key], badges[key] = b, set
	return b
end
addButton("Store", "shop", "Store", 1, function()
	UITheme.openScreen("Store")
end)
addButton("Workers", "backpack", "Workers", 2, function()
	UITheme.closeScreens()
	UIKit.Signals.ToggleInventory:Fire(nil)
end)
addButton("Index", "book", "Index", 3, function()
	UITheme.openScreen("Index")
end)
addButton("Daily", "calendar", "Daily", 4, function()
	UITheme.openScreen("Daily")
end)
addButton("Gifts", "gift", "Gifts", 5, function()
	UITheme.openScreen("Gifts")
end)
addButton("Settings", "settings", "Settings", 6, function()
	UITheme.openScreen("Settings")
end)
local giftsLabel = buttons.Gifts:FindFirstChild("Label") :: TextLabel

-- Workers count chip on the Workers button (gold, not a red badge: nothing to act on).
local countChip = UITheme.make("TextLabel", {
	Name = "Count",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0.5, 0, 0, 2),
	Size = UDim2.fromOffset(0, 20),
	AutomaticSize = Enum.AutomaticSize.X,
	BackgroundColor3 = T.Accent,
	Font = UITheme.Fonts.Display,
	TextSize = 14,
	TextColor3 = Color3.new(1, 1, 1),
	Text = "0/" .. CAPACITY,
	ZIndex = 4,
	Parent = buttons.Workers,
})
UITheme.corner(countChip, UITheme.PillRadius)
UITheme.stroke(countChip, T.Stroke, 2)
UITheme.make("UIStroke", { Color = T.Stroke, Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual, Parent = countChip })
UITheme.make("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), Parent = countChip })

local function showButtons()
	buttons.Store.Visible = on("StoreOn")
	plus.Visible = on("StoreOn")
	buttons.Daily.Visible = on("RewardsOn")
	buttons.Gifts.Visible = on("RewardsOn")
	if relayout then
		relayout()
	end
end
for _, attribute in { "StoreOn", "RewardsOn", "IndexBonusOn" } do
	ReplicatedStorage:GetAttributeChangedSignal(attribute):Connect(showButtons)
end
showButtons()

-- Cash and income ------------------------------------------------------------------------------------------
local cashValue = Instance.new("NumberValue")
local cashTween: Tween? = nil
cashValue.Changed:Connect(function(value)
	cashLabel.Text = CashFormat.format(math.floor(value + 0.5))
end)
local function updateCash()
	local cashNow = player:GetAttribute("Cash") or 0
	if cashTween then
		cashTween:Cancel()
		cashTween = nil
	end
	if cashNow > cashValue.Value and cashNow - cashValue.Value < 1e12 then
		cashTween = UITheme.tween(cashValue, 0.45, { Value = cashNow })
	else
		cashValue.Value = cashNow
		cashLabel.Text = CashFormat.format(cashNow)
	end
end
local incomeScale = UITheme.make("UIScale", { Parent = incomeLabel })
local shownIncome: number? = nil
local function updateIncome()
	local income = math.floor((player:GetAttribute("Income") or 0) + 0.5)
	incomeLabel.Text = if income > 0 then "+" .. CashFormat.format(income) .. "/s" else "No income yet"
	incomeLabel.TextColor3 = if income > 0 then T.Cash else T.TextMuted
	if shownIncome and income > shownIncome then
		incomeScale.Scale = 1.2
		UITheme.tween(incomeScale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	end
	shownIncome = income
	local bonus = player:GetAttribute("IncomeBonus")
	bonusChip.Visible = type(bonus) == "number" and bonus > 0
	if bonusChip.Visible then
		bonusLabel.Text = ("+%d%% Index"):format(math.floor(bonus * 100 + 0.5))
	end
end
player:GetAttributeChangedSignal("Cash"):Connect(updateCash)
player:GetAttributeChangedSignal("Income"):Connect(updateIncome)
player:GetAttributeChangedSignal("IncomeBonus"):Connect(updateIncome)
updateCash()
updateIncome()

-- Carry card (bottom centre) ---------------------------------------------------------------------------------
local CARRY_W, CARRY_H, STORE_W = 440, 88, 170
local carry =
	UITheme.panel({ Name = "CarryCard", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -HUD.MARGIN), Size = UDim2.fromOffset(CARRY_W, CARRY_H), Parent = root })
carry.Visible = false
local carryHolder = UITheme.make("UIScale", { Name = "Fit", Parent = carry }) -- the HUD rule (layout)
local carryTag = UITheme.text({
	Name = "CarryRarity",
	Text = "CARRYING",
	Role = "Small",
	Font = UITheme.Fonts.Display,
	TextSize = 17,
	Align = "Left",
	Position = UDim2.fromOffset(16, 10),
	Size = UDim2.new(1, -STORE_W - 32, 0, 22),
	Parent = carry,
})
local carryName = UITheme.text({
	Name = "CarryName",
	Text = "",
	Role = "Title",
	TextSize = 27,
	Align = "Left",
	Position = UDim2.fromOffset(16, 36),
	Size = UDim2.new(1, -STORE_W - 32, 0, 36),
	Parent = carry,
})
local storeButton = UITheme.button({
	Name = "StoreButton",
	Kind = "Secondary",
	Text = "Store",
	Icon = "backpack",
	TextSize = 22,
	Size = UDim2.fromOffset(STORE_W, 64),
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -12, 0.5, 0),
	Parent = carry,
	OnActivated = function()
		WorkerState.request("StoreCarried")
	end,
})
local carryBase = 1
local function updateWorkers()
	local stored, equipped, carried = WorkerState.counts()
	local snap = WorkerState.snapshot
	countChip.Text = ("%d/%d"):format(stored + equipped + carried, math.max(CAPACITY, snap.slots + snap.stations))
	local entry = if player:GetAttribute("CarryingNPC") == true then WorkerState.carried() else nil
	local was = carry.Visible
	carry.Visible = entry ~= nil
	if entry and not was then
		local base = carryBase
		carryHolder.Scale = base * 0.8
		UITheme.tween(carryHolder, 0.22, { Scale = base }, Enum.EasingStyle.Back)
	end
	if entry then
		local worker = WorkerCatalogue.get(entry.id)
		local rarity = worker and worker.rarity or "Common"
		carryName.Text = worker and worker.name or "Worker"
		carryTag.Text = "CARRYING  " .. (UITheme.RarityGlyph[rarity] or "") .. " " .. string.upper(rarity)
		carryTag.TextColor3 = UITheme.Rarity[rarity] or T.Text
		local full = stored >= snap.slots
		UITheme.setEnabled(storeButton, not full, if full then "Full" else "Store")
	end
end
WorkerState.Changed:Connect(updateWorkers)
player:GetAttributeChangedSignal("CarryingNPC"):Connect(updateWorkers)

-- Layout ------------------------------------------------------------------------------------------------------
local topBar = UITheme.topBar()
local view: any = nil
local function pvpColumn(): GuiObject?
	local pvp = player.PlayerGui:FindFirstChild("PvP")
	local column = pvp and pvp:FindFirstChild("Actions", true)
	return if column and column:IsA("GuiObject") and column.Visible and column.AbsoluteSize.Y > 1 then column else nil
end
local function inAvoid(y0: number, y1: number, x0: number, x1: number): number?
	-- the top edge of the first touch control this box would cover, if any
	for _, r in view.avoid do
		if x1 > r.min.X and x0 < r.max.X and y1 > r.min.Y and y0 < r.max.Y then
			return r.min.Y
		end
	end
	return nil
end
function relayout()
	if not view then
		return
	end
	local s, size = view.scale, view.size
	local gap = HUD.GAP
	-- top-left block (the pill's "+" is a button: at least TOUCH px)
	local pillH = math.max(PILL_H, math.ceil(HUD.TOUCH / s) + 6) -- (its "+" is pillH - 6: >= TOUCH on screen)
	local pillW = math.max(PILL_W, math.ceil(200 / s))
	topScale.Scale = s
	topLeft.Size = UDim2.fromOffset(pillW, 0)
	pill.Size = UDim2.fromOffset(pillW, pillH)
	incomeRow.Size = UDim2.fromOffset(pillW, 26)
	local topBottom = 8 + (pillH + 4 + 26) * s
	-- menu grid: the most columns-first shape that fits between the top block and the bottom
	local cell = UITheme.touchSize(CELL, s)
	local labelSize = math.max(15, math.ceil(11 / s)) -- never under 11 px on screen
	for _, b in buttons do
		local label = b:FindFirstChild("Label") :: TextLabel?
		if label then
			label.TextSize = labelSize
			label.Size = UDim2.new(1, 4, 0, labelSize + 2)
		end
		for _, child in b:GetChildren() do
			if child:GetAttribute("Icon") ~= nil and child:IsA("GuiObject") then
				child.Size = UDim2.new(1, -14, 1, -(labelSize + 10))
			end
		end
	end
	local n = 0
	for _, b in buttons do
		n += if b.Visible then 1 else 0
	end
	local bandTop = topBottom + gap
	local bandBottom = size.Y - HUD.MARGIN
	local thumbTop = inAvoid(0, size.Y, HUD.MARGIN, HUD.MARGIN + 1)
	if thumbTop then
		bandBottom = math.min(bandBottom, thumbTop - gap)
	end
	local cols, rows, w, h = 2, 1, 0, 0
	for _, c in { 2, 3, 6 } do
		cols = math.min(c, math.max(n, 1))
		rows = math.ceil(n / cols)
		w = (cols * cell + (cols - 1) * CELL_GAP) * s
		h = (rows * cell + (rows - 1) * CELL_GAP) * s
		if h <= bandBottom - bandTop then
			break
		end
	end
	gridLayout.CellSize = UDim2.fromOffset(cell, cell)
	gridScale.Scale = s
	grid.Size = UDim2.fromOffset(cols * cell + (cols - 1) * CELL_GAP, rows * cell + (rows - 1) * CELL_GAP)
	local y = math.clamp(size.Y / 2 - h / 2, bandTop, math.max(bandTop, bandBottom - h))
	grid.Position = UDim2.fromOffset(HUD.MARGIN, y)
	grid:SetAttribute("Columns", cols)
	-- carry card
	carryBase = s
	carryHolder.Scale = s
	local storeH = UITheme.touchSize(64, s)
	storeButton.Size = UDim2.fromOffset(STORE_W, storeH)
	carry.Size = UDim2.fromOffset(CARRY_W, math.max(CARRY_H, storeH + 20))
	-- the shared top piece: centred and a touch bigger, but never on the cash pill or, when they share
	-- the same height, on the right-hand column (then it is narrowed to fit between them)
	local fit = topBar:FindFirstChild("Fit") :: UIScale?
	if fit and fit.Scale > 0 then
		local natural = topBar.AbsoluteSize.X / fit.Scale
		local pillRight = HUD.MARGIN + pillW * s
		local right = size.X - HUD.MARGIN
		local column = pvpColumn()
		local barBottom = topBar.Position.Y.Offset + topBar.AbsoluteSize.Y
		if column and column.AbsolutePosition.Y - root.AbsolutePosition.Y < barBottom + gap then
			right = column.AbsolutePosition.X - root.AbsolutePosition.X
		end
		local avail = right - gap - (pillRight + gap)
		local want = s * 1.12
		local scale = if natural > 0 then math.min(want, avail / natural) else want
		if math.abs(fit.Scale - scale) > 0.002 then
			fit.Scale = scale
		end
		local w = natural * scale
		local cx = math.clamp(size.X / 2, pillRight + gap + w / 2, math.max(pillRight + gap + w / 2, right - gap - w / 2))
		topBar.AnchorPoint = Vector2.new(0.5, 0)
		topBar.Position = UDim2.new(0, cx, 0, topBar.Position.Y.Offset)
	end
end
UITheme.onHudLayout(root, function(v)
	view = v
	relayout()
end)
topBar:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
	if relayout then
		relayout()
	end
end)
task.spawn(function() -- the PvP column (another script) moves: keep the top piece clear of it
	local pvp = player.PlayerGui:WaitForChild("PvP", 30)
	local column = pvp and pvp:FindFirstChild("Actions", true)
	if column and column:IsA("GuiObject") then
		column:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
			if relayout then
				relayout()
			end
		end)
	end
end)
updateWorkers()

-- Badges from the rewards state ------------------------------------------------------------------------------
local lastState: any = nil
local stateAt = 0
local function nextGift(state: any): (number?, boolean)
	-- seconds until the next unopened gift, and whether one is ready now
	if not (state and state.play) then
		return nil, false
	end
	local played = state.play.secs + (os.clock() - stateAt)
	local wait, ready = nil, false
	for i, gift in state.play.gifts do
		if not state.play.got[tostring(i)] then
			local remaining = gift.minutes * 60 - played
			if remaining <= 0 then
				ready = true
			elseif not wait or remaining < wait then
				wait = remaining
			end
		end
	end
	return wait, ready
end
local function paintBadges()
	local s = lastState
	badges.Daily(if s and s.daily and s.daily.canClaim then "!" else nil)
	local wait, ready = nextGift(s)
	badges.Gifts(if ready then "!" else nil)
	giftsLabel.Text = if ready then "Gifts" elseif wait then ("%d:%02d"):format(math.floor(wait / 60), math.floor(wait % 60)) else "Gifts"
	local claimable = false
	if s and s.indexBonus and s.index then
		for _, z in s.index.zones do
			claimable = claimable or z.reached > z.claimed
		end
	end
	badges.Index(if claimable then "!" else nil)
end
rewardsState.OnClientEvent:Connect(function(state)
	lastState, stateAt = state, os.clock()
	paintBadges()
end)
rewardsAction:FireServer("State")
task.spawn(function()
	while gui.Parent do
		paintBadges() -- the gift countdown
		task.wait(1)
	end
end)
