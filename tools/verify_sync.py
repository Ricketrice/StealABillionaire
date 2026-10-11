#!/usr/bin/env python3
"""Prints a Luau snippet that compares every script in src/ with the open Studio place (Edit mode).

Run it from the repo root, paste the output into an MCP execute_luau call (or the command bar) and
it returns "all match" or one line per script that differs, exists only in Studio or only in src/.
Backups, _DevOnly._WorkerLineup and the stock Animate scripts inside rigs are ignored.
"""
import glob, json, re


def rolling_hash(data: bytes) -> int:
    h = 0
    for c in data:
        h = (h * 31 + c) % 4294967296
    return h


def main():
    manifest = {}
    for f in glob.glob("src/**/*.lua", recursive=True):
        first, body = open(f, encoding="utf-8").read().split("\n", 1)
        path = re.match(r"-- Studio location: (\S+) ", first).group(1)
        raw = body.encode("utf-8")
        manifest[path] = [len(raw), rolling_hash(raw)]
    print('local M = game:GetService("HttpService"):JSONDecode([==[' + json.dumps(manifest) + "]==])")
    print(SNIPPET)


SNIPPET = r'''local out, seen = {}, {}
local function full(i) local t = {} while i and i ~= game do table.insert(t, 1, i.Name) i = i.Parent end return table.concat(t, ".") end
for _, svc in {"ReplicatedStorage", "ServerScriptService", "ServerStorage", "StarterPlayer", "Workspace", "StarterGui", "ReplicatedFirst", "Lighting"} do
	for _, d in game:GetService(svc):GetDescendants() do
		if d:IsA("LuaSourceContainer") then
			local p = full(d)
			if not p:find("_Backups") and not p:find("_WorkerLineup") and d.Name ~= "Animate" then
				seen[p] = true
				local s, x = d.Source, 0
				for i = 1, #s do x = (x * 31 + string.byte(s, i)) % 4294967296 end
				local e = M[p]
				if not e then table.insert(out, "ONLY IN STUDIO: " .. p .. " (" .. d.ClassName .. ", " .. #s .. ")")
				elseif e[1] ~= #s or e[2] ~= x then table.insert(out, "DIFFERS: " .. p .. " studio " .. #s .. " file " .. e[1]) end
			end
		end
	end
	task.wait()
end
for p in M do if not seen[p] then table.insert(out, "ONLY IN FILE: " .. p) end end
return #out == 0 and "all match" or table.concat(out, "\n")'''

if __name__ == "__main__":
    main()
