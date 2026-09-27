# fm-supersede-sweep.sh — live CLI transcripts

The change adds `bin/fm-supersede-sweep.sh`: when a decision is changed or reversed
mid-flight, it re-checks every open brief and queued task note for the superseded
statement before the next dispatch, and exits non-zero (1) while any copy remains so
the sweep is a real gate rather than an intention.

Driven against the real script + real `tasks-axi` backend in a throwaway `FM_HOME`.

## 1. In-flight brief and queued hold reason still cite the superseded decision

```
$ fm-supersede-sweep.sh 'legacy export disabled'
brief: ship-42 .../data/ship-42/brief.md:3:Constraint: keep the legacy export disabled for now.
note: ship-45 queued: ship-45,queued,task,"-",await decision,"","blocked: legacy export disabled decision pending"
hits: 2
help: correct each brief before it is dispatched; relay the correction to a live worker with fm-send.sh; update each note with fm-tasks-axi.sh update <id> --title or --body-file
exit: 1
```

The already-dispatched (live) worker's brief AND a queued item's hold reason are both
surfaced. Exit 1 blocks the next dispatch until they are corrected.

## 2. Full retro shape — queued brief + queued title (the "rename poisons" precedent), done work skipped, then clean after correction

```
$ fm-supersede-sweep.sh 'legacy export disabled' 'Retire the legacy export'
brief: ship-43 .../data/ship-43/brief.md:3:Leave the legacy export disabled, per the standing decision.
note: ship-44 queued: ship-44,queued,task,"-",Retire the legacy export path,"","-"
hits: 2
help: correct each brief before it is dispatched; ...
exit: 1

# after each brief corrected and the poisoning title renamed:
$ fm-supersede-sweep.sh 'legacy export disabled' 'Retire the legacy export'
clean: no open brief or task note states the superseded statement
exit: 0
```

A finished (`done`) task that also mentioned the phrase was NOT swept — finished work
is out of scope. Once the briefs are re-steered and the poisoning title renamed, the
sweep reports clean and exits 0.

## 3. Behavior test suite

`bash tests/fm-supersede-sweep.test.sh` → all 3 cases pass:
- names every open brief and task note that states the superseded fact (live brief,
  queued brief, queued note/title/hold-reason; skips done and orphan briefs; hits: 5)
- matches any phrase and reports a clean sweep
- refuses (exit 2) rather than reporting clean on usage errors and an unreadable backlog
