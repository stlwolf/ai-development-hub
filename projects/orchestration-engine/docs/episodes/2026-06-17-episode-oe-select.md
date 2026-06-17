---
id: "01KVAX293595K4VVKRABX80H5E"
title: "oe-select — cockpit ペイン宛先セレクタ（fzf/番号フォールバック）追加（#176 駆動層記録）"
date: 2026-06-17
type: episode
status: stable
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/176"
    reason: "本サイクルの Issue（cockpit 最小 UI＝oe-list + fzf 対話セレクタ）"
  - type: design_context
    ref: "https://github.com/stlwolf/ai-development-hub/issues/169"
    reason: "傘 Issue（CLI cockpit リッチ UI 群。oe-list/state/audit を data source に WezTerm+tmux を本線化）"
  - type: design_context
    ref: "projects/orchestration-engine/docs/episodes/2026-06-08-episode-oe-delegate-redesign.md"
    reason: "疎結合 CLI 設計（delegate は spawn+kick に純化、隣接 bin を ${BIN_DIR}/oe-send で呼ぶ）— 本件が踏襲した責務分界"
tags: [orchestration, oe-select, cockpit, fzf, tmux, delegate, episode]
---

# oe-select — cockpit ペイン宛先セレクタ（fzf/番号フォールバック）追加（#176 駆動層記録）

> `oe-list` の宛先候補を fzf（無ければ番号 read）で対話選択し、選んだペインの `%N` を抽出して `oe-send` へ繋ぐ最小 cockpit UI を追加した1サイクル。設計段階で codex+cursor の SO を通し、案 A を「自ペイン既定除外・明示 exit semantics・first-token 抽出・option パススルー」で補強した A' を実装。さらに**設計 SO とは別観点の実装 SO（実コード欠陥検出）**を実施し契約違反4点を修正。shellcheck clean / ユニット 35/0 / 既存テスト回帰 PASS。

## Context / なぜ

#169 で「オーケストレーションの主戦場を WezTerm + tmux（CLI cockpit）に寄せ、Cursor は補助」と方針確定（README 明文化済・PR #180）。その並列トラックの「最小の1点」が #176＝`oe-list` 出力を対話選択して `oe-send` に繋ぐ導線。data source（`oe_reg_list` の `PANE/SOURCE/LABEL`）と送信口（`oe-send`、target に `%N` 素通し可）は既存で、間の対話導線だけが欠けていた。

## 確定した設計（A'）と設計 SO の流れ

初期に形態 3 案を提示しユーザーが A（新規 `bin/oe-select`、end-to-end + 合成）を選択。確定前に設計 SO（`so-compare --with codex,cursor`、選択肢拡張セクション込み）を実施。

- **2者合意**: 案 A が妥当（B=`oe-list --select` は「引数なし一覧」契約を破る／C=純セレクタは `--print` として A に内包）。`%N` 素通しも妥当（行で実体特定済→ラベル再解決は冗長・空白ラベルのパース事故も回避。`%N` は `oe_reg_resolve` の escape hatch として既存契約）。
- **両者が指摘した改善必須点（ゲートの価値）**→ A' に反映:
  - 自ペイン誤送信: `oe_reg_list` は `$TMUX_PANE` 含む全生存ペインを出す → **既定除外 + `--include-self`**。
  - `set -euo pipefail` × fzf cancel: 一覧を先に変数取得し、fzf 非0 を **cancel=130** に明示。
  - option パススルー: `--no-enter` だけでなく **`--kickoff`** も `oe-send` へ。
  - `command -v fzf`（path 固定不可）、preview は `-S -200 … 2>/dev/null || true` で fail-soft、抽出は **first-token のみ**。
- **ゼロベース代替案（選択肢拡張）**: D=lib に JSON/TSV 中間層（表パース廃止・長期堅牢）、E=tmux display-popup、F=ステートフル宛先（連続追送向け）、G=tmux bind（新 bin なし）。いずれも A と直交し #176 のブロッカーではない → follow-up に記録。

確定 CLI 契約: `oe-select [--print|-p] [--no-enter] [--include-self] [--kickoff <path>] [--] [ad-hoc...]`。cancel(ESC/Ctrl-C/空)=130、候補0=1、不正opt=2。

## 実装と検証

- `bin/oe-select` 新規（既存 oe-* 流儀踏襲: コメントヘッダ / `usage()` / `while [[ "${1:-}" == -* ]]` / `oe-select:` プレフィックス / `BIN_DIR` / 隣接 `${BIN_DIR}/oe-send` を exec）。Bash 3.2 互換（`declare -A` 不使用、空配列は `${PASS[@]+"${PASS[@]}"}` でガード）。
- `bin/README.md` に oe-select 節を追記。`oe-list`/`oe-send`/`delegate-registry.sh` は非破壊。
- テスト `tests/test_oe_select.sh`（26/0）: 空白ラベル行 `#142 redesign` からの `%N` 抽出（fzf/番号 両経路）、`--print` の stdout 専用、自ペイン除外/`--include-self`、候補0=1、番号フォールバックの非数値/範囲外/空、fzf cancel=130（送信なし）、`--no-enter`/`--kickoff` の `oe-send` パススルー。テストシーム `OE_SELECT_TTY`（既定 `/dev/tty`、本番未設定）は既存 `OE_*_DIR` 規約と同型。番号フォールバックは system Bash 3.2 でも実行し互換確認。
- ゲート（親が独立検証）: `shellcheck` script+test clean、`bash tests/test_oe_select.sh` 35/0（実装 SO 指摘の修正後）、`test_delegate_registry.sh`/`test_oe_delegate.sh` 回帰 PASS。

