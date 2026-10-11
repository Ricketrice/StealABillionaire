-- Studio location: StarterPlayer.StarterPlayerScripts.CityLife (LocalScript)
-- CityLife  (Milestone 025): the moving bits of Billionaire City's decoration. Display only.
--   * stock tickers in The Exchange scroll (SurfaceGuis tagged "CityTicker"; the prices are made up)
--   * each business lot's FOR SALE board shows only while that plot has no owner
-- Works with instance streaming: everything is found by tag as it arrives.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local plots = workspace:WaitForChild("Hub"):WaitForChild("Plots")

-- Tickers -------------------------------------------------------------------------------------------
type Row = { strip: Frame, width: number, offset: number, speed: number }
local rows: { [Instance]: { Row } } = {}

local function buildTicker(gui: Instance)
	if rows[gui] or not gui:IsA("SurfaceGui") then
		return
	end
	local list = {}
	rows[gui] = list
	for _, row in gui:GetChildren() do
		local items = row:GetAttribute("Items")
		if not (row:IsA("Frame") and type(items) == "string") then
			continue
		end
		local static = row:FindFirstChild("Static")
		if static then
			static:Destroy()
		end
		local strip = Instance.new("Frame")
		strip.Name = "Strip"
		strip.BackgroundTransparency = 1
		strip.Size = UDim2.fromScale(0, 1)
		strip.AutomaticSize = Enum.AutomaticSize.X
		local layout = Instance.new("UIListLayout")
		layout.FillDirection = Enum.FillDirection.Horizontal
		layout.Padding = UDim.new(0, 46)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = strip
		local order = 0
		for _ = 1, 2 do -- twice over, so the loop has no seam
			for _, text in string.split(items, "|") do
				order += 1
				local label = Instance.new("TextLabel")
				label.BackgroundTransparency = 1
				label.Size = UDim2.fromScale(0, 1)
				label.AutomaticSize = Enum.AutomaticSize.X
				label.Font = Enum.Font.GothamBold
				label.TextSize = 40
				label.RichText = true
				label.TextColor3 = Color3.fromRGB(240, 228, 204)
				label.Text = text
				label.LayoutOrder = order
				label.Parent = strip
			end
		end
		strip.Parent = row
		table.insert(list, { strip = strip, width = 0, offset = 0, speed = row:GetAttribute("Speed") or 40 })
	end
end
for _, gui in CollectionService:GetTagged("CityTicker") do
	buildTicker(gui)
end
CollectionService:GetInstanceAddedSignal("CityTicker"):Connect(buildTicker)
CollectionService:GetInstanceRemovedSignal("CityTicker"):Connect(function(gui)
	rows[gui] = nil
end)
RunService.Heartbeat:Connect(function(dt)
	for _, list in rows do
		for _, row in list do
			local half = row.strip.AbsoluteSize.X / 2 -- the strip holds the items twice
			if half > 1 then
				row.offset = (row.offset + row.speed * dt) % half
				row.strip.Position = UDim2.fromOffset(-row.offset, 0)
			end
		end
	end
end)

-- FOR SALE boards -----------------------------------------------------------------------------------
local function showForSale(part: Instance)
	if not part:IsA("BasePart") then
		return
	end
	local plot = plots:FindFirstChild(part:GetAttribute("Plot") or "")
	local function update()
		local free = plot == nil or plot:GetAttribute("OwnerUserId") == nil
		part.Transparency = if free then 0 else 1
		for _, child in part:GetChildren() do
			if child:IsA("SurfaceGui") then
				child.Enabled = free
			end
		end
	end
	if plot then
		plot:GetAttributeChangedSignal("OwnerUserId"):Connect(function()
			if part.Parent then
				update()
			end
		end)
	end
	update()
end
for _, part in CollectionService:GetTagged("LotForSale") do
	showForSale(part)
end
CollectionService:GetInstanceAddedSignal("LotForSale"):Connect(showForSale)
