# Evidence Verification — Claim-Level Status & Spot-Check Discipline

Concretizes `behavioral-rule.md` §1 "Evidence First." Evidence First states the principle (prefer primary sources, mark speculation explicitly); this rule operationalizes it into a checkable protocol: every non-trivial claim in a research/analysis deliverable carries a verification status (and, where the status requires it, a source), and downstream consumers spot-check before trusting.

Applies to consumed deliverables: research-intake notes, OSS research reports, investigation findings (including other investigation agents such as `vendor-inspector`) — any output whose claims feed another agent or a human gate. Exploratory drafts are exempt (§4).

## 1. Verification Status (output side)

Annotate each non-trivial claim with one status. Default to the weakest status that honestly applies — never inflate.

| Status | 和名 | Meaning | Requirement |
|--------|------|---------|-------------|
| `verified` | 一次確認済み | The cited source directly supports the claim (entailment holds) | MUST be backed by a source entity (URL or `file:line`) the author actually inspected — independent of the generated text, never self-evaluation (§2) |
| `unverified-summary` | AI要約のみ | A source is cited but entailment is unconfirmed, or the claim is a model paraphrase | DEFAULT for AI-generated summaries |
| `speculation` | 推測 | No supporting source | No source required (give a brief reason if useful). Value is `speculation`; inline `Speculation:` prefix is an accepted shorthand |

- Bind status at the **statement level** (per claim / sentence), not per paragraph.
- Each `verified` / `unverified-summary` claim carries its source as a URL or `file:line`. `speculation` carries no source (a brief reason is optional).
- Do not pad with irrelevant sources — a citation that does not support its claim is a defect, not coverage.
- Generation and verification are separate passes — do not self-confirm a claim in the same step that produced it.
- Minimal grammar: tag each claim inline as `[status]` with its source adjacent — e.g. `… [verified] (https://…)`, `… [unverified-summary] (path/to/file.md:42)`, `… [speculation]` — or, in tables, use dedicated status + source columns.
- A claim that a source actively contradicts is a review defect: flag and correct it (§3). It is a finding, not a stable deliverable status.

## 2. The `verified` bar (hard constraint)

`verified` requires checking the claim against the **actual source entity** (open the URL / read the `file:line`). A model asserting its own correctness is NOT verification — intrinsic self-correction without an external oracle is unreliable. If the source was not inspected, the status is at most `unverified-summary`.

## 3. Spot-Check (consumer side)

A consumer (parent agent, reviewer, gate) MUST spot-check an output's claims before trusting it.

- Allocate verification by **risk and uncertainty**, not uniformly: high-stakes and low-confidence claims are checked first. Verifying every claim is neither feasible nor required.
- The final check MUST hit the **source entity directly** (human or deterministic check). Do NOT rely solely on an LLM judge — a judge is itself an attack surface and can be misled.
- There is no universal "check N claims / X%". If a skill fixes a number, it MUST label it an operational heuristic, not an evidence-backed threshold.
- Selective verification (partial acceptance) is legitimate resource allocation, not negligence — but a claim no one inspected against its source cannot be promoted to `verified`; leave it `unverified-summary`.

## 4. Staged Application

Match rigor to maturity. Exploratory drafts and brainstorming are exempt; the protocol binds once an output is promoted to a consumed deliverable (a saved note, a report handed to another agent, a finding feeding a decision). Promotion means handoff to another agent/gate or an explicit save for reuse — a private working draft stays exploratory until then. Do not let strict status-tracking choke the divergent phase.

## References

- `behavioral-rule.md` §1 Evidence First — parent principle
- Research basis: `docs/research/2026-06-03-llm-verification-discipline-literature.md` (CoVe / ALCE / RARR / GLEAN; self-correction limits; judge fragility)
