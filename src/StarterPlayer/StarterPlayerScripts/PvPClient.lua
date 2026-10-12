-- Studio location: StarterPlayer.StarterPlayerScripts.PvPClient (LocalScript)
-- PvPClient  (Milestone 022)
-- Controls for PvP: the BAT, LOCKER and LOCK BASE buttons, the attack input (mouse, F, gamepad R2
-- and an on-screen button on touch devices; hold it to charge), the special attack (R, gamepad L2,
-- on-screen button), the weapon locker, and which Steal prompts this player sees. Requests only:
-- the server decides every outcome. Nothing is shown while both PvP flags are off.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PvPBat = require(ReplicatedStorage:WaitForChild("PvPBat"))
local PvPConfig = require(ReplicatedStorage:WaitForChild("PvPConfig"))
local UIKit = require(ReplicatedStorage:WaitForChild("UIKit"))
local UIStyle = require(ReplicatedStorage:WaitForChild("UIStyle"))

local player = Players.LocalPlayer
local actionEvent = ReplicatedStorage:WaitForChild("PvPAction", 60) :: RemoteEvent?
if not actionEvent then
	return
end
local clientEvent = ReplicatedStorage:WaitForChild("PvPEvent") :: RemoteEvent
local plots = workspace:WaitForChild("Hub"):WaitForChild("Plots")
local C = UIStyle.Colors
local WIDTH = 136
local ATTACK_ACTION, SPECIAL_ACTION, TOGGLE_ACTION = "PvPAttack", "PvPSpecial", "PvPBatToggle"
local CHARGED = PvPConfig.Attacks.charged

local function stealing(): boolean
	return ReplicatedStorage:GetAttribute("PvPStealing") == true
end
local function combat(): boolean
	return ReplicatedStorage:GetAttribute("WeaponCombat") == true
end
local function secondsLeft(attribute: string): number
	return math.max(0, (player:GetAttribute(attribute) or 0) - workspace:GetServerTimeNow())
