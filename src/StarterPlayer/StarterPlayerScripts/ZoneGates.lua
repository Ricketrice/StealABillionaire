-- Studio location: StarterPlayer.StarterPlayerScripts.ZoneGates (LocalScript)
-- ZoneGates
-- District gates for this player only. For every wired gate (ZoneConfig `gate`), this client:
--   * lets its own character through once the district is unlocked, by switching the barrier's
--     collision off locally (other players' copies are untouched; the server separately turns back
--     anyone who isn't allowed in, so this is never the only protection)
--   * shows a prompt at the gate that opens the unlock panel: district, price, cash, progress, and
--     the reason it can't be bought yet (previous district or cash). Buying takes two taps.
-- Display only: the server decides every purchase. Gate parts may stream in and out, so their local
-- state is reapplied regularly.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CashFormat = require(ReplicatedStorage:WaitForChild("CashFormat"))
local UIKit = require(ReplicatedStorage:WaitForChild("UIKit"))
local UIStyle = require(ReplicatedStorage:WaitForChild("UIStyle"))
local ZoneConfig = require(ReplicatedStorage:WaitForChild("ZoneConfig"))
local C = UIStyle.Colors

local player = Players.LocalPlayer
local unlockRemote = ReplicatedStorage:WaitForChild("ZoneUnlock") :: RemoteFunction
local noticeEvent = ReplicatedStorage:WaitForChild("ZoneNotice") :: RemoteEvent

local PROMPT_NAME = "ZoneUnlockPrompt"
local PROMPT_RANGE = 14
local PANEL_RANGE = 24 -- the panel closes when the player walks this far from its gate
local CONFIRM_WINDOW = 4 -- seconds the second (confirming) tap stays available
local REAPPLY_INTERVAL = 0.5

local futureZones = workspace:WaitForChild("World"):WaitForChild("FutureZones")

local function unlockedSet(): { [string]: boolean }
	local set = { [ZoneConfig.FREE_ZONE] = true }
	for id in string.gmatch(player:GetAttribute("UnlockedZones") or "", "[^,]+") do
		set[id] = true
	end
	return set
end

local function getCash(): number
	return player:GetAttribute("Cash") or 0
end

local function getBarrier(zone: ZoneConfig.Zone): BasePart?
	local folder = zone.folder and futureZones:FindFirstChild(zone.folder)
	local gate = folder and folder:FindFirstChild("Gate")
	local barrier = gate and gate:FindFirstChild("Barrier")
	return if barrier and barrier:IsA("BasePart") then barrier else nil
end

-- Unlock panel -------------------------------------------------------------------------------------
local gui = UIKit.screen("ZoneUnlock", UIStyle.DisplayOrder.Inventory + 1)
local root = UIKit.root(gui)
local panel = UIKit.panel({ Name = "Panel", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -16), Size = UDim2.new(0.94, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BorderColor = C.GoldDark, Parent = root })
panel.Visible = false
UIKit.make("UISizeConstraint", { MaxSize = Vector2.new(380, math.huge), Parent = panel })
UIKit.padding(panel, 16, 14)
UIKit.list(panel, Enum.FillDirection.Vertical, 8)

local header = UIKit.text({ Text = "", Role = "Micro", Font = UIStyle.FontBold, Color = C.Gold, LayoutOrder = 1, Parent = panel })
local title = UIKit.text({ Text = "", Role = "Title", LayoutOrder = 2, Parent = panel })
local status = UIKit.text({ Text = "", Role = "Body", Color = C.TextMuted, Wrap = true, Truncate = false, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 3, Parent = panel })

local function statRow(order: number, label: string): TextLabel
	local row = UIKit.make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 22), LayoutOrder = order, Parent = panel })
	UIKit.text({ Text = label, Role = "Small", Font = UIStyle.FontBold, Color = C.TextDim, Size = UDim2.fromScale(0.5, 1), Parent = row })
	return UIKit.text({ Text = "", Role = "Heading", AlignX = Enum.TextXAlignment.Right, Size = UDim2.fromScale(0.5, 1), Position = UDim2.fromScale(0.5, 0), Parent = row })
end
local priceValue = statRow(4, "PRICE")
priceValue.TextColor3 = C.Gold
local cashValue = statRow(5, "YOUR CASH")
cashValue.TextColor3 = C.Cash
local _, meter = UIKit.meter({ LayoutOrder = 6, Parent = panel })

local buttons = UIKit.make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, UIStyle.TouchTarget), LayoutOrder = 7, Parent = panel })
UIKit.list(buttons, Enum.FillDirection.Horizontal, 8)

local current: ZoneConfig.Zone? = nil
local confirmUntil = 0
local pending = false
local refresh: () -> ()

local function close()
	current = nil
	confirmUntil = 0
	panel.Visible = false
end

