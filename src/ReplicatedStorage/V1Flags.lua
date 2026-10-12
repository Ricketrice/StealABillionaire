-- Studio location: ReplicatedStorage.V1Flags (ModuleScript)
-- V1Flags  (Milestone 029)
-- The four switches for the 029 UI kit and V1 screens. All OFF = the game behaves and looks exactly as
-- before 029. Turn one on here for live servers, or in Studio with a ServerStorage attribute (Studio
-- only): StudioUiV1 / StudioStore / StudioRewards / StudioIndexBonus.
--   UI_V1_ENABLED        the new look (UITheme V1 palette for every screen), the V1 HUD (cash pill,
--                        icon buttons, carry card), Index screen, Settings, inventory sort + favourites
--   STORE_ENABLED        the Store screen (gamepasses, cash packs, starter pack; "Coming soon" until
--                        ProductConfig has real ids)
--   REWARDS_ENABLED      daily streak, playtime gifts, offline earnings
--   INDEX_BONUS_ENABLED  D15 index completion bonus (claimed tiers add to all income)
-- The server publishes what is on as ReplicatedStorage attributes UiV1On / StoreOn / RewardsOn /
-- IndexBonusOn (+ V1FlagsReady once published), which is all clients read. The look (UI_V1) is
-- chosen once when a client starts: changing it mid-session needs a new Play.

local V1Flags = {}

V1Flags.UI_V1_ENABLED = false
V1Flags.STORE_ENABLED = false
V1Flags.REWARDS_ENABLED = false
V1Flags.INDEX_BONUS_ENABLED = false

V1Flags.NAMES = { "UI_V1_ENABLED", "STORE_ENABLED", "REWARDS_ENABLED", "INDEX_BONUS_ENABLED" }
V1Flags.STUDIO_ATTRIBUTES = {
	UI_V1_ENABLED = "StudioUiV1",
	STORE_ENABLED = "StudioStore",
	REWARDS_ENABLED = "StudioRewards",
	INDEX_BONUS_ENABLED = "StudioIndexBonus",
}
V1Flags.PUBLISHED = {
	UI_V1_ENABLED = "UiV1On",
	STORE_ENABLED = "StoreOn",
	REWARDS_ENABLED = "RewardsOn",
	INDEX_BONUS_ENABLED = "IndexBonusOn",
}
V1Flags.READY = "V1FlagsReady"

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Is this switch on? Server: the value above or (Studio) the ServerStorage attribute. Client: what the
-- server published.
function V1Flags.on(name: string): boolean
	if RunService:IsServer() then
		if (V1Flags :: any)[name] == true then
			return true
		end
		return RunService:IsStudio() and game:GetService("ServerStorage"):GetAttribute(V1Flags.STUDIO_ATTRIBUTES[name]) == true
	end
	return ReplicatedStorage:GetAttribute(V1Flags.PUBLISHED[name]) == true
end

-- Client: waits (up to `timeout` seconds) until the server has published the switches.
function V1Flags.waitReady(timeout: number?): boolean
	local deadline = os.clock() + (timeout or 6)
	while ReplicatedStorage:GetAttribute(V1Flags.READY) ~= true and os.clock() < deadline do
		task.wait(0.05)
	end
	return ReplicatedStorage:GetAttribute(V1Flags.READY) == true
end

-- Server: writes the published attributes (call again whenever a Studio switch changes).
function V1Flags.publish()
	for _, name in V1Flags.NAMES do
		ReplicatedStorage:SetAttribute(V1Flags.PUBLISHED[name], if V1Flags.on(name) then true else nil)
	end
	ReplicatedStorage:SetAttribute(V1Flags.READY, true)
end

return V1Flags
