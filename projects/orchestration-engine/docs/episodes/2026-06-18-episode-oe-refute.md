---
id: "01KVBBKHZVQR89E2NS74A3X6N7"
title: "oe-refute — 確定前の同期反証 verb 追加（#183 / Stage A・クロスセッション実装）"
date: 2026-06-18
type: episode
status: stable
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/183"
    reason: "本サイクルの Issue（oe-refute / Stage A）"
  - type: design_context
    ref: "projects/orchestration-engine/docs/discussions/2026-06-18-discussion-exploration-hard-layer-on-engine.md"
    reason: "戦略設計の出自（cockpit⇄探索クラスタのクロスセッション・ラリー統合・Stage A）"
  - type: design_context
    ref: "https://github.com/stlwolf/ai-development-hub/issues/169"
    reason: "cockpit 傘（engine トラックの受け皿）"
tags: [orchestration, oe-refute, refutation, so-compare, cross-session, episode]
---

# oe-refute — 確定前の同期反証 verb 追加（#183 / Stage A）

> 確定（設計判断・根拠断定・外部仮説ジャンプ）の前に独立反証レーンを立て、共有 verdict エンベロープ `{verdict, reason}` を同期で返す薄いラッパー verb。探索原則クラスタ（完了済み #75-78）が手動 so-compare で行う「確定前の反証」を engine 統合・addressable な verb に格上げ。**クロスセッション・ラリー（cockpit %16 ⇄ 探索 %3）で設計確定 → cockpit が実装 → 設計SO=ラリー / 実装SO=codex+cursor のゲート**を通した1サイクル。shellcheck clean / ユニット 57/0（bash 3.2 含む）。

## Context / なぜ

#169 cockpit の並列トラックとして、探索クラスタ hard 層を engine substrate に載せる Stage A。設計は cockpit⇄探索クラスタのクロスセッション・ラリー（`oe-send` + 駆動層 doc ポインタ、turn1-12）で確定済み（discussion doc 参照）。実行者も rally で「engine=cockpit 直接（案1）/ skill=探索」と共同決定。

## 設計（rally が設計 SO を兼ねた）

- **設計ゲート = ラリー自体**: peer（探索クラスタ）が 12 turn にわたり設計を反証・精緻化し、claim doc ↔ verb の I/O 契約（`explore-turn10-claim-contract.md`）を確定。単発の設計 SO より網羅的だったため、別途の設計 SO は省略（engine フロー: 設計=rally / 実装=impl SO）。
- **backend = so-compare wrap**: 契約は backend を cockpit に委任（要件=独立・物理分離・exploration レンズ）。既存の枯れた so-compare レーン分離（codex/cursor）を wrap する最薄案を採用（discussion doc の「so-compare を engine 化」framing どおり）。
  - **out-of-scope finding（記録）**: discussion doc Stage A 行は backend を「既存 spawn+verify の薄ラッパー」と記述。実装は so-compare wrap で、engine の spawn.sh/verify.sh substrate は使っていない。契約が backend を委任していた範囲内の選択だが、将来 engine-spawn レーンに替える場合はレーン抽象（provider→verdict file）の差し替えが要る。
- **契約**: frontmatter（claim/rubric/domain・機械パース）＋ body（不透明・refuter へ素通し＝domain 非依存）/ 出力 JSON `{verdict, reason, rubric, lanes, dissent[], output_dir, audit_id}` / exploration rubric=breadth(軸5)+grounding(軸3) / 集約 conservative / exit survived→0・refuted→3（advisory・JSON 正本）/ Stage B メトリクス superset。

## 実装と検証

- `bin/oe-refute` 新規（既存 oe-* 流儀・Bash 3.2 互換）、`bin/README.md` 節追加、`tests/test_oe_refute.sh`（57/0）。`oe-list`/`oe-send`/`spawn.sh` 等は非破壊。
- 実装は cockpit セッションが subagent + 親レビューで実施（#176 と同パターン・bypassPermissions 不要）。
- ゲート（親が独立検証）: shellcheck clean、`bash tests/test_oe_refute.sh` 57/0（system bash 3.2.57 でも green）、回帰（test_delegate_registry / test_oe_select）PASS。

