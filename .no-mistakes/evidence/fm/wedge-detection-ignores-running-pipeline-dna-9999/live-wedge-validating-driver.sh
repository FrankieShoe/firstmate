#!/usr/bin/env bash
# Live driver: real Herdr lab session, real fm-watch.sh, real fm-crew-state.sh
# against the live no-mistakes run on this branch. Usage: <repo-root> <lab-home> <seconds>
set -u
ROOT=$1 LAB=$2 DURATION=${3:-75} RESURFACE=${4:-999} WITH_NORUN=${5:-1}
cd "$ROOT"
. "$ROOT/tests/herdr-test-safety.sh"
unset FM_GATE_REFUSE_BYPASS
herdr_forget_inherited_pane
SESSION=$(bin/fm-herdr-lab.sh name wedgeval) || exit 1
export HERDR_SESSION="$SESSION" FM_HOME="$LAB"
echo "lab session: $SESSION  lab home: $LAB"
trap 'fm_herdr_lab_teardown "$SESSION"; echo "teardown rc=$?"' EXIT
fm_herdr_lab_prepare "$SESSION" || { echo "prepare failed"; exit 1; }
. "$ROOT/bin/fm-backend.sh"
fm_backend_source herdr || exit 1
RAW=$(fm_backend_herdr_container_ensure /tmp) || { echo "container_ensure failed"; exit 1; }
CONTAINER=${RAW%%$'\t'*}; SEEDED=${RAW#*$'\t'}
mk() {  # <id> <worktree> [seeded]
  local id=$1 wt=$2 ids tab pane
  ids=$(fm_backend_herdr_create_task "$CONTAINER" "fm-$id" /tmp ${3:-}) || { echo "create_task $id failed"; exit 1; }
  read -r tab pane <<EOF
$ids
EOF
  printf 'backend=herdr\nwindow=%s:%s\nherdr_session=%s\nherdr_workspace_id=%s\nherdr_tab_id=%s\nherdr_pane_id=%s\nkind=ship\nharness=grok\nworktree=%s\n' \
    "$SESSION" "$pane" "$SESSION" "${CONTAINER#*:}" "$tab" "$pane" "$wt" > "$LAB/state/$id.meta"
  printf 'working: handed to validation\n' > "$LAB/state/$id.status"
  herdr pane run "$pane" "clear; printf 'waiting at the gate\n'; exec cat" --session "$SESSION" >/dev/null
  sleep 2
  herdr pane report-agent "$pane" --source fm-live-test --agent grok --state idle --session "$SESSION" >/dev/null 2>&1
  echo "task $id -> $SESSION:$pane (worktree $wt)"
}
mk wedge /Users/hamishgray/.treehouse/firstmate-7bab20/1/firstmate "$SEEDED"
[ "$WITH_NORUN" = 1 ] && mk norun "$LAB/norun"
echo "--- real fm-crew-state.sh verdicts"
for id in wedge $( [ "$WITH_NORUN" = 1 ] && echo norun ); do printf '%s: ' "$id"; bin/fm-crew-state.sh "$id"; done
echo "--- backend agent state"
for id in wedge $( [ "$WITH_NORUN" = 1 ] && echo norun ); do w=$(grep '^window=' "$LAB/state/$id.meta" | cut -d= -f2-); printf '%s: %s\n' "$id" "$(fm_backend_agent_state herdr "$w")"; done
echo "--- driving real fm-watch.sh for ${DURATION}s (FM_STALE_ESCALATE_SECS=6)"
end=$(( $(date +%s) + DURATION )); round=0
while [ "$(date +%s)" -lt "$end" ]; do
  round=$((round+1))
  left=$(( end - $(date +%s) ))
  FM_STALE_ESCALATE_SECS=6 FM_POLL=1 FM_SIGNAL_GRACE=1 FM_CHECK_INTERVAL=999999 FM_HEARTBEAT=999999 \
    FM_PAUSE_RESURFACE_SECS=$RESURFACE FM_SECONDMATE_LIVENESS_SECS=99999999 bin/fm-watch.sh > "$LAB/watch.$round.out" 2>"$LAB/watch.$round.err" &
  pid=$!
  t=0; while kill -0 $pid 2>/dev/null && [ $t -lt $left ]; do sleep 1; t=$((t+1)); done
  if kill -0 $pid 2>/dev/null; then kill $pid; wait $pid 2>/dev/null; echo "[round $round] watcher still running at deadline (no wake) - stopped"; else
    wait $pid; echo "[round $round] watcher exited with wake: $(cat "$LAB/watch.$round.out")"
    err=$(bin/fm-wake-drain.sh 2>&1 >/dev/null)
    seq=$(printf '%s' "$err" | sed -n 's/^WAKE_ACK_REQUIRED:.*--ack-through \([0-9]*\) --recovery-generation \([A-Za-z0-9._-]*\)$/\1 \2/p')
    [ -n "$seq" ] && bin/fm-wake-drain.sh --ack-through "${seq% *}" --recovery-generation "${seq#* }" >/dev/null 2>&1
  fi
done
echo "--- wake queue (stale rows)"
cat "$LAB/state/.wake-queue" 2>/dev/null | awk -F'\t' '$3=="stale"' 
echo "--- triage log"
cat "$LAB/state/"*triage* 2>/dev/null | tail -40
echo "--- markers"
ls -la "$LAB/state" | grep -E 'validating|wedge-escalations|stale-since' 
for f in "$LAB/state"/.validating-since-* "$LAB/state"/.wedge-escalations-*; do [ -e "$f" ] && echo "$(basename "$f"): $(cat "$f")"; done
