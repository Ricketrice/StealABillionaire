-- Studio location: ReplicatedStorage.UIKit (ModuleScript)
-- UIKit
-- Reusable client UI components built on UIStyle tokens: screens, panels, text, buttons, chips,
-- rarity tags, meters and a shared toast stack. Every screen (HUD, inventory, reveal card, and
-- future unlock/progression menus) builds from these so the game looks consistent.
-- Client only.

local Players = game:GetService("Players")
local ContentProvider = game:GetService("ContentProvider")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local UIStyle = require(ReplicatedStorage:WaitForChild("UIStyle"))
local C = UIStyle.Colors
-- Milestone 029: with the V1 look on, components take UITheme's chunky style (thick dark outlines,
-- light-top gradients, bright buttons with outlined white text). Off = unchanged.
local V1 = UIStyle.v1 == true
local function shade(obj: GuiObject, dark: number?)
	if V1 then
		local g = Instance.new("UIGradient")
		g.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(dark or 0.84, dark or 0.84, dark or 0.84))
		g.Rotation = 90
		g.Parent = obj
	end
end

local UIKit = {}

-- Signals other scripts use to talk to each other without knowing about each other.
local function signal(name: string): BindableEvent
	local e = Instance.new("BindableEvent")
	e.Name = name
	return e
end
UIKit.Signals = {
	ToggleInventory = signal("ToggleInventory"), -- :Fire(open: boolean?) (nil = toggle)
	DebugFx = signal("DebugFx"), -- Studio-only review helper: :Fire("steal" | "place" | "refuse")
}

-- Generic constructor: UIKit.make("Frame", { Size = ..., Parent = ... })
function UIKit.make(className: string, props: { [string]: any }?): Instance
	local inst = Instance.new(className)
	local parent = nil
	for k, v in props or {} do
		if k == "Parent" then
			parent = v
		else
			(inst :: any)[k] = v
		end
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end
local make = UIKit.make

function UIKit.tween(obj: Instance, time: number, goal: { [string]: any }, style: Enum.EasingStyle?, dir: Enum.EasingDirection?): Tween
	local t = TweenService:Create(obj, TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), goal)
	t:Play()
	return t
end

function UIKit.padding(parent: Instance, px: number, py: number?)
	return make(
		"UIPadding",
		{ PaddingLeft = UDim.new(0, px), PaddingRight = UDim.new(0, px), PaddingTop = UDim.new(0, py or px), PaddingBottom = UDim.new(0, py or px), Parent = parent }
	)
end

function UIKit.list(parent: Instance, dir: Enum.FillDirection?, gap: number?, alignX: Enum.HorizontalAlignment?, alignY: Enum.VerticalAlignment?)
	return make("UIListLayout", {
		FillDirection = dir or Enum.FillDirection.Vertical,
		Padding = UDim.new(0, gap or UIStyle.Space.S),
		HorizontalAlignment = alignX or Enum.HorizontalAlignment.Left,
		VerticalAlignment = alignY or Enum.VerticalAlignment.Top,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = parent,
	})
end

-- A ScreenGui that stays clear of the Roblox top bar and device notches.
function UIKit.screen(name: string, displayOrder: number): ScreenGui
	return make("ScreenGui", {
		Name = name,
		ResetOnSpawn = false,
		DisplayOrder = displayOrder,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		IgnoreGuiInset = false,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
	}) :: ScreenGui
end

function UIKit.mount(gui: ScreenGui)
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

-- Every screen lays out inside a Root frame that normally fills the safe area. For layout testing
-- in Studio, setting the PlayerGui attribute "UITestViewport" (a Vector2, e.g. 390x780) shrinks
-- every Root to that size, so the real responsive code runs at phone dimensions. Unset = normal.
function UIKit.root(gui: ScreenGui): Frame
	local root = make(
		"Frame",
		{ Name = "Root", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Parent = gui }
	) :: Frame
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local function apply()
		local v = playerGui:GetAttribute("UITestViewport")
		root.Size = if typeof(v) == "Vector2" then UDim2.fromOffset(v.X, v.Y) else UDim2.fromScale(1, 1)
		root.ClipsDescendants = typeof(v) == "Vector2"
	end
	playerGui:GetAttributeChangedSignal("UITestViewport"):Connect(apply)
	apply()
	return root
