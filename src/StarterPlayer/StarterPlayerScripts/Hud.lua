-- Studio location: StarterPlayer.StarterPlayerScripts.Hud (LocalScript)
-- Hud
-- Always-on HUD, a compact stack on the left (vertically centred a little low: clear of the top bar,
-- the default chat window, and the mobile thumbstick and jump button):
--   * cash card: balance and combined income per second
--   * Workers button: workers owned / capacity and how many are earning; opens the inventory
--   * carrying row (only while carrying): the worker's rarity and name, with a Store shortcut
-- The income counter counts to its new value and pops when it grows (Milestone 017).
-- Display only: cash and income are server-written player attributes; worker data comes from
-- WorkerState; Store is a request the server validates.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CashFormat = require(ReplicatedStorage:WaitForChild("CashFormat"))
local InventoryConfig = require(ReplicatedStorage:WaitForChild("InventoryConfig"))
local UIKit = require(ReplicatedStorage:WaitForChild("UIKit"))
local UIStyle = require(ReplicatedStorage:WaitForChild("UIStyle"))
local WorkerCatalogue = require(ReplicatedStorage:WaitForChild("WorkerCatalogue"))
local WorkerState = require(ReplicatedStorage:WaitForChild("WorkerState"))

if UIStyle.v1 then
	return -- Milestone 029: with the V1 look on, HudV1 is the HUD
end

local player = Players.LocalPlayer
local C, S = UIStyle.Colors, UIStyle.Space
local CAPACITY = InventoryConfig.INVENTORY_SLOTS + InventoryConfig.STATION_SLOTS
local WIDTH = 214

local gui = UIKit.screen("Hud", UIStyle.DisplayOrder.Hud)
local root = UIKit.root(gui)

local stack = UIKit.make("Frame", {
	Name = "Stack",
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 12, 0.48, 0),
	Size = UDim2.fromOffset(WIDTH, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
	Parent = root,
})
UIKit.list(stack, Enum.FillDirection.Vertical, S.S)
UIKit.scaled(stack, 0.8, 1.2, root)

-- Cash card
local cash = UIKit.panel({ Name = "CashCard", Size = UDim2.fromOffset(WIDTH, 64), LayoutOrder = 1, Parent = stack })
local coin = UIKit.make(
	"Frame",
	{ Name = "Coin", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 11, 0.5, 0), Size = UDim2.fromOffset(40, 40), BackgroundColor3 = C.Gold, Parent = cash }
)
UIStyle.corner(coin, UIStyle.Radius.Pill)
UIStyle.outline(coin, C.GoldDark, 2)
UIKit.text({
	Text = CashFormat.SYMBOL,
	Role = "Title",
	TextSize = 24,
	Color = C.PrimaryText,
	AlignX = Enum.TextXAlignment.Center,
	Size = UDim2.fromScale(1, 1),
	Stroke = false,
	Parent = coin,
})
local cashLabel =
	UIKit.text({ Name = "Cash", Text = CashFormat.format(0), Role = "Display", TextSize = 26, Position = UDim2.fromOffset(60, 7), Size = UDim2.new(1, -68, 0, 30), Parent = cash })
local incomeLabel = UIKit.text({
	Name = "Income",
	Text = "+" .. CashFormat.format(0) .. "/s",
	Role = "Heading",
	TextSize = 14,
	Color = C.Cash,
	Position = UDim2.fromOffset(60, 38),
	Size = UDim2.new(1, -68, 0, 18),
	Parent = cash,
})

-- With the 028 juice on (ReplicatedStorage.JuiceOn) the cash counter rolls up instead of jumping.
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
	if game:GetService("ReplicatedStorage"):GetAttribute("JuiceOn") == true and cashNow > cashValue.Value then
		cashTween = UIKit.tween(cashValue, 0.45, { Value = cashNow })
	else
		cashValue.Value = cashNow
		cashLabel.Text = CashFormat.format(cashNow)
	end
end
local function renderIncome(income: number)
	income = math.floor(income + 0.5)
	incomeLabel.Text = if income > 0 then "+" .. CashFormat.format(income) .. "/s" else "No income yet"
	incomeLabel.TextColor3 = if income > 0 then C.Cash else C.TextMuted
