-- Studio location: ReplicatedStorage.AquarisAttacks (ModuleScript)
-- AquarisAttacks  (036 boss pass, step 3): the four attack clips of Aquaris, the Sunken Kingdom boss, for the Boss Heist chase. Data only plus a tiny sampler.
-- They are the same four slots every boss has in BossHeist (name / clip / impact / callout) and play on the same cue: the server writes VW_Clip / VW_ClipT0 on the chaser
-- model, so the clip's `impact` second lands on the attack's hitAt (HeistConfig warnings 1.6-2.0 s, 2.5 s gap: nothing here changes a rule).
--   TailSwipe     = Basic      (wake-up flourish: the tail whips round)
--   TidalBreath   = Laser      (rears up, opens its jaw, a jet of water along the ground)
--   RiptideDash   = Searchlight(coils back, then dashes forward through the water)
--   WhirlpoolSlam = Stomp      (rears up on its hind legs, slams down: a ring of water rolls out)
-- Clip format (rig space of the creature model: front = -Z, up = +Y; degrees; translations in studs at scale 1, the runtime multiplies by the creature scale):
--   { length, loop, joints = { [Piece] = { { t, rx, ry, rz, px, py, pz }, ... } }, fx = { { at = seconds, kind = ... }, ... } }
--   Pieces are the animated parts of the Aquaris model (CreatureSpecs.aquarisBoss partAnim): Neck, Head, Jaw, TailA/B/C, WingR/L, LegFR/FL/HR/HL, plus "Root" = the whole
--   creature (its placement is offset by it). Key values are poses RELATIVE to the idle; the first and last key of a one-shot clip are 0 so it blends with the idle.
-- Cosmetic only; kid-safe (water, wind, no gore).

local AquarisAttacks = {}

AquarisAttacks.PARENT = { Head = "Neck", Jaw = "Head", TailB = "TailA", TailC = "TailB" } -- a piece follows its parent's pose

local function k(t: number, rx: number?, ry: number?, rz: number?, px: number?, py: number?, pz: number?): { number }
	return { t, rx or 0, ry or 0, rz or 0, px or 0, py or 0, pz or 0 }
end

