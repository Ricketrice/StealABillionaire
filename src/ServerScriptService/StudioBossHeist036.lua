-- Studio location: ServerScriptService.StudioBossHeist036 (Script)
-- StudioBossHeist036: STUDIO-ONLY remote control for checking the boss chaser of the Boss Heist from the Studio MCP (whose own require() cache is separate from the game's, so it
-- cannot call HeistService._test itself). Inert unless ServerStorage attribute StudioBossHeist036 = true. Write a command string to ServerStorage attribute BossHeistCmd; the result
-- appears in BossHeistResult:
--   open               open the vault now
--   place <x> <y> <z>  put the chaser there (clamped to its area)
--   attack <Kind>      Searchlight | Laser | Stomp against the first player (no cooldown)
--   hold <seconds>     no automatic attacks for that long
--   state              chaser mode / attack / stats
-- Cosmetic check only: no save data, economy or rewards are touched.

local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")
if not RunService:IsStudio() or ServerStorage:GetAttribute("StudioBossHeist036") ~= true then
	return
end

local HeistService = require(script.Parent:WaitForChild("HeistService")) :: any

ServerStorage:GetAttributeChangedSignal("BossHeistCmd"):Connect(function()
	local cmd = ServerStorage:GetAttribute("BossHeistCmd")
	if typeof(cmd) ~= "string" or cmd == "" then
		return
	end
	local words = string.split(cmd, " ")
	local result = "?"
	local test = HeistService._test
	if words[1] == "open" then
		result = tostring(HeistService.forceOpen())
	elseif words[1] == "place" then
		test.placeRobot(Vector3.new(tonumber(words[2]) or 0, tonumber(words[3]) or 0, tonumber(words[4]) or 0))
		result = "placed"
	elseif words[1] == "attack" then
		local player = Players:GetPlayers()[1]
		result = if player then tostring(test.attack(words[2], player)) else "no player"
	elseif words[1] == "hold" then
		test.holdAttacks(workspace:GetServerTimeNow() + (tonumber(words[2]) or 0))
		result = "held"
	elseif words[1] == "state" then
		local r = test.robot
		result = ("mode=%s attack=%s attacks=%d pos=%s"):format(r.mode, if r.attack then r.attack.kind else "-", HeistService.stats.attacks, tostring(r.pos))
	end
	ServerStorage:SetAttribute("BossHeistResult", result)
	ServerStorage:SetAttribute("BossHeistCmd", "")
end)
