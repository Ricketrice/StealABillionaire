-- Studio location: StarterPlayer.StarterPlayerScripts.RankClient (LocalScript)
-- RankClient  (Milestone 030): the short celebration when RankServer says you ranked up.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FxKit = require(ReplicatedStorage:WaitForChild("FxKit"))
local RankConfig = require(ReplicatedStorage:WaitForChild("RankConfig"))
local UITheme = require(ReplicatedStorage:WaitForChild("UITheme"))

local player = Players.LocalPlayer
local rankUp = ReplicatedStorage:WaitForChild("RankUp") :: RemoteEvent

rankUp.OnClientEvent:Connect(function(name: string, index: number)
	local rank = RankConfig.RANKS[index]
	if type(name) ~= "string" or not rank then
		return
	end
	UITheme.toast("success", "RANK UP!", "You are now a " .. name .. "!")
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		FxKit.burst(root, "sparkle", rank.color, 36)
		FxKit.burst(root, "glow", rank.color, 6)
		FxKit.text(root, string.upper(name) .. "!", rank.color, 5)
		FxKit.sound("epic")
	end
end)