end
local function clock(seconds: number): string
	return ("%d:%02d"):format(seconds // 60, seconds % 60)
end
local function skin(): string
	return player:GetAttribute("BatSkin") or PvPConfig.DEFAULT_SKIN
end
local function special(): string
	return player:GetAttribute("BatSpecial") or PvPConfig.DEFAULT_SPECIAL
end

-- Buttons: a short column on the right edge, above the jump button on phones --------------------------
local gui = UIKit.screen("PvP", UIStyle.DisplayOrder.Hud)
local root = UIKit.root(gui)
local column = UIKit.make("Frame", {
	Name = "Actions",
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -12, 0.4, 0),
	Size = UDim2.fromOffset(WIDTH, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
	Parent = root,
}) :: Frame
UIKit.list(column, Enum.FillDirection.Vertical, UIStyle.Space.S, Enum.HorizontalAlignment.Right)
-- (V1 look: sized and placed by the one HUD rule further down; Classic keeps the 022 scaling)
local columnScale = if UIStyle.v1 then UIKit.make("UIScale", { Parent = column }) :: UIScale else UIKit.scaled(column, 0.8, 1.2, root)

local setLocker: (boolean) -> () -- defined with the locker below
local lockerOpen = false

-- V1 look: Check-UI 3D buttons and status plates (UITheme); Classic: the 022 UIKit ones. Both give the
-- same controller: setEnabled(on, textWhileDisabled?), setText(text), setKind(kind) (V1 only).
local UITheme = if UIStyle.v1 then require(ReplicatedStorage:WaitForChild("UITheme")) :: any else nil
local function actionButton(name: string, text: string, kind: string, order: number, onActivated: () -> ())
	if not UITheme then
		return UIKit.button({ Name = name, Kind = "Secondary", Text = text, Size = UDim2.fromOffset(WIDTH, 46), LayoutOrder = order, Parent = column, OnActivated = onActivated })
	end
	local b = UITheme.button({ Name = name, Kind = kind, Text = text, Size = UDim2.fromOffset(WIDTH, 46), LayoutOrder = order, Parent = column, OnActivated = onActivated })
	local on, shown = true, text
	local ctl = {}
	function ctl.setEnabled(enabled: boolean, disabledText: string?)
		local want = if enabled then shown else disabledText or shown
		if enabled ~= on or b.Text ~= want then
			on = enabled
			UITheme.setEnabled(b, enabled, want)
		end
	end
	function ctl.setText(t: string)
		shown = t
		if on and b.Text ~= t then
			b.Text = t
		end
	end
	function ctl.setKind(k: string)
		if b:GetAttribute("Kind") ~= k then
			b:SetAttribute("Kind", k)
			if on then
				UITheme.paint(b, k)
			end
		end
	end
	return b, ctl
end
local function statusChip(name: string, kind: string, color: Color3, order: number): (GuiObject, TextLabel)
	if UITheme then
		return UITheme.plate({ Name = name, Kind = kind, Size = UDim2.fromOffset(WIDTH, 26), LayoutOrder = order, Parent = column })
	end
	return UIKit.chip({ Name = name, Text = "", Height = 26, Color = color, LayoutOrder = order, Parent = column })
end

local shield, shieldLabel = statusChip("Protected", "Secondary", C.Info, 1)
local batButton, batControl = actionButton("BatButton", "BAT", "Danger", 2, function()
	actionEvent:FireServer("Equip", player:GetAttribute("BatEquipped") ~= true)
end)
local lockerButton = actionButton("LockerButton", "LOCKER", "Ghost", 3, function()
	setLocker(not lockerOpen)
end)
local lockButton, lockControl = actionButton("LockButton", "LOCK BASE", "Primary", 4, function()
	actionEvent:FireServer("Lock")
end)
-- Only while the bat is out: the special's name and cooldown, and the charge meter.
local specialChip, specialLabel = statusChip("Special", "Gold", C.Gold, 5)
local chargeTrack, chargeMeter = UIKit.meter({ Name = "Charge", Size = UDim2.fromOffset(WIDTH, 10), LayoutOrder = 6, Parent = column })
chargeTrack.Visible = false

-- V1 layout (029 layout fix): right side, vertically centred, equal gaps, buttons 200 x 56 at 1080p and
-- never under 56 px on screen; kept above the jump button on touch screens.
if UITheme then
	local HUD = UITheme.HUD
	local BUTTON_W = HUD.ACTION_W
	local list = column:FindFirstChildOfClass("UIListLayout")
	if list then
		list.Padding = UDim.new(0, HUD.GAP)
	end
	local view: any = nil
	local function place()
		if not view then
			return
		end
		local s = view.scale
		columnScale.Scale = s
		local buttonH = UITheme.touchSize(56, s)
		local buttonText = math.max(22, math.ceil(13 / s)) -- never under 13 px on screen
		for _, b in { batButton, lockerButton, lockButton } do
			b.Size = UDim2.fromOffset(BUTTON_W, buttonH)
			b.TextSize = buttonText -- (shown by its ButtonText label)
		end
		local chipText = math.max(17, math.ceil(11 / s))
		local chipH = chipText + 16
		shield.Size = UDim2.fromOffset(BUTTON_W, chipH)
		specialChip.Size = UDim2.fromOffset(BUTTON_W, chipH)
		shieldLabel.TextSize = chipText
		specialLabel.TextSize = chipText
		chargeTrack.Size = UDim2.fromOffset(BUTTON_W, 12)
		column.Size = UDim2.fromOffset(BUTTON_W, 0)
		local h = column.AbsoluteSize.Y
		local left = view.size.X - HUD.MARGIN - BUTTON_W * s
		local bottom = view.size.Y - HUD.MARGIN
		for _, r in view.avoid do
			if r.max.X > left then
				bottom = math.min(bottom, r.min.Y - HUD.GAP)
			end
		end
		local y = math.clamp(view.size.Y / 2 - h / 2, HUD.MARGIN, math.max(HUD.MARGIN, bottom - h))
		column.AnchorPoint = Vector2.new(1, 0)
		column.Position = UDim2.fromOffset(view.size.X - HUD.MARGIN, y)
	end
	UITheme.onHudLayout(root, function(v)
		view = v
		place()
	end)
	column:GetPropertyChangedSignal("AbsoluteSize"):Connect(place)
end

-- Attack input: bound only while the bat is out, so it never takes clicks away from normal play ---------
-- Press = start charging, let go = swing. The server times the hold: a short press is a basic
-- swing, a full charge is the charged swing.
local pressedAt: number? = nil
local function release()
	if pressedAt then
		pressedAt = nil
		actionEvent:FireServer("ChargeRelease")
	end
end
local function onAttack(_name: string, state: Enum.UserInputState): Enum.ContextActionResult
	if state == Enum.UserInputState.Begin then
		if not pressedAt then
			local at = os.clock()
			pressedAt = at
			actionEvent:FireServer("ChargeStart")
			task.delay(CHARGED.maxCharge - 0.3, function() -- swing before a charge held too long fizzles
				if pressedAt == at then
					release()
				end
			end)
		end
	elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
		release()
	end
	return Enum.ContextActionResult.Pass
end
local function onSpecial(_name: string, state: Enum.UserInputState): Enum.ContextActionResult
	if state == Enum.UserInputState.Begin and secondsLeft("SpecialReadyAt") <= 0 then
		actionEvent:FireServer("Special")
	end
	return Enum.ContextActionResult.Pass
end
local bound = false
local function bindAttack(on: boolean)
	if on == bound then
		return
	end
	bound = on
	if on then
		ContextActionService:BindAction(ATTACK_ACTION, onAttack, true, Enum.UserInputType.MouseButton1, Enum.KeyCode.F, Enum.KeyCode.ButtonR2)
		ContextActionService:SetTitle(ATTACK_ACTION, "HIT")
		ContextActionService:SetPosition(ATTACK_ACTION, UDim2.new(0.28, 0, 0.42, 0)) -- up and left of the jump button
		ContextActionService:BindAction(SPECIAL_ACTION, onSpecial, true, Enum.KeyCode.R, Enum.KeyCode.ButtonL2)
		ContextActionService:SetTitle(SPECIAL_ACTION, "SPECIAL")
		ContextActionService:SetPosition(SPECIAL_ACTION, UDim2.new(0.02, 0, 0.66, 0)) -- left of the jump button
	else
		pressedAt = nil
		ContextActionService:UnbindAction(ATTACK_ACTION)
		ContextActionService:UnbindAction(SPECIAL_ACTION)
	end
end
ContextActionService:BindAction(TOGGLE_ACTION, function(_name, state)
	if state == Enum.UserInputState.Begin and combat() then
		actionEvent:FireServer("Equip", player:GetAttribute("BatEquipped") ~= true)
	end
	return Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.Q, Enum.KeyCode.ButtonY)
clientEvent.OnClientEvent:Connect(function(kind)
	if kind == "ChargeEnded" then
		pressedAt = nil -- the server ended the charge (hit, or held too long)
	end
end)

-- Weapon locker: bat look and special attack. Looks only; the server keeps the choice ------------------
local lockerGui = UIKit.screen("PvPLocker", UIStyle.DisplayOrder.Inventory)
local lockerRoot = UIKit.root(lockerGui)
local locker = UIKit.panel({
	Name = "Locker",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(420, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	Parent = lockerRoot,
})
locker.Visible = false
UIKit.padding(locker, UIStyle.Space.L, UIStyle.Space.M)
UIKit.list(locker, Enum.FillDirection.Vertical, UIStyle.Space.S, Enum.HorizontalAlignment.Center)
UIKit.scaled(locker, 0.62, 1.15, lockerRoot)

local header = UIKit.make("Frame", { Name = "Header", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, UIStyle.TouchTarget), LayoutOrder = 1, Parent = locker })
UIKit.text({ Text = "WEAPON LOCKER", Role = "Title", Size = UDim2.new(1, -52, 1, 0), Parent = header })
UIKit.button({
	Name = "Close",
	Kind = "Ghost",
	Text = "X",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.fromScale(1, 0),
	Size = UDim2.fromOffset(UIStyle.TouchTarget, UIStyle.TouchTarget),
	Parent = header,
	OnActivated = function()
		setLocker(false)
	end,
})

local function preview(parent: Instance, skinName: string)
	local view = UIKit.make("ViewportFrame", {
		Name = "Preview",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 84),
		Ambient = Color3.fromRGB(200, 200, 210),
		LightColor = Color3.new(1, 1, 1),
		LightDirection = Vector3.new(-1, -1, -1),
		Parent = parent,
	}) :: ViewportFrame
	local bat = PvPBat.build(skinName)
	for _, part in bat:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
		end
	end
	bat:PivotTo(CFrame.new(-0.74, -0.95, 0) * CFrame.Angles(0, 0, math.rad(-38))) -- leaning, its middle at the origin
	bat.Parent = view
	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	camera.CFrame = CFrame.lookAt(Vector3.new(0, 0, 9.5), Vector3.new(0, 0, 0))
	camera.Parent = view
	view.CurrentCamera = camera
