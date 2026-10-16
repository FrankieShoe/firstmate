#!/usr/bin/env bash
# Drive the real bin/fm-watch.sh wedge timer with the REAL bin/fm-crew-state.sh
# reading a REAL no-mistakes run. Only the tmux pane is the test suite's fake
# shim (tmux is not installed on this host). Usage: <repo> <crew-worktree> <name> <rounds>
set -u
REPO=$1 CREW_WT=$2 NAME=$3 ROUNDS=${4:-3}
LIB="$REPO/tests/.live-drive-helpers.sh"
grep -v -E '^test_[a-z0-9_]+$' "$REPO/tests/fm-watch-triage.test.sh" > "$LIB"
. "$LIB"
rm -f "$LIB"
window="test:fm-wedge"; key=$(printf '%s' "$window" | tr ':/.' '___')
dir=$(wedge_threshold_fixture "live-$NAME" 'working: handed to validation' 0)
state="$dir/state"; fakebin="$dir/fakebin"; out="$dir/watch.out"; capture="$dir/pane.txt"
printf 'worktree=%s\n' "$CREW_WT" >> "$state/wedge.meta"
echo "== real crew-state verdict for this lane:"
env -u NO_MISTAKES_GATE FM_STATE_OVERRIDE="$state" "$REPO/bin/fm-crew-state.sh" wedge
n=1
while [ "$n" -le "$ROUNDS" ]; do
  : > "$out"
  env -u NO_MISTAKES_GATE PATH="$fakebin:$PATH" FM_FAKE_TMUX_WINDOW="$window" FM_FAKE_TMUX_CAPTURE="$capture" \
    FM_CONFIG_OVERRIDE="$dir/config" FM_FAKE_TMUX_CURRENT_COMMAND=claude \
    FM_WATCH_HANDLING_SUCCESSOR=1 FM_STATE_OVERRIDE="$state" \
    FM_CREW_STATE_BIN="$REPO/bin/fm-crew-state.sh" \
    FM_PAUSE_RESURFACE_SECS=999 FM_STALE_ESCALATE_SECS=1 FM_POLL=1 FM_SIGNAL_GRACE=1 \
    FM_CHECK_INTERVAL=999999 FM_HEARTBEAT=999999 "$REPO/bin/fm-watch.sh" >> "$out" &
  pid=$!
  i=0; while kill -0 "$pid" 2>/dev/null && [ $i -lt 40 ]; do sleep 1; i=$((i+1)); done
  if kill -0 "$pid" 2>/dev/null; then reap "$pid"; echo "-- round $n: watcher still polling after ${i}s, no wake emitted"
  else echo "-- round $n: watcher exited with wake: $(cat "$out")"; ack_stopped_cycle "$state" >/dev/null 2>&1; fi
  n=$((n+1))
done
echo "== triage log (absorb/escalate decisions):"
cat "$state/.watch-triage.log" 2>/dev/null | tail -12
echo "== .validating-since-$key: $(cat "$state/.validating-since-$key" 2>/dev/null || echo '<absent>')"
echo "== .wedge-escalations-$key: $(cat "$state/.wedge-escalations-$key" 2>/dev/null || echo '<absent>')"
echo "== stale wakes queued: $(wedge_stale_wakes "$state" "$window")"