end

-- Calls fn(size) now and whenever the root's size changes.
function UIKit.onResize(root: GuiObject, fn: (Vector2) -> ())
	root:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		fn(root.AbsoluteSize)
	end)
	task.defer(function()
		fn(root.AbsoluteSize)
	end)
end

-- UIScale for a fixed-pixel component. With a root, it follows the root's short side (so the
-- test viewport works); otherwise the camera viewport.
local REFERENCE_SHORT_SIDE = 700
function UIKit.scaled(obj: GuiObject, minScale: number?, maxScale: number?, root: GuiObject?): UIScale
	local s = make("UIScale", { Parent = obj }) :: UIScale
	if root then
		UIKit.onResize(root, function(size)
			s.Scale = math.clamp(math.min(size.X, size.Y) / REFERENCE_SHORT_SIDE, minScale or 0.8, maxScale or 1.2)
		end)
	else
		UIStyle.scaleWithViewport(s, minScale, maxScale)
	end
	return s
end

function UIKit.panel(props: { [string]: any }?): Frame
	local p = props or {}
	local f = make("Frame", {
		BackgroundColor3 = p.Color or C.Panel,
		BorderSizePixel = 0,
		Size = p.Size,
		Position = p.Position,
		AnchorPoint = p.AnchorPoint,
		Name = p.Name,
		AutomaticSize = p.AutomaticSize,
		LayoutOrder = p.LayoutOrder,
		Parent = p.Parent,
	}) :: Frame
	UIStyle.corner(f, p.Radius or UIStyle.Radius.L)
	if p.Border ~= false then
		UIStyle.outline(f, if V1 then C.Border else p.BorderColor or C.Border, p.BorderThickness)
	end
	shade(f)
	return f
end

-- Text in one of the type roles: "Display", "Title", "Heading", "Body", "Small", "Micro".
function UIKit.text(props: { [string]: any }): TextLabel
	local role = props.Role or "Body"
	local font = props.Font or (if role == "Display" or role == "Title" then UIStyle.Font elseif role == "Heading" then UIStyle.FontBold else UIStyle.FontBody)
	local l = make("TextLabel", {
		Name = props.Name,
		BackgroundTransparency = 1,
		Text = props.Text or "",
		Font = font,
		TextSize = props.TextSize or UIStyle.TextSize[role] or 15,
		TextColor3 = props.Color or C.Text,
		TextXAlignment = props.AlignX or Enum.TextXAlignment.Left,
		TextYAlignment = props.AlignY or Enum.TextYAlignment.Center,
		TextTruncate = props.Truncate == false and Enum.TextTruncate.None or Enum.TextTruncate.AtEnd,
		TextWrapped = props.Wrap or false,
		RichText = props.Rich or false,
		Size = props.Size or UDim2.new(1, 0, 0, (props.TextSize or UIStyle.TextSize[role] or 15) + 6),
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		AutomaticSize = props.AutomaticSize,
		LayoutOrder = props.LayoutOrder,
		Parent = props.Parent,
	}) :: TextLabel
	if props.Stroke ~= false and (role == "Display" or role == "Title" or V1 and role == "Heading") then
		UIStyle.outline(l)
	end
	return l
end

