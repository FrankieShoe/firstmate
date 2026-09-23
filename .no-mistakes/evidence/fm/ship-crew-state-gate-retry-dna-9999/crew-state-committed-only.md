# Live evidence — no-mistakes committed-only ship reads `working`

Change: treat a no-mistakes ship that has only committed (no shipment claim, no
`pr=` recorded) as `working` (mid-pipeline), never terminal `done` or `blocked`.
Empty mode is treated the same as `no-mistakes` (unregistered-project default).

## Scenario A — empty-mode committed-only ship (real `bin/fm-crew-state.sh`)

Setup: `kind=ship`, meta has **no `mode=`** and **no `pr=`**, status log's last
event is `done: implementation complete`, no matching run, idle pane.

```
=== status log (last event, stale) ===
done: implementation complete
=== meta (no pr=, no mode=) ===
window=fm:fm-preval
worktree=.../preval-empty-evidence/wt
project=.../preval-empty-evidence/wt
kind=ship
harness=claude
=== real bin/fm-crew-state.sh verdict ===
state: working · source: status-log · implementation complete · committed only: no PR recorded, no-mistakes validation owed
```

Result: reads `state: working`, source `status-log`, with a detail that names the
committed-only / PR-owed state. Not `done`, not `blocked`.

## Scenario B — boundary / exact-match exclusion (real `fm_dod_ship_committed_only`)

Driven directly against the shipped predicate with real meta files:

```
empty mode, no pr, plain done:        committed-only=YES   (expect YES)
no-mistakes, no pr, plain done:       committed-only=YES   (expect YES)
empty mode, pr= in file:              committed-only=NO    (expect NO)
no-mistakes, pr= in file:             committed-only=NO    (expect NO)
direct-pr mode, no pr, plain done:    committed-only=NO    (expect NO)
local-only mode, no pr:               committed-only=NO    (expect NO)
no-mistakes, ci-ready shipment claim: committed-only=NO    (expect NO)
kind=scout, empty mode:               committed-only=NO    (expect NO)
empty mode, non-done verb:            committed-only=NO    (expect NO)
```

The empty-mode / no-mistakes committed-only handoff reads working; a recorded
`pr=`, a ci-ready shipment claim, any other delivery mode (direct-pr/local-only),
a non-ship kind, and a non-`done` verb are all excluded — the exact-match
exclusion the change intended is intact.

## Automated tests driving the same behavior end-to-end

- `tests/fm-crew-state.test.sh::test_no_mistakes_prevalidation_done_reads_working` — pass
- `tests/fm-crew-state.test.sh::test_empty_mode_prevalidation_done_reads_working` — pass
- Full `tests/fm-crew-state.test.sh` — `all fm-crew-state tests passed` (exit 0)
