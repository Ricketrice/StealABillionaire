-- Studio location: StarterPlayer.StarterPlayerScripts.HudV1 (LocalScript)
-- HudV1  (Milestone 029) -- the HUD in the V1 look (V1Flags.UI_V1_ENABLED; the old Hud runs otherwise).
-- Layout (029 layout fix), all sizes from the one HUD rule (UITheme.hudScale / touchSize):
--   * left side, vertically centred, as one group (top-left stays free for Roblox's chat window):
--     the cash pill (rolls up; the green "+" opens the Store's cash tab while the Store is on) with
--     the income per second under it (+ the index bonus chip; 032: a shoe + "Speed 100" row under that
--     while ReplicatedStorage.SpeedOn, green when a trail boosts it), and directly below them the menu
--     buttons Store, Workers, Index, Daily, Gifts, Settings (each only while its feature is on) in 2
--     columns; on short screens 3 columns (or one row) so the group stays clear of the thumbstick on
--     touch screens; red "!" badges when ready
--   * bottom centre (only while carrying): the worker's rarity + name and a Store button
--   * this script also keeps the shared top piece (Golden timer + goal) clear of the left group
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
local laneRequest = ReplicatedStorage:WaitForChild("LaneTravel") :: RemoteEvent -- Home / Zones (030)

local function on(attribute: string): boolean
	return ReplicatedStorage:GetAttribute(attribute) == true
end

local gui, root = UITheme.gui("HudV1", 2)

-- Left column ------------------------------------------------------------------------------------------
local HUD = UITheme.HUD
local left = UITheme.make("Frame", { Name = "Left", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = root })
-- cash block: pill + income, scaled as one (the pill's own "Bump" UIScale is separate)
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
	Text = CashFormat.format(0),
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
	Text = "+" .. CashFormat.format(0) .. "/s",
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

-- Speed (032, D24): shoe icon + the Speed number (100 = normal), only while the Speed stat is on
local SPEED_H = 26
local speedRow =
	UITheme.make("Frame", { Name = "SpeedRow", BackgroundTransparency = 1, Size = UDim2.fromOffset(PILL_W, SPEED_H), LayoutOrder = 3, Visible = false, Parent = topLeft })
UITheme.make("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	VerticalAlignment = Enum.VerticalAlignment.Center,
	Padding = UDim.new(0, 4),
	SortOrder = Enum.SortOrder.LayoutOrder,
	Parent = speedRow,
})
UITheme.make("UIPadding", { PaddingLeft = UDim.new(0, 4), Parent = speedRow })
UITheme.image({ Icon = "shoe", Name = "Shoe", Size = UDim2.fromOffset(SPEED_H + 6, SPEED_H + 6), LayoutOrder = 1, Parent = speedRow })
local speedLabel = UITheme.text({
	Name = "Speed",
	Text = "Speed 100",
	Role = "Display",
	TextSize = 19,
	Align = "Left",
	Size = UDim2.fromOffset(0, SPEED_H),
	AutomaticSize = Enum.AutomaticSize.X,
	LayoutOrder = 2,
	Parent = speedRow,
})
speedLabel.TextTruncate = Enum.TextTruncate.None
local speedScale = UITheme.make("UIScale", { Parent = speedLabel })

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
addButton("Home", "base", "Home", 7, function()
	laneRequest:FireServer("Home")
end)
addButton("Zones", "flag", "Zones", 8, function()
	UITheme.openScreen("Zones")
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
local shownSpeed: number? = nil
local function updateSpeed()
	local visible = on("SpeedOn")
	local n = player:GetAttribute("SpeedHud")
	n = if type(n) == "number" then n else 100
	speedLabel.Text = "Speed " .. n
	speedLabel.TextColor3 = if n > 100 then T.Cash else T.Text
	if shownSpeed and n > shownSpeed then
		speedScale.Scale = 1.3
		UITheme.tween(speedScale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
	end
	shownSpeed = n
	if speedRow.Visible ~= visible then
		speedRow.Visible = visible
		if relayout then
			relayout()
		end
	end
end
player:GetAttributeChangedSignal("SpeedHud"):Connect(updateSpeed)
ReplicatedStorage:GetAttributeChangedSignal("SpeedOn"):Connect(updateSpeed)
task.defer(updateSpeed)
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
-- The right-hand (PvP) column's visible pieces, as Rects in root coordinates. On short landscape phones
-- it is two columns (buttons, and status items under the top piece), so its frame isn't one solid block.
local function pvpRects(): { Rect }
	local pvp = player.PlayerGui:FindFirstChild("PvP")
	local column = pvp and pvp:FindFirstChild("Actions", true)
	local rects = {}
	if column and column:IsA("GuiObject") and column.Visible then
		for _, item in column:GetChildren() do
			if item:IsA("GuiObject") and item.Visible and item.AbsoluteSize.Y > 1 then
				local p = item.AbsolutePosition - root.AbsolutePosition
				table.insert(rects, Rect.new(p, p + item.AbsoluteSize))
			end
		end
	end
	return rects
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
-- Roblox's chat window opens top-left. On tablets and PCs the left group stays under where it opens
-- (8, 12, 475 x 190) even while it is closed; on phones it can't fit under it, and the open chat covers it.
local CHAT_RESERVE = Rect.new(8, 12, 483, 202)
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
	local maxW = size.X - 2 * HUD.MARGIN - HUD.ACTION_W * s - gap -- room left of the right-hand column
	local pvp = pvpRects()
	local function rightLimit(y0: number, y1: number): number
		-- the left edge of the right-hand column's pieces beside this band (or of the screen's margin)
		local x = size.X - HUD.MARGIN
		for _, r in pvp do
			if r.Min.Y < y1 + gap and r.Max.Y > y0 - gap then
				x = math.min(x, r.Min.X)
			end
		end
		return x
	end
	-- the pill (its "+" is a button, pillH - 6), narrowed to fit beside the right-hand column
	local pillH = math.max(PILL_H, math.ceil(floor / sL) + 6)
	local pillW = math.max(PILL_W, math.min(math.ceil(200 * factor / sL), math.floor(maxW / sL)))
	local cell = math.max(CELL, math.ceil(floor / sL))
	local thumbTop = inAvoid(0, size.Y, HUD.MARGIN, HUD.MARGIN + 1)
	local bottomLimit = if thumbTop then thumbTop - gap else size.Y - HUD.MARGIN
	topScale.Scale = sL
	topLeft.Size = UDim2.fromOffset(pillW, 0)
	pill.Size = UDim2.fromOffset(pillW, pillH)
	incomeRow.Size = UDim2.fromOffset(pillW, INCOME_H)
	speedRow.Size = UDim2.fromOffset(pillW, SPEED_H)
	local pillRight = HUD.MARGIN + pillW * sL
	local pillBlock = (pillH + 4 + INCOME_H + (if speedRow.Visible then 4 + SPEED_H else 0)) * sL

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

	-- The left group: the cash pill (income under it) directly above the menu grid, vertically centred
	-- on the left, above the thumbstick and, when it fits, under the chat window. The grid takes the
	-- most columns-first shape (2, 3, 4 or 6 columns) that fits and leaves room for the right-hand column.
	local function placeGroup(topMin: number)
		local room = bottomLimit - topMin - pillBlock - gap
		local cols, rows, h, fits = 2, 1, 0, false
		for _, c in { 2, 3, 4, 6 } do
			local tryCols = math.min(c, math.max(n, 1))
			local w = (tryCols * cell + (tryCols - 1) * CELL_GAP) * sL
			local tryRows = math.ceil(n / tryCols)
			local tryH = if n > 0 then (tryRows * cell + (tryRows - 1) * CELL_GAP) * sL else 0
			local tryTop = math.clamp(size.Y / 2 - (pillBlock + gap + tryH) / 2, topMin, math.max(topMin, bottomLimit - pillBlock - gap - tryH))
			local gridTop = tryTop + pillBlock + gap
			if tryCols > 2 and (w > maxW or HUD.MARGIN + w + gap > rightLimit(gridTop, gridTop + tryH)) then
				break -- wider would run into the right-hand column
			end
			cols, rows, h = tryCols, tryRows, tryH
			fits = h <= room
			if fits then
				break
			end
		end
		local groupH = pillBlock + (if n > 0 then gap + h else 0)
		local top = math.clamp(size.Y / 2 - groupH / 2, topMin, math.max(topMin, bottomLimit - groupH))
		return { top = top, cols = cols, rows = rows, h = h, fits = fits }
	end
	local group
	local openChat = chatRect()
	local chat = openChat or (if small then nil else CHAT_RESERVE)
	if chat and chat.Min.X < size.X / 2 then
		group = placeGroup(math.max(8, math.ceil(chat.Max.Y) + gap))
	end
	if not (group and group.fits) then
		group = placeGroup(8)
	end
	if not group.fits and n > 6 then
		-- still too tall (a very short screen with the right column wrapped): smaller menu buttons, never under 48 px
		cell = math.max(math.floor(CELL * 0.75), math.ceil(48 / sL))
		group = placeGroup(8)
	end

	-- the shared top piece (Golden timer + goal): centred and a touch bigger, narrowed to fit between the
	-- left group (and the open chat window) and the right-hand column where they reach its height; on
	-- portrait screens, if it would lose more than 20%, the left group moves under it instead
	local fit = topBar:FindFirstChild("Fit") :: UIScale?
	if fit and fit.Scale > 0 and topBar.AbsoluteSize.X > 0 then
		local natural = topBar.AbsoluteSize / fit.Scale
		local want = s * 1.12
		local function leftLimit(y0: number, y1: number): number
			local x = HUD.MARGIN
			if openChat and openChat.Min.X < size.X / 2 and y0 < openChat.Max.Y + gap and y1 > openChat.Min.Y - gap then
				x = math.max(x, openChat.Max.X + gap)
			end
			if y0 < group.top + pillBlock + gap and y1 > group.top - gap then
				x = math.max(x, pillRight + gap)
			end
			local gridTop = group.top + pillBlock + gap
			if n > 0 and y0 < gridTop + group.h + gap and y1 > gridTop - gap then
				x = math.max(x, HUD.MARGIN + (group.cols * cell + (group.cols - 1) * CELL_GAP) * sL + gap)
			end
			return x
		end
		local plateH = natural.Y * want
		local plateLeft = leftLimit(PLATE_Y, PLATE_Y + plateH)
		local right = rightLimit(PLATE_Y, PLATE_Y + plateH)
		if size.Y > size.X and right - gap - plateLeft < natural.X * want * 0.8 then -- portrait, no room
			local lower = placeGroup(math.ceil(PLATE_Y + plateH) + gap)
			if lower.fits then
				group = lower
				plateLeft = leftLimit(PLATE_Y, PLATE_Y + plateH)
			end
		end
		local scale = math.min(want, (right - gap - plateLeft) / natural.X)
		if math.abs(fit.Scale - scale) > 0.002 then
			fit.Scale = scale
		end
		local w = natural.X * scale
		local cx = math.clamp(size.X / 2, plateLeft + w / 2, math.max(plateLeft + w / 2, right - gap - w / 2))
		topBar.AnchorPoint = Vector2.new(0.5, 0)
		topBar.Position = UDim2.fromOffset(cx, PLATE_Y)
	end

	topLeft.Position = UDim2.fromOffset(HUD.MARGIN, group.top)
	gridLayout.CellSize = UDim2.fromOffset(cell, cell)
	gridScale.Scale = sL
	grid.Size = UDim2.fromOffset(group.cols * cell + (group.cols - 1) * CELL_GAP, math.max(0, group.rows * cell + (group.rows - 1) * CELL_GAP))
	grid.Position = UDim2.fromOffset(HUD.MARGIN, group.top + pillBlock + gap)
	grid:SetAttribute("Columns", group.cols)

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
task.spawn(function() -- the PvP column (another script) moves or changes: keep clear of its pieces
	local pvp = player.PlayerGui:WaitForChild("PvP", 30)
	local column = pvp and pvp:FindFirstChild("Actions", true)
	if not (column and column:IsA("GuiObject")) then
		return
	end
	local queued = false
	local function soon()
		if not queued then
			queued = true
			task.defer(function()
				queued = false
				if relayout then
					relayout()
				end
			end)
		end
	end
	for _, piece in { column, table.unpack(column:GetChildren()) } do
		if piece:IsA("GuiObject") then
			piece:GetPropertyChangedSignal("AbsolutePosition"):Connect(soon)
			piece:GetPropertyChangedSignal("AbsoluteSize"):Connect(soon)
			piece:GetPropertyChangedSignal("Visible"):Connect(soon)
		end
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