end
-- The counter runs to its new value in 0.3 s (one tween, no loop) and pops when income grows.
local incomeValue = Instance.new("NumberValue")
local incomeScale = UIKit.make("UIScale", { Parent = incomeLabel }) :: UIScale
local incomeTween: Tween? = nil
local shownIncome: number? = nil
incomeValue.Changed:Connect(renderIncome)
local function popIncome()
	incomeScale.Scale = 1.2
	UIKit.tween(incomeScale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
end
local function updateIncome()
	local income = player:GetAttribute("Income") or 0
	if shownIncome == nil then
		incomeValue.Value = income
		renderIncome(income)
	elseif income ~= shownIncome then
		if incomeTween then
			incomeTween:Cancel()
		end
		incomeTween = UIKit.tween(incomeValue, 0.3, { Value = income })
		if income > shownIncome then
			popIncome()
		end
	end
	shownIncome = income
end
if RunService:IsStudio() then
	UIKit.Signals.DebugFx.Event:Connect(function(kind)
		if kind == "place" then
			popIncome()
		end
	end)
end
player:GetAttributeChangedSignal("Cash"):Connect(updateCash)
player:GetAttributeChangedSignal("Income"):Connect(updateIncome)
updateCash()
updateIncome()

-- Creatures button: label + "x/6 earning" on the left, owned/capacity chip on the right
local workersButton = UIKit.button({
	Name = "WorkersButton",
	Kind = "Secondary",
	Text = "",
	Size = UDim2.fromOffset(WIDTH, 52),
	LayoutOrder = 2,
	Parent = stack,
	OnActivated = function()
		UIKit.Signals.ToggleInventory:Fire(nil)
	end,
})
UIKit.text({ Text = "CREATURES", Role = "Heading", TextSize = 15, Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -96, 0, 18), Parent = workersButton })
local earningLabel = UIKit.text({
	Name = "Earning",
	Text = "0/6 earning",
	Role = "Micro",
	Font = UIStyle.FontBold,
	Color = C.TextMuted,
	Position = UDim2.fromOffset(14, 27),
	Size = UDim2.new(1, -96, 0, 14),
	Parent = workersButton,
})
local _, countLabel = UIKit.chip({
	Name = "Owned",
	Text = "0/" .. CAPACITY,
	Height = 26,
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -10, 0.5, 0),
	Color = C.Gold,
	Parent = workersButton,
})

-- Carrying row: compact, with a large Store target
local carry = UIKit.panel({ Name = "CarryCard", Size = UDim2.fromOffset(WIDTH, 56), LayoutOrder = 3, BorderColor = C.Gold, Parent = stack })
carry.Visible = false
local carryTag = UIKit.text({
	Name = "CarryRarity",
	Text = "CARRYING",
	Role = "Micro",
	Font = UIStyle.FontBold,
	Color = C.Gold,
	Position = UDim2.fromOffset(12, 8),
	Size = UDim2.new(1, -112, 0, 14),
	Parent = carry,
})
local carryScale = UIKit.make("UIScale", { Parent = carry }) :: UIScale
local carryName = UIKit.text({
	Name = "CarryName",
	Text = "",
	Role = "Heading",
	TextSize = 14,
	Rich = true,
	Position = UDim2.fromOffset(12, 25),
	Size = UDim2.new(1, -112, 0, 20),
	Parent = carry,
})
local storeCtl -- assigned below; the click handler needs it as an upvalue
local _, ctl = UIKit.button({
	Name = "StoreButton",
	Kind = "Primary",
	Text = "Store",
	Size = UDim2.fromOffset(88, UIStyle.TouchTarget),
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -6, 0.5, 0),
	Parent = carry,
	OnActivated = function()
		storeCtl.setEnabled(false, "…")
		WorkerState.request("StoreCarried")
		task.delay(1.5, function()
			storeCtl.setEnabled(true)
		end)
	end,
})
storeCtl = ctl

local function updateWorkers()
	local stored, equipped, carried = WorkerState.counts()
	local snap = WorkerState.snapshot
	countLabel.Text = ("%d/%d"):format(stored + equipped + carried, math.max(CAPACITY, snap.slots + snap.stations))
	earningLabel.Text = ("%d/%d earning"):format(equipped, snap.stations)
	earningLabel.TextColor3 = if equipped > 0 then C.Cash else C.TextMuted
	local entry = if player:GetAttribute("CarryingNPC") == true then WorkerState.carried() else nil
	local wasCarrying = carry.Visible
	carry.Visible = entry ~= nil
	if entry and not wasCarrying then
		carryScale.Scale = 0.85
		UIKit.tween(carryScale, 0.2, { Scale = 1 }, Enum.EasingStyle.Back)
	end
	if entry then
		local worker = WorkerCatalogue.get(entry.id)
		local rarity = worker and worker.rarity or "Common"
		local color = UIStyle.Rarity[rarity] or C.Text
		carryName.Text = worker and worker.name or "Creature"
		carryTag.Text = (UIStyle.RarityGlyph[rarity] or "") .. " " .. string.upper(rarity)
		carryTag.TextColor3 = color
		local full = stored >= snap.slots
		storeCtl.setEnabled(not full, if full then "Full" else nil)
	end
end
WorkerState.Changed:Connect(updateWorkers)
player:GetAttributeChangedSignal("CarryingNPC"):Connect(updateWorkers)
updateWorkers()

UIKit.mount(gui)
