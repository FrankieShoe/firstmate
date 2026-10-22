#!/usr/bin/env bash
# Drives bin/fm-captain-hold.sh and bin/fm-teardown.sh in a disposable lab home
# with the real tasks-axi. tmux/treehouse/no-mistakes/gh are stubbed so teardown
# can never touch the live fleet. Usage: lab-cli-driver.sh <repo-root> <lab-dir>
set -u
R=$1 LAB=$2
mkdir -p "$LAB/fakebin"
for t in tmux treehouse no-mistakes gh gh-axi; do printf '#!/bin/sh\nexit 0\n' > "$LAB/fakebin/$t"; chmod +x "$LAB/fakebin/$t"; done
printf 'backend = "markdown"\n\n[markdown]\npath = "data/backlog.md"\ndone_keep = 10\n' > "$LAB/.tasks.toml"
printf '## In flight\n\n## Queued\n\n## Done\n' > "$LAB/data/backlog.md"
export FM_HOME=$LAB PATH="$LAB/fakebin:$PATH"
unset FM_STATE_OVERRIDE FM_DATA_OVERRIDE FM_CONFIG_OVERRIDE FM_ROOT_OVERRIDE FM_PROJECTS_OVERRIDE
CH="$R/bin/fm-captain-hold.sh" TD="$R/bin/fm-teardown.sh"
run() { echo "\$ ${*#"$R/"}"; "$@" 2>&1; echo "[exit $?]"; }
meta() {
  printf 'window=firstmate:fm-%s\nworktree=%s/projects/missing-%s\nproject=%s/projects/sample\nharness=codex\nkind=scout\nmode=scout\nspawn_gen=lab-%s\n' \
    "$1" "$LAB" "$1" "$LAB" "$1" > "$LAB/state/$1.meta"
  printf 'done: report complete\n' > "$LAB/state/$1.status"
  mkdir -p "$LAB/data/$1"; echo '# report' > "$LAB/data/$1/report.md"
}
cd "$LAB" || exit 1

echo "## Scenario A: answered hold archived by Done retention (default archive beside backlog)"
tasks-axi add lab-review "Lab scout" --kind scout --repo sample --start >/dev/null; meta lab-review
run "$CH" hold lab-call --title "Pick option" --reason "captain must pick" --repo sample --origin lab-review
run "$CH" complete lab-review lab-call
echo "Captain picked B" > "$LAB/dec.txt"
run "$CH" answer lab-call --decision-file "$LAB/dec.txt"
perl -pi -e 's/done_keep = 10/done_keep = 0/' .tasks.toml
tasks-axi add lab-trigger "trigger" --kind ship --repo sample >/dev/null; tasks-axi done lab-trigger >/dev/null
echo "--- data/done-archive.md rows for lab-call:"; grep -n -A3 "lab-call" data/done-archive.md
run tasks-axi show lab-call
run "$CH" verify lab-review
run "$CH" complete lab-review lab-call

echo; echo "## Scenario B: unanswered hold closed out of band, then archived -> must refuse"
tasks-axi add lab-review2 "Lab scout 2" --kind scout --repo sample --start >/dev/null; meta lab-review2
run "$CH" hold lab-call2 --title "Pick other" --reason "captain must pick other" --repo sample --origin lab-review2
run "$CH" complete lab-review2 lab-call2
tasks-axi done lab-call2 >/dev/null
echo "--- archived:"; grep -n "lab-call2" data/done-archive.md
run "$CH" verify lab-review2
run "$TD" lab-review2
echo "--- origin meta still present after refused teardown:"; ls state/lab-review2.meta

echo; echo "## Scenario C: attested call found nowhere -> must refuse"
printf 'decisions_reviewed=1\ndecision_keys=lab-never-held\n' >> state/lab-review2.meta
run "$CH" verify lab-review2

echo; echo "## Scenario A (teardown): scout whose answered hold is archived"
run "$TD" lab-review
echo "--- origin meta after teardown:"; ls state/lab-review.meta 2>&1
