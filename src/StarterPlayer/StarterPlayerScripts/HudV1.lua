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
local PILL_W, PILL_H, INCOME_H = 260, 62, 22

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

local incomeRow = UITheme.make("Frame", { Name = "IncomeRow", BackgroundTransparency = 1, Size = UDim2.fromOffset(PILL_W, INCOME_H), LayoutOrder = 2, Parent = topLeft })
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
	Size = UDim2.fromOffset(0, INCOME_H),
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
-- Roblox's chat window while it is open, in root coordinates (nil when closed). Studio layout tests:
-- PlayerGui attribute UITestChat = Rect (root coordinates) stands in for it.
local chatWindow = game:GetService("TextChatService"):FindFirstChildOfClass("ChatWindowConfiguration")
local function chatRect(): Rect?
	local test = player.PlayerGui:GetAttribute("UITestChat")
	if typeof(test) == "Rect" then
		return test
	elseif player.PlayerGui:GetAttribute("UITestViewport") ~= nil then
		return nil -- (a simulated screen size: the real chat window's place doesn't apply)
	end
	if chatWindow and chatWindow.Enabled and chatWindow.AbsoluteSize.X > 1 then
		local p = chatWindow.AbsolutePosition - root.AbsolutePosition
		return Rect.new(p, p + chatWindow.AbsoluteSize)
	end
	return nil
end

