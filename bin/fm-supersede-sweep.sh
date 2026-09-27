#!/usr/bin/env bash
# fm-supersede-sweep.sh - find every open brief and task note that still states a superseded fact.
#
# Usage: fm-supersede-sweep.sh <superseded statement>...
#        fm-supersede-sweep.sh --help
#
# Run it the moment a decision is changed or reversed while work is under way,
# before the next dispatch. A brief is accurate when written and can be stale
# when dispatched, and a queued task title or note is read as fact by a fresh
# session, so the old statement has to be found wherever it was copied.
#
# Each argument is a short phrase from the superseded statement, matched as a
# case-insensitive fixed string; a line matching any phrase is a hit. It
# searches:
#   - the brief (`data/<id>/brief.md`) of every task that is live in this
#     home (`state/<id>.meta`) or open in its backlog, including a brief
#     already written for work not yet dispatched;
#   - the title, note, and hold reason of every backlog item that is not done,
#     read through bin/fm-tasks-axi.sh so any configured backend is covered;
#     the id, state, kind, and repo fields that lead each row are not searched.
# It reads only; correcting a brief, re-steering a live worker, or updating a
# note stays a deliberate act by the caller, and the printed help names how.
#
# Output lines:
#   brief: <id> <path>:<line>: <text>
#   note: <id> <state>: <task row>
# followed by `hits: <n>` or `clean: ...`.
#
# Exit status: 0 when nothing matches, 1 when any hit needs correcting, 2 on a
# usage error or when the backlog or an open brief cannot be read, so an
# incomplete sweep is never reported clean.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FM_ROOT="${FM_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
FM_HOME="${FM_HOME:-${FM_ROOT_OVERRIDE:-$FM_ROOT}}"
STATE="${FM_STATE_OVERRIDE:-$FM_HOME/state}"
DATA="${FM_DATA_OVERRIDE:-$FM_HOME/data}"

usage() {
  awk '
    NR == 1 { next }
    /^#/ { sub(/^# ?/, ""); print; next }
    { exit }
  ' "$0"
}

fail() {
  printf 'fm-supersede-sweep: %s\n' "$*" >&2
  exit 2
}

case "${1:-}" in
  -h|--help) usage; exit 0 ;;
  '') usage >&2; exit 2 ;;
esac

patterns=()
for phrase in "$@"; do
  [ -n "$phrase" ] || fail "an empty phrase would match every line"
  patterns+=(-e "$phrase")
done

rows=$("$SCRIPT_DIR/fm-tasks-axi.sh" list --fields body,hold_reason --limit 100000) \
  || fail "cannot read this home's backlog; nothing was swept"
rows=$(printf '%s\n' "$rows" | awk '
  /^tasks\[/ { in_rows = 1; next }
  /^[^ ]/ { in_rows = 0 }
  in_rows && /^  [A-Za-z0-9._-]+,/ { print substr($0, 3) }
')

open_ids=$(printf '%s\n' "$rows" | awk -F, '$1 != "" && $2 != "done" { print $1 }')
live_ids=''
for meta in "$STATE"/*.meta; do
  [ -f "$meta" ] || continue
  meta=${meta##*/}
  live_ids="$live_ids${meta%.meta}"$'\n'
done

hits=0
while IFS= read -r id; do
  [ -n "$id" ] || continue
  brief="$DATA/$id/brief.md"
  [ -f "$brief" ] || continue
  grep_rc=0
  matches=$(grep -n -i -F "${patterns[@]}" -- "$brief") || grep_rc=$?
  [ "$grep_rc" -le 1 ] || fail "cannot read $brief; the sweep is incomplete"
  [ -n "$matches" ] || continue
  while IFS= read -r line; do
    printf 'brief: %s %s:%s\n' "$id" "$brief" "$line"
    hits=$((hits + 1))
  done <<< "$matches"
done < <(printf '%s%s\n' "$live_ids" "$open_ids" | sort -u)

while IFS= read -r row; do
  [ -n "$row" ] || continue
  state=${row#*,}
  state=${state%%,*}
  [ "$state" != "done" ] || continue
  searched=${row#*,*,*,*,}
  printf '%s\n' "$searched" | grep -q -i -F "${patterns[@]}" || continue
  printf 'note: %s %s: %s\n' "${row%%,*}" "$state" "$row"
  hits=$((hits + 1))
done <<< "$rows"

if [ "$hits" -eq 0 ]; then
  echo "clean: no open brief or task note states the superseded statement"
  exit 0
fi
printf 'hits: %s\n' "$hits"
echo "help: correct each brief before it is dispatched; relay the correction to a live worker with fm-send.sh; update each note with fm-tasks-axi.sh update <id> --title or --body-file"
exit 1
