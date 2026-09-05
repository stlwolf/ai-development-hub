---
review-when: the harness changes its delegation defaults or where concurrency and nesting limits live
---

# Subagent Strategy

## Principles
- One task per subagent — keep them focused.
- When delegating implementation, enforce the `implementer-contract` skill (status enum, report format, self-review).
- Concurrency and nesting limits for delegation belong to the harness, not to this rule. Do not write a numeric cap here; where a harness exposes such limits, set them there.

## Custom Agents First
- Prefer domain-specific custom agents over generic subagents.
- Before delegating, check project-level and user-level `agents/` directories for a matching custom agent.
- If a match exists, use it over the standard subagent.
  - Use the tool's native agent launch mechanism when available.
  - Otherwise, read the definition file and inject its full content into the subagent prompt.
- Fall back to standard subagents only when no custom agent matches.

## Routing Gate
The harness already routes inline ⇄ subagent and selects custom agents — do not re-decide that. This gate adds only what the harness does not: a human-facing escalation signal and a PR-unit check.

Default: subagent or inline. Surface a one-line recommendation to the user ONLY when escalation is warranted — when ≥2 escalate-lean axes hold, or judgment is dense with no objective gate. The model cannot open a thread, so this never blocks delegation:

```text
[routing] recommend new thread — reason: scope emerges mid-run; no objective gate
```

Escalate-lean axes (else the default holds):
- Pre-specifiability: scope / acceptance criteria cannot be fully written yet
- Objective verifiability: no mechanical gate (build / test / schema) decides pass/fail — needs human eyes
- Blast radius: outward-facing or irreversible

An environment or platform quirk is not a capability difference — never route by presumed subagent capability.

Principles:
- A task with an objective gate can run as subagent + parent review — review substitutes for a thread's "eyes". Autonomous subagents cannot stop at a user gate (`implementation-gate-rule`), so keep judgment-dense or direction-shifting work where that gate applies, not fire-and-forget. Advisory, not hook-enforced.
- For implementation delegation, 1 PR = one logical change with definable acceptance criteria (mechanical or review-based); delegation unit = PR unit. Investigation and exploration are exempt — decompose them first.
- Delegation prompts surface out-of-scope findings and follow-ups without implementing them — see `implementer-contract`.
