#!/usr/bin/env python3
"""Runs a long Luau tool script in the open Studio without pasting it: packs the file into Studio's content
folder (like push_to_studio.py) and prints a 3-line snippet for MCP execute_luau / the command bar that loads
and runs it. Usage: run_file.py file.lua [PRELUDE]   (PRELUDE = Luau prepended, e.g. "local UNDO = true")
"""
import glob, os, sys, time

CONTENT = glob.glob(os.path.expanduser("~/.var/app/org.vinegarhq.Vinegar/data/vinegar/versions/*/content"))


def main(path, prelude=""):
    body = open(path, encoding="utf-8").read()
    if prelude:
        body = prelude + "\n" + body
    body = body.replace("]]>", "]]]]><![CDATA[>")
    name = "run_%s_%s.rbxmx" % (os.path.splitext(os.path.basename(path))[0], time.strftime("%H%M%S"))
    for content in CONTENT:
        folder = os.path.join(content, "sab_sync")
        os.makedirs(folder, exist_ok=True)
        for old in glob.glob(os.path.join(folder, "run_*.rbxmx")):
            os.remove(old)
        with open(os.path.join(folder, name), "w", encoding="utf-8") as f:
            f.write('<roblox version="4">\n<Item class="ModuleScript" referent="RBX1"><Properties>'
                    '<string name="Name">run</string><ProtectedString name="Source"><![CDATA['
                    + body + ']]></ProtectedString></Properties></Item>\n</roblox>\n')
    print('local o = game:GetObjects("rbxasset://sab_sync/%s")[1]' % name)
    print('local fn = assert(loadstring(o.Source, "=%s"))' % os.path.basename(path))
    print("return fn()")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else "")
