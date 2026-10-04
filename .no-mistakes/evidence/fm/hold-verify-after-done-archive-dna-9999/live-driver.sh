#!/usr/bin/env bash
# Live driver: real fm-captain-hold.sh / fm-teardown.sh / tasks-axi in a marked lab FM_HOME.
# Usage: live-driver.sh <firstmate-root> [user-config]
set -u
ROOT=$1; MODE=${2:-default}
LAB=$(mktemp -d "${TMPDIR:-/tmp}/fm-lab.XXXXXX"); rmdir "$LAB"
"$ROOT/bin/fm-lab-home.sh" create "$LAB" >/dev/null 2>&1 || bash "$PWD/bin/fm-lab-home.sh" create "$LAB" >/dev/null
trap 'rm -rf "$LAB"' EXIT
mkdir -p "$LAB/fakebin"
for b in tmux treehouse no-mistakes gh gh-axi; do printf '#!/bin/sh\nexit 0\n' > "$LAB/fakebin/$b"; chmod +x "$LAB/fakebin/$b"; done
AXH=$HOME
if [ "$MODE" = user-config ]; then
  AXH="$LAB/axi-home"; mkdir -p "$AXH/.tasks-axi"
  printf 'backend = "markdown"\n\n[markdown]\npath = "data/backlog.md"\ndone_keep = 10\n' > "$LAB/.tasks.toml"
  printf '[markdown]\narchive = "data/relocated-done-archive.md"\n' > "$AXH/.tasks-axi/config.toml"
  ARCHIVE="$LAB/data/relocated-done-archive.md"
else
  cp "$ROOT/.tasks.toml" "$LAB/.tasks.toml"; ARCHIVE="$LAB/data/done-archive.md"
fi
printf '## In flight\n\n## Queued\n\n## Done\n' > "$LAB/data/backlog.md"
E() { env -u NO_MISTAKES_GATE -u FM_GATE_REFUSE_BYPASS -u FM_ROOT_OVERRIDE -u FM_STATE_OVERRIDE -u FM_DATA_OVERRIDE -u FM_CONFIG_OVERRIDE -u FM_PROJECTS_OVERRIDE \
  HOME="$AXH" PATH="$LAB/fakebin:$PATH" FM_HOME="$LAB" "$@"; }
