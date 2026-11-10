#!/usr/bin/env bash
# Drives the real treehouse binary against a throwaway pool (TREEHOUSE_ROOT in a temp dir).
set -u
WT_REPO=$1
T=$(mktemp -d)
export TREEHOUSE_ROOT=$T/pool
git init -q --bare "$T/origin.git"
git init -q -b main "$T/proj"
cd "$T/proj" || exit 1
echo hi > README
git add README
git -c user.email=t@t -c user.name=t commit -qm init
git remote add origin "$T/origin.git"
git push -q origin main
PROJ_ABS=$T/proj
. "$WT_REPO/bin/fm-timeout-lib.sh"
sed -n '/^spawn_treehouse_dirty_slots_note() {/,/^}/p' "$WT_REPO/bin/fm-spawn.sh" > "$T/fns.sh"
sed -n '/^teardown_scrub_scratch_copy() {/,/^}/p' "$WT_REPO/bin/fm-teardown.sh" >> "$T/fns.sh"
. "$T/fns.sh"
seed() {
  mkdir -p "$1/.scout"
  git clone -q "$T/origin.git" "$1/.scout/sibling-repo"
  echo 'echo measure' > "$1/.scout/measure.sh"
  echo notes > "$1/.scout/notes.md"
}
echo "== 1. Incident repro: a returned (unleased) pool slot still holding a scout's .scout/ folder"
S1=$(treehouse get --lease --no-fetch 2>/dev/null); echo "leased: $S1"
treehouse return "$S1" </dev/null 2>&1 | tail -1
seed "$S1"
git -C "$S1" status --porcelain
echo "-- treehouse status --json:"; treehouse status --json 2>/dev/null
echo "-- spawn deadline note from real treehouse status:"; echo "[$(spawn_treehouse_dirty_slots_note)]"
echo "== 2. Scout teardown path: scrub (fm-teardown's teardown_scrub_scratch_copy) then return"
S2=$(treehouse get --lease --no-fetch 2>/dev/null); echo "leased: $S2"; seed "$S2"
teardown_scrub_scratch_copy "$S2"; echo "scrub rc=$?; .scout exists? $([ -e "$S2/.scout" ] && echo yes || echo no)"
echo "porcelain after scrub: [$(git -C "$S2" status --porcelain --untracked-files=all)]"
treehouse return "$S2" </dev/null 2>&1 | tail -1
echo "-- treehouse status --json:"; treehouse status --json 2>/dev/null
echo "== 3. Scrub the incident slot; note goes silent and get hands out a slot"
teardown_scrub_scratch_copy "$S1"; treehouse status --json 2>/dev/null
echo "note: [$(spawn_treehouse_dirty_slots_note)]"
S3=$(treehouse get --lease --no-fetch 2>/dev/null); echo "next get leased: $S3"
treehouse return --force "$S3" </dev/null >/dev/null 2>&1
rm -rf "$T"