local function onBuy()
	local zone = current
	if pending or not zone then
		return
	end
	if os.clock() >= confirmUntil then
		confirmUntil = os.clock() + CONFIRM_WINDOW -- first tap arms the confirmation
		refresh()
		task.delay(CONFIRM_WINDOW, refresh)
		return
	end
	confirmUntil = 0
	pending = true
	refresh()
	local ok, success, _, message = pcall(unlockRemote.InvokeServer, unlockRemote, zone.id)
	pending = false
	if ok then
		UIKit.toast(if success then "success" else "error", zone.name, message)
	else
		UIKit.toast("error", zone.name, "Couldn't reach the server. Please try again.")
	end
	refresh()
end

local _, buy = UIKit.button({ Name = "Buy", Kind = "Primary", Text = "UNLOCK", Size = UDim2.new(0.62, -4, 1, 0), LayoutOrder = 1, Parent = buttons, OnActivated = onBuy })
UIKit.button({ Name = "Close", Kind = "Secondary", Text = "CLOSE", Size = UDim2.new(0.38, -4, 1, 0), LayoutOrder = 2, Parent = buttons, OnActivated = close })

function refresh()
	local zone = current
	if not zone then
		return
	end
	local unlocked = unlockedSet()
	local previous = ZoneConfig.previous(zone.id)
	local cash = getCash()
	header.Text = ("DISTRICT %d"):format(zone.number)
	title.Text = string.upper(zone.name)
	priceValue.Text = CashFormat.format(zone.price)
	cashValue.Text = CashFormat.format(cash)
	if unlocked[zone.id] then
		status.Text = "Unlocked. Walk through the gate to enter."
		meter.set(1, C.Success)
		buy.setEnabled(false, "UNLOCKED")
	elseif not zone.purchasable then
		status.Text = "This district isn't open yet."
		meter.set(0)
		buy.setEnabled(false, "COMING SOON")
	elseif previous and not unlocked[previous.id] then
		status.Text = ("Unlock %s first. Districts open in order."):format(previous.name)
		meter.set(0)
		buy.setEnabled(false, "LOCKED")
	elseif cash < zone.price then
		status.Text = ("You need %s more."):format(CashFormat.format(zone.price - cash))
		meter.set(cash / zone.price, C.Gold)
		buy.setEnabled(false, "NOT ENOUGH CASH")
	elseif pending then
		meter.set(1, C.Cash)
		buy.setEnabled(false, "UNLOCKING...")
	elseif os.clock() < confirmUntil then
		status.Text = "Tap again to confirm. Unlocks are permanent."
		meter.set(1, C.Cash)
		buy.setText("CONFIRM " .. CashFormat.format(zone.price))
		buy.setEnabled(true)
	else
		status.Text = "You can afford this district."
		meter.set(1, C.Cash)
		buy.setText("UNLOCK FOR " .. CashFormat.format(zone.price))
		buy.setEnabled(true)
	end
end

local function open(zone: ZoneConfig.Zone)
	current = zone
	confirmUntil = 0
	panel.Visible = true
	refresh()
end

UIKit.mount(gui)

-- Gates --------------------------------------------------------------------------------------------
local function applyGate(zone: ZoneConfig.Zone, unlocked: { [string]: boolean })
	local barrier = getBarrier(zone)
	if not barrier then
		return -- not streamed in right now
	end
	local isOpen = unlocked[zone.id] == true
	barrier.CanCollide = not isOpen -- local to this client: only this player's character passes
	barrier.LocalTransparencyModifier = if isOpen then 0.75 else 0
	local plate = (barrier.Parent :: Instance):FindFirstChild("LockPlate")
	if plate and plate:IsA("BasePart") then
		plate.LocalTransparencyModifier = if isOpen then 1 else 0
		for _, child in plate:GetChildren() do
			if child:IsA("SurfaceGui") then
				child.Enabled = not isOpen
			end
		end
	end
	local prompt = barrier:FindFirstChild(PROMPT_NAME) :: ProximityPrompt?
	if not prompt then
		local created = Instance.new("ProximityPrompt")
		created.Name = PROMPT_NAME
		created.HoldDuration = 0
		created.MaxActivationDistance = PROMPT_RANGE
		created.RequiresLineOfSight = false
		created.Triggered:Connect(function()
			open(zone)
		end)
		created.Parent = barrier
		prompt = created
	end
	local p = prompt :: ProximityPrompt
	p.ObjectText = string.upper(zone.name)
	p.ActionText = "Unlock " .. CashFormat.format(zone.price)
	p.Enabled = not isOpen
end

local function applyAll()
	local unlocked = unlockedSet()
	for _, zone in ZoneConfig.ZONES do
		if zone.gate then
			applyGate(zone, unlocked)
		end
	end
end

player:GetAttributeChangedSignal("UnlockedZones"):Connect(function()
	applyAll()
	refresh()
end)
player:GetAttributeChangedSignal("Cash"):Connect(refresh)
noticeEvent.OnClientEvent:Connect(function(kind: string, noticeTitle: string, message: string)
	UIKit.toast(kind, noticeTitle, message)
end)

while true do
	applyAll()
	if current then
		local barrier = getBarrier(current)
		local character = player.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")
		local near = barrier and rootPart and ((rootPart :: BasePart).Position - barrier.Position).Magnitude <= PANEL_RANGE
		if not near then
			close()
		end
	end
	task.wait(REAPPLY_INTERVAL)
end
