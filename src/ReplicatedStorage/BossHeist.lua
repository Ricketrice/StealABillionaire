-- Studio location: ReplicatedStorage.BossHeist (ModuleScript)
-- BossHeist  (036 boss pass, small scope): which boss CHASES in the Boss Heist. Presentation only: the chaser model, the clip each attack plays and the callout text.
-- Nothing here changes a rule: warnings, ranges, radii, the 2.5 s gap, hits, rewards, odds and ids all stay in HeistConfig (the three boss attacks copy Sir Ironclad's
-- HeistConfig.ATTACKS numbers because the server keeps using them: warning 1.6-2.0 s, ATTACK_GAP 2.5 s). Every boss maps its four attacks onto the existing three attack
-- kinds plus a "Basic" one:
--   Searchlight = a circle on the target that locks then hits   Laser = a line across the lane   Stomp = a ring + shockwave you jump
--   Basic       = the wake-up flourish played once when the vault opens and the boss leaves its dock (no damage, no new mechanic)
-- Entry format (identical for every boss, rigged or not):  attacks.<kind> = { name, clip, impact, callout }
--   clip   = the clip the boss plays (a BossRigs clip, or for Aquaris an AquarisAttacks clip)
--   impact = seconds into the clip when the harmful effect lands: the server starts the clip at hitAt - impact, so the effect arrives with the hit
-- The vault stands in HeistConfig.ZONE (Knight's Keep); that zone's boss chases. The other two entries are used when the vault is moved there, and in Studio through the
-- ServerStorage attribute StudioHeistBoss = "SunkenKingdom" | "BillionaireHills" (test only).
-- Switch: ENABLED = false puts the old Sir Ironclad robot back (the 032 / 034 build is untouched).

local BossHeist = {}

BossHeist.ENABLED = true
BossHeist.STUDIO_ATTRIBUTE = "StudioHeistBoss"

export type Attack = { name: string, clip: string, impact: number, callout: string? }
export type Boss = {
	creature: string, -- worker id (the display name comes from the catalogue)
	rig: string?, -- ServerStorage.BossRigs.<rig>.Template (rigged boss); nil = the creature's own model from ReplicatedStorage.CreatureModels
	lens: string, -- the part the searchlight beam starts from (searchlight kind)
	attacks: { Basic: Attack, Laser: Attack, Searchlight: Attack, Stomp: Attack },
}

BossHeist.BOSSES = {
	-- Knight's Keep: Sir Malgrave (the Secret slot, mystery_millionaire)
	MainStreet = {
		creature = "mystery_millionaire",
		rig = "Malgrave",
		lens = "Head",
		attacks = {
			Basic = { name = "Sword Swing", clip = "Basic_SwordSwing", impact = 0.45 },
			Laser = { name = "Riftcleave", clip = "Special_Riftcleave", impact = 0.98, callout = "RIFTCLEAVE! Step aside!" },
			Searchlight = { name = "Oathbreaker Throw", clip = "Special_OathbreakerThrow", impact = 0.69, callout = "SWORD THROW! Get out of the circle!" },
			Stomp = { name = "Ironcall", clip = "Special_Ironcall", impact = 0.25, callout = "IRONCALL! JUMP!" },
		},
	},
	-- Ember Academy (zone id BillionaireHills): the Vault Wizard (the Secret slot, the_trillionaire)
	BillionaireHills = {
		creature = "the_trillionaire",
		rig = "Vault",
		lens = "Head",
		attacks = {
			Basic = { name = "Ledger Tap", clip = "Normal_Repossess", impact = 0.64 },
			Laser = { name = "Vault Beam", clip = "Event_VaultLock", impact = 0.55, callout = "VAULT BEAM! Step aside!" },
			Searchlight = { name = "Coin Rain", clip = "Event_MarketCrash", impact = 0.68, callout = "COIN RAIN! Get out of the circle!" },
			Stomp = { name = "Coin Nova", clip = "Event_BankruptNova", impact = 1.26, callout = "COIN NOVA! JUMP!" },
		},
	},
	-- Sunken Kingdom: Aquaris (the Secret slot, aquaris); its four attacks are step 3 of the boss pass
	SunkenKingdom = {
		creature = "aquaris",
		rig = nil,
		lens = "Head_Blue",
		attacks = {
			Basic = { name = "Tail Swipe", clip = "TailSwipe", impact = 0.5 },
			Laser = { name = "Tidal Breath", clip = "TidalBreath", impact = 0.9, callout = "TIDAL BREATH! Step aside!" },
			Searchlight = { name = "Riptide Dash", clip = "RiptideDash", impact = 0.7, callout = "RIPTIDE DASH! Get out of the circle!" },
			Stomp = { name = "Whirlpool Slam", clip = "WhirlpoolSlam", impact = 0.6, callout = "WHIRLPOOL SLAM! JUMP!" },
		},
	},
} :: { [string]: Boss }

-- The boss of a zone id, or nil (the old robot stays).
function BossHeist.forZone(zone: string?): Boss?
	return if BossHeist.ENABLED and zone then BossHeist.BOSSES[zone] else nil
end

return BossHeist