local PLATE_Y = 16
function relayout()
	if not view then
		return
	end
	local s, size = view.scale, view.size
	local gap = HUD.GAP
	local small = math.min(size.X, size.Y) <= 500
	-- the left group (cash pill + menu buttons) is bigger than the rest of the HUD: x1.25 on phones,
	-- x1.15 on tablets and PCs
	local factor = if small then 1.25 else 1.15
	local sL = s * factor
	local floor = HUD.TOUCH * factor -- its smallest tap size grows with it (70 px on phones)
	-- top-left block (the pill's "+" is a button)
	local pillH = math.max(PILL_H, math.ceil(floor / sL) + 6) -- (its "+" is pillH - 6)
	local pillW = math.max(PILL_W, math.ceil(200 * factor / sL))
	local cell = math.max(CELL, math.ceil(floor / sL))
	local thumbTop = inAvoid(0, size.Y, HUD.MARGIN, HUD.MARGIN + 1)
	local bottomLimit = if thumbTop then thumbTop - gap else size.Y - HUD.MARGIN
	topScale.Scale = sL
	topLeft.Size = UDim2.fromOffset(pillW, 0)
	pill.Size = UDim2.fromOffset(pillW, pillH)
	incomeRow.Size = UDim2.fromOffset(pillW, INCOME_H)
	local pillRight = HUD.MARGIN + pillW * sL
	-- below the chat window while it is open there (it draws over everything) - when the whole group
	-- still fits under it; on short phone screens it can't, and the open chat covers it
	local top = 8
	local chat = chatRect()
	if chat and chat.Min.X < pillRight and chat.Max.X > HUD.MARGIN then
		local below = math.ceil(chat.Max.Y) + gap
		local portraitPlate = if size.Y > size.X then 72 * s * 1.12 + gap else 0
		local besideColumn = pillW * sL <= size.X - 2 * HUD.MARGIN - HUD.ACTION_W * s - gap
		if besideColumn and below + (pillH + 4 + INCOME_H) * sL + gap + portraitPlate + cell * sL <= bottomLimit then
			top = below
		end
	end
	topLeft.Position = UDim2.fromOffset(HUD.MARGIN, top)
	local topBottom = top + (pillH + 4 + INCOME_H) * sL

	-- the shared top piece (Golden timer + goal): centred and a touch bigger, beside the cash pill
	-- (narrowed to fit); on portrait screens, if it would lose more than 20%, on its own row under the pill
	local plateBottom = 0
	local fit = topBar:FindFirstChild("Fit") :: UIScale?
	if fit and fit.Scale > 0 and topBar.AbsoluteSize.X > 0 then
		local natural = topBar.AbsoluteSize / fit.Scale
		local want = s * 1.12
		local column = pvpColumn()
		local function rightLimit(y0: number, y1: number): number
			if column then
				local cy = column.AbsolutePosition.Y - root.AbsolutePosition.Y
				if cy < y1 + gap and cy + column.AbsoluteSize.Y > y0 then
					return column.AbsolutePosition.X - root.AbsolutePosition.X
				end
			end
			return size.X - HUD.MARGIN
		end
		local plateH = natural.Y * want
		local plateLeft = if top < PLATE_Y + plateH then pillRight + gap else HUD.MARGIN
		local right = rightLimit(PLATE_Y, PLATE_Y + plateH)
		local y = PLATE_Y
		if size.Y > size.X and right - gap - plateLeft < natural.X * want * 0.8 then -- portrait, no room: own row
			y = math.ceil(topBottom) + gap
			plateLeft = HUD.MARGIN
			right = rightLimit(y, y + plateH)
		end
		local scale = math.min(want, (right - gap - plateLeft) / natural.X)
		if math.abs(fit.Scale - scale) > 0.002 then
			fit.Scale = scale
		end
		local w = natural.X * scale
		local cx = math.clamp(size.X / 2, plateLeft + w / 2, math.max(plateLeft + w / 2, right - gap - w / 2))
		topBar.AnchorPoint = Vector2.new(0.5, 0)
		topBar.Position = UDim2.fromOffset(cx, y)
		plateBottom = if y > PLATE_Y then y + natural.Y * scale else 0
	end

	-- menu grid: the most columns-first shape that fits between the top block and the bottom, and
	-- leaves room for the right-hand column
	local labelSize = math.max(15, math.ceil(11 / sL)) -- never under 11 px on screen
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
	local bandTop = math.max(topBottom, plateBottom) + gap
	local bandBottom = bottomLimit
	local maxW = size.X - 2 * HUD.MARGIN - HUD.ACTION_W * s - gap
	local cols, rows, h = 2, 1, 0
	for _, c in { 2, 3, 6 } do
		local tryCols = math.min(c, math.max(n, 1))
		if tryCols > 2 and (tryCols * cell + (tryCols - 1) * CELL_GAP) * sL > maxW then
			break -- wider would run into the right-hand column
		end
		cols = tryCols
		rows = math.ceil(n / cols)
		h = (rows * cell + (rows - 1) * CELL_GAP) * sL
		if h <= bandBottom - bandTop then
			break
		end
	end
	gridLayout.CellSize = UDim2.fromOffset(cell, cell)
	gridScale.Scale = sL
	grid.Size = UDim2.fromOffset(cols * cell + (cols - 1) * CELL_GAP, rows * cell + (rows - 1) * CELL_GAP)
	local y = math.clamp(size.Y / 2 - h / 2, bandTop, math.max(bandTop, bandBottom - h))
	grid.Position = UDim2.fromOffset(HUD.MARGIN, y)
	grid:SetAttribute("Columns", cols)

	-- carry card (the rest of the HUD's size)
	carryBase = s
	carryHolder.Scale = s
	local storeH = UITheme.touchSize(64, s)
	storeButton.Size = UDim2.fromOffset(STORE_W, storeH)
	carry.Size = UDim2.fromOffset(CARRY_W, math.max(CARRY_H, storeH + 20))
	-- bottom centre, lifted above the thumbstick / jump button where it would reach them (portrait)
	local half = CARRY_W * s / 2
	local bottom = size.Y - HUD.MARGIN
	for _, r in view.avoid do
		if size.X / 2 + half > r.min.X and size.X / 2 - half < r.max.X then
			bottom = math.min(bottom, r.min.Y - gap)
		end
	end
	carry.Position = UDim2.new(0.5, 0, 0, bottom)
end
if chatWindow then
	chatWindow:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		relayout()
	end)
end
player.PlayerGui:GetAttributeChangedSignal("UITestChat"):Connect(function()
	relayout()
end)
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
