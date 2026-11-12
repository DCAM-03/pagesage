#!/usr/bin/env bash
# Check the device through the SDK's adb, independently of emulator launcher PID.
set -euo pipefail
serial="${1:-emulator-5554}"
boot_timeout="${2:-600}"
if [[ ! "$boot_timeout" =~ ^[1-9][0-9]*$ ]]; then
  echo 'Boot timeout must be a positive number of seconds' >&2
  exit 1
fi
adb="$ANDROID_HOME/platform-tools/adb"
adb_log="$RUNNER_TEMP/pagesage-adb.log"
started=$SECONDS
next_report=0
state=unavailable
boot=unknown
package=unknown

while (( SECONDS - started < boot_timeout )); do
  state="$(timeout 10 "$adb" -s "$serial" get-state 2>> "$adb_log")" || state=unavailable
  state="$(printf '%s' "$state" | tr -d '\r\n')"
  if [[ "$state" == device ]]; then
    boot="$(timeout 10 "$adb" -s "$serial" shell getprop sys.boot_completed 2>> "$adb_log")" || boot=query_failed
    boot="$(printf '%s' "$boot" | tr -d '\r\n')"
    if [[ "$boot" == 1 ]]; then
      package="$(timeout 10 "$adb" -s "$serial" shell pm path android 2>> "$adb_log")" || package=unavailable
      if [[ "$package" == package:* ]]; then
        printf 'Android ready: serial=%s, sys.boot_completed=1, package manager available (%ss)\n' "$serial" "$((SECONDS - started))"
        exit 0
      fi
    fi
  fi
  if (( SECONDS - started >= next_report )); then
    printf 'Waiting for Android: serial=%s, state=%s, sys.boot_completed=%s, package=%s (%ss)\n' \
      "$serial" "$state" "$boot" "$package" "$((SECONDS - started))"
    next_report=$((SECONDS - started + 30))
  fi
  sleep 2
done

printf 'Android readiness timed out after %ss: state=%s, sys.boot_completed=%s, package=%s\n' \
  "$boot_timeout" "$state" "$boot" "$package" >&2
timeout 10 "$adb" version || true
timeout 10 "$adb" devices -l || true
timeout 10 "$adb" -s "$serial" shell getprop sys.boot_completed || true
if [[ -f "$adb_log" ]]; then tail -50 "$adb_log"; fi
exit 1
