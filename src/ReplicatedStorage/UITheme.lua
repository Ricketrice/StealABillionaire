-- Studio location: ReplicatedStorage.UITheme (ModuleScript)
-- UITheme  (Milestone 028)
-- The ONE place that decides how the 028 UI looks: colours, fonts, text sizes, stroke thickness,
-- corner radius and button style, plus the few constructors that apply them. The goal bar, the
-- collection book, the reveal banner, the Golden Parade countdown and the parade odds panel are
-- built only through this module, so milestone 029 can restyle them by editing this file alone.
-- Older screens still use UIStyle/UIKit; the starting values here match them so everything fits.
--
--   UITheme.panel{ Size, Position, AnchorPoint, Parent, Color?, Stroke? }    -> Frame
--   UITheme.text{ Text, Size, Role = "Display"|"Title"|"Body"|"Small", Color?, Parent, ... } -> TextLabel
--   UITheme.button{ Text, Size, Kind = "Primary"|"Secondary"|"Ghost", OnActivated, Parent } -> TextButton
--   UITheme.bar{ Size, Parent, Color? }  -> (Frame, set(fraction, animate?))
--   UITheme.icon{ Text (emoji/glyph), Size, Parent }                          -> TextLabel
--   UITheme.corner(obj, radius?) / UITheme.stroke(obj, color?, thickness?)
--   UITheme.squash(button)  -- the press bounce every button gets
-- Display only: nothing here talks to the server.

local TweenService = game:GetService("TweenService")

local UITheme = {}

local rgb = Color3.fromRGB

-- Colours ---------------------------------------------------------------------------------------------
UITheme.Colors = {
	Panel = rgb(28, 34, 52),
	PanelDark = rgb(19, 23, 36),
	PanelRaised = rgb(38, 46, 68),
	Stroke = rgb(10, 12, 20),
	Border = rgb(72, 80, 104),
	Text = rgb(240, 232, 214),
	TextMuted = rgb(164, 170, 190),
	Accent = rgb(214, 176, 104), -- gold
	AccentText = rgb(30, 28, 24),
	Cash = rgb(132, 214, 124),
	Success = rgb(124, 202, 132),
	Danger = rgb(228, 108, 100),
	Info = rgb(120, 172, 232),
	Golden = rgb(255, 204, 64), -- Golden Parade
	GoldenDeep = rgb(170, 110, 20),
	Secondary = rgb(58, 72, 106),
	Track = rgb(19, 23, 36), -- progress bar background
	Fill = rgb(132, 214, 124), -- progress bar fill
	Silhouette = rgb(0, 0, 0),
}
-- Rarity colour + glyph + name always together, so rarity never depends on colour alone.
UITheme.Rarity = {
	Common = rgb(180, 188, 202),
	Rare = rgb(92, 160, 236),
	Epic = rgb(170, 114, 236),
	Legendary = rgb(236, 184, 76),
	Secret = rgb(236, 98, 156),
}
UITheme.RarityGlyph = { Common = "●", Rare = "◆", Epic = "▲", Legendary = "★", Secret = "✦" }

-- Type ------------------------------------------------------------------------------------------------
UITheme.Fonts = {
	Display = Enum.Font.FredokaOne, -- titles, big numbers, banners
	Body = Enum.Font.GothamMedium,
	Bold = Enum.Font.GothamBold,
}
UITheme.TextSize = { Display = 30, Title = 22, Body = 16, Small = 13 }
local ROLE_FONT = { Display = "Display", Title = "Display", Body = "Body", Small = "Bold" }

-- Shapes ----------------------------------------------------------------------------------------------
UITheme.CornerRadius = UDim.new(0, 12)
UITheme.PillRadius = UDim.new(1, 0)
UITheme.StrokeThickness = 2 -- panels and buttons
UITheme.TextStrokeThickness = 1.5
UITheme.Padding = 10
UITheme.TouchTarget = 44 -- minimum height of anything tappable

