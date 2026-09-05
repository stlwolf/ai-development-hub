# Output Format
1. Conclusion (one line)
2. Evidence / verification results (commands and output)
3. Steps (minimal granularity — one command / one PR / one change per item)
4. Open questions / risks
5. Related links — required whenever this turn created or updated an addressable artifact.
   - Trigger: you created or updated an Issue, a PR, or an in-repo document during this turn. The report then MUST end with a related-links block. **Introduce it with a line-head label, not a heading**: `関連リンク:` when the report is written in Japanese, `Related links:` when it is in English — pick by the language of the report, not by the language of this rule. A label keeps the block out of the way when a harness tells short replies to carry no headings; a heading would collide with that. Comments and review replies (e.g. a Copilot response) are optional — include them when the thread is worth revisiting.
   - This is the operator-facing block. A subagent's structured `Links` field (see the `implementer-contract` skill) is the same information on the agent-to-agent channel; the two names are not interchangeable.
   - Contents: every artifact you created or updated in this turn, one per line, labeled. Order: PR first, then Issue, then documents, then anything else.
   - Form: a bare full URL, e.g. `PR #110: https://github.com/<owner>/<repo>/pull/110` (§6). A bare `#110` with no URL does not count as a link. In-repo Markdown documents use the absolute path that resolves at the time of writing (§7) — inside a worktree that is the worktree path, not the post-merge one.
   - Not required when the turn produced no such artifact: investigation, a question answered, read-only work. Do not pad the block with links you did not touch.
6. URL form follows the destination.
   - Terminal output shown to the operator (chat replies, reports): bare full URLs. This terminal auto-links a bare URL but renders `[label](url)` literally, so the Markdown form loses the click target.
   - Text handed to a Markdown renderer (PR body, Issue body, comments, in-repo docs): `[label](url)` — e.g. [PR #5143](https://github.com/...), [Pipeline #16261](https://app.circleci.com/...).
7. Markdown doc paths: prefer the **absolute path** of an in-repo Markdown document over relative or `~` forms — an absolute path is unambiguously resolvable and directly actionable (e.g. click-to-open) by the surrounding tooling, whereas relative/`~` forms are not. Apply where practical; incidental mentions not meant to be opened are exempt.
8. Japanese wording: write plain Japanese. Do not drop raw English into slots where Japanese belongs — above all descriptive/qualifying words (adjectives, adverbs, connectives). This, not technical jargon, is the main readability problem.
   - Test: is the English word *naming the work object*, or *describing its quality / degree / manner*?
     - Naming → keep English: `git`, `PR`, `hook`, `engine`, `malform`, `oe-*`, plus established loanwords (コンフリクト / レビュー / コミット).
     - Describing → use Japanese: genuine→本当の, pivotal→肝心の, contained→収まっている, behavioral に→振る舞いとして.
   - Also avoid English+する/させる (landing させる → 取り込む; validate します → 検証します) and needless abbreviation pile-ups that trade readability for density.
   - Scope: all Japanese output — chat replies and documents you generate (issue / PR / episode / discussion). Not: already-emitted text, existing docs, code identifiers, or the English rule files themselves.
   - Why documents too: AI-authored docs become the register the AI later mirrors — a feedback loop; applying this to generated docs starves it.
9. Operator-facing prose: when the reader is the human operator, write so the meaning is clear on one read. This applies to the message the operator sees — chat replies and explanations, and any confirmation or human-gate request shown to them (including one relayed by a parent session).
   - It applies only to that operator-visible message. It does not constrain internal reasoning or hidden working notes; those may use any register, including English.
   - Do not compress prose into telegram style: noun-ending (体言止め) fragments, symbols used as sentence glue (→ ＝ ・ ★ 〔〕), nested parentheses that bury the main clause, or one dense line packing several points. Prefer complete sentences, one main point each. Normal Markdown structure (headings, `-` lists, inline code) and tables are fine; the ban is on symbols standing in for grammar.
   - Vocabulary follows §8. Keeping English work-object names alongside a Japanese description is expected under §8 and is not "bad mixing"; do not switch languages merely to shorten a sentence.
   - Check: can the operator act on the meaning after one read? If not, rewrite.
   - Out of scope: agent-to-agent channels (brief, report, SO prompts) and the board's compact state-transfer register. Document register (issue, PR, episode) belongs with the skills that generate those documents; §8 still governs their Japanese vocabulary.
