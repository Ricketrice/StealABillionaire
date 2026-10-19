#!/bin/bash
# snapshot.sh <name> : copies the open place to backups/<name>.rbxl (+ backups/<name>_scripts).
# Start it, then launch a 1-client test from Studio Edit:
#   task.spawn(function() game:GetService("StudioTestService"):ExecuteMultiplayerTestAsync(1, "snapshot") end)
# Studio writes server.rbxl before the test processes load; this copies it and kills the test processes at once
# (tools/kill_tests.sh never touches the editor). No test runs ("snapshot" matches no DevTest arg).
name=$1
cd "$(dirname "$0")/../.." || exit 1
RBXL=$HOME/.var/app/org.vinegarhq.Vinegar/data/vinegar/prefixes/studio/drive_c/users/ricketrice/AppData/Local/Roblox/server.rbxl
marker=$(mktemp); start=$(date +%s)
while [ ! "$RBXL" -nt "$marker" ]; do
  sleep 1
  if [ $(( $(date +%s) - start )) -gt 300 ]; then echo "TIMEOUT: no new server.rbxl"; rm -f "$marker"; exit 1; fi
done
sleep 3 # let Studio finish writing
cp "$RBXL" "backups/$name.rbxl"; rm -f "$marker"
sleep 2; tools/kill_tests.sh >/dev/null 2>&1; sleep 2; tools/kill_tests.sh --check | head -1
python3 tools/rbxl_scripts.py "backups/$name.rbxl" --export "backups/${name}_scripts" >/dev/null 2>&1
echo "SNAPSHOT backups/$name.rbxl $(stat -c %s "backups/$name.rbxl") bytes, scripts: $(find "backups/${name}_scripts" -type f | wc -l)"
