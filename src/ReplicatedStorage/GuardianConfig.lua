-- Studio location: ReplicatedStorage.GuardianConfig (ModuleScript)
-- GuardianConfig  (Hub 2b): every number for the zone guardians, shared by server (GuardianService) and client
-- (GuardianClient). Each of our zones has its boss as a guardian, standing at its post (Workspace.Zones.<zone>.GuardianPost):
--   Knight's Keep = Sir Malgrave, Sunken Kingdom = Aquaris, Ember Academy = the Vault Wizard (the BossHeist entries).
-- Rule: it wakes when a player carries a creature they caught in ITS zone, chases and attacks only that carrier, gives
-- up when the carrier is GIVE_UP_MARGIN studs outside the zone's ZoneBoundary (or safe at home), then walks back.
-- Attacks are the Boss Heist's three telegraphed ones (BossChase): every one shows its warning >= MIN_WARNING s first.
-- A hit deals real Humanoid damage (cartoon effects only). At 0 health the carried creature goes back into its zone
-- (a wanderer again) and the player respawns at their base. Coins, stored/placed creatures and the save's other
-- fields are never touched.
-- Switch: ENABLED (false = no guardians, nothing added to the world). Studio: ServerStorage attribute StudioGuardian
-- (true/false) overrides it (LaunchFlag). The server publishes ReplicatedStorage attribute GuardianOn for clients.

local GuardianConfig = {}

GuardianConfig.ENABLED = true -- Hub 2b: on (owner: default ON; turn off here, or in Studio with StudioGuardian = false)
GuardianConfig.STUDIO_ATTRIBUTE = "StudioGuardian"
GuardianConfig.PUBLISHED = "GuardianOn"

-- zone id -> BossHeist entry (the same boss data as the Boss Heist chaser; separate models)
GuardianConfig.ZONES = { "MainStreet", "SunkenKingdom", "BillionaireHills" }

GuardianConfig.BOSS_SCALE = 2.5 -- like the Boss Heist chaser (HeistService.BOSS_SCALE)
GuardianConfig.CHASE_SPEED = 13.6 -- studs/s = a carrier's speed (walk 16 x 0.85), like the heist chaser: it only gains while you stop or turn
GuardianConfig.RETURN_SPEED = 10 -- studs/s walking back to its post
GuardianConfig.STOP_SHORT = 7 -- studs: stops this far from the target
GuardianConfig.LEASH = 8 -- studs: the guardian itself never walks further than this outside its ZoneBoundary
GuardianConfig.GIVE_UP_MARGIN = 40 -- studs outside the ZoneBoundary (flat) where it gives up on the carrier
GuardianConfig.WAKE_DELAY = 1.0 -- seconds between the catch and the first step (the wake-up flourish plays)
GuardianConfig.MIN_WARNING = 1.5 -- every attack shows its fixed warning at least this long before it can hit
GuardianConfig.ATTACK_GAP = 2.5 -- rest between two attacks
GuardianConfig.HIT_GRACE = 1.5 -- after a hit, that player can't be hit again for this long
-- The same three attack shapes and ranges as the Boss Heist (HeistConfig.ATTACKS) + damage per hit (Humanoid health 100):
-- 4-5 hits knock a full-health carrier out; a careful player dodges them all.
GuardianConfig.ATTACKS = {
	Searchlight = { warning = 2.0, range = 60, radius = 6, damage = 20 }, -- circle follows, locks red, zaps: walk out of it
	Laser = { warning = 1.8, range = 40, length = 36, width = 4, damage = 25 }, -- red line on the ground, then a sweep: step off it
	Stomp = { warning = 1.6, range = 24, radius = 28, waveSpeed = 22, band = 2.5, damage = 20 }, -- ring + shockwave: jump it
}

do
	for name, attack in GuardianConfig.ATTACKS do
		assert(attack.warning >= GuardianConfig.MIN_WARNING, name .. " warning is shorter than MIN_WARNING")
		assert(attack.damage > 0 and attack.damage < 100, name .. " damage must be 1-99")
	end
	assert(GuardianConfig.GIVE_UP_MARGIN > GuardianConfig.LEASH, "the guardian must give up before it reaches its leash")
end

return GuardianConfig
