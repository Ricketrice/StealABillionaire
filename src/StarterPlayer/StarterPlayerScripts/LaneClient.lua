-- Studio location: StarterPlayer.StarterPlayerScripts.LaneClient (LocalScript)
-- LaneClient  (Milestone 030): the Zones window (opened by the HUD's Zones button) and the answers to Home /
-- Zones / portal requests. Display and requests only: LaneService decides who may go where and says why not.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CashFormat = require(ReplicatedStorage:WaitForChild("CashFormat"))
local LaneConfig = require(ReplicatedStorage:WaitForChild("LaneConfig"))
local UITheme = require(ReplicatedStorage:WaitForChild("UITheme"))
local ZoneConfig = require(ReplicatedStorage:WaitForChild("ZoneConfig"))

local player = Players.LocalPlayer
local requestEvent = ReplicatedStorage:WaitForChild(LaneConfig.REQUEST) :: RemoteEvent
local noticeEvent = ReplicatedStorage:WaitForChild(LaneConfig.NOTICE) :: RemoteEvent

local _, root = UITheme.gui("Lane030", 5)
local ROW_H, ROW_GAP = 56, 8
local window = UITheme.window({
	Name = "Zones",
	Title = "Zones",
	Icon = "flag",
	Theme = "Codes",
	Size = Vector2.new(560, #ZoneConfig.ZONES * (ROW_H + ROW_GAP) + 60),
	Parent = root,
})
UITheme.text({
	Name = "Note",
	Text = "Travel to a zone's start. Not while carrying a worker!",
	Role = "Body",
	TextSize = 17,
	TextWrapped = true,
	Size = UDim2.new(1, -24, 0, 30),
	Position = UDim2.fromOffset(12, 6),
	ZIndex = 13,
	Parent = window.content,
})

local rows: { [string]: { button: TextButton, status: TextLabel } } = {}
for index, zone in ZoneConfig.ZONES do
	local card = UITheme.card({
		Name = zone.id,
		Size = UDim2.new(1, -24, 0, ROW_H),
		Position = UDim2.fromOffset(12, 42 + (index - 1) * (ROW_H + ROW_GAP)),
		ZIndex = 13,
		Parent = window.content,
	})
	UITheme.text({
		Name = "Name",
		Text = ("%d  %s"):format(zone.number, zone.name),
		Role = "Body",
		Font = UITheme.Fonts.Display,
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(0.5, -10, 1, 0),
		Position = UDim2.fromOffset(14, 0),
		ZIndex = 14,
		Parent = card,
	})
	local status = UITheme.text({
		Name = "Status",
		Text = "",
		Role = "Small",
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Right,
		Size = UDim2.fromScale(0.22, 1),
		Position = UDim2.fromScale(0.5, 0),
		ZIndex = 14,
		Parent = card,
	})
	local button = UITheme.button({
		Name = "Go",
		Kind = "Primary",
		Text = "GO",
		TextSize = 20,
		Size = UDim2.fromOffset(96, 44),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		ZIndex = 14,
		Parent = card,
		OnActivated = function()
			window.close()
			requestEvent:FireServer("Zone", zone.id)
		end,
	})
	rows[zone.id] = { button = button, status = status }
end

-- What the list shows (the server re-checks every request, so this is only a hint).
local function paint()
	local unlocked = {}
	for id in string.gmatch(player:GetAttribute("UnlockedZones") or "", "[^,]+") do
		unlocked[id] = true
	end
	for _, zone in ZoneConfig.ZONES do
		local row = rows[zone.id]
		local open, text = true, "Open"
		if not LaneConfig.OURS[zone.id] then
			if not zone.gate or zone.ready == false then
				open, text = false, "Coming soon"
			elseif not unlocked[zone.id] then
				open, text = false, "Locked " .. CashFormat.format(zone.price)
			end
		end
		row.status.Text = text
		row.button.Active = open
		row.button.AutoButtonColor = false
		row.button.BackgroundTransparency = if open then 0 else 0.5
		row.button.Text = if open then "GO" else "LOCKED"
	end
end
player:GetAttributeChangedSignal("UnlockedZones"):Connect(paint)
paint()

-- The teammate portal stops' status signs (034, Lane.Stop<n>_<zone>.Status, attr ZoneId): COMING SOON until that zone
-- is ready, then the price until this player unlocks it, then OPEN. Re-applied now and then (signs stream in and out).
local function paintSigns()
	local lane = workspace:FindFirstChild("World") and workspace.World:FindFirstChild("SkyCity") and workspace.World.SkyCity:FindFirstChild("Lane")
	if not lane then
		return
	end
	local unlocked = player:GetAttribute("UnlockedZones") or ""
	for _, stop in lane:GetChildren() do
		local sign = stop:FindFirstChild("Status")
		local zone = sign and ZoneConfig.get(sign:GetAttribute("ZoneId") or "")
		if zone then
			local text = if zone.ready == false
				then "COMING SOON"
				elseif table.find(string.split(unlocked, ","), zone.id) then "OPEN"
				else "UNLOCK " .. CashFormat.format(zone.price)
			for _, gui in sign:GetChildren() do
				local label = gui:FindFirstChild("Label")
				if label and label:IsA("TextLabel") and label.Text ~= text then
					label.Text = text
				end
			end
		end
	end
end
player:GetAttributeChangedSignal("UnlockedZones"):Connect(paintSigns)
task.spawn(function()
	while true do
		paintSigns()
		task.wait(3)
	end
end)

UITheme.registerScreen("Zones", function()
	paint()
	window.open()
end, window.close)

noticeEvent.OnClientEvent:Connect(function(ok: boolean, title: string, message: string)
	UITheme.toast(if ok then "success" else "error", title, message)
end)
