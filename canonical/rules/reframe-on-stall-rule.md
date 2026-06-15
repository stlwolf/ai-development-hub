# Reframe on Stall

Complements `behavioral-rule.md` §1 Evidence First and serves as the always-on soft floor under `exhaustion-before-conclusion-rule.md`. Where that rule says "do not conclude too early," this one says "do not keep grinding the same way."

## Principle

> When exploration stalls — your last moves return no material new information, only lateral repetition at the same level — do not just continue. Before the next same-direction attempt, explicitly consider rebuilding from zero (a zero-base reframe) once.

This is a default stance, on every session — not a tool to invoke or a hook to fire.

## Trigger: a stall, judged by observable signs (not a step count)

Do not use a count threshold ("after N tries"): a count is context-blind — three repetitions on a triviality is not a stall, and a single lateral move on a hard problem can already be the cue. A single no-new-information move can be the cue; repetition strengthens the signal but is not required.

"Am I stuck?" is the judgment a model is worst at, so prefer observable signs of the last move's result over a feeling:

- Did the error / failure change, or repeat unchanged?
- Did a hypothesis get ruled in or out?
- Did the set of live options shrink?
- Did the next action change as a result?

If none of these moved — including a reasoning step that only restated the problem (a stall need not involve a tool call) — that is the cue to reframe. Materiality matters: piling up confirming detail that does not change the conclusion is a stall even though it is technically new information. Where no observable sign applies, this falls back to a soft "was that just a lateral move?" judgment — and that judgment is itself model-dependent and unreliable (see Limits).

## Reframe, then reconcile

A rebuild is not a reset:

- Before rebuilding, note in one line the premises, hypotheses, and known facts you are discarding — otherwise there is nothing to reconcile against afterward (especially once context is compressed).
- After the zero-base pass, reconcile it against that note: convergence (it lands where the old path did) raises confidence but is not proof — both passes can share a blind spot; divergence means the old path missed something — record what.
- If the rebuild also stalls, surface it / escalate rather than loop.

## Scope

- Applies to costly, stuck exploration. It does not apply to small, low-risk work — a zero-base rebuild is expensive; do not reframe a two-line fix (consistent with `behavioral-rule.md` §4 Minimal Scope).
- If a reframe changes scope, cost, or direction, surface it as an option rather than silently pivoting, unless autonomous exploration was requested (`decision-pacing-rule` / `implementation-gate-rule`).

## Limits

- Adherence is model-dependent; there is no firing guarantee. This raises the floor — it does not close the gap. The trigger judgment itself ("was that material new information?") is partly self-evaluation and unreliable where no observable sign applies. Over-firing (reframing where grinding was right) and under-firing (missing the stall) both remain.
- High-stakes or irreversible conclusions are not left to this soft reflex. A hard gate (count + script + human) is planned for the design-decision domain (#77) and is not yet implemented — until it lands, rely on `exhaustion-before-conclusion-rule.md`'s minimal discipline plus human confirmation for such conclusions.

## Relationship

- `exhaustion-before-conclusion-rule.md` — the umbrella. Its discipline is conclusion-time (may you commit while reachable paths or options are unexamined?); this rule is mid-exploration (what is the next move when the frame stalls?). They can co-fire — e.g. when you are about to jump to an external hypothesis while stuck. This rule is the permanent always-on floor; that rule's "Minimal discipline" is the interim floor until the hard mechanisms (#77 / #78) land.
- `persistent-exploration` (skill) — the related anti-give-up reflex (do not quit before trying alternatives). The two can both apply and chain: try other approaches; if those also stall, rebuild the frame.

## Example (illustrative)

A bug investigation retries the same request three ways and gets the same error each time — no new information, lateral moves: a stall. The reframe is not a fourth variant of the request but a zero-base question re-derived from scratch — "what if the request is not the problem at all?" — then reconciled against the discarded "it is the request" premise.

## References

- `exhaustion-before-conclusion-rule.md` — umbrella principle; this rule is its always-on soft floor
- `behavioral-rule.md` §1 Evidence First
- `docs/specs/2026-04-23-discussion-exploration-process-design.md` — canonical design discussion
- `canonical/skills/persistent-exploration/SKILL.md` — the related anti-give-up reflex
