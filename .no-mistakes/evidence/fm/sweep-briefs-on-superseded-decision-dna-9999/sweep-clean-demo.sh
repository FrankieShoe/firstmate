#!/usr/bin/env bash
# Clean-path drive: sweep for the superseded STATEMENT phrase, correct it, resweep.
set -u
WORKTREE=/Users/hamishgray/.no-mistakes/worktrees/4f4eb3e494f1/01M3JEVWFRN8DK82XPMJR46GPV
LAB=$(mktemp -d "${TMPDIR:-/tmp}/fm-sweep-clean.XXXXXX")
mkdir -p "$LAB/data" "$LAB/state"
printf '## In flight\n\n## Queued\n\n## Done\n' > "$LAB/data/backlog.md"
export FM_HOME="$LAB"
unset FM_ROOT_OVERRIDE FM_DATA_OVERRIDE FM_STATE_OVERRIDE FM_CONFIG_OVERRIDE FM_PROJECTS_OVERRIDE TASKS_AXI_FILE TASKS_AXI_BACKEND
TASKS="$WORKTREE/bin/fm-tasks-axi.sh"
SWEEP="$WORKTREE/bin/fm-supersede-sweep.sh"

"$TASKS" add export-fix "Export work" >/dev/null
"$TASKS" start export-fix >/dev/null
printf 'kind=ship\n' > "$LAB/state/export-fix.meta"
mkdir -p "$LAB/data/export-fix"
printf '# Task\nKeep the export disabled until further notice.\n' > "$LAB/data/export-fix/brief.md"
"$TASKS" add followup "Follow-up work" >/dev/null

echo "=== Superseded statement phrase: 'keep the export disabled' ==="
echo "\$ fm-supersede-sweep.sh 'keep the export disabled'"
"$SWEEP" "keep the export disabled"; echo "(exit $?)"
echo
echo "=== Operator corrects the live brief, then resweeps ==="
printf '# Task\nRe-enable the export immediately (fix now).\n' > "$LAB/data/export-fix/brief.md"
echo "\$ fm-supersede-sweep.sh 'keep the export disabled'"
"$SWEEP" "keep the export disabled"; echo "(exit $?)"

rm -rf "$LAB"
