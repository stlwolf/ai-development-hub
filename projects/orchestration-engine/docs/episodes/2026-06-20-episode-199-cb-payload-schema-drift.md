---
id: "01KVJQD8YNXSM4JM36H5XV0H1C"
title: "#199 circuit_breaker_triggered audit payload の schema↔impl ドリフト是正"
date: 2026-06-20
type: episode
status: stable
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/199"
    reason: "本 episode の対象 Issue（CB payload キーが schema(limit_type) と impl(reason) で不一致）"
  - type: design_context
    ref: "projects/orchestration-engine/docs/episodes/2026-06-20-episode-177-oe-status.md"
    reason: "本ドリフトの発見元（#177 oe-status reducer 実装中に検出 → #199 へ routing）"
tags: [orchestration, audit-log, schema, circuit-breaker, drift, episode]
---

# #199 circuit_breaker_triggered audit payload の schema↔impl ドリフト是正 episode

## Context / なぜ

`circuit_breaker_triggered` audit イベントの payload キーが、schema 記述（`limit_type` / `reached_value`）と実装の emit（`reason`）で不一致だった。schema を信じて audit を読む将来の消費者が CB 理由を取りこぼす。#177（oe-status の read-only 観測UI）reducer 実装中に検出され、reducer 側は `reason` 優先 + `limit_type` フォールバックで両対応して回避済み。ドリフト自体の是正は #177 のスコープ外として #199 に routing された。本 episode はその是正作業の記録。

## やったこと

- `schemas/audit-log.schema.json` の `circuit_breaker_triggered` ブランチの `description` を、実装が実際に emit する payload に合わせて修正（方針 b）。
  - 旧: `payload に limit_type (timeout / max_turns / max_panes) と reached_value を含む。`
  - 新: `payload に reason (timeout / max_turns / max_panes、検証ゲート由来は verification_timeout) を含む。reason=verification_timeout の場合は target_pane_id も含む。`
- `reached_value`（schema 記載のみ・実 emit ゼロ）を description から除去。

## 決定と根拠（a/b 比較）

- **採用 = (b) schema を実装（`reason`）に合わせる。** 当該ブランチは `then.description` のみ（`required` も property 制約もなく、payload は `additionalProperties: true`＝「MVP では厳格な payload スキーマは定義しない」）。よって構造不変・純粋な記述修正・後方互換◎。既存 audit jsonl は元から `reason` を使用しており、impl が ground truth。
- **棄却 = (a) impl を schema（`limit_type`）に寄せる。** producer 変更（`lib/monitor.sh` 3 箇所 + `lib/verify.sh` 1 箇所）+ 既存 jsonl の後方互換破壊 + tests（`reason` 参照）更新 + #177 reducer の主キー差し替え、と blast radius が大。得られるのは `limit_type` という命名の語感のみで、移行コストに見合わない。
- **棄却 = (c) 両キー emit / 厳格 payload schema 定義。** MVP 方針（厳格 payload schema を定義しない）に反し、#199 のスコープを超える over-engineering。
- 方針 (b) は kickoff で推奨・親 `%32` が承認済み。本作業のゼロベース確認は (a)/(c) を棄却して (b) を**確認**したもの（新発見ではない）。

## わかったこと（W）

- `reached_value` はコードベースのどこからも emit されていない（`grep` 全数確認）。schema にだけ存在した幽霊キー。
- `circuit_breaker_triggered` の `reason` 値は実装上 4 種: `timeout` / `max_turns` / `max_panes`（`lib/monitor.sh`）+ `verification_timeout`（`lib/verify.sh`、`target_pane_id` も同梱）。

## 検証

- `jq -e .` で schema の JSON 妥当性 OK。
- `tests/test_oe_status.sh`: pass=27 fail=0
- `tests/test_monitor.sh`: PASS=31 FAIL=0
- description のみの変更につき挙動テストは不変（回帰なし、想定どおり）。

## 残課題（routing 付き）

- **#177 reducer の `limit_type` フォールバック**: schema が `limit_type` を主張しなくなったため、reducer のフォールバックは「起こり得ないケース」への防御コードになった。ただし無害であり、削除は reducer（#177）への変更＝**#199 のスコープ外**（kickoff「#177 reducer は触らない」）。→ **追わない**（無害な防御コード。是正を #199 に巻き込むと不要な結合が生じる）。
- 過去の frozen episode `docs/episodes/2026-05-14-episode-audit-log-schema.md`（payload 表に旧 `limit_type, reached_value` 記載）→ **追わない**（当時の設計状態の歴史記録。frozen snapshot を遡及改変しない）。

## 蒸留シグナル

- 昇格候補: **なし**（schema 記述の事実整合修正。Decision / skill / rule 化する一般則なし）。

---

## Closure

- **tier 判定: standard**（heavy トリガなし）。
  - heavy 不該当の根拠: 失敗・撤回なし / 意図起動の外部レビューレーンなし（oe-review は right-size 判断でスキップ・後述、so-compare 未実施）/ 学習が主成果でない / 設計判断は kickoff 推奨＋親承認済みでゼロベースは確認のみ（非自明な未決の比較ではない）/ 昇格候補なし。kickoff の明示指示「right-size・過剰ゲートにしない」とも整合。
- **oe-review（実装SO）スキップ判断**: 変更は schema の `description` 文字列のみ（bash コードでなく shellcheck 対象外、構造制約なし）。oe-review のレンズ（コード欠陥 / 到達可能性）は記述文字列に適用対象がない。kickoff「実装SO（oe-review）はコード変更時に」に従いスキップ。
- **次の消費者**: schema を信じて audit を読む将来の消費者（Stage-B 横断観測）。#177 reducer 保守者（将来 `limit_type` フォールバックを安全に削れる根拠としても参照可）。
- **follow-up routing**: 上記「残課題」で全件に行き先付与（2 件とも「追わない」+ 理由）。行き先なしの箇条書きなし。
- **status 確定**: stable / 達成。
- **evidence anchor**: 検証結果（27/27・31/31・JSON OK）を本文に転記済。揮発パス参照なし。
