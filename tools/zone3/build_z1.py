#!/usr/bin/env python3
"""Builds Z1_NecroZone3.lua from Z1_NecroZone3.src.lua + necro_boxes.luau.txt (138 collision boxes)."""
import os
here = os.path.dirname(os.path.abspath(__file__))
src = open(os.path.join(here, "Z1_NecroZone3.src.lua")).read()
rows = open(os.path.join(here, "necro_boxes.luau.txt")).read().rstrip("\n")
open(os.path.join(here, "Z1_NecroZone3.lua"), "w").write(src.replace("--@@BOXES@@", rows))
print("wrote Z1_NecroZone3.lua")
