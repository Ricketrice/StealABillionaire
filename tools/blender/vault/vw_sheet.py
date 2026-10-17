# Contact sheet: before (original clip) / after (corrected clip) rows, rendered from the converted Roblox data. python3 -I tools/blender/vault/vw_sheet.py
import os, sys
from PIL import Image, ImageDraw
W = os.path.expanduser("~/Pictures/035_preview/vault2")
clips = ["Steal_Grab", "Normal_Repossess", "Event_MarketCrash", "Event_BankruptNova"]
cw, ch = 300, 420; sc = 0.62; cw2, ch2 = int(cw * sc), int(ch * sc)
sheet = Image.new("RGB", (8 * cw2 + 150, len(clips) * 2 * ch2), (24, 26, 32)); d = ImageDraw.Draw(sheet)
for r, clip in enumerate(clips):
    for k, (tag, lab) in enumerate((("vault_roblox_orig", "BEFORE"), ("vault_roblox", "AFTER"))):
        y = (r * 2 + k) * ch2; d.text((6, y + 8), "%s\n%s" % (clip, lab), fill=(255, 255, 0) if k else (255, 150, 150))
        for i in range(8):
            p = os.path.join(W, "r_" + tag, "%s_%d.png" % (clip, i))
            if os.path.exists(p): sheet.paste(Image.open(p).resize((cw2, ch2)), (150 + i * cw2, y))
out = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))), "assets/export/vault/VAULT_clips_before_after.jpg")
sheet.save(out, quality=88); print(out, sheet.size)