-- Buttons ---------------------------------------------------------------------------------------------
UITheme.Button = {
	Primary = { fill = rgb(198, 160, 86), text = rgb(30, 28, 24), stroke = rgb(122, 96, 52) },
	Secondary = { fill = rgb(58, 72, 106), text = rgb(240, 232, 214), stroke = rgb(10, 12, 20) },
	Ghost = { fill = rgb(19, 23, 36), text = rgb(240, 232, 214), stroke = rgb(72, 80, 104) },
	PressScale = 0.92, -- squash on press
	Font = "Display",
	TextSize = 18,
}

-- Motion ----------------------------------------------------------------------------------------------
UITheme.Motion = { Fast = 0.15, Normal = 0.25, Slow = 0.45 }

-- Helpers ---------------------------------------------------------------------------------------------
local function make(className: string, props: { [string]: any }): any
	local obj = Instance.new(className)
	local parent = props.Parent
	for key, value in props do
		if key ~= "Parent" then
			(obj :: any)[key] = value
		end
	end
	if parent then
		obj.Parent = parent
	end
	return obj
end
UITheme.make = make

function UITheme.tween(obj: Instance, time: number, goal: { [string]: any }, style: Enum.EasingStyle?, dir: Enum.EasingDirection?): Tween
	local t = TweenService:Create(obj, TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), goal)
	t:Play()
	return t
end

function UITheme.corner(obj: GuiObject, radius: UDim?): UICorner
	return make("UICorner", { CornerRadius = radius or UITheme.CornerRadius, Parent = obj })
end

function UITheme.stroke(obj: GuiObject, color: Color3?, thickness: number?): UIStroke
	local isText = obj:IsA("TextLabel") or obj:IsA("TextButton") and (obj :: TextButton).BackgroundTransparency >= 1
	return make("UIStroke", {
		Color = color or (if isText then UITheme.Colors.Stroke else UITheme.Colors.Border),
		Thickness = thickness or (if isText then UITheme.TextStrokeThickness else UITheme.StrokeThickness),
		Transparency = if isText and not color then 0.3 else 0,
		ApplyStrokeMode = if isText then Enum.ApplyStrokeMode.Contextual else Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Parent = obj,
	})
end

-- A rounded panel. props: the Frame's own properties plus Color (fill) and Stroke (false = none).
function UITheme.panel(props: { [string]: any }): Frame
	local color, stroke = props.Color, props.Stroke
	props.Color, props.Stroke = nil, nil
	props.BackgroundColor3 = color or UITheme.Colors.Panel
	props.BorderSizePixel = 0
	local frame = make("Frame", props)
	UITheme.corner(frame)
	if stroke ~= false then
		UITheme.stroke(frame, if typeof(stroke) == "Color3" then stroke else nil)
	end
	return frame
end

-- Text. props: the TextLabel's own properties plus Role, Color, Align ("Left"|"Center"|"Right").
function UITheme.text(props: { [string]: any }): TextLabel
	local role = props.Role or "Body"
	local color, align = props.Color, props.Align
	props.Role, props.Color, props.Align = nil, nil, nil
	props.BackgroundTransparency = 1
	props.Font = props.Font or UITheme.Fonts[ROLE_FONT[role] or "Body"]
	props.TextSize = props.TextSize or UITheme.TextSize[role] or UITheme.TextSize.Body
	props.TextColor3 = color or UITheme.Colors.Text
	props.TextXAlignment = Enum.TextXAlignment[align or "Center"]
	if props.TextWrapped == nil then
		props.TextTruncate = Enum.TextTruncate.AtEnd
	end
	local label = make("TextLabel", props)
	UITheme.stroke(label)
	return label
end

-- An emoji or glyph icon, sized to its box.
function UITheme.icon(props: { [string]: any }): TextLabel
	props.BackgroundTransparency = 1
	props.TextScaled = true
	props.Font = props.Font or UITheme.Fonts.Display
	props.TextColor3 = props.TextColor3 or UITheme.Colors.Text
	return make("TextLabel", props)
end

-- The press bounce: shrink while held, spring back on release.
function UITheme.squash(button: GuiButton)
	local scale = button:FindFirstChildOfClass("UIScale") or make("UIScale", { Parent = button })
	button.MouseButton1Down:Connect(function()
		UITheme.tween(scale, UITheme.Motion.Fast, { Scale = UITheme.Button.PressScale })
	end)
	local function release()
		UITheme.tween(scale, UITheme.Motion.Normal, { Scale = 1 }, Enum.EasingStyle.Back)
	end
	button.MouseButton1Up:Connect(release)
	button.MouseLeave:Connect(release)
