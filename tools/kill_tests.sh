#!/bin/bash
# kill_tests.sh [--check] : kills every Studio TEST process (server + clients started by StudioTestService, i.e. with
# -studiotestservicemode) and the crash handlers that started after the main editor's own one. Never the main editor.
# Processes are told apart by their program (argv[0]), not by words anywhere in their arguments (webview helpers
# mention RobloxStudioBeta.exe too).
# --check only lists them (exit 1 if any are left). Always prints what Studio runs afterwards and free memory.
# Rule (owner, 2026-10-14): run it before every test (--check must be clean) and after every test (pass, fail or crash).
check=0; [ "$1" = "--check" ] && check=1
prog() { tr '\0' '\n' < "/proc/$1/cmdline" 2>/dev/null | head -1; }
args() { tr '\0' ' ' < "/proc/$1/cmdline" 2>/dev/null; }
editor=""; tests=""; handlers=""; others=""
for d in /proc/[0-9]*; do
  p=${d#/proc/}
  case "$(prog $p)" in
    *RobloxStudioBeta.exe)
      case "$(args $p)" in
        *-studiotestservicemode*) tests="$tests $p" ;;
        *) editor="$editor $p" ;;
      esac ;;
    *RobloxCrashHandler.exe) others="$others $p" ;;
  esac
done
editor=$(echo $editor)
if [ $(echo "$editor" | wc -w) -ne 1 ]; then
  echo "editor not found exactly once ('$editor'): crash handlers left alone"
else
  estart=$(awk '{print $22}' /proc/$editor/stat)
  for p in $others; do
    s=$(awk '{print $22}' /proc/$p/stat 2>/dev/null)
    [ -n "$s" ] && [ $((s - estart)) -gt 500 ] && handlers="$handlers $p" # started > 5 s after the editor = a test's
  done
fi
if [ $check = 1 ]; then
  if [ -z "$tests$handlers" ]; then echo "CLEAN: no test processes"; else echo "LEFT: tests[$tests ] handlers[$handlers ]"; fi
else
  if [ -n "$tests$handlers" ]; then kill -9 $tests $handlers 2>/dev/null; echo "killed: tests[$tests ] handlers[$handlers ]"; else echo "nothing to kill"; fi
  sleep 1
fi
echo "main editor: ${editor:-none}"
for d in /proc/[0-9]*; do
  p=${d#/proc/}
  case "$(prog $p)" in
    *Roblox*) echo "  $p $(( $(awk '/VmRSS/{print $2}' $d/status 2>/dev/null || echo 0) / 1024 )) MB $(prog $p | sed 's/.*\\//') $(args $p | grep -o -e '-task [A-Za-z]*')" ;;
  esac
done
free -m | awk 'NR==2{print "memory: available " $7 " MB of " $2 " MB"} NR==3{print "swap used: " $3 " MB"}'
if [ $check = 1 ] && [ -n "$tests$handlers" ]; then exit 1; fi
exit 0
