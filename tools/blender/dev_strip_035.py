# dev helper: python3 tools/blender/dev_strip_035.py Name [tags...]  -> ~/Pictures/035_preview/b1_dev/Name_strip.png (grey strip of the dev renders)
import sys, os
from PIL import Image
D = os.path.expanduser("~/Pictures/035_preview/b1_dev")
name = sys.argv[1]
tags = sys.argv[2:] or ["front", "tq", "back", "side"]
ims = [Image.open(os.path.join(D, "%s_%s.png" % (name, t))).convert("RGBA") for t in tags]
w, h = ims[0].size
out = Image.new("RGBA", (w * len(ims), h), (150, 160, 175, 255))
for i, im in enumerate(ims):
    out.alpha_composite(im, (i * w, 0))
out.convert("RGB").save(os.path.join(D, name + "_strip.png"))
