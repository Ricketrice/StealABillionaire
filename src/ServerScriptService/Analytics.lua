-- Studio location: ServerScriptService.Analytics (ModuleScript)
-- Analytics  (036): AnalyticsService events for the Creator Dashboard. Server only and display-free: it never reads
-- or writes a save, and every call is wrapped in pcall so a failed log can never touch gameplay.
--   * Onboarding funnel, only for players who join with no creatures: 1 Joined -> 2 First catch -> 3 First pad
--     place -> 4 First purchase prompt shown. Each step at most once per player per session.
--   * Custom events: SessionLength (seconds, when the player leaves), BossHeistStart, BossHeistWin (field 1 =
--     the capsule's rarity), SecretCatch (field 1 = the creature id).
-- AnalyticsServer reports joins and leaves; WorkerInventory, PurchaseService and HeistService call the rest.

local AnalyticsService = game:GetService("AnalyticsService")

local Analytics = {}

local STEPS = { Joined = 1, FirstCatch = 2, FirstPadPlace = 3, FirstPurchasePrompt = 4 }
local STEP_NAMES = { "Joined", "First catch", "First pad place", "First purchase prompt shown" }

local onboarding: { [Player]: { [number]: boolean } } = {} -- only players in the funnel have an entry
local joinedAt: { [Player]: number } = {}

local function log(method: string, ...: any)
	local ok, err = pcall((AnalyticsService :: any)[method], AnalyticsService, ...)
	if not ok then
		warn(("[Analytics] %s failed: %s"):format(method, tostring(err)))
	end
end

-- A funnel step ("Joined", "FirstCatch", "FirstPadPlace", "FirstPurchasePrompt"). Ignored for players not in the
-- funnel and for steps already logged this session.
function Analytics.step(player: Player, key: string)
	local done, n = onboarding[player], STEPS[key]
	if not (done and n) or done[n] then
		return
	end
	done[n] = true
	log("LogOnboardingFunnelStepEvent", player, n, STEP_NAMES[n])
end

-- A custom event; `field1` goes in CustomField01.
function Analytics.event(player: Player, name: string, value: number?, field1: string?)
	if field1 then
		log("LogCustomEvent", player, name, value or 1, { [Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = field1 })
	else
		log("LogCustomEvent", player, name, value or 1)
	end
end

function Analytics.playerAdded(player: Player)
	joinedAt[player] = os.clock()
end

-- Data loaded: a player with no creatures yet enters the onboarding funnel.
function Analytics.loaded(player: Player, isNew: boolean)
	if isNew and not onboarding[player] then
		onboarding[player] = {}
		Analytics.step(player, "Joined")
	end
end

function Analytics.playerRemoving(player: Player)
	local t = joinedAt[player]
	if t then
		Analytics.event(player, "SessionLength", math.floor(os.clock() - t))
	end
	joinedAt[player], onboarding[player] = nil, nil
end

return Analytics
