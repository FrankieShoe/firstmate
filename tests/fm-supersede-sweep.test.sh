#!/usr/bin/env bash
# Behavior tests for bin/fm-supersede-sweep.sh: after a decision changes, it
# must name every open brief and not-done backlog title, note, or hold reason
# that still states the superseded fact, skip finished work, report a clean
# sweep only when nothing matches, and never report clean when the backlog or
# an open brief cannot be read.
set -u

# shellcheck source=tests/lib.sh disable=SC1091
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

SWEEP="$ROOT/bin/fm-supersede-sweep.sh"
TASKS="$ROOT/bin/fm-tasks-axi.sh"
TMP_ROOT=$(fm_test_tmproot fm-supersede-sweep)

unset TASKS_AXI_FILE TASKS_AXI_BACKEND FM_ROOT_OVERRIDE \
  FM_DATA_OVERRIDE FM_STATE_OVERRIDE FM_CONFIG_OVERRIDE FM_PROJECTS_OVERRIDE

make_home() {  # <name>; prints the home directory
  local home="$TMP_ROOT/$1"
  mkdir -p "$home/data" "$home/state"
  printf '## In flight\n\n## Queued\n\n## Done\n' > "$home/data/backlog.md"
  printf '%s\n' "$home"
}

tasks() {  # <home> <tasks-axi args...>
  local home=$1
  shift
  FM_HOME="$home" "$TASKS" "$@" >/dev/null || fail "tasks-axi $* failed"
}

sweep() {  # <home> <phrases...>; sets OUT and RC
  local home=$1
  shift
  RC=0
  OUT=$(FM_HOME="$home" "$SWEEP" "$@" 2>&1) || RC=$?
}

test_names_every_open_copy_of_the_statement() {
  local home
  home=$(make_home hits)
  tasks "$home" add live-1 "live work"
  tasks "$home" start live-1
  fm_write_meta "$home/state/live-1.meta" "kind=ship"
  mkdir -p "$home/data/live-1"
  printf '# Task\nKeep the Legacy Export off for now.\n' > "$home/data/live-1/brief.md"

  tasks "$home" add queued-1 "not yet dispatched"
  mkdir -p "$home/data/queued-1"
  printf 'Intro\nLeave the legacy export disabled.\n' > "$home/data/queued-1/brief.md"

  printf 'Wait for the legacy export decision.\n' > "$home/note.txt"
  tasks "$home" add note-1 "unrelated title"
  tasks "$home" update note-1 --body-file "$home/note.txt"
  tasks "$home" add title-1 "Retire the legacy export"
  tasks "$home" add held-1 "held work"
  tasks "$home" hold held-1 --reason "legacy export pending" --kind captain

  tasks "$home" add done-1 "legacy export shipped"
  mkdir -p "$home/data/done-1" "$home/data/orphan"
  printf 'legacy export\n' > "$home/data/done-1/brief.md"
  tasks "$home" "done" done-1
  printf 'legacy export\n' > "$home/data/orphan/brief.md"

  sweep "$home" "legacy export"
  assert_equals 1 "$RC" "a sweep with hits must exit 1"
  assert_contains "$OUT" "brief: live-1 $home/data/live-1/brief.md:2:Keep the Legacy Export off" "live brief hit missing"
  assert_contains "$OUT" "brief: queued-1 $home/data/queued-1/brief.md:2:" "queued brief hit missing"
  assert_contains "$OUT" "note: note-1 queued:" "queued note hit missing"
  assert_contains "$OUT" "note: title-1 queued:" "queued title hit missing"
  assert_contains "$OUT" "note: held-1 queued:" "hold reason hit missing"
  assert_not_contains "$OUT" "done-1" "finished work must not be swept"
  assert_not_contains "$OUT" "orphan" "a brief with no live or open task must not be swept"
  assert_contains "$OUT" "hits: 5" "hit count wrong"
  pass "fm-supersede-sweep.sh names every open brief and task note that states the superseded fact"
}

test_any_phrase_matches_and_clean_is_reported() {
  local home
  home=$(make_home clean)
  tasks "$home" add q-1 "Ship the nightly job"
  sweep "$home" "weekly job"
  assert_equals 0 "$RC" "a clean sweep must exit 0"
  assert_contains "$OUT" "clean:" "a clean sweep must say so"
  sweep "$home" "weekly job" "NIGHTLY"
  assert_equals 1 "$RC" "any one phrase must be enough for a hit"
  assert_contains "$OUT" "note: q-1 queued:" "second phrase did not match"
  pass "fm-supersede-sweep.sh matches any phrase and reports a clean sweep"
}

test_row_metadata_is_not_searched() {
  local home
  home=$(make_home metadata)
  tasks "$home" add legacy-export-cleanup "Tidy the exporter" --repo legacy-export
  sweep "$home" "legacy-export"
  assert_equals 0 "$RC" "a phrase only in the id or repo must not be a hit"
  assert_contains "$OUT" "clean:" "id and repo fields were searched"
  pass "fm-supersede-sweep.sh searches only the title, note, and hold reason of a backlog row"
}

test_refuses_rather_than_reporting_clean() {
  local home
  home=$(make_home unreadable)
  sweep "$home"
  assert_equals 2 "$RC" "no phrase is a usage error"
  sweep "$home" ""
  assert_equals 2 "$RC" "an empty phrase must be refused"
  sweep "$home" "x" ""
  assert_equals 2 "$RC" "an empty later phrase must be refused"
  tasks "$home" add q-1 "queued work"
  mkdir -p "$home/data/q-1"
  printf 'nothing stale\n' > "$home/data/q-1/brief.md"
  chmod 000 "$home/data/q-1/brief.md"
  if [ ! -r "$home/data/q-1/brief.md" ]; then
    sweep "$home" "anything"
    assert_equals 2 "$RC" "an unreadable open brief must not be reported clean"
    assert_not_contains "$OUT" "clean:" "an unreadable open brief was reported clean"
  else
    echo "skip: running as a user who can read mode-000 files; unreadable-brief case not run"
  fi
  chmod 600 "$home/data/q-1/brief.md"
  ln -sf "$TMP_ROOT/elsewhere.md" "$home/data/backlog.md"
  sweep "$home" "anything"
  assert_equals 2 "$RC" "an unreadable backlog must not be reported clean"
  assert_not_contains "$OUT" "clean:" "an unreadable backlog was reported clean"
  pass "fm-supersede-sweep.sh refuses rather than reporting a sweep it could not finish"
}

if command -v tasks-axi >/dev/null 2>&1; then
  test_names_every_open_copy_of_the_statement
  test_any_phrase_matches_and_clean_is_reported
  test_row_metadata_is_not_searched
  test_refuses_rather_than_reporting_clean
else
  echo "skip: tasks-axi not found; supersede-sweep cases not run"
fi
