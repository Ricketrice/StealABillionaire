-- Studio location: StarterPlayer.StarterPlayerScripts.HudV1 (LocalScript)
-- HudV1  (Milestone 029) -- the HUD in the V1 look (V1Flags.UI_V1_ENABLED; the old Hud runs otherwise).
-- Top-left, kept clear of the Roblox top bar, the thumbstick (bottom-left) and the jump button:
--   * cash pill (rolls up; the green "+" opens the Store's cash tab while the Store is on)
--   * income per second, with the index bonus ("+10%") when one is claimed
--   * icon buttons, 3 per row: Store, Workers, Index, Daily, Gifts, Settings (each only while its
--     feature is on); red "!" badges when something is ready to collect
-- Bottom centre (only while carrying): the worker's rarity + name and a Store button.
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
local left = UITheme.make("Frame", {
	Name = "Left",
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(18, 10),
	Size = UDim2.fromOffset(222, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	Parent = root,
})
UITheme.make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = left })
-- 0.68 keeps a 66 px button at 45 px on the smallest phones (touch target 44).
UITheme.scaleWith(left, 0.68, 1.1)

local pill, cashLabel = UITheme.pill({
	Name = "CashPill",
	Icon = "cash",
	Text = "$0",
	Width = 222,
	Height = 52,
	LayoutOrder = 1,
	Parent = left,
	OnPlus = function()
		UITheme.openScreen("Store", "cash")
	end,
})
UITheme.make("UIScale", { Name = "Bump", Parent = pill })
UITheme.setCashTarget(pill)
local plus = pill:FindFirstChild("Plus") :: TextButton

local incomeRow = UITheme.make("Frame", { Name = "IncomeRow", BackgroundTransparency = 1, Size = UDim2.fromOffset(222, 26), LayoutOrder = 2, Parent = left })
UITheme.make(
	"UIListLayout",
	{
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = incomeRow,
	}
)
UITheme.make("UIPadding", { PaddingLeft = UDim.new(0, 8), Parent = incomeRow })
local incomeLabel = UITheme.text({
	Name = "Income",
	Text = "+$0/s",
	Role = "Display",
	TextSize = 20,
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

local grid =
	UITheme.make("Frame", { Name = "Buttons", BackgroundTransparency = 1, Size = UDim2.fromOffset(222, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 3, Parent = left })
UITheme.make("UIGridLayout", { CellSize = UDim2.fromOffset(70, 70), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })

local buttons, badges = {}, {}
local function addButton(key: string, icon: string, label: string, order: number, action: () -> ())
	local b = UITheme.iconButton({ Name = key, Icon = icon, Label = label, LayoutOrder = order, Size = UDim2.fromOffset(70, 70), Parent = grid, OnActivated = action })
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
local carry = UITheme.panel({ Name = "CarryCard", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -14), Size = UDim2.fromOffset(330, 70), Parent = root })
carry.Visible = false
local carryScale = UITheme.scaleWith(carry, 0.68, 1.05)
local carryTag = UITheme.text({
	Name = "CarryRarity",
	Text = "CARRYING",
	Role = "Small",
	Font = UITheme.Fonts.Display,
	TextSize = 15,
	Align = "Left",
	Position = UDim2.fromOffset(14, 8),
	Size = UDim2.new(1, -140, 0, 20),
	Parent = carry,
})
local carryName = UITheme.text({
	Name = "CarryName",
	Text = "",
	Role = "Title",
	TextSize = 22,
	Align = "Left",
	Position = UDim2.fromOffset(14, 30),
	Size = UDim2.new(1, -140, 0, 30),
	Parent = carry,
})
local storeButton = UITheme.button({
	Name = "StoreButton",
	Kind = "Secondary",
	Text = "Store",
	Icon = "backpack",
	Size = UDim2.fromOffset(116, 52),
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -9, 0.5, 0),
	Parent = carry,
	OnActivated = function()
		WorkerState.request("StoreCarried")
	end,
})
local function updateWorkers()
	local stored, equipped, carried = WorkerState.counts()
	local snap = WorkerState.snapshot
	countChip.Text = ("%d/%d"):format(stored + equipped + carried, math.max(CAPACITY, snap.slots + snap.stations))
	local entry = if player:GetAttribute("CarryingNPC") == true then WorkerState.carried() else nil
	local was = carry.Visible
	carry.Visible = entry ~= nil
	if entry and not was then
		local base = carryScale.Scale
		carryScale.Scale = base * 0.8
		UITheme.tween(carryScale, 0.22, { Scale = base }, Enum.EasingStyle.Back)
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
