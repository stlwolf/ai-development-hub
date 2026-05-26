---
id: "01KSH0G8ZEZ8WX3RPH2D1K80J0"
title: "Issue #109 実装エピソード — 既存ペイン attach 入口 oe-capture（capture グルー + 実wez自己検証）"
date: 2026-05-26
type: episode
status: stable
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/109"
    reason: "本 Episode の対象 Issue"
  - type: source_material
    ref: "projects/orchestration-engine/docs/plans/2026-05-26-plan-issue-109-oe-capture-attach.md"
    reason: "本 Episode が実行した Plan（so-compare 反映済み）"
  - type: source_material
    ref: "projects/orchestration-engine/docs/episodes/2026-05-18-episode-step-4-4-implementation.md"
    reason: "wez pane capture viewport-only セマンティクスの一次資料（Step 4-4）"
tags: [orchestration, phase-5, issue-109, episode, oe-capture, attach, capture-glue, self-verify]
---

# Issue #109 実装エピソード — 既存ペイン attach 入口 oe-capture

## 概要

`bin/oe` の spawn 専用フローとは独立した、**既存（対話中）ペインに attach して終端マーカーを読み取る**
最小入口 `bin/oe-capture` を実装した（#105 Phase 5 dogfood の Slice A）。既存 capture/classify/KVS は無改変、
mock suite は 306 → 335 assertions に増加し全 GREEN。実 wez 自己検証も PASS。

## 何を作ったか

| ファイル | 種別 | 内容 |
|---|---|---|
| `lib/session.sh` | 新規 | `oe_generate_session_id` を `bin/oe` から抽出（spawn/monitor を source せずに id 生成するため lib 化） |
| `bin/oe` | 改修 | ローカル定義を削除し `source lib/session.sh` に置換（挙動不変） |
| `lib/attach.sh` | 新規 | `oe_capture_attach()` グルー: scan→（EXIT検出時）classify→`session_end` audit→write_kvs |
| `bin/oe-capture` | 新規 | 読み取り専用入口。引数解析 + バリデーション + `oe_capture_attach` 呼び出し。末尾ガードで source 可能 |
| `tests/test_attach.sh` | 新規 | mock hermetic テスト（29 assertions）。グルー + 入口バリデーション |
| `tests/e2e_real_agent/self_verify_attach.sh` | 新規 | 実 wez 自己検証（local-only） |

## 設計判断（確定）

- **グルーを `lib/attach.sh` に隔離**: `capture.sh` を純粋（audit 非依存）なまま維持し、`test_capture.sh` の source 前提を崩さない。
- **audit は `session_end`（`payload.source="attach"`）のみ emit**: spawn 無しのため `session_start`/`state_change` は出さない。audit schema は1行単位検証で違反なし（so-compare 両者確認）。`source=attach` で monitor 由来と区別可能。
- **EXIT マーカー未検出は exit 1（未完了）**: `@@OE_VERIFY:` 単独 / マーカー無しを含む。`monitor.sh` が EXIT 以外を「未完了（ポーリング継続）」とする設計と整合。KVS は書かない（誤記録防止）。
- **読み取り専用**: spawn/monitor/cleanup/trap を source しない。ペインを kill しないため対話中ペインを壊さない。

## viewport スコープ契約（option 2）

