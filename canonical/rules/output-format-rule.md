# Output Format
1. Conclusion (one line)
2. Evidence / verification results (commands and output)
3. Steps (minimal granularity — one command / one PR / one change per item)
4. Open questions / risks
5. Related links
6. Format all URLs as Markdown links (e.g., [PR #5143](https://github.com/...), [Pipeline #16261](https://app.circleci.com/...))
7. Markdown doc paths: prefer the **absolute path** of an in-repo Markdown document over relative or `~` forms — an absolute path is unambiguously resolvable and directly actionable (e.g. click-to-open) by the surrounding tooling, whereas relative/`~` forms are not. Apply where practical; incidental mentions not meant to be opened are exempt.
8. Japanese wording: write plain Japanese. Do not drop raw English into slots where Japanese belongs — above all descriptive/qualifying words (adjectives, adverbs, connectives). This, not technical jargon, is the main readability problem.
   - Test: is the English word *naming the work object*, or *describing its quality / degree / manner*?
     - Naming → keep English: `git`, `PR`, `hook`, `engine`, `malform`, `oe-*`, plus established loanwords (コンフリクト / レビュー / コミット).
     - Describing → use Japanese: genuine→本当の, pivotal→肝心の, contained→収まっている, behavioral に→振る舞いとして.
   - Also avoid English+する/させる (landing させる → 取り込む; validate します → 検証します) and needless abbreviation pile-ups that trade readability for density.
   - Scope: all Japanese output — chat replies and documents you generate (issue / PR / episode / discussion). Not: already-emitted text, existing docs, code identifiers, or the English rule files themselves.
   - Why documents too: AI-authored docs become the register the AI later mirrors — a feedback loop; applying this to generated docs starves it.
