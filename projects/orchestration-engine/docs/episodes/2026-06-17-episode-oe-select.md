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

> `oe-list` の宛先候補を fzf（無ければ番号 read）で対話選択し、選んだペインの `%N` を抽出して `oe-send` へ繋ぐ最小 cockpit UI を追加した1サイクル。設計段階で codex+cursor の SO を通し、案 A を「自ペイン既定除外・明示 exit semantics・first-token 抽出・option パススルー」で補強した A' を実装。shellcheck clean / ユニット 26/0 / 既存テスト回帰 PASS。

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
- ゲート（親が独立検証）: `shellcheck` script+test clean、`bash tests/test_oe_select.sh` 26/0、`test_delegate_registry.sh`/`test_oe_delegate.sh` 回帰 PASS。

## closure gate

- **次の消費者**: #176 PR レビュアー（A' 妥当性・exit semantics 確認）。cockpit を使う人間（`oe-select` で選択→送信）。将来 `oe-select` を触る駆動層作業。
- **follow-up routing**:
  - D（lib の構造化 enum: JSON/TSV）→ **defer**。表パースは first-token 限定で現状堅牢。列追加やラベルで send したい要求が出たら #177（観測 UI）と合わせて検討。
  - F（ステートフル宛先 `oe-target set` + `oe-send` target 省略）→ **defer**。同一子への連続追送が頻発したら別 enhancement として issue 化検討。
  - E（tmux popup）/ G（tmux bind）→ **追わない**（現行 shell 起動で足りる。狭ペイン UX が課題化したら再考）。
- **status**: stable（達成）。コード + README + ユニット 26/0 + 親レビュー + 設計 SO ゲート完了。
- **SO ゲートの形**: 本件は SO を**設計段階**で実施（ユーザー指示）。合意した A' を忠実実装→テスト検証したため、設計 SO + 親レビュー + テストでゲート充足とし、実装後 SO の再投入はしていない。
- **evidence anchor**: 設計 SO 出力は `tmp/so-20260617-222442/`（codex/cursor stdout・gitignore 対象）。

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
