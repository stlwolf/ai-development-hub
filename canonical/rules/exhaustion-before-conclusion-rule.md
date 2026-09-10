---
review-when: a deterministic hard gate for exploration lands, which would replace the minimal discipline here
---

# Exhaustion Before Conclusion

Complements `behavioral-rule.md` §1 Evidence First. Evidence First governs the *quality* of grounding (prefer primary sources). This rule governs the *breadth* of exploration: do not conclude while reachable paths or options remain unexamined. (Claim-level verification is `evidence-verification-rule.md`; this rule is about exploration breadth, not source checking.)

## Principle

> Do not conclude while known reachable paths or options remain unexamined.

The design discussion phrases it as "do not jump to a conclusion before exhaustiveness is guaranteed" — operationalized as *structural suppression of early convergence*, not literal 100% coverage (see Scope).

Why it is needed: LLMs carry an early-convergence bias — latching onto a plausible local optimum, externalizing judgment ("it depends on the requirements") to cut exploration short, and emitting superficial diversity (N variants of one category). Exploration *quality* is probabilistic (model-dependent), but exploration *structure* can be enforced deterministically. This rule sets that default stance.

## Minimal discipline

Until a deterministic hard gate exists, apply this floor directly at high-stakes conclusions — committing a design, asserting a root cause, or jumping to an external hypothesis:

- Do not self-declare "explored enough" without a stated reason. The model is biased to announce sufficiency; the design discussion is explicit that convergence must not be left to the model's own judgment.
- Decide the stopping condition before exploring, not when you feel done.
- At conclusion, state briefly what was read, what was explored, and what reachable area was left unexamined.

This does not apply to small, low-risk decisions — avoid analysis paralysis (see Scope).

## Scope

- Aim to lift exploration quality from the ~50% "jump early" level to ~80%. Do not aim for 100%.
- The remaining ~20% is edge cases — the "handle it once it shows up" level, even for humans. Do not over-enforce exhaustiveness (consistent with `behavioral-rule.md` §4 Minimal Scope).
