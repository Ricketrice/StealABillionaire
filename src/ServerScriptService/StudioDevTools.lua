-- Studio location: ServerScriptService.StudioDevTools (ModuleScript)
-- StudioDevTools  (032) -- STUDIO-ONLY shortcuts for testing by hand. Nothing here ever runs in a live server:
-- every check starts with RunService:IsStudio(), and everything is off unless the ServerStorage attribute
-- "StudioDevTools" is true (default unset = off; read live, so it can be flipped during Play).
-- Only real accounts (UserId > 0, i.e. the developer in Play Solo) get them; multi-client test players
-- (negative ids) never do, so automated tests run unchanged even with the flag left on.
--   * Zone 6 (Billionaire Hills) counts as unlocked (ZoneProgress.isUnlocked + the UnlockedZones attribute).
--     The save is untouched: nothing is added to data.zones, and buying it is refused as "owned".
--   * Chat "/devcash [amount]" adds test cash (default 300,000). Cash is saved with the player's data, so it
--     only works on the in-memory save (PlayerData.isPersistent() false), never on a real DataStore.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local TextChatService = game:GetService("TextChatService")

local CashService = require(script.Parent:WaitForChild("CashService"))
local PlayerData = require(script.Parent:WaitForChild("PlayerData"))

local StudioDevTools = {}

local ATTRIBUTE = "StudioDevTools"
local DEV_ZONE = "BillionaireHills" -- Zone 6 (ours); Zones 2-5 are teammate-owned and never touched here
local DEFAULT_CASH = 300000
local MAX_CASH = 1000000000

function StudioDevTools.enabled(): boolean
	return RunService:IsStudio() and ServerStorage:GetAttribute(ATTRIBUTE) == true
end

function StudioDevTools.enabledFor(player: Player): boolean
	return player.UserId > 0 and StudioDevTools.enabled()
end

-- Whether the dev tools make this district count as unlocked for the player (Zone 6 only).
function StudioDevTools.unlocksZone(player: Player, zoneId: string): boolean
	return zoneId == DEV_ZONE and StudioDevTools.enabledFor(player)
end

-- Calls back whenever the flag changes (Studio only).
function StudioDevTools.onChanged(callback: () -> ())
	if RunService:IsStudio() then
		ServerStorage:GetAttributeChangedSignal(ATTRIBUTE):Connect(callback)
	end
end

-- Handles "/devcash [amount]". Returns whether cash was added and a message for the output.
local function devCash(player: Player, text: string): (boolean, string)
	if not StudioDevTools.enabledFor(player) then
		return false, "dev tools are off"
	end
	if PlayerData.isPersistent() then
		return false, "refused: this session saves to the real DataStore (set ServerStorage.StudioMemoryStore = true)"
	end
	local arg = text:match("^%s*/devcash%s+(%S+)")
	local amount = if arg then tonumber(arg) else DEFAULT_CASH
	if not amount or amount ~= amount or amount < 1 then
		return false, "usage: /devcash [amount]"
	end
	amount = math.min(math.floor(amount), MAX_CASH)
	CashService.add(player, amount)
	return true, ("added %d test cash to %s"):format(amount, player.Name)
end

local function report(player: Player, text: string)
	local ok, message = devCash(player, text)
	print(("[StudioDevTools] /devcash: %s"):format(message))
	return ok
end

local command: TextChatCommand? = nil
local legacyConnections: { [Player]: RBXScriptConnection } = {}

-- Adds the chat command while the flag is on and removes it when it goes off.
local function refreshCommand()
	local on = StudioDevTools.enabled()
	if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
		if on and not command then
			local c = Instance.new("TextChatCommand")
			c.Name = "StudioDevCash"
			c.PrimaryAlias = "/devcash"
			c.Triggered:Connect(function(source: TextSource, text: string)
				local player = Players:GetPlayerByUserId(source.UserId)
				if player then
					report(player, text)
				end
			end)
			c.Parent = TextChatService
			command = c
		elseif not on and command then
			command:Destroy()
			command = nil
		end
	end
end

function StudioDevTools.start()
	if not RunService:IsStudio() then
		return
	end
	refreshCommand()
	StudioDevTools.onChanged(refreshCommand)
	if TextChatService.ChatVersion ~= Enum.ChatVersion.TextChatService then
		local function watch(player: Player)
			legacyConnections[player] = player.Chatted:Connect(function(message: string)
				if StudioDevTools.enabledFor(player) and message:match("^%s*/devcash") then
					report(player, message)
				end
			end)
		end
		Players.PlayerAdded:Connect(watch)
		for _, player in Players:GetPlayers() do
			watch(player)
		end
		Players.PlayerRemoving:Connect(function(player)
			local c = legacyConnections[player]
			if c then
				c:Disconnect()
				legacyConnections[player] = nil
			end
		end)
	end
end

StudioDevTools._test = {
	devCash = devCash,
	command = function(): TextChatCommand?
		return command
	end,
}

return StudioDevTools