end

-- A selectable card; returns a function that marks it chosen or not.
local function card(props): (boolean) -> ()
	local button = UIKit.make(
		"TextButton",
		{ Name = props.Name, AutoButtonColor = false, Text = "", BackgroundColor3 = C.PanelRaised, Size = props.Size, LayoutOrder = props.LayoutOrder, Parent = props.Parent }
	) :: TextButton
	UIStyle.corner(button, UIStyle.Radius.M)
	local stroke = UIStyle.outline(button, C.Border, 1.5)
	UIKit.padding(button, 8, 8)
	UIKit.list(button, Enum.FillDirection.Vertical, 2, Enum.HorizontalAlignment.Center)
	if props.Skin then
		preview(button, props.Skin)
	end
	UIKit.text({ Text = props.Title, Role = "Heading", AlignX = Enum.TextXAlignment.Center, LayoutOrder = 2, Parent = button })
	if props.Hint then
		UIKit.text({
			Text = props.Hint,
			Role = "Small",
			Color = C.TextMuted,
			AlignX = Enum.TextXAlignment.Center,
			Wrap = true,
			Truncate = false,
			Size = UDim2.new(1, 0, 0, 34),
			LayoutOrder = 3,
			Parent = button,
		})
	end
	local state =
		UIKit.text({ Name = "State", Text = "", Role = "Micro", Font = UIStyle.FontBold, Color = C.Gold, AlignX = Enum.TextXAlignment.Center, LayoutOrder = 4, Parent = button })
	button.Activated:Connect(props.OnActivated)
	return function(chosen: boolean)
		stroke.Color = if chosen then C.Gold else C.Border
		stroke.Thickness = if chosen then 2.5 else 1.5
		state.Text = if chosen then "EQUIPPED" else "TAP TO USE"
		state.TextColor3 = if chosen then C.Gold else C.TextDim
		button:SetAttribute("Chosen", chosen)
	end