-- Button kinds: "Primary" (gold), "Secondary" (navy), "Ghost" (transparent). Returns the button and
-- a small controller with :setEnabled(enabled, labelWhenDisabled?) and :setText(text).
function UIKit.button(props: { [string]: any })
	local kind = props.Kind or "Primary"
	local bg = if kind == "Primary" then C.Primary elseif kind == "Secondary" then C.Secondary else C.PanelDark
	local fg = if kind == "Primary" then C.PrimaryText else C.Text
	if V1 then
		fg = Color3.new(1, 1, 1)
	end
	local b = make("TextButton", {
		Name = props.Name or "Button",
		AutoButtonColor = false,
		Text = "",
		BackgroundColor3 = bg,
		BackgroundTransparency = if kind == "Ghost" then 0.2 else 0,
		Size = props.Size or UDim2.new(1, 0, 0, UIStyle.TouchTarget),
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		LayoutOrder = props.LayoutOrder,
		Parent = props.Parent,
	}) :: TextButton
	UIStyle.corner(b, props.Radius or UIStyle.Radius.M)
	local restStroke = if V1 then C.Border elseif kind == "Primary" then C.GoldDark else C.Border
	local stroke = UIStyle.outline(b, restStroke)
	shade(b, 0.78)
	local label = UIKit.text({
		Text = props.Text or "",
		Role = "Heading",
		TextSize = props.TextSize,
		Color = fg,
		AlignX = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		Parent = b,
	})
	local press = make("UIScale", { Parent = b }) :: UIScale
	local enabled = true
	b.InputBegan:Connect(function(input)
		if enabled and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
			UIKit.tween(press, 0.06, { Scale = 0.95 })
		end
	end)
	b.InputEnded:Connect(function()
		UIKit.tween(press, 0.1, { Scale = 1 })
	end)
	b.MouseEnter:Connect(function()
		if enabled then
			stroke.Color = if V1 then C.Border else C.Gold
			b.BackgroundColor3 = bg:Lerp(Color3.new(1, 1, 1), 0.08)
		end
	end)
	b.MouseLeave:Connect(function()
		stroke.Color = restStroke
		if enabled then
			b.BackgroundColor3 = bg
		end
	end)
	if props.OnActivated then
		b.Activated:Connect(function()
			if enabled then
				props.OnActivated()
			end
		end)
	end
	local ctl = {}
	function ctl.setEnabled(on: boolean, disabledText: string?)
		enabled = on
		b.Active = on
		b.BackgroundColor3 = if on then bg else C.Disabled
		label.TextColor3 = if on then fg else C.TextDim
		if disabledText and not on then
			label.Text = disabledText
		elseif on and props.Text then
			label.Text = props.Text
		end
	end
	function ctl.setText(t: string)
		props.Text = t
		label.Text = t
	end
	ctl.button, ctl.label = b, label
	return b, ctl
end

