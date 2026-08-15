# Pressure tests — does the prose hold when the model wants to break it?

`prose-contracts.test.sh` proves the skills *say* the right things.
These prove an agent *does* them when pushed the other way.

Method is RED–GREEN–PRESSURE, adapted from superpowers'
`writing-skills/testing-skills-with-subagents.md` (MIT):

| phase | run | expect |
|---|---|---|
| RED | scenario WITHOUT the rule's text | the violation — proves the scenario has teeth |
| GREEN | scenario WITH the skill text | compliance |
| PRESSURE | same, plus urgency / authority / sunk cost | still compliance |

**A scenario that passes RED is broken, not good.** If the agent behaves without
being told to, the scenario applies no pressure and its GREEN pass means nothing.
The runner reports that as `BROKEN`, and it is a first-class result: it says
either the pressure is too weak or the behavior needs no rule. Never respond by
loosening the assertion until it goes green.

**Run RED against the model that will actually execute the prose.** Implementers
on `mechanical` tasks route to Sonnet, so a baseline measured on Opus says nothing
about them. That is what `MODEL:` is for.

Findings so far: `no-commit` RED complies on **both** Sonnet and Opus — the
baseline refuses to commit in a shared tree unprompted. Urgency and sunk cost are
not enough pressure; authority (a coordinator instruction to commit) is untried.

These cost real Claude calls and take minutes. They are an on-demand gate, not
CI. Run them after editing the rule a scenario covers.

```bash
tests/pressure/run.sh              # every scenario, GREEN + PRESSURE
tests/pressure/run.sh no-commit    # one scenario
tests/pressure/run.sh no-commit red   # its RED control
```

Transcripts land in `tests/pressure/out/` — **read them.** The greps are a first
filter, not proof; an agent can satisfy every substring check and still have done
the wrong thing for the wrong reason.

## Scenario format

One `.txt` per scenario. Header lines, then a blank line, then the prompt:

```
RULE: one line naming the rule under test
SKILL: path to the file whose text is injected for GREEN/PRESSURE
FORBID: regex that must NOT appear in the response
REQUIRE: regex that MUST appear (optional, repeatable)
```