AquarisAttacks.CLIPS = {
	Walk = {
		length = 1.2,
		loop = true,
		joints = {
			Root = { k(0), k(0.3, 0, 0, 2, 0, 0.12), k(0.6), k(0.9, 0, 0, -2, 0, 0.12), k(1.2) },
			LegFR = { k(0), k(0.3, 22), k(0.9, -22), k(1.2) },
			LegHL = { k(0), k(0.3, 22), k(0.9, -22), k(1.2) },
			LegFL = { k(0), k(0.3, -22), k(0.9, 22), k(1.2) },
			LegHR = { k(0), k(0.3, -22), k(0.9, 22), k(1.2) },
			TailA = { k(0), k(0.3, 0, 7), k(0.9, 0, -7), k(1.2) },
			TailB = { k(0), k(0.3, 0, 9), k(0.9, 0, -9), k(1.2) },
			TailC = { k(0), k(0.3, 0, 12), k(0.9, 0, -12), k(1.2) },
			WingR = { k(0), k(0.3, 0, 0, -8), k(0.9, 0, 0, 4), k(1.2) },
			WingL = { k(0), k(0.3, 0, 0, 8), k(0.9, 0, 0, -4), k(1.2) },
		},
		fx = {},
	},
	TailSwipe = {
		length = 1.6,
		loop = false,
		joints = {
			Root = { k(0), k(0.3, 0, -6), k(0.5, 0, 12), k(1.0, 0, 3), k(1.6) },
			Neck = { k(0), k(0.3, 0, 10), k(0.5, 0, -12), k(1.6) },
			TailA = { k(0), k(0.3, 0, 30), k(0.5, 0, -35), k(0.9, 0, 6), k(1.6) },
			TailB = { k(0), k(0.3, 0, 40), k(0.5, 0, -55), k(0.9, 0, 8), k(1.6) },
			TailC = { k(0), k(0.3, 0, 50), k(0.5, 0, -75), k(0.9, 0, 10), k(1.6) },
		},
		fx = { { at = 0.5, kind = "tail" } },
	},
	TidalBreath = {
		length = 2.6,
		loop = false,
		joints = {
			Root = { k(0), k(0.5, 10, 0, 0, 0, 0.4), k(0.9, -6), k(1.7, -6), k(2.6) },
			Neck = { k(0), k(0.5, 25), k(0.9, -10), k(1.7, -10), k(2.6) },
			Head = { k(0), k(0.5, 15), k(0.9, -12), k(1.7, -12), k(2.6) },
			Jaw = { k(0), k(0.5, -30), k(1.7, -30), k(2.3, -5), k(2.6) },
			WingR = { k(0), k(0.5, 0, 0, -30), k(1.7, 0, 0, -30), k(2.6) },
			WingL = { k(0), k(0.5, 0, 0, 30), k(1.7, 0, 0, 30), k(2.6) },
		},
		fx = {
			{ at = 0.9, kind = "stream", count = 9, every = 0.1 },
		},
	},
	RiptideDash = {
		length = 2.2,
		loop = false,
		joints = {
			Root = { k(0), k(0.35, 8, 0, 0, 0, -0.5, 1.8), k(0.7, -10, 0, 0, 0, -0.2, -9), k(1.1, -10, 0, 0, 0, -0.2, -9), k(2.2) },
			Neck = { k(0), k(0.35, 15), k(0.7, -20), k(1.1, -20), k(2.2) },
			Head = { k(0), k(0.7, -10), k(1.1, -10), k(2.2) },
			TailA = { k(0), k(0.7, 15), k(1.1, 12), k(2.2) },
			WingR = { k(0), k(0.7, 0, 0, -35), k(1.1, 0, 0, -35), k(2.2) },
			WingL = { k(0), k(0.7, 0, 0, 35), k(1.1, 0, 0, 35), k(2.2) },
		},
		fx = { { at = 0.5, kind = "trail", count = 6, every = 0.1 }, { at = 0.7, kind = "splash" } },
	},
	WhirlpoolSlam = {
		length = 2.2,
		loop = false,
		joints = {
			Root = { k(0), k(0.35, 22, 0, 0, 0, 1.2), k(0.6, -8, 0, 0, 0, -0.4), k(0.8, -3), k(1.4) },
			Neck = { k(0), k(0.35, 20), k(0.6, -18), k(1.4) },
			Head = { k(0), k(0.35, 10), k(0.6, -14), k(1.4) },
			WingR = { k(0), k(0.35, 0, 0, -45), k(0.6, 0, 0, -10), k(1.4) },
			WingL = { k(0), k(0.35, 0, 0, 45), k(0.6, 0, 0, 10), k(1.4) },
			LegFR = { k(0), k(0.35, 25), k(0.6, -15), k(1.4) },
			LegFL = { k(0), k(0.35, 25), k(0.6, -15), k(1.4) },
		},
		fx = { { at = 0.6, kind = "ring" } },
	},
}

local function smooth(u: number): number
	return u * u * (3 - 2 * u)
end

-- The pose of one joint at time t: { rx, ry, rz, px, py, pz } (a loop wraps; a one-shot holds its last key).
function AquarisAttacks.sampleJoint(keys: { { number } }, t: number): { number }
	local n = #keys
	if t <= keys[1][1] then
		return { table.unpack(keys[1], 2, 7) }
	elseif t >= keys[n][1] then
		return { table.unpack(keys[n], 2, 7) }
	end
	for i = 1, n - 1 do
		local a, b = keys[i], keys[i + 1]
		if t >= a[1] and t <= b[1] then
			local u = smooth((t - a[1]) / (b[1] - a[1]))
			local out = {}
			for j = 2, 7 do
				out[j - 1] = a[j] + (b[j] - a[j]) * u
			end
			return out
		end
	end
	return { 0, 0, 0, 0, 0, 0 }
end

-- Poses of every joint of a clip at elapsed time `el` (nil when a one-shot is over).
function AquarisAttacks.sample(name: string, el: number): { [string]: { number } }?
	local clip = AquarisAttacks.CLIPS[name]
	if not clip then
		return nil
	end
	local t = el
	if clip.loop then
		t = el % clip.length
	elseif el > clip.length then
		return nil
	end
	local pose = {}
	for piece, keys in clip.joints do
		pose[piece] = AquarisAttacks.sampleJoint(keys, t)
	end
	return pose
end

return AquarisAttacks
