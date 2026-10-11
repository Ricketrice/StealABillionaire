-- Studio location: ReplicatedStorage.PvPConfig (ModuleScript)
-- PvPConfig  (Milestone 022)
-- Every switch and number for PvP stealing, base defence and bats. Shared by server and clients.
--
-- The two feature flags are independent and OFF by default: with both off the game behaves exactly
-- as it did before Milestone 022 (no steal prompts on placed workers, no bats, no PvP buttons).
-- To test in Studio without editing this file, set a ServerStorage attribute to true (they are
-- ignored outside Studio):  StudioPvPStealing  /  StudioWeaponCombat

local PvPConfig = {}

PvPConfig.PVP_STEALING_ENABLED = false -- steal placed workers from other players' bases, base lock, new-player protection
PvPConfig.WEAPON_COMBAT_ENABLED = false -- bats

PvPConfig.STUDIO_STEALING_ATTRIBUTE = "StudioPvPStealing"
PvPConfig.STUDIO_COMBAT_ATTRIBUTE = "StudioWeaponCombat"
PvPConfig.STUDIO_PROTECTION_ATTRIBUTE = "StudioPvPProtection" -- Studio only: seconds of protection for everyone who joins, or false for none

PvPConfig.Steal = {
	HOLD = 2, -- seconds the Steal prompt must be held
	HOLD_TOLERANCE = 0.35, -- the server accepts a hold this much shorter (latency)
	DISTANCE = 8, -- studs from the worker
	DISTANCE_TOLERANCE = 4,
	CHECK_INTERVAL = 0.1, -- seconds between checks on each thief (delivery, shortcuts)
	TELEPORT_STUDS = 30, -- moving further than this between two checks counts as a teleport
	THIRD_PARTY_CAN_TAG = true, -- anyone's hit knocks a stolen worker loose (it always returns to its owner)
	CONFIRM_RETRY = 2, -- seconds between checks of a hand-over whose journal write could not be confirmed
	FINAL_SAVE_WAIT = 6, -- seconds a leaving player's final save may wait for a hand-over that is being written
	MAX_CARRY = 90, -- seconds a stolen worker may be carried before it goes back to its owner (0 = no limit)
	SAFE_ZONE_LIMIT = 6, -- seconds in total a thief may spend in safe zones with a stolen worker: enough to cut across, not to hide
	BLOCK_JUMP_BOOSTS = true, -- jump height can't be raised while carrying a stolen worker (speed never can)
	BLOCK_SEATS = true, -- no seats or vehicles while carrying a stolen worker
}

PvPConfig.Lock = {
	DURATION = 60, -- seconds a base stays locked
	COOLDOWN = 180, -- seconds after a lock ends before the next one
	LEAVE_PENALTY = 120, -- lock cooldown given to an owner who leaves while being robbed
}

PvPConfig.Protection = {
	DURATION = 600, -- seconds from the start of a player's first session
	ENDS_ON_STEAL = true, -- a protected player who starts a steal gives up the rest of it
}

PvPConfig.Safe = {
	SPAWN_RADIUS = 28, -- studs around Workspace.SpawnLocation where nobody can attack or be hit
	SPAWN_IMMUNITY = 4, -- seconds after spawning during which a player can't be hit (ends if they attack or steal)
	TAG = "PvPSafeZone", -- any part with this tag is a safe zone too
}

-- Attacks. range/height in studs; arcDot = cosine of half the swing arc; knockback/lift in studs per
-- second for `duration` seconds; immunity = seconds the victim can't be hit again. No attack deals
-- damage. Strength never depends on the bat skin. Every immunity is longer than its knockback, and
-- a hit never takes control away, so nobody can be stun-locked.
--   charged: hold the attack for chargeTime (up to maxCharge, then it fizzles) and let go. Letting go
--   early is a basic swing. Being hit while charging cancels it (interruptCooldown before the next).
--   specials: the attacker is marked for `telegraph` seconds before it lands, where they stand then.
PvPConfig.Attacks = {
	basic = { cooldown = 0.6, windup = 0.12, range = 7.5, height = 6, arcDot = 0.3, maxTargets = 1, knockback = 30, lift = 12, duration = 0.18, immunity = 0.8 },
	charged = { cooldown = 2.2, windup = 0.15, chargeTime = 0.7, chargeTolerance = 0.1, maxCharge = 3, interruptCooldown = 0.8, range = 8.5, height = 6, arcDot = 0.2, maxTargets = 3, knockback = 52, lift = 20, duration = 0.24, immunity = 1 },
}
PvPConfig.Specials = {
	shockwave = { name = "Shockwave", hint = "Pushes back everyone around you.", cooldown = 12, telegraph = 0.7, shape = "radial", range = 13, height = 8, maxTargets = 8, knockback = 46, lift = 24, duration = 0.26, immunity = 1.2 },
	burst = { name = "Burst Push", hint = "A long, narrow push straight ahead.", cooldown = 10, telegraph = 0.55, shape = "cone", range = 16, arcDot = 0.7, height = 7, maxTargets = 4, knockback = 60, lift = 14, duration = 0.26, immunity = 1.2 },
}
PvPConfig.SPECIAL_ORDER = { "shockwave", "burst" }
PvPConfig.DEFAULT_SPECIAL = "shockwave"

-- Bat looks (cosmetic only). The chosen look and special are kept per player for as long as the
-- server runs and are NOT saved: PlayerData's save has no place for them. Saving them would need a
-- new field in the save (for example pvp = { skin = "Neon", special = "burst" }), which is a save
-- schema change (schema 3, defaults for older saves, and the sanitizer taught to keep the field).
PvPConfig.SKIN_ORDER = { "Starter", "Neon", "Golden" }
PvPConfig.DEFAULT_SKIN = "Starter"

-- What players see and hear (clients only; nothing here changes an outcome).
PvPConfig.Alarm = { BEEP_INTERVAL = 1.1, MAX_BEEPS = 10 } -- the robbery alarm beeps this often, this many times per robbery
PvPConfig.Banner = { TIME = 2.4 } -- seconds a STEAL SUCCESSFUL / DEFENDED banner stays up

PvPConfig.ACTION_RATE = 12 -- PvP requests a client may send per second (extra ones are dropped)

return PvPConfig