-- Small rounded chip: text on a dark pill.
function UIKit.chip(props: { [string]: any }): (Frame, TextLabel)
	local f = make("Frame", {
		Name = props.Name or "Chip",
		BackgroundColor3 = props.Background or C.PanelDark,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, props.Height or 24),
		LayoutOrder = props.LayoutOrder,
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		Parent = props.Parent,
	}) :: Frame
	UIStyle.corner(f, UIStyle.Radius.Pill)
	if V1 then
		UIStyle.outline(f, C.Border, 2)
	end
	UIKit.padding(f, 10, 0)
	local l = UIKit.text({
		Text = props.Text or "",
		Role = props.Role or "Small",
		Font = props.Font or UIStyle.FontBold,
		Color = props.Color or C.Text,
		AlignX = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(0, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		Truncate = false,
		Parent = f,
	})
	return f, l
end

-- Rarity tag: glyph + name in the rarity colour, on a dark pill with a rarity-tinted border.
function UIKit.rarityTag(props: { [string]: any })
	local f, l = UIKit.chip({ Height = props.Height or 22, Parent = props.Parent, LayoutOrder = props.LayoutOrder, Position = props.Position, AnchorPoint = props.AnchorPoint })
	local stroke = f:FindFirstChildOfClass("UIStroke") or UIStyle.outline(f, C.Border, 1) -- (one outline per frame)
	local ctl = {}
	function ctl.set(rarity: string)
		local color = UIStyle.Rarity[rarity] or C.TextMuted
		l.Text = (UIStyle.RarityGlyph[rarity] or "") .. "  " .. string.upper(rarity)
		l.TextColor3 = color
		stroke.Color = color:Lerp(C.PanelDark, 0.45)
	end
	if props.Rarity then
		ctl.set(props.Rarity)
	end
	ctl.frame = f
	return f, ctl
end

-- Horizontal meter with :set(fraction, color?).
function UIKit.meter(props: { [string]: any })
	local track = make("Frame", {
		Name = props.Name or "Meter",
		BackgroundColor3 = C.PanelDark,
		BorderSizePixel = 0,
		Size = props.Size or UDim2.new(1, 0, 0, 8),
		Position = props.Position,
		LayoutOrder = props.LayoutOrder,
		Parent = props.Parent,
	}) :: Frame
	UIStyle.corner(track, UIStyle.Radius.Pill)
	if V1 then
		UIStyle.outline(track, C.Border, 2)
	end
	local fill = make("Frame", { Name = "Fill", BackgroundColor3 = props.Color or C.Gold, BorderSizePixel = 0, Size = UDim2.fromScale(0, 1), Parent = track }) :: Frame
	UIStyle.corner(fill, UIStyle.Radius.Pill)
	shade(fill, 0.72)
	local ctl = {}
	function ctl.set(fraction: number, color: Color3?)
		fill.Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
		if color then
			fill.BackgroundColor3 = color
		end
	end
	return track, ctl
end

-- Toasts -------------------------------------------------------------------------------------------
-- UIKit.toast(kind, title, message): kind = "success" | "error" | "info". At most 3 on screen;
-- an identical toast that is still on screen is refreshed (with a small bump) instead of stacked.
local TOAST_TIME, TOAST_MAX = 2.8, 3
local toastGui, toastHolder = nil, nil
local active = {} -- { key, frame, expires, seq }
local seq = 0
local KIND = {
	success = { color = C.Success, glyph = "✓" },
	error = { color = C.Danger, glyph = "!" },
	info = { color = C.Info, glyph = "i" },
}
local function ensureToastHost()
	if toastGui then
		return
	end
	toastGui = UIKit.screen("Toasts", UIStyle.DisplayOrder.Toast)
	local root = UIKit.root(toastGui)
	toastHolder = make("Frame", {
		Name = "Stack",
		AnchorPoint = Vector2.new(0.5, 0),
		-- (V1 look: under the shared top piece instead of on it)
		Position = UDim2.new(0.5, 0, 0, if V1 then (require(script.Parent:WaitForChild("UITheme")) :: any).bannerTop() else 10),
		Size = UDim2.new(0.9, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = root,
	})
	make("UISizeConstraint", { MaxSize = Vector2.new(400, math.huge), Parent = toastHolder })
	UIKit.list(toastHolder, Enum.FillDirection.Vertical, 6, Enum.HorizontalAlignment.Center)
	UIKit.mount(toastGui)
end
local function dismiss(entry)
	for i, e in active do
		if e == entry then
			table.remove(active, i)
			break
		end
	end
	local f = entry.frame
	UIKit.tween(f, 0.18, { BackgroundTransparency = 1 }).Completed:Once(function()
		f:Destroy()
	end)
	for _, d in f:GetDescendants() do
		if d:IsA("TextLabel") then
			UIKit.tween(d, 0.15, { TextTransparency = 1 })
		elseif d:IsA("UIStroke") then
			UIKit.tween(d, 0.15, { Transparency = 1 })
		elseif d:IsA("Frame") then
			UIKit.tween(d, 0.15, { BackgroundTransparency = 1 })
		end
	end
end
function UIKit.toast(kind: string, title: string?, message: string?)
	ensureToastHost()
	local key = (kind or "") .. "|" .. (title or "") .. "|" .. (message or "")
	local now = os.clock()
	for _, e in active do
		if e.key == key then
			e.expires = now + TOAST_TIME -- refresh instead of stacking a duplicate
			if e.scale and now - e.bumped > 0.3 then
				e.bumped = now
				e.scale.Scale = 1.06
				UIKit.tween(e.scale, 0.18, { Scale = 1 })
			end
			return
		end
	end
	while #active >= TOAST_MAX do
		dismiss(active[1])
	end
	local k = KIND[kind] or KIND.info
	seq += 1
	local f = UIKit.panel({
		Name = "Toast",
		Color = C.Panel,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Radius = UIStyle.Radius.M,
		LayoutOrder = seq,
		Parent = toastHolder,
	})
	f.BackgroundTransparency = 0.04
	UIKit.padding(f, 12, 9)
	local accent =
		make("Frame", { Name = "Accent", BackgroundColor3 = k.color, BorderSizePixel = 0, Size = UDim2.new(0, 4, 1, -6), Position = UDim2.fromOffset(-6, 3), Parent = f })
	UIStyle.corner(accent, UIStyle.Radius.Pill)
	local icon = make("Frame", { Name = "Icon", BackgroundColor3 = k.color, Size = UDim2.fromOffset(22, 22), Position = UDim2.fromOffset(4, 0), Parent = f })
	UIStyle.corner(icon, UIStyle.Radius.Pill)
	UIKit.text({ Text = k.glyph, Role = "Heading", TextSize = 14, Color = C.Panel, AlignX = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), Parent = icon })
	local body = make("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(36, 0), Size = UDim2.new(1, -36, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = f })
	UIKit.list(body, Enum.FillDirection.Vertical, 1)
	if title and title ~= "" then
		UIKit.text({ Text = title, Role = "Heading", TextSize = 15, Color = C.Text, LayoutOrder = 1, Parent = body })
	end
	if message and message ~= "" then
		UIKit.text({
			Text = message,
			Role = "Body",
			TextSize = 14,
			Color = C.TextMuted,
			Wrap = true,
			Truncate = false,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = 2,
			Parent = body,
		})
	end
	local entry = { key = key, frame = f, shown = now, bumped = now, expires = now + TOAST_TIME, scale = nil :: UIScale? }
	table.insert(active, entry)
	local scale = make("UIScale", { Scale = 0.92, Parent = f }) :: UIScale
	UIKit.tween(scale, 0.18, { Scale = 1 }, Enum.EasingStyle.Back)
	entry.scale = scale
	task.spawn(function()
		while entry.frame.Parent and os.clock() < entry.expires do
			task.wait(entry.expires - os.clock())
		end
		if entry.frame.Parent then
			dismiss(entry)
		end
	end)
end

-- Sounds -------------------------------------------------------------------------------------------
-- UIKit.sound(name, zoneId?, startAt?): short UI sounds, one pooled Sound per effect.
-- Default set: sound files that ship with Roblox itself (rbxasset://sounds), pitched per use.
-- Our own zones have original effects instead (CUSTOM below).
local SOUNDS: { [string]: { id: string, volume: number, speed: number } } = {
	pop = { id = "rbxasset://sounds/volume_slider.ogg", volume = 0.6, speed = 1.2 },
	chime = { id = "rbxasset://sounds/volume_slider.ogg", volume = 0.7, speed = 1.8 },
	deny = { id = "rbxasset://sounds/volume_slider.ogg", volume = 0.6, speed = 0.6 },
	steal = { id = "rbxasset://sounds/action_jump.mp3", volume = 0.5, speed = 1.4 },
	place = { id = "rbxasset://sounds/action_jump_land.mp3", volume = 0.5, speed = 1.25 },
	build = { id = "rbxasset://sounds/action_get_up.mp3", volume = 0.4, speed = 0.7 },
	epic = { id = "rbxasset://sounds/action_get_up.mp3", volume = 0.5, speed = 1.35 },
	legendary = { id = "rbxasset://sounds/impact_explosion_03.mp3", volume = 0.45, speed = 1.3 },
	secret = { id = "rbxasset://sounds/impact_explosion_03.mp3", volume = 0.55, speed = 0.85 },
}
-- Custom effects (Milestone 017D): original sounds for our own zones, Main Street and Velocity
-- Royale. Any other zone, and any call without a zone, keeps the default sounds above.
-- hit = seconds into the file where the reveal lands; the build-up before it is part of the file.
local CUSTOM_ZONES = { MainStreet = true, BillionaireHills = true }
local CUSTOM: { [string]: { id: string, volume: number, speed: number, hit: number? } } = {
	pop = { id = "rbxassetid://74021374247483", volume = 0.6, speed = 1 }, -- common_pop
	chime = { id = "rbxassetid://114449852068977", volume = 0.65, speed = 1 }, -- rare_chime
	epic = { id = "rbxassetid://115158325076999", volume = 0.7, speed = 1, hit = 0.62 }, -- epic_shimmer
	legendary = { id = "rbxassetid://132416818212146", volume = 0.75, speed = 1, hit = 1.25 }, -- legendary_impact
	secret = { id = "rbxassetid://94692027964501", volume = 0.75, speed = 1, hit = 2.35 }, -- secret_reveal
	steal = { id = "rbxassetid://125938756014881", volume = 0.6, speed = 1 }, -- steal_confirm
	place = { id = "rbxassetid://71774379383351", volume = 0.6, speed = 1 }, -- place_reward
}
local soundPool: { [string]: Sound } = {}
local function pooled(key: string, def): Sound
	local s = soundPool[key]
	if not s then
		s = make("Sound", { Name = "UI_" .. key, SoundId = def.id, Volume = def.volume, PlaybackSpeed = def.speed, Parent = SoundService }) :: Sound
		if V1 then
			local UITheme = require(ReplicatedStorage:WaitForChild("UITheme")) :: any
			s.SoundGroup = UITheme.soundGroup("SFX") -- (029 Settings: Sounds on/off)
		end
		soundPool[key] = s
	end
	return s
end

-- The custom effect for `name` in this zone, or nil if the zone uses the default sounds.
function UIKit.customSound(name: string, zoneId: string?)
	return if zoneId and CUSTOM_ZONES[zoneId] then CUSTOM[name] else nil
end

-- Plays an effect and returns its Sound. startAt (seconds) only applies to custom effects.
function UIKit.sound(name: string, zoneId: string?, startAt: number?): Sound?
	local custom = UIKit.customSound(name, zoneId)
	local def = custom or SOUNDS[name]
	if not def then
		return nil
	end
	local s = pooled(if custom then name .. "_custom" else name, def)
	s.TimePosition = if custom then (startAt or 0) else 0
	s:Play()
	return s
end

task.spawn(function() -- load the custom effects up front so the first reveal isn't late
	local list = {}
	for name, def in CUSTOM do
		table.insert(list, pooled(name .. "_custom", def))
	end
	pcall(function()
		ContentProvider:PreloadAsync(list)
	end)
end)

-- World pops ---------------------------------------------------------------------------------------
-- UIKit.worldPop(adornee, text, color?, height?): a short text pop above a part in the world
-- ("STOLEN!", "+$12/s"). Billboards are pooled and reused.
local popPool: { BillboardGui } = {}
function UIKit.worldPop(adornee: Instance?, text: string, color: Color3?, height: number?)
	if not adornee then
		return
	end
	local bb = table.remove(popPool)
	if not bb then
		bb = make(
			"BillboardGui",
			{ Name = "WorldPop", Size = UDim2.fromOffset(240, 52), AlwaysOnTop = true, LightInfluence = 0, MaxDistance = 150, ResetOnSpawn = false, Enabled = false }
		) :: BillboardGui
		local l = UIKit.text({
			Name = "Label",
			Role = "Display",
			TextSize = 32,
			AlignX = Enum.TextXAlignment.Center,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),
			Truncate = false,
			Parent = bb,
		})
		make("UIScale", { Parent = l })
		bb.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	end
	local label = bb:FindFirstChild("Label") :: TextLabel
	local scale = label:FindFirstChildOfClass("UIScale") :: UIScale
	local stroke = label:FindFirstChildOfClass("UIStroke")
	local h = height or 4
	label.Text = text
	label.TextColor3 = color or C.Text
	label.TextTransparency = 0
	if stroke then
		stroke.Transparency = 0.2
	end
	scale.Scale = 0.4
	bb.StudsOffsetWorldSpace = Vector3.new(0, h, 0)
	bb.Adornee = adornee
	bb.Enabled = true
	UIKit.tween(scale, 0.2, { Scale = 1 }, Enum.EasingStyle.Back)
	UIKit.tween(bb, 0.9, { StudsOffsetWorldSpace = Vector3.new(0, h + 2, 0) })
	task.delay(0.6, function()
		UIKit.tween(label, 0.3, { TextTransparency = 1 })
		if stroke then
			UIKit.tween(stroke, 0.3, { Transparency = 1 })
		end
		task.delay(0.32, function()
			bb.Enabled = false
			bb.Adornee = nil
			table.insert(popPool, bb)
		end)
	end)
end

return UIKit