T() { (cd "$LAB" && E tasks-axi "$@"); }
C() { echo "\$ fm-captain-hold.sh $*"; E "$ROOT/bin/fm-captain-hold.sh" "$@"; echo "[exit $?]"; }
meta() { printf 'window=firstmate:fm-%s\nworktree=%s/projects/missing-%s\nproject=%s/projects/sample\nharness=codex\nkind=scout\nmode=scout\nspawn_gen=lab-%s\n' "$1" "$LAB" "$1" "$LAB" "$1" > "$LAB/state/$1.meta"; }
echo "== root=$ROOT mode=$MODE archive=${ARCHIVE#$LAB/}"
ID=pig-reset-service-and-graph-dna-9774; CALL=pig-reset-open-calls-dna-9774
mkdir -p "$LAB/data/$ID"; T add "$ID" "Reset service and graph" --kind scout --repo sample --start >/dev/null
meta "$ID"; printf 'done: report complete\n' > "$LAB/state/$ID.status"; printf '# report\n' > "$LAB/data/$ID/report.md"
C hold "$CALL" --title "Open calls" --reason "captain must pick" --repo sample --origin "$ID" >/dev/null
C complete "$ID" "$CALL" | tail -1
printf 'A - start all 3\n' > "$LAB/decision.txt"
C answer "$CALL" --decision-file "$LAB/decision.txt" | tail -1
C verify "$ID" | tail -2
echo "-- Done retention: done_keep=0, close a trigger row"
perl -0pi -e 's/done_keep = 10/done_keep = 0/' "$LAB/.tasks.toml"
T add trigger-row "Trigger" --kind ship --repo sample >/dev/null; T done trigger-row >/dev/null
echo "archive has call: $(grep -c "$CALL" "$ARCHIVE" 2>/dev/null)"; T show "$CALL" >/dev/null 2>&1 && echo "live backlog still shows call" || echo "live backlog no longer shows call"
C verify "$ID" 2>&1 | tail -3
C complete "$ID" "$CALL" 2>&1 | tail -3
echo "\$ fm-teardown.sh $ID"; E "$ROOT/bin/fm-teardown.sh" "$ID" 2>&1 | tail -3; echo "[exit ${PIPESTATUS[0]}]"
[ -f "$LAB/state/$ID.meta" ] && echo "meta still present" || echo "meta removed (teardown proceeded)"
if [ "$MODE" = default ]; then
  echo "-- Adversarial: archived close with no captain answer"
  ID2=sample-unanswered-review; CALL2=sample-unanswered-call
  mkdir -p "$LAB/data/$ID2"; T add "$ID2" "Unanswered" --kind scout --repo sample --start >/dev/null; meta "$ID2"
  printf 'done: report complete\n' > "$LAB/state/$ID2.status"; printf "# r\n" > "$LAB/data/$ID2/report.md"
  C hold "$CALL2" --title "Unanswered" --reason "pending" --repo sample --origin "$ID2" >/dev/null
  C complete "$ID2" "$CALL2" | tail -1
  T done "$CALL2" >/dev/null; echo "archive has unanswered call: $(grep -c "$CALL2" "$ARCHIVE")"
  C verify "$ID2" 2>&1 | tail -3
  echo "\$ fm-teardown.sh $ID2"; E "$ROOT/bin/fm-teardown.sh" "$ID2" 2>&1 | tail -2; echo "[exit ${PIPESTATUS[0]}]"
  [ -f "$LAB/state/$ID2.meta" ] && echo "meta still present (refused)"
  echo "-- Adversarial: attested call found nowhere"
  printf 'decisions_reviewed=1\ndecision_keys=sample-never-held-call\n' >> "$LAB/state/$ID2.meta"
  C verify "$ID2" 2>&1 | tail -3
  echo "-- Adversarial: wedged tasks-axi on archive read (bound 2s)"
  ID3=sample-wedge-review; CALL3=sample-wedge-call
  mkdir -p "$LAB/data/$ID3"; T add "$ID3" "Wedge" --kind scout --repo sample --start >/dev/null; meta "$ID3"
  printf 'done: report complete\n' > "$LAB/state/$ID3.status"; printf "# r\n" > "$LAB/data/$ID3/report.md"
  C hold "$CALL3" --title "Wedge" --reason "pending" --repo sample --origin "$ID3" >/dev/null
  C complete "$ID3" "$CALL3" | tail -1
  perl -0pi -e "s/done_keep = 0/done_keep = 10/" "$LAB/.tasks.toml"; C answer "$CALL3" --decision-file "$LAB/decision.txt" | tail -1
  perl -0pi -e "s/done_keep = 10/done_keep = 0/" "$LAB/.tasks.toml"; T add trigger2 "Trigger2" --kind ship --repo sample >/dev/null; T done trigger2 >/dev/null
  REAL=$(command -v tasks-axi)
  printf '#!/bin/bash\ncase "$PWD" in *fm-captain-hold-archive*) sleep 60;; esac\nexec %s "$@"\n' "$REAL" > "$LAB/fakebin/tasks-axi"; chmod +x "$LAB/fakebin/tasks-axi"
  start=$(date +%s)
  echo "\$ FM_BACKLOG_ROW_TIMEOUT_SECS=2 fm-captain-hold.sh verify $ID3"
  E env FM_BACKLOG_ROW_TIMEOUT_SECS=2 "$ROOT/bin/fm-captain-hold.sh" verify "$ID3" 2>&1 | tail -3; echo "[exit ${PIPESTATUS[0]}] after $(( $(date +%s) - start ))s"
  rm -f "$LAB/fakebin/tasks-axi"
fi
