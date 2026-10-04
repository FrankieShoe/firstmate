#!/usr/bin/env bash
set -u
ROOT=$1 H=$2
mkdir -p "$H/fakebin"; cp "$ROOT/.tasks.toml" "$H/"; printf '## In flight\n\n## Queued\n\n## Done\n' > "$H/data/backlog.md"
for b in tmux treehouse no-mistakes gh gh-axi; do printf '#!/bin/sh\nexit 0\n' > "$H/fakebin/$b"; chmod +x "$H/fakebin/$b"; done
unset FM_ROOT_OVERRIDE FM_STATE_OVERRIDE FM_DATA_OVERRIDE FM_CONFIG_OVERRIDE FM_PROJECTS_OVERRIDE
export PATH="$H/fakebin:$PATH" FM_HOME=$H
CH=$ROOT/bin/fm-captain-hold.sh; ID=pig-reset-service-and-graph-dna-9774; CALL=pig-reset-open-calls-dna-9774
run(){ echo "\$ ${*#$ROOT/}"; "$@"; echo "[exit $?]"; }
meta(){ printf 'window=firstmate:fm-%s\nworktree=%s/projects/missing-%s\nproject=%s/projects/sample\nharness=codex\nkind=scout\nmode=scout\nspawn_gen=lab-%s\n' "$1" "$H" "$1" "$H" "$1" > "$H/state/$1.meta"; }
echo "## Marked lab home (fm-lab-home.sh create), real tasks-axi $(tasks-axi --version), tmux faked"
(cd "$H" && tasks-axi add $ID "Reset service and graph" --kind scout --repo sample --start >/dev/null)
mkdir -p "$H/data/$ID"; printf "# Report\n\nOne captain choice remains.\n" > "$H/data/$ID/report.md"; printf 'done: report complete\n' > "$H/state/$ID.status"; meta $ID
run "$CH" hold $CALL --title "Reset open calls?" --reason "captain choice pending" --repo sample --origin $ID
run "$CH" complete $ID $CALL
echo "A - start all 3" > "$H/decision.txt"
run "$CH" answer $CALL --decision-file "$H/decision.txt"
echo "## verify before Done retention"; run "$CH" verify $ID
echo "## Trigger Done retention (done_keep=0)"
perl -0pi -e 's/done_keep = 10/done_keep = 0/' "$H/.tasks.toml"
(cd "$H" && tasks-axi add trigger-x "Trigger" --kind ship --repo sample >/dev/null && tasks-axi done trigger-x >/dev/null)
echo "\$ grep $CALL data/done-archive.md"; grep -n "$CALL" "$H/data/done-archive.md"
echo "\$ tasks-axi show $CALL"; (cd "$H" && tasks-axi show $CALL 2>&1 | head -1)
echo "## verify/complete after the answered hold was archived"
run "$CH" verify $ID
run "$CH" complete $ID $CALL
echo "## ADVERSARIAL A: wedged tasks-axi on the archived read, FM_BACKLOG_ROW_TIMEOUT_SECS=2"
mkdir -p "$H/slowbin"
printf '#!/bin/sh\nif [ "$1" = show ] && ! grep -q "^path" .tasks.toml 2>/dev/null; then sleep 30; fi\nexec %s "$@"\n' "$(command -v tasks-axi)" > "$H/slowbin/tasks-axi"; chmod +x "$H/slowbin/tasks-axi"
SECONDS=0; echo "\$ bin/fm-captain-hold.sh verify $ID   (slow archive read)"
PATH="$H/slowbin:$PATH" FM_BACKLOG_ROW_TIMEOUT_SECS=2 "$CH" verify $ID; echo "[exit $? after ${SECONDS}s]"
echo "## Real teardown of the scout whose answered hold is archived"
run "$ROOT/bin/fm-teardown.sh" $ID
[ -e "$H/state/$ID.meta" ] && echo "meta still present" || echo "scout meta removed by teardown"
echo "## ADVERSARIAL B: archived close with NO captain answer must still refuse"
ID2=lab-unanswered-scout; CALL2=lab-unanswered-call
(cd "$H" && tasks-axi add $ID2 "Unanswered" --kind scout --repo sample --start >/dev/null)
mkdir -p "$H/data/$ID2"; printf "# Report\n\nOne captain choice remains.\n" > "$H/data/$ID2/report.md"; printf 'done: report complete\n' > "$H/state/$ID2.status"; meta $ID2
run "$CH" hold $CALL2 --title "Unanswered?" --reason "pending" --repo sample --origin $ID2
run "$CH" complete $ID2 $CALL2
(cd "$H" && tasks-axi done $CALL2 >/dev/null); echo "\$ grep -c $CALL2 data/done-archive.md"; grep -c "$CALL2" "$H/data/done-archive.md"
run "$CH" verify $ID2
run "$ROOT/bin/fm-teardown.sh" $ID2
[ -e "$H/state/$ID2.meta" ] && echo "meta still present (teardown refused)" || echo "meta removed"
echo "## ADVERSARIAL C: attested call that exists nowhere must still refuse"
printf 'decision_keys=lab-never-held-call\n' >> "$H/state/$ID2.meta"
run "$CH" verify $ID2
