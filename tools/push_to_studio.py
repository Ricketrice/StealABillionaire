#!/usr/bin/env python3
"""Packs Luau source files into a model file that the open Studio can load (no network needed).

Studio reads rbxasset:// URLs from its own content folder, so a model written there can be loaded
with game:GetObjects from a command-bar / MCP script. Each source file must start with a line
    -- Studio location: <Service.Path.To.Script> (<ClassName>)
which is not part of the script in Studio. Usage:
    push_to_studio.py file.lua [file.lua ...]
It prints the Luau snippet to run in Studio (Edit mode). The snippet creates missing scripts,
replaces the source of existing ones, and checks every script against the file (length + hash)
and for syntax errors. It does not back anything up: do that first.
"""
import glob, hashlib, json, os, re, sys, time

CONTENT = glob.glob(os.path.expanduser(
    "~/.var/app/org.vinegarhq.Vinegar/data/vinegar/versions/*/content"))


def rolling_hash(data: bytes) -> int:
    h = 0
    for c in data:
        h = (h * 31 + c) % 4294967296
    return h


def cdata(text: str) -> str:
    return "<![CDATA[" + text.replace("]]>", "]]]]><![CDATA[>") + "]]>"


def main(paths):
    if not CONTENT:
        sys.exit("Studio content folder not found")
    items, manifest = [], []
    for i, path in enumerate(paths, 1):
        text = open(path, encoding="utf-8").read()
        first, body = text.split("\n", 1)
        m = re.match(r"-- Studio location: (\S+) \((\w+)\)$", first)
        if not m:
            sys.exit(f"{path}: first line must be '-- Studio location: <path> (<Class>)'")
        raw = body.encode("utf-8")
        manifest.append({"item": f"f{i}", "path": m.group(1), "class": m.group(2),
                         "length": len(raw), "hash": rolling_hash(raw), "file": os.path.basename(path)})
        items.append(f'<Item class="ModuleScript" referent="RBX{i}"><Properties>'
                     f'<string name="Name">f{i}</string>'
                     f'<ProtectedString name="Source">{cdata(body)}</ProtectedString></Properties></Item>')
    items.append('<Item class="StringValue" referent="RBX0"><Properties><string name="Name">manifest</string>'
                 f'<string name="Value">{cdata(json.dumps(manifest))}</string></Properties></Item>')
    name = "push_%s_%s.rbxmx" % (time.strftime("%H%M%S"), hashlib.md5(json.dumps(manifest).encode()).hexdigest()[:6])
    for content in CONTENT:
        folder = os.path.join(content, "sab_sync")
        os.makedirs(folder, exist_ok=True)
        for old in glob.glob(os.path.join(folder, "push_*.rbxmx")):
            os.remove(old)
        with open(os.path.join(folder, name), "w", encoding="utf-8") as f:
            f.write('<roblox version="4">\n' + "\n".join(items) + "\n</roblox>\n")
    print(f"-- {len(paths)} file(s) packed as {name}")
    print(SNIPPET.replace("FILE_NAME", name))


SNIPPET = r'''local objects = game:GetObjects("rbxasset://sab_sync/FILE_NAME")
local SES, byName, out = game:GetService("ScriptEditorService"), {}, {}
for _, o in objects do byName[o.Name] = o end
for _, e in game:GetService("HttpService"):JSONDecode(byName.manifest.Value) do
	local source = byName[e.item].Source
	local segments = string.split(e.path, ".")
	local parent = game:GetService(segments[1])
	for i = 2, #segments - 1 do parent = parent:FindFirstChild(segments[i]) or error("missing parent in " .. e.path) end
	local target = parent:FindFirstChild(segments[#segments])
	local state = "updated"
	if target and target.ClassName ~= e.class then error(e.path .. " is a " .. target.ClassName) end
	if not target then
		target = Instance.new(e.class)
		target.Name = segments[#segments]
		target.Source = source
		target.Parent = parent
		state = "CREATED"
	elseif target.Source == source then
		state = "unchanged"
	else
		SES:UpdateSourceAsync(target, function() return source end)
	end
	local now, h = target.Source, 0
	for i = 1, #now do h = (h * 31 + string.byte(now, i)) % 4294967296 end
	local fn, err = loadstring(now)
	local good = #now == e.length and h == e.hash and fn ~= nil
	table.insert(out, ("%s %s: %s (%d chars)%s"):format(good and "ok " or "BAD", e.path, state, #now, fn and "" or " SYNTAX " .. tostring(err)))
end
return table.concat(out, "\n")'''

if __name__ == "__main__":
    main(sys.argv[1:])