end
local function row(name: string, order: number, height: number): Frame
	local frame = UIKit.make("Frame", { Name = name, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, height), LayoutOrder = order, Parent = locker }) :: Frame
	local layout = UIKit.list(frame, Enum.FillDirection.Horizontal, UIStyle.Space.S, Enum.HorizontalAlignment.Center)
	layout.HorizontalFlex = Enum.UIFlexAlignment.Fill
	return frame
end

UIKit.text({ Text = "BAT LOOK", Role = "Small", Font = UIStyle.FontBold, Color = C.TextMuted, LayoutOrder = 2, Parent = locker })
local skinRow = row("Skins", 3, 150)
local skinCards: { [string]: (boolean) -> () } = {}
for index, name in PvPConfig.SKIN_ORDER do
	skinCards[name] = card({
		Name = name,
		Skin = name,
		Title = PvPBat.SKINS[name].name,
		Size = UDim2.new(0, 110, 1, 0),
		LayoutOrder = index,
		Parent = skinRow,
		OnActivated = function()
			actionEvent:FireServer("Loadout", "skin", name)
		end,
	})
end
UIKit.text({ Text = "SPECIAL ATTACK", Role = "Small", Font = UIStyle.FontBold, Color = C.TextMuted, LayoutOrder = 4, Parent = locker })
local specialRow = row("Specials", 5, 104)
local specialCards: { [string]: (boolean) -> () } = {}
for index, name in PvPConfig.SPECIAL_ORDER do
	local def = PvPConfig.Specials[name]
	specialCards[name] = card({
		Name = name,
		Title = def.name,
		Hint = def.hint,
		Size = UDim2.new(0, 170, 1, 0),
		LayoutOrder = index,
		Parent = specialRow,
		OnActivated = function()
			actionEvent:FireServer("Loadout", "special", name)
		end,
	})
end
UIKit.text({ Text = "Looks only: every bat hits exactly the same.", Role = "Small", Color = C.TextDim, AlignX = Enum.TextXAlignment.Center, LayoutOrder = 6, Parent = locker })

