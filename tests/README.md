# tests

repo の直下の `scripts/` など、どの `projects/` にも属さないもののテストを置く。`projects/` の下のツールキットのテストは、それぞれの `projects/<name>/tests/` に置く。

- 置き場は、テストする対象の path に合わせる（`scripts/cloud/link-project-context.sh` のテストは `tests/scripts/test_link_project_context.sh`）。
- まとめて流すランナーは無い。1本ずつ bash で流す。

```bash
bash tests/scripts/test_link_project_context.sh
```

`scripts/sync/` のテストは、この置き場ができる前から `projects/orchestration-engine/tests/` にある（`test_check_orphan_links.sh` など）。移すかは別に決める。