end

-- A button. props: the TextButton's own properties plus Kind and OnActivated.
function UITheme.button(props: { [string]: any }): TextButton
	local style = UITheme.Button[props.Kind or "Primary"] or UITheme.Button.Primary
	local onActivated = props.OnActivated
	props.Kind, props.OnActivated = nil, nil
	props.BackgroundColor3 = style.fill
	props.TextColor3 = style.text
	props.Font = UITheme.Fonts[UITheme.Button.Font]
	props.TextSize = props.TextSize or UITheme.Button.TextSize
	props.AutoButtonColor = false
	props.BorderSizePixel = 0
	local button = make("TextButton", props)
	UITheme.corner(button)
	UITheme.stroke(button, style.stroke)
	UITheme.squash(button)
	if onActivated then
		button.Activated:Connect(onActivated)
	end
	return button
end

-- A progress bar. Returns the bar and set(fraction 0..1, animate?).
function UITheme.bar(props: { [string]: any }): (Frame, (number, boolean?) -> ())
	local fillColor = props.Color or UITheme.Colors.Fill
	props.Color = nil
	props.BackgroundColor3 = UITheme.Colors.Track
	props.BorderSizePixel = 0
	local track = make("Frame", props)
	UITheme.corner(track, UITheme.PillRadius)
	UITheme.stroke(track, UITheme.Colors.Stroke)
	local fill = make("Frame", { Name = "Fill", BackgroundColor3 = fillColor, BorderSizePixel = 0, Size = UDim2.fromScale(0, 1), Parent = track })
	UITheme.corner(fill, UITheme.PillRadius)
	local function set(fraction: number, animate: boolean?)
		local goal = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
		fill.Visible = fraction > 0
		if animate then
			UITheme.tween(fill, UITheme.Motion.Slow, { Size = goal })
		else
			fill.Size = goal
		end
	end
	return track, set
end

-- The shared top bar (ScreenGui "TopBar028"): one centred row under the Roblox top bar, clear of the
-- HUD on the left and the PvP buttons on the right. Items: Golden Parade pill (1), goal (2), book (3),
-- effects toggle (4). Hidden while the 026 tutorial card (same spot) is up. Client only.
function UITheme.topBar(): Frame
	local playerGui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
	local gui = playerGui:FindFirstChild("TopBar028")
	if gui then
		return gui:WaitForChild("Bar") :: Frame
	end
	gui = make("ScreenGui", { Name = "TopBar028", ResetOnSpawn = false, DisplayOrder = 3, Parent = playerGui })
	local bar = make("Frame", {
		Name = "Bar",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(0, 56),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
	})
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = bar,
	})
	UITheme.scaleWith(bar, 0.75, 1.1)
	bar.Parent = gui
	local function follow(hub: Instance)
		local function update()
			bar.Visible = hub:GetAttribute("Tutorial") == nil
		end
		hub:GetAttributeChangedSignal("Tutorial"):Connect(update)
		update()
	end
	local hub = playerGui:FindFirstChild("Hub")
	if hub then
		follow(hub)
	else
		playerGui.ChildAdded:Connect(function(child)
			if child.Name == "Hub" then
				follow(child)
			end
		end)
	end
	return bar
end

-- Scales a phone-first layout: UI is authored for a ~700 px short side.
function UITheme.scaleWith(obj: GuiObject, minScale: number?, maxScale: number?): UIScale
	local scale = make("UIScale", { Parent = obj })
	local function update()
		local camera = workspace.CurrentCamera
		local v = if camera then camera.ViewportSize else Vector2.new(1280, 720)
		scale.Scale = math.clamp(math.min(v.X, v.Y) / 700, minScale or 0.75, maxScale or 1.15)
	end
	local function watch()
		local camera = workspace.CurrentCamera
		if camera then
			camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
		end
		update()
	end
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watch)
	watch()
	return scale
end

return UITheme
