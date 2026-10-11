#!/bin/bash
# test_guard.sh <label> [timeout_s] : guards one Studio multi-client test session (TAG env var = the test's print prefix, default T022; Milestone 026 uses T026).
# Start it just BEFORE launching the test from Studio (StudioTestService:ExecuteMultiplayerTestAsync).
# It copies Studio's recovery file aside, stops the test's own processes if memory runs out, and
# ends when the test prints its "@@${TAG:-T022}|SUMMARY" line. It never touches Studio processes that were
# already running when it started (the Edit session). Output goes to $OUT (default /tmp/sab_test).
label=$1; timeout=${2:-900}
S=${OUT:-/tmp/sab_test}; mkdir -p "$S"; LOGS=$HOME/.var/app/org.vinegarhq.Vinegar/data/vinegar/appdata/Roblox/logs
RBXL=$HOME/.var/app/org.vinegarhq.Vinegar/data/vinegar/prefixes/studio/drive_c/users/ricketrice/AppData/Local/Roblox/server.rbxl
marker=$S/marker_$label; touch $marker
ls $LOGS > $S/logs_before_$label   # only logs of processes started after this count (an earlier session may still be writing its own)
newlogs() { for f in $(find $LOGS -name '*_Studio_*_last.log' -newer $marker 2>/dev/null); do grep -qxF "$(basename $f)" $S/logs_before_$label || echo $f; done; }
start=$(date +%s); low=0; stall=0; copied=0; minavail=99999999; maxproc=0
# Test processes = Studio executables (by argv[0], so not the embedded web views) that did not exist
# when this script started.
studiopids() { for d in /proc/[0-9]*; do a=$( { tr '\0' '\n' < $d/cmdline | head -1; } 2>/dev/null); case "$a" in *RobloxStudioBeta.exe) echo ${d#/proc/};; esac; done; }
BASE=" $(studiopids | tr '\n' ' ') "
testpids() { for p in $(studiopids); do case "$BASE" in *" $p "*) ;; *) echo $p;; esac; done; }
while :; do
  now=$(date +%s); el=$((now-start))
  avail=$(awk '/MemAvailable/{print $2}' /proc/meminfo); swapfree=$(awk '/SwapFree/{print $2}' /proc/meminfo)
  [ $avail -lt $minavail ] && minavail=$avail
  n=$(testpids | wc -l); [ $n -gt $maxproc ] && maxproc=$n
  if [ $copied = 0 ] && [ $RBXL -nt $marker ]; then sleep 2; cp $RBXL $S/server_$label.rbxl && copied=1; fi
  # Compressed swap (zram) keeps MemAvailable low by design, so the limits are: swap nearly used up,
  # sustained stalling (pressure), or almost no memory at all for 10 s.
  psi=$(awk '/^full/{sub("avg10=","",$2); print int($2)}' /proc/pressure/memory)
  if [ $avail -lt 100000 ]; then low=$((low+1)); else low=0; fi
  if [ $psi -ge 50 ]; then stall=$((stall+1)); else stall=0; fi
  [ $((el % 10)) -lt 2 ] && echo "$el avail=$((avail/1024))MB swapfree=$((swapfree/1024))MB psi_full10=$psi procs=$n" >> $S/trace_$label.txt
  if [ $low -ge 5 ] || [ $stall -ge 3 ] || [ $swapfree -lt 5000000 ]; then
    echo "WATCHDOG: low memory (avail ${avail} kB, swap free ${swapfree} kB, pressure ${psi}) after ${el}s; stopping test processes"
    testpids | xargs -r kill -9; result=watchdog; break
  fi
  if [ -n "$(newlogs)" ] && grep -l "@@${TAG:-T022}|SUMMARY" $(newlogs) >/dev/null 2>&1; then result=summary; break; fi
  if [ $el -gt $timeout ]; then result=timeout; break; fi
  sleep 2
done
echo "RESULT=$result label=$label elapsed=${el}s min_avail=$((minavail/1024))MB max_test_procs=$maxproc recovery_copy=$copied"
for f in $(newlogs); do
  if grep -q "@@${TAG:-T022}|" $f; then echo "--- $(basename $f)"; grep -o "@@${TAG:-T022}|.*" $f | grep -E "FAIL|ERROR|done |ABORTED" | cut -c1-600; grep -o "@@${TAG:-T022}|SUMMARY [^#]*" $f | head -1; fi
done
