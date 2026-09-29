# Scout completion gate — answered captain hold in Done archive

Change under test: `fix: count answered captain holds in the Done archive at the
completion gate` (4e4de24), base 40e981d.

The regression test `test_archived_answered_hold_still_satisfies_the_gate` drives
the real product scripts (`bin/fm-captain-hold.sh` verify/complete/answer,
`bin/fm-teardown.sh`, and `tasks-axi` Done retention) against an isolated FM_HOME.
It reproduces the 2026-09-28 pig-reset report: an answered captain call moved into
`data/done-archive.md` by Done retention must still count as durable.

## Before the fix (base `bin/fm-captain-hold.sh` from 40e981d)

The test FAILS with the exact reported failure:

```
not ok - verify refused an answered call Done retention archived: fm-captain-hold:
no captain-held task sample-archived-call and no migrated hold for it in this home's
configured backlog (data directory .../archived-answer/data); the nearest legacy
identity sample-archived-review-decision-sample-archived-call also resolves to nothing
EXIT=1
```

## After the fix (target `bin/fm-captain-hold.sh` from 4e4de24)

```
ok - an answered captain call archived by Done retention still satisfies the completion gate
EXIT=0
```

The single test drives three end-to-end scenarios:
1. Happy path — answered hold, then Done retention archives it (`done_keep=0`),
   then `verify`, `complete`, and `fm-teardown.sh` all accept the scout.
2. Adversarial guard — an archived close with NO recorded captain answer: `verify`
   and teardown both refuse, and refused teardown preserves investigation metadata.
3. Adversarial guard — an attested captain call that exists nowhere: `verify`
   refuses and the refusal names the missing call `sample-never-held-call`.