setLocker = function(open: boolean)
	lockerOpen = open and combat()
	locker.Visible = lockerOpen
	lockerGui:SetAttribute("Open", lockerOpen)
end
local function refreshLocker()
	local chosenSkin, chosenSpecial = skin(), special()
	for name, set in skinCards do
		set(name == chosenSkin)
	end
	for name, set in specialCards do
		set(name == chosenSpecial)
	end
	lockerGui:SetAttribute("Skin", chosenSkin)
	lockerGui:SetAttribute("Special", chosenSpecial)
end
player:GetAttributeChangedSignal("BatSkin"):Connect(refreshLocker)
player:GetAttributeChangedSignal("BatSpecial"):Connect(refreshLocker)
refreshLocker()

-- Steal prompts: never on your own workers, and not while your hands are full ------------------------------
local prompts: { ProximityPrompt } = {}
local function track(instance: Instance)
	if instance:IsA("ProximityPrompt") and instance.Name == "PvPStealPrompt" then
		table.insert(prompts, instance)
	end
end
for _, d in plots:GetDescendants() do
	track(d)
end
plots.DescendantAdded:Connect(track)

local function refresh()
	local showSteal, showCombat = stealing(), combat()
	column.Visible = showSteal or showCombat
	batButton.Visible = showCombat
	lockerButton.Visible = showCombat
	lockButton.Visible = showSteal
	if lockerOpen and not showCombat then
		setLocker(false)
	end

	local equipped = player:GetAttribute("BatEquipped") == true
	batControl.setText(if equipped then "BAT: OUT" else "BAT")
	if batControl.setKind then
		batControl.setKind(if equipped then "Pink" else "Danger") -- (V1) brighter while the bat is out
	end
	bindAttack(showCombat and equipped)

	local cooling = math.ceil(secondsLeft("SpecialReadyAt"))
	specialChip.Visible = showCombat and equipped
	specialLabel.Text = PvPConfig.Specials[special()].name:upper() .. (if cooling > 0 then "  " .. cooling .. "s" else "  READY")
	if UITheme then
		local kind = if cooling > 0 then "Disabled" else "Gold"
		if specialChip:GetAttribute("Kind") ~= kind then
			specialChip:SetAttribute("Kind", kind)
			UITheme.paint(specialChip, kind)
		end
	else
		specialLabel.TextColor3 = if cooling > 0 then C.TextDim else C.Gold
	end
	if bound then
		ContextActionService:SetTitle(SPECIAL_ACTION, if cooling > 0 then tostring(cooling) else "SPECIAL")
	end

	local locked, recharging, protected = secondsLeft("LockedUntil"), secondsLeft("LockCooldownUntil"), secondsLeft("ProtectedUntil")
	if locked > 0 then
		lockControl.setEnabled(false, "LOCKED " .. clock(math.ceil(locked)))
	elseif recharging > 0 then
		lockControl.setEnabled(false, "LOCK " .. clock(math.ceil(recharging)))
	else
		lockControl.setEnabled(true)
	end
	shield.Visible = showSteal and protected > 0
	shieldLabel.Text = "PROTECTED " .. clock(math.ceil(protected))

	local plotId = player:GetAttribute("PlotId")
	local own = plotId and plots:FindFirstChild("Plot" .. plotId)
	local handsFull = player:GetAttribute("CarryingNPC") == true
	for i = #prompts, 1, -1 do
		local prompt = prompts[i]
		if not prompt.Parent then
			table.remove(prompts, i)
		else
			local show = showSteal and not handsFull and not (own and prompt:IsDescendantOf(own))
			if prompt.Enabled ~= show then
				prompt.Enabled = show
			end
		end
	end
end

-- The charge meter fills while the attack is held; gold once the charged swing is ready.
RunService.RenderStepped:Connect(function()
	local startedAt = player:GetAttribute("BatCharging")
	local on = type(startedAt) == "number"
	if chargeTrack.Visible ~= on then
		chargeTrack.Visible = on
	end
	if on then
		local fraction = (workspace:GetServerTimeNow() - startedAt) / CHARGED.chargeTime
		chargeMeter.set(fraction, if fraction >= 1 then C.Gold else C.Info)
	end
end)

UIKit.mount(gui)
UIKit.mount(lockerGui)
while true do
	refresh()
	task.wait(0.2)
end
