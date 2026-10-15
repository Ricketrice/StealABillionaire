-- Studio location: StarterPlayer.StarterPlayerScripts.PvPAlerts (LocalScript)
-- PvPAlerts  (Milestone 022, phase 2)
-- On-screen PvP messages for this player. Display only: every one shows a real server result.
--   * robbery alarm: who is stealing which worker from this player's base, with a few beeps.
--     One bar that stays up until the worker is recovered or delivered (read from the base's
--     replicated AlarmThief / AlarmWorker attributes), so it can't spam.
--   * STOLEN bar: while this player carries someone else's worker.
--   * STEAL SUCCESSFUL / DEFENDED banners: a short pop with a sound.
-- The ScreenGui's attributes (Alarm, Stolen, Banner, BannerCount) mirror what is showing.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local PvPConfig = require(ReplicatedStorage:WaitForChild("PvPConfig"))
local UIKit = require(ReplicatedStorage:WaitForChild("UIKit"))
local UIStyle = require(ReplicatedStorage:WaitForChild("UIStyle"))

local player = Players.LocalPlayer
local clientEvent = ReplicatedStorage:WaitForChild("PvPEvent", 60) :: RemoteEvent?
if not clientEvent then
	return
end
local plots = workspace:WaitForChild("Hub"):WaitForChild("Plots")
local C = UIStyle.Colors
local ALARM_COLOR = Color3.fromRGB(255, 90, 76)

local gui = UIKit.screen("PvPAlerts", UIStyle.DisplayOrder.Inventory + 1)
local root = UIKit.root(gui)

local function bar(name: string, position: UDim2, accent: Color3): (Frame, TextLabel, TextLabel, UIStroke)
	local frame = UIKit.panel({
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = position,
		Size = UDim2.fromOffset(380, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BorderColor = accent,
		BorderThickness = 2.5,
		Parent = root,
	})
	frame.Visible = false
	frame.Active = false
	UIKit.padding(frame, 14, 8)
	UIKit.list(frame, Enum.FillDirection.Vertical, 0, Enum.HorizontalAlignment.Center)
	UIKit.scaled(frame, 0.7, 1.15, root)
	local title = UIKit.text({ Name = "Title", Role = "Title", Color = accent, AlignX = Enum.TextXAlignment.Center, LayoutOrder = 1, Parent = frame })
	local detail = UIKit.text({
		Name = "Detail",
		Role = "Body",
		Color = C.Text,
		AlignX = Enum.TextXAlignment.Center,
		Wrap = true,
		Truncate = false,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
		Parent = frame,
	})
	return frame, title, detail, frame:FindFirstChildOfClass("UIStroke") :: UIStroke
end

-- Robbery alarm -------------------------------------------------------------------------------------
local alarmBar, alarmTitle, alarmDetail, alarmStroke = bar("Alarm", UDim2.new(0.5, 0, 0, 58), ALARM_COLOR)
alarmTitle.Text = "ROBBERY!"
local beep = UIKit.make("Sound", { Name = "PvP_Alarm", SoundId = "rbxasset://sounds/volume_slider.ogg", Volume = 0.8, Parent = SoundService }) :: Sound
local alarmKey, beeps, nextBeep = "", 0, 0

local function ownPlot(): Instance?
	local plotId = player:GetAttribute("PlotId")
	return if plotId then plots:FindFirstChild("Plot" .. tostring(plotId)) else nil
end
local function updateAlarm()
	local plot = ownPlot()
	local thief = plot and plot:GetAttribute("AlarmThief")
	local worker = plot and plot:GetAttribute("AlarmWorker")
	local on = type(thief) == "string" and ReplicatedStorage:GetAttribute("PvPStealing") == true
	local key = if on then thief .. "|" .. tostring(worker) else ""
	if key ~= alarmKey then
		alarmKey, beeps, nextBeep = key, 0, 0
		alarmBar.Visible = on
		if on then
			alarmDetail.Text = ("%s is stealing %s. Hit them with your bat!"):format(thief, if type(worker) == "string" then worker else "a creature")
		end
		gui:SetAttribute("Alarm", if on then alarmDetail.Text else nil)
	end
	if on then
		alarmStroke.Transparency = if (os.clock() % 0.6) < 0.3 then 0 else 0.6
		if beeps < PvPConfig.Alarm.MAX_BEEPS and os.clock() >= nextBeep then
			beeps += 1
			nextBeep = os.clock() + PvPConfig.Alarm.BEEP_INTERVAL
			beep.PlaybackSpeed = if beeps % 2 == 0 then 1.5 else 2
			beep:Play()
		end
	end
end

-- STOLEN bar ----------------------------------------------------------------------------------------
local stolenBar, stolenTitle, stolenDetail = bar("Stolen", UDim2.new(0.5, 0, 0.7, 0), C.Gold)
stolenTitle.Text = "STOLEN!"
local function updateStolen()
	local on = player:GetAttribute("CarryingStolen") == true
	if stolenBar.Visible ~= on then
		stolenBar.Visible = on
		if on then
			UIKit.sound("steal")
		end
	end
	if on then
		local worker = player:GetAttribute("StolenWorker")
		stolenDetail.Text = ("Run %s into your own base to keep it. No shortcuts!"):format(if type(worker) == "string" then worker else "it")
	end
	gui:SetAttribute("Stolen", if on then stolenDetail.Text else nil)
end
player:GetAttributeChangedSignal("CarryingStolen"):Connect(updateStolen)

-- Banners -------------------------------------------------------------------------------------------
local banner = UIKit.make(
	"Frame",
	{
		Name = "Banner",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.3),
		Size = UDim2.fromOffset(520, 96),
		BackgroundTransparency = 1,
		Visible = false,
		Active = false,
		Parent = root,
	}
) :: Frame
UIKit.scaled(banner, 0.6, 1.25, root)
local bannerTitle =
	UIKit.text({ Name = "Title", Role = "Display", TextSize = 44, AlignX = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 56), Truncate = false, Parent = banner })