## 実装 SO（欠陥検出・設計 SO と別観点）

設計 SO（アプローチ妥当性）とは別観点として、実装後に **実コードの欠陥検出 SO**（`so-compare --with codex,cursor`、option-expansion なし）を実施。設計 SO + テスト GREEN では出ない契約違反・堅牢性欠陥を複数検出した（実装 SO は設計 SO の代替にならない＝両方回す。[[feedback_engine_driving_layer_flow]]）。

| 指摘 | 重大度 | 対応 |
|------|--------|------|
| message 空入力が cancel(130) でなく oe-send 経由 rc1 | 両者 medium | 修正（空入力→exit 130） |
| unknown option が rc2 でなく rc1 | 両者 low | 修正（usage 非 exit 化、unknown→2 / --help→0） |
| 番号 `08`/`09` が 8 進解釈で算術クラッシュ | codex low | 修正（`10#` で 10 進化） |
| fzf 非 cancel エラー / rc0+空も一律 130 | 両者 low | 修正（130/1=cancel、rc>=2=2、空選択=130） |
| 複数行 label/pane_title で候補行偽造→別ペイン送信 | codex medium | **defer**（`oe_reg_list` 出力衛生 + `oe-delegate --label` 改行拒否。oe-select 範囲外・oe-list にも影響） |
| `$TMUX_PANE` 未設定時 self 除外が無効 | cursor medium | **defer/明記**（tmux 内では設定済・`oe_reg_list` 自体 tmux 必須・強制 fail は正当用途を壊す。自入力で復帰可） |
| fzf あり + 非 TTY で番号フォールバック不可 | cursor medium | **defer/明記**（対話専用ツール。非対話は `oe-send %N` 直叩き） |

修正後: ユニット 35/0、shellcheck clean、回帰 PASS（親が独立検証）。

## closure gate

- **次の消費者**: #176 PR レビュアー（A' 妥当性・exit semantics 確認）。cockpit を使う人間（`oe-select` で選択→送信）。将来 `oe-select` を触る駆動層作業。
- **follow-up routing**:
  - D（lib の構造化 enum: JSON/TSV）→ **defer**。表パースは first-token 限定で現状堅牢。列追加やラベルで send したい要求が出たら #177（観測 UI）と合わせて検討。
  - F（ステートフル宛先 `oe-target set` + `oe-send` target 省略）→ **defer**。同一子への連続追送が頻発したら別 enhancement として issue 化検討。
  - E（tmux popup）/ G（tmux bind）→ **追わない**（現行 shell 起動で足りる。狭ペイン UX が課題化したら再考）。
  - 実装 SO defer: 複数行 label/pane_title の候補行偽造 → **issue 化候補**（`oe_reg_list` 出力衛生 + `oe-delegate --label` 改行拒否。oe-list にも共通の cross-cutting）。`$TMUX_PANE` 未設定の self 除外無効 / fzf+非TTY → **明記のみ**（設計限界・対話専用ツール）。
- **status**: stable（達成）。コード + README + ユニット 26/0 + 親レビュー + 設計 SO ゲート完了。
- **SO ゲートの形**: 設計 SO（codex+cursor、A' 確定・選択肢拡張つき）と実装 SO（codex+cursor、実コード欠陥検出・option-expansion なし）の**両方を実施**。観点が違うので設計 SO だけで実装 SO を省略しない。実装 SO 指摘の契約違反4点を修正、cross-cutting/設計限界3点は defer（上記「実装 SO」表）。
- **evidence anchor**: 設計 SO 出力 `tmp/so-20260617-222442/`、実装 SO 出力 `tmp/so-20260617-225419/`（いずれも codex/cursor stdout・gitignore 対象）。

## 振り返り（出力型 × 消費チャネル）

### 事実・わかったこと（W）
- `oe_reg_list` は全生存ペイン（自ペイン含む）を出す。即送信 UI では自ペイン選択＝自分のシェルへ注入の事故経路になる → セレクタ側で既定除外が要る（list 側は非破壊のまま）。
- 人間が「行」を選ぶ UI では `%N` 素通しが最適。ラベル再解決は曖昧一致・空白ラベル・親スコープ差を再導入するだけ。

### 決定と根拠
- 形態 A（独立 bin）: 単機能分離（oe-delegate redesign と同型）。`oe-list` の「引数なし一覧」契約を壊さない。C（純セレクタ）は `--print` として内包。
- cancel=130: 慣習的な SIGINT 相当。`--print` 合成時に空ターゲット送信を防ぐ。

### 原則（Pattern / Anti-pattern）
- **Pattern**: 既存の data source（一覧）と sink（送信）が揃っているなら、間の導線は薄い合成 bin に純化し、両端は非破壊で残す。
- **Anti-pattern**: 人間表示用の固定幅テキストを多列パースする → ラベル空白で壊れる。**first-token だけ**に限定する。
- **Pattern**: 設計確定 SO に選択肢拡張を付け、初期 3 案の外（JSON 層・tmux popup 等）を引き出してから確定する。

### 蒸留シグナル
- 昇格候補: **なし**（コード追加 + 既存 episode 形式で十分。skill/rule/Decision 化は不要）。

### 残課題
- D（構造化 enum）/ F（ステートフル宛先）は defer（上記 routing）。現行は first-token パースで堅牢、実需が出たら再評価。