## 実装 SO（欠陥検出・codex+cursor）

実コードに対し `so-compare --with codex,cursor`（option-expansion なし）。両者が同じ欠陥群を捕捉（テスト 41/0 GREEN でも出なかった＝gate の価値）。

| 指摘 | 重大度 | 対応 |
|------|--------|------|
| `VERDICT: survived (not refuted)` で行内 `refuted` を拾い false refuted | 両者 high/med | 修正（VERDICT 直後の token のみ判定） |
| 閉じ `---` 欠落で body 空のまま静かに続行 | 両者 high/med | 修正（fail loud＝exit 2） |
| プロンプトの例示 VERDICT 行をレーンがエコー→誤抽出 | 両者 med | 修正（例をプレースホルダ化＋token 一致で無害化） |
| `-w claim_dir` で body の repo-root 相対参照を解決できない | codex med | 修正（-w=cwd の git root にフォールバック） |
| CRLF frontmatter 非対応 | 両者 low | 修正 |
| rubric default vs 契約「必須」/ 複数行 claim / OUTPUT_DIR 残置 | low | **defer**（default-exploration は寛容拡張・1行 claim は契約準拠・output_dir 残置は意図） |

修正後: ユニット 57/0、shellcheck clean、回帰 PASS。

## closure gate

- **次の消費者**: #183 PR の査読（peer ＋ user＋Copilot で全体査読）。**探索クラスタ step2**（so-compare 呼び→`oe-refute --rubric exploration` 差し替え＋ verdict 書き戻し＝skill 側 PR、verb land 後）。
- **follow-up routing**:
  - defer 3点（rubric required ドリフト / 複数行 claim / output_dir GC）→ 実需が出たら対応。rubric ドリフトは契約author（探索）に PR で共有。
  - Stage B（verify ゲート reject 条件＋探索メトリクス emit、JSON superset で拡張）/ #177 観測 / Stage C #24 → discussion doc のとおり #177 測定後に判断（保留）。
- **status**: stable（達成）。コード + README + ユニット 57/0 + 親レビュー + 設計ゲート(rally) + 実装SO 完了。PR で締め。
- **evidence anchor**: ラリー turn1-12（`/tmp/rally-explore-cockpit/`）、契約 `explore-turn10-claim-contract.md`、実装 SO 出力 `tmp/so-20260618-024341/`（codex/cursor stdout・gitignore 対象）。

## 振り返り（出力型 × 消費チャネル）

### 事実・わかったこと（W）
- **クロスセッション・ラリーが設計 SO の役割を果たせた**: peer による多 turn の反証＋契約確定は、単発 SO より網羅的。oe-send の1行制約は「駆動層 doc + 1行ポインタ」で実用 transport になった。
- 実装 SO は設計ゲート（rally）通過後でも実コード欠陥（verdict 部分一致・閉じ`---`欠落）を捕捉＝**設計 SO と実装 SO は別観点**（[[feedback_engine_driving_layer_flow]]）を再確認。

### 決定と根拠
- backend=so-compare wrap: 既存の枯れた実装の再利用が最薄・最確実（Stage A）。engine-spawn レーンは将来の差し替え余地として残す。
- 実行者=cockpit 直接（案1）: 自律 bypass 子は gate で止まれず（implementation-gate）かつ permission 未承認。ピアセッションが end-to-end 実装まで担えるかのドッグフードにもなった。

### 原則（Pattern / Anti-pattern）
- **Pattern**: LLM レーンの自由出力から機械判定を取るときは、行全体マッチでなく **token を切り出す**（`VERDICT: survived (not refuted)` 部分一致バグの教訓）。
- **Anti-pattern**: プロンプトに実値と同形の例（`VERDICT: refuted`）を載せる → レーンのエコーで誤抽出。プレースホルダ化する。
- **Pattern**: 確定前 forcing（探索）の実体は「別 spawn の反証＋conservative 集約」。engine の既存 gen/refut 分離 substrate に薄く載る。

### 蒸留シグナル
- 昇格候補: なし（コード + discussion doc + 本 episode で十分）。Stage B 着手時に discussion doc を更新。

### 残課題
- defer 3点 / Stage B・C（#177 測定後）。
