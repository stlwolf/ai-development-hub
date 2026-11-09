# tests

repo の直下の `scripts/` など、どの `projects/` にも属さないもののテストを置く。`projects/` の下のツールキットのテストは、それぞれの `projects/<name>/tests/` に置く。

- 置き場は、テストする対象の path に合わせる（`scripts/cloud/link-project-context.sh` のテストは `tests/scripts/test_link_project_context.sh`）。
- まとめて流すランナーは無い。1本ずつ bash で流す。

```bash
bash tests/scripts/test_link_project_context.sh
```

`scripts/sync/`・`scripts/so-compare.sh`・`canonical/hooks/scripts/`・`canonical/claude/statusline/` のテストは、#616 で `projects/orchestration-engine/tests/` からここへ移した。engine の `bin/`・`lib/` も呼ぶテスト（`tests/scripts/test_so_compare_input_rejection.sh` など）は、主に検査する対象の path に置き、engine は `projects/orchestration-engine/` を指して呼ぶ。

`projects/orchestration-engine/tests/test_session_name.sh` と `test_prompt_receipt.sh` は、hook（`canonical/hooks/scripts/`）とエンジンの部品が記録を介してつながる形を検査していて、どちらにも寄せにくい。どちらに置くかが決まるまで、engine の tests に残す。
