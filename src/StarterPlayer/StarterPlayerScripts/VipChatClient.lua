-- Studio location: StarterPlayer.StarterPlayerScripts.VipChatClient (LocalScript)
-- VipChatClient  (Milestone 033): a gold [VIP] in front of the names of players with the VIP pass in chat (player
-- attribute IsVIP, set by PurchaseService). Display only. Nothing happens unless someone owns VIP.

local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")

if TextChatService.ChatVersion ~= Enum.ChatVersion.TextChatService then
	return
end

TextChatService.OnIncomingMessage = function(message: TextChatMessage)
	local source = message.TextSource
	local speaker = source and Players:GetPlayerByUserId(source.UserId)
	if speaker and speaker:GetAttribute("IsVIP") == true then
		local properties = Instance.new("TextChatMessageProperties")
		properties.PrefixText = '<font color="#FFCD3C">[VIP]</font> ' .. message.PrefixText
		return properties
	end
	return nil
end