local bannerDetail =
	UIKit.text({ Name = "Detail", Role = "Heading", AlignX = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 60), Size = UDim2.new(1, 0, 0, 26), Parent = banner })
UIStyle.outline(bannerDetail)
local pop = UIKit.make("UIScale", { Parent = bannerTitle }) :: UIScale
local bannerSeq = 0
local function showBanner(text: string, detail: string, color: Color3, sound: string)
	bannerSeq += 1
	local seq = bannerSeq
	bannerTitle.Text, bannerTitle.TextColor3, bannerDetail.Text = text, color, detail
	bannerTitle.TextTransparency, bannerDetail.TextTransparency = 0, 0
	banner.Visible = true
	pop.Scale = 0.3
	UIKit.tween(pop, 0.28, { Scale = 1 }, Enum.EasingStyle.Back)
	UIKit.sound(sound)
	gui:SetAttribute("Banner", text)
	gui:SetAttribute("BannerCount", seq)
	task.delay(PvPConfig.Banner.TIME, function()
		if bannerSeq ~= seq then
			return -- a newer banner took over
		end
		UIKit.tween(bannerTitle, 0.3, { TextTransparency = 1 })
		UIKit.tween(bannerDetail, 0.3, { TextTransparency = 1 })
		task.wait(0.32)
		if bannerSeq == seq then
			banner.Visible = false
		end
	end)
end

clientEvent.OnClientEvent:Connect(function(kind, info)
	if type(info) ~= "table" then
		return
	end
	local worker = if type(info.worker) == "string" then info.worker else "The creature"
	if kind == "StealEnded" and info.outcome == "delivered" then
		showBanner("STEAL SUCCESSFUL", worker .. " is yours now!", C.Gold, "epic")
	elseif kind == "TheftEnded" and info.outcome == "tagged" then
		if info.ownerId == player.UserId then
			showBanner("DEFENDED!", worker .. " is back on its station.", C.Success, "chime")
		elseif info.byId == player.UserId then
			showBanner("DEFENDED!", ("You saved %s for %s."):format(worker, tostring(info.owner)), C.Success, "chime")
		end
	end
end)

UIKit.mount(gui)
updateStolen()
while true do
	updateAlarm()
	task.wait(0.15)
end
