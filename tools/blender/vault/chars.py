# Per-character pipeline configuration (Claude Design GLB -> Blender -> Roblox). Select with env VW_CHAR (default "vault").
# Contract for a new character: R15 joint-node names, one mesh per joint node (identity local transform), "<Part>_Neon" sibling meshes, cosmetic nodes start with FX_ / Attach_.
import os

H = os.path.expanduser("~")
CONCEPT = os.path.join(H, "Pictures/035_preview/concept")
CHARS = {
    "vault": dict(
        name="Vault", prefix="VaultWizard", glb=os.path.join(CONCEPT, "Vault.glb"), work=os.path.join(H, "Pictures/035_preview/vault2"), export="vault", S=2.5,
        drop={"CoinRainMarks_Neon", "GroundSigil_Neon", "NovaRing_Neon", "Shockwave_Neon", "TakeoverBeam_Neon", "CoinOrbit", "CoinOrbit_Neon", "CoinRain", "CoinRain_Neon", "AuraFlames_A_Neon", "AuraFlames_B_Neon"},
        ratios={"UpperTorso": 0.48, "UpperTorso_Neon": 0.6, "LowerTorso": 0.5, "LedgerScepter": 0.5, "LedgerScepter_Neon": 0.5, "WizardTopHat": 0.6, "WizardTopHat_Neon": 0.6, "Head": 0.55,
                "LeftFoot": 0.6, "RightFoot": 0.6, "LeftLowerArm": 0.6, "RightLowerArm": 0.6, "VaultHalo": 0.5, "VaultHalo_Neon": 0.5},
        texture="palette", neon_extra=("ScepterGem",), loops=("Idle", "Walk"),
        clips=["Idle", "Walk", "Steal_Grab", "Normal_Repossess", "Event_MarketCrash", "Event_VaultLock", "Event_HostileTakeover", "Event_BankruptNova"],
        weapon=["LedgerScepter", "LedgerScepter_Neon"], right_extra=["LedgerScepter"],
        obstacles=["UpperTorso", "UpperTorso_Neon", "LowerTorso", "LowerTorso_Neon", "Head", "Head_Neon", "WizardTopHat", "WizardTopHat_Neon", "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "LeftLowerLeg_Neon", "RightLowerLeg", "RightLowerLeg_Neon"],
        fx_bbox=["CoinRainMarks_Neon", "GroundSigil_Neon", "NovaRing_Neon", "Shockwave_Neon", "TakeoverBeam_Neon", "CoinOrbit", "CoinRain", "AuraFlames_A_Neon"],
        fx_full=[], neon_srgb=[0.70, 0.58, 1.0], lua="BossRigs/Vault", color_png="VaultPalette_Color.png", metal_png="VaultPalette_Metalness.png", rough_png="VaultPalette_Roughness.png",
        spin={"FX_VaultHalo": 45.0, "FX_ScepterGem": 90.0}, extents_skip=["VaultHalo", "VaultHalo_Neon"], rest_rot_parts=[], clip_rename={}, fx_rename={},
    ),
    "malgrave": dict(
        name="Malgrave", prefix="Malgrave", glb=os.path.join(CONCEPT, "Malgrave.glb"), work=os.path.join(H, "Pictures/035_preview/malgrave"), export="malgrave", S=2.5,
        drop={"SwordEnergy_FX", "GroundSigil_FX", "AuraEnergy_FX", "AuraSmoke_Emitter_Emitter", "AuraEmbers_Emitter_Emitter", "AuraWisps_Emitter_Emitter", "SlashArc_FX", "Fissure", "Fissure_FX", "WindBurst_Wind",
              "WindGust_Wind", "ThrownGreatsword", "ThrownGreatsword_Neon", "ThrownSawRing_FX", "GraveMarks_FX", "GraveBlades_Inner_Spectral", "GraveBlades_Outer_Spectral", "GraveShock_FX"},
        ratios={}, texture="atlas", neon_extra=(), loops=("Idle", "Walk"),
        clips=["Idle", "Walk", "Basic_SwordSwing", "Special_Riftcleave", "Special_SwordThrow", "Special_Gravecall"],
        weapon=["Greatsword", "Greatsword_Neon"], right_extra=["Greatsword"],
        obstacles=["UpperTorso", "UpperTorso_Neon", "LowerTorso", "LowerTorso_Neon", "Head", "Head_Neon", "LeftUpperLeg", "LeftUpperLeg_Neon", "RightUpperLeg", "RightUpperLeg_Neon", "LeftLowerLeg", "RightLowerLeg"],
        fx_bbox=["SwordEnergy_FX", "GroundSigil_FX", "AuraEnergy_FX", "SlashArc_FX", "Fissure", "WindBurst_Wind", "WindGust_Wind", "ThrownGreatsword", "ThrownSawRing_FX", "GraveMarks_FX", "GraveBlades_Inner_Spectral",
                 "GraveBlades_Outer_Spectral", "GraveShock_FX"],
        fx_full=["FX_ThrownSword"], neon_srgb=None, lua="BossRigs/Malgrave", color_png="Malgrave_Color.png", metal_png="Malgrave_Metalness.png", rough_png="Malgrave_Roughness.png",
        spin={}, extents_skip=[],
        # kid-safe / owner names in everything that ships (Lua data, tests): "Gravecall" -> "Ironcall", "SwordThrow" -> "OathbreakerThrow", Grave* effect nodes -> Iron*
        rest_rot_parts=["Greatsword", "Greatsword_Neon"],
        clip_rename={"Special_Gravecall": "Special_Ironcall", "Special_SwordThrow": "Special_OathbreakerThrow"},
        fx_rename={"FX_GraveBlades_Inner": "FX_IronBlades_Inner", "FX_GraveBlades_Outer": "FX_IronBlades_Outer", "FX_GraveMarks": "FX_IronMarks", "FX_GraveShock": "FX_IronShock", "GraveMarks_FX": "IronMarks_FX",
                   "GraveBlades_Inner_Spectral": "IronBlades_Inner", "GraveBlades_Outer_Spectral": "IronBlades_Outer", "GraveShock_FX": "IronShock_FX"},
    ),
}
CHAR = os.environ.get("VW_CHAR", "vault")
CFG = CHARS[CHAR]
