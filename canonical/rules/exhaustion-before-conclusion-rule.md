# Exhaustion Before Conclusion

Complements `behavioral-rule.md` §1 Evidence First. Evidence First governs the *quality* of grounding (prefer primary sources). This rule governs the *breadth* of exploration: do not conclude while reachable paths or options remain unexamined. (Claim-level verification is `evidence-verification-rule.md`; this rule is about exploration breadth, not source checking.)

## Principle

> Do not conclude while known reachable paths or options remain unexamined.

The design discussion phrases it as "do not jump to a conclusion before exhaustiveness is guaranteed" — operationalized as *structural suppression of early convergence*, not literal 100% coverage (see Scope).

Why it is needed: LLMs carry an early-convergence bias — latching onto a plausible local optimum, externalizing judgment ("it depends on the requirements") to cut exploration short, and emitting superficial diversity (N variants of one category). Exploration *quality* is probabilistic (model-dependent), but exploration *structure* can be enforced deterministically. This rule sets that default stance.

## Where it shows up (illustrative)

The same failure structure recurs across domains. The two cases below are illustrative examples, not verification-grade proof — the principle rests on the reasoning above. The pattern is the point; it need not be these specific cases.

| Bug investigation (code-path exhaustion) | Design decision (option exhaustion) |
|---|---|
| Jump to an external hypothesis while a code-path segment from input to output is still unread | Commit while an unexplored alternative remains in the option set |
| "Read the whole path before moving to external hypotheses" | "Explore alternatives from zero before committing" |
| Externalize each hypothesis to make spinning (same-level lateral moves) visible | Externalize the option set to make exploration coverage visible |

- Design-decision example: the wez notify `option C` (TTY direct write) surfaced only after an ad-hoc zero-base re-review, when a commit on options A/B was already near. Worked example in this repo: `projects/wezterm-ai-mode/docs/episodes/2026-04-22-episode-wez-notify.md`.
- Bug-investigation example: an error investigation that jumped to an external hypothesis (infra difference) while an input→output code path was still unread — 6 steps for what 2 would have. From a separate project (external, ref omitted); cited as illustration only, not inspectable here.

## Application

The reachable space splits in two, so the planned mechanisms split into two tracks while the principle stays single:

- Design-decision domain (unexplored options): a soft forcing layer — the `predecision-exploration` skill, which requires ≥1 zero-base alternative exploration with a confirm-time trace before confirming — has landed (#77). Its deterministic hard gate (script-layer convergence) is still deferred.
- Bug-investigation domain (unread code paths): a hard mechanism to externalize hypotheses and make spinning visible — design tracked in #78 (planned, not yet implemented).
- An always-on soft floor (reframe / zero-base on detecting spin) — landed as `reframe-on-stall-rule.md` (#161).

## Minimal discipline (until the hard mechanisms land)

The deterministic hard mechanisms (#77 / #78) do not exist yet (#77's soft forcing layer `predecision-exploration` has landed; the hard gates are deferred). At high-stakes conclusions — committing a design, asserting a root cause, or jumping to an external hypothesis — apply this floor directly:

- Do not self-declare "explored enough" without a stated reason. The model is biased to announce sufficiency; the design discussion is explicit that convergence must not be left to the model's own judgment.
- Decide the stopping condition before exploring, not when you feel done.
- At conclusion, state briefly what was read, what was explored, and what reachable area was left unexamined.

This does not apply to small, low-risk decisions — avoid analysis paralysis (see Scope).

## Scope

- Aim to lift exploration quality from the ~50% "jump early" level to ~80%. Do not aim for 100%.
- The remaining ~20% is edge cases — the "handle it once it shows up" level, even for humans. Do not over-enforce exhaustiveness (consistent with `behavioral-rule.md` §4 Minimal Scope).

## References

- `behavioral-rule.md` §1 Evidence First — complemented principle (quality of grounding vs breadth of exploration)
- `evidence-verification-rule.md` — sibling under Evidence First; claim-level verification status, orthogonal to this rule's exploration breadth
- `docs/specs/2026-04-23-discussion-exploration-process-design.md` — canonical design discussion (§3.4: convergence is not the model's call; §6 caveat that one principle name spans two distinct problems)
- `docs/specs/2026-04-22-discussion-hypothesis-driven-exploration.md` — sibling discussion
- `projects/wezterm-ai-mode/docs/episodes/2026-04-22-episode-wez-notify.md` — worked design-decision example