`wez pane capture --lines N` は viewport の `tail -n N` セマンティクス（Step 4-4 / ADR-004）。
**スクロールアウトしたマーカーは `--lines` 拡大でも回収不能**（verify.sh が tee log 経路に逃げた制約と同一）。
そのため「attach が読める pane の条件」を契約として明文化し、[Issue #109 にコメント](https://github.com/stlwolf/ai-development-hub/issues/109#issuecomment-4535751802)で残した:

- 読めるのは「マーカー規約でコマンドを流し、直前に完了し、まだ追加出力で流れていない pane」の viewport 末尾 N 行
- self-verify（マーカー送出→即読み取り）は必ず viewport 内 → 成立
- スクロールアウト時は incomplete=exit 1、回復策は「マーカーを末尾に再出力して再 capture」

## セカンドオピニオン（so-compare）

実装前に Plan を `so-compare`（Codex + Claude、`tmp/so-20260526-003703`）にかけ、以下を反映:

- **pane_id regex 強化** `^(0|[1-9][0-9]*)$`: 先頭ゼロ（`07`）で `jq --argjson` が `Invalid numeric literal`（RFC 8259）
- **`--session-id` 衝突拒否 + ULID 形式検証**: 既存 state があると `oe_capture_write_kvs` の `mv -f` が verification map を黙って破壊する欠落を両者が指摘。指定 id の state ファイル存在時は exit 2 で拒否。非 ULID は downstream `validate-session-state.sh` 整合のため弾く
- **wez 不在チェック / PROJECT_DIR・mkdir 前提**: `set -u` 下で `${PROJECT_DIR}` ネスト展開が unbound だと abort する点を明記反映
- 実装完了後にも diff へ so-compare を当てる SO ゲート（G6）を Plan に追加

### G6 SO ゲート（実装 diff）で検出・修正したバグ

実装完了後に diff を `so-compare`（`tmp/so-20260526-111125`）にかけたところ、両者一致で **`shift 2` バグ**（Medium）を検出:

- `bin/oe-capture` の `--session-id` / `--lines` が値なしで末尾に来ると（例 `oe-capture 42 --lines`）`$#==1` で `shift 2` が失敗。
  - 実 CLI（`set -e`）: while body 末尾コマンドの失敗で**無言の exit 1**（=「未完了」と誤認）。
  - `set -e` 無効文脈（テストの `|| rc=$?`）: shift が何も消費せず**無限ループ（ハング）**。
- 修正: `[[ $# -ge 2 ]]` ガードを追加し、値欠落時は exit 2 + メッセージ。
- 回帰テスト: `test_attach.sh` に末尾値欠落 2 ケースを追加（29→31 assertions、全 suite 337）。

mock suite GREEN でも見つからなかった実引数エッジを SO ゲートが捕捉した（Plan の SO ゲート追加が機能した実例）。
その他の指摘（自動生成 session_id の衝突チェック無し・SKIP の exit code・wez 不在分岐の mock 不能）は軽微 or 設計通りでスコープ外とした。

## ゲート結果

| ゲート | 内容 | 結果 |
|---|---|---|
| G1 | `bash tests/test_e2e_smoke.sh`（bin/oe 抽出の回帰） | PASS=44 / FAIL=0 |
| G2 | `bash tests/test_attach.sh`（新規） | PASS=29 / FAIL=0 |
| G3 | 全 mock suite（`for f in ./tests/test_*.sh`） | TOTAL PASS=335 / FAIL=0（既存 306 維持 + 新規 29） |
| G4 | `shellcheck bin/oe-capture bin/oe lib/session.sh lib/attach.sh tests/test_attach.sh` | ALL CLEAN |
| G5 | `self_verify_attach.sh`（実 wez） | PASS（state=success / KVS / audit(session_end, source=attach)） |
| G6 | `so-compare`（実装 diff）→ shift バグ修正 → 再検証 | `shift 2` バグ検出・修正、G2 31 / G3 337 / FAIL=0 |

### G5 実機実行の所見（stale socket gotcha）

実行環境（Claude Code の Bash）が**消滅済み WezTerm セッションの `WEZTERM_UNIX_SOCKET`（gui-sock-92240）を継承**しており、
初回は `no WezTerm socket found` で失敗。生きているソケット（`default-org.wezfurlong.wezterm` → gui-sock-38784）を
`WEZTERM_UNIX_SOCKET` で明示指定して PASS。`self_verify_attach.sh` は live な WezTerm セッションを前提とする
（README の e2e_real_agent 同様、socket 不在環境では skip 可）。

## スコープ外（本 Issue では未対応）

- 実 target case への適用（Slice B dogfood）
- `--workspace` 外部出力（#108 側）
- `lib/verify.sh` の `_oe_verify_generate_session_id` は session_id 生成の3個目の重複として残存（寄せるなら別 Issue）
- `capture.sh` の OSC 7/133 エスケープ未除去（capture.sh 無改変方針のため認識のみ）

## 関連
- [Issue #109](https://github.com/stlwolf/ai-development-hub/issues/109) / [viewport スコープ契約コメント](https://github.com/stlwolf/ai-development-hub/issues/109#issuecomment-4535751802)
- Plan: `docs/plans/2026-05-26-plan-issue-109-oe-capture-attach.md`
- `lib/spawn.sh:97`（marker emit 自動注入の手動版）/ Step 4-4 episode（viewport-only）
