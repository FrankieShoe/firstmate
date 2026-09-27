#!/usr/bin/env bash
# End-to-end drive of fm-supersede-sweep.sh reproducing the retro failure shape.
set -u
WORKTREE=/Users/hamishgray/.no-mistakes/worktrees/4f4eb3e494f1/01M3JEVWFRN8DK82XPMJR46GPV
LAB=$(mktemp -d "${TMPDIR:-/tmp}/fm-sweep-demo.XXXXXX")
mkdir -p "$LAB/data" "$LAB/state"
printf '## In flight\n\n## Queued\n\n## Done\n' > "$LAB/data/backlog.md"
export FM_HOME="$LAB"
unset FM_ROOT_OVERRIDE FM_DATA_OVERRIDE FM_STATE_OVERRIDE FM_CONFIG_OVERRIDE FM_PROJECTS_OVERRIDE TASKS_AXI_FILE TASKS_AXI_BACKEND

TASKS="$WORKTREE/bin/fm-tasks-axi.sh"
SWEEP="$WORKTREE/bin/fm-supersede-sweep.sh"

echo "=== Scenario: a 'fix now' reversal makes an in-flight brief stale ==="
echo
echo "--- LIVE worker briefed from the now-superseded statement ---"
"$TASKS" add export-fix "Disable the legacy export" >/dev/null
"$TASKS" start export-fix >/dev/null
printf 'kind=ship\n' > "$LAB/state/export-fix.meta"
mkdir -p "$LAB/data/export-fix"
printf '# Task\nKeep the Legacy Export disabled until further notice.\n' > "$LAB/data/export-fix/brief.md"

echo "--- QUEUED brief not yet dispatched, written from the same stale fact ---"
"$TASKS" add export-followup "Document the legacy export" >/dev/null
mkdir -p "$LAB/data/export-followup"
printf 'Follow-up\nThe legacy export stays off.\n' > "$LAB/data/export-followup/brief.md"

echo "--- Queued task TITLE read as fact by a fresh session ---"
"$TASKS" add retire-legacy "Retire the legacy export" >/dev/null

echo "--- Finished work that must NOT be re-swept ---"
"$TASKS" add old-job "legacy export migration" >/dev/null
"$TASKS" done old-job >/dev/null
echo

echo "=== Decision reversed: 'fix now, re-enable the legacy export'. Sweep before next dispatch ==="
echo "\$ fm-supersede-sweep.sh 'legacy export'"
"$SWEEP" "legacy export"; RC=$?
echo "(exit $RC)"
echo

echo "=== After correcting each hit, the sweep reports clean ==="
printf '# Task\nRe-enable the legacy export immediately (fix now).\n' > "$LAB/data/export-fix/brief.md"
printf 'Follow-up\nThe export is being re-enabled.\n' > "$LAB/data/export-followup/brief.md"
"$TASKS" update retire-legacy --title "Re-enable the exporter" >/dev/null
echo "\$ fm-supersede-sweep.sh 'legacy export'"
"$SWEEP" "legacy export"; RC=$?
echo "(exit $RC)"

rm -rf "$LAB"
