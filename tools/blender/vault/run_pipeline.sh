#!/usr/bin/env bash
# Vault wizard: GLB -> Roblox pipeline, offline half (no Studio). Reproducible from Vault.glb (never modified).
#   tools/blender/vault/run_pipeline.sh [--skip-fix]     (--skip-fix reuses WORK/anim_fixed.json: the clip solver takes ~25 min)
# Outputs: assets/export/vault/{VaultWizard.fbx, VaultPalette_*.png, fx/*.png, vault_roblox.json, vault_expected.json, vault_parts.json}
#          src/ServerStorage/VaultWizardTest/RuntimeSrc/{VaultData.lua, Clips/*.lua}, Tests/Expected.lua
set -euo pipefail
cd "$(dirname "$0")/../../.."
BL="flatpak run org.blender.Blender -b -P"
export PATH="$PATH:$HOME/.rokit/bin"
python3 -I tools/blender/vault/vw_textures.py
python3 -I tools/blender/vault/vw_fx_textures.py
$BL "$PWD/tools/blender/vault/vw_prep.py" 2>&1 | grep -E "BODY|FBX |Error|Traceback" || true
if [[ "${1:-}" != "--skip-fix" ]]; then
  $BL "$PWD/tools/blender/vault/vw_anim_fix.py" 2>&1 | grep -E "^(Idle|Walk|Steal|Normal|Event)|REST|Error|Traceback"
fi
python3 -I tools/blender/vault/vw_convert.py --scale 2.5 --anim "$HOME/Pictures/035_preview/vault2/anim_fixed.json" --tag vault_roblox
stylua src/ServerStorage/VaultWizardTest
echo "offline pipeline done; next: owner saves the place, runs Import 3D on assets/export/vault/VaultWizard.fbx (docs/VAULT_PIPELINE.md)"
