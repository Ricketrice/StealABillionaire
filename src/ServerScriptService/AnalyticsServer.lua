-- Studio location: ServerScriptService.AnalyticsServer (Script)
-- AnalyticsServer  (036): tells Analytics when players join, finish loading and leave (session length, funnel start).

local Players = game:GetService("Players")

local Analytics = require(script.Parent:WaitForChild("Analytics"))
local PlayerData = require(script.Parent:WaitForChild("PlayerData"))

Players.PlayerAdded:Connect(Analytics.playerAdded)
for _, player in Players:GetPlayers() do
	Analytics.playerAdded(player)
end
Players.PlayerRemoving:Connect(Analytics.playerRemoving)
PlayerData.onLoaded(function(player, data)
	Analytics.loaded(player, #((data :: any).workers or {}) == 0)
end)
