---
id: "01KV5YVP42FKC3HSH7WY6MGKM0"
title: "Phase 2 dotfiles 統合（Lua ハンドラ + bashrc socket export）（Issue #86）"
date: 2026-06-16
type: episode
status: stable
related:
  - type: implements
    ref: "https://github.com/stlwolf/ai-development-hub/issues/86"
    reason: "Phase 2: dotfiles 統合で wez notify の toast を開通"
  - type: depends_on
    ref: ../decisions/ADR-006-lua-integration-policy.md
    reason: "Phase 2 先送り判断（選択肢 C: dotfiles 統合）の実装"
  - type: depends_on
    ref: ../decisions/ADR-007-notify-design-decisions.md
    reason: "DJ-3（gmatch 空セグメント問題）の修正を実装"
  - type: evidence_for
    ref: ../VERIFICATION_MATRIX.md
    reason: "A-1-4 を PARTIAL → PASSED に更新した根拠"
tags: [phase2, dotfiles, wezterm, lua, notify, socket, copilot-review]
---

# Phase 2 dotfiles 統合（Lua ハンドラ + bashrc socket export）（Issue #86）

## 概要 / なぜ

Phase 1 で `wez notify` の CLI（OSC 1337 SetUserVar 送信）は完成していたが、toast 表示には `.wezterm.lua` 側の `user-var-changed` → `toast_notification` ハンドラが必要で、ユーザー観点では「無音」だった（ADR-006 が Phase 2 へ先送り）。本 episode は Issue #86 として、dotfiles リポジトリ（`stlwolf/dotfiles`）に Lua ハンドラと socket 自動 export を統合し、toast を開通させた記録。

実装は dotfiles 側で完結（[PR #20](https://github.com/stlwolf/dotfiles/pull/20)、squash merge `0eb96e7`）。hub 側はこの episode + VERIFICATION_MATRIX `A-1-4` + ADR-006 の更新のみ。

tier: **standard**。`episode-retrospective` Step 1 では heavy トリガ（外部レビューレーン=Copilot 使用 / 方針転回 / 非自明な設計判断）に該当するが、owner 判断で standard を採用（理由は §6）。

## 1. 実装内容（dotfiles）

### `.wezterm.lua`（feat, `adcb13a` → 改善 `99c3067`/`97e4411`）

`return config` 直前に既存イベントハンドラと同じインラインスタイルで追加:

- パーサは `string.match('^([^|]*)|([^|]*)|([^|]*)$')` で `title|body|timeout` を固定3フィールド抽出。PoC の `gmatch('[^|]+')` は**空 body セグメントで timeout が body にずれる**問題（ADR-007 DJ-3）があったため修正（Lua の `|` はリテラルで alternation ではない点が固定3フィールド抽出の前提）。
- match 失敗時は生 `value` を title に使うフォールバック（将来の区切り変更=DJ-3 や手動送信に備える）。
- 空 body 時は toast メッセージを `title` のみに（末尾 `: ` を残さない）。
- `ai_notify` / `ai_status` の分岐は `if/elseif`（`name` は排他）。

### `.bashrc`（feat, `adcb13a` → 改善 `99c3067`/`97e4411`）

`is_ai_ide()` の Homebrew ブロック内で、`WEZTERM_UNIX_SOCKET` 未設定時のみ `~/.local/share/wezterm/gui-sock-*` の mtime 最新を自動 export。AI IDE 統合ターミナルへ socket が伝搬しない **stale socket 問題（課題A）** の緩和。socket 探索は `for` + `-nt` 比較ループ（`ls` を使わず ShellCheck SC2012 を回避）、存在チェックは `-S`（socket file。stale な通常ファイルを掴まない）。未設定時のみ・socket 無しなら no-op。

### `.gitignore`（chore, `09a3f7f`）

`tmp/` と `.antigravitycli/` を ignore 化（リポ衛生。#86 とは別論理コミット）。

## 2. 決定と根拠（選択肢比較）

| 論点 | 採用 | 棄却 / 理由 |
|------|------|------------|
| ブランチ運用 | **通常ブランチ（main checkout）** | wt worktree を棄却。dotfiles は symlink デプロイ（`~/.wezterm.lua` → main checkout）で、別ディレクトリの worktree 編集は**ライブ設定に反映されず**、`make validate`（`$HOME/<f>` が `$(PWD)` を指すか検査）も main からでないと成立しない |
| dirty tree の隔離 | **`.wezterm.lua` 1行だけ stash → 作業 → マージ後 pop** | 作業ツリーに無関係な未コミット変更（うち `.wezterm.lua` 1行）が同居。衝突するファイルだけ退避し、#86 コミットを純粋化。他ファイルは `git add` で触れない |
| socket 選択 | **bash `-nt` ループ + `-S`** | `ls -t \| head -1` を棄却（Copilot 指摘 SC2012、非ソケット混入リスク） |
| パーサ堅牢化 | **match 失敗時フォールバック** | 全 nil → `'AI Mode'` への潰れ（内容消失・デバッグ困難）を回避 |
| セカンドオピニオン | **SO なし** | コードは spec 転記 + ADR-007 で peer-review 済のため SO の上積みが薄い。代わりに live toast 実機検証 + 一次情報（WezTerm user-var 仕様）で代替（evidence-verification-rule） |

## 3. わかったこと（W）

- **symlink デプロイ × worktree の非両立**: 配備が固定パスへの symlink の場合、別ディレクトリ worktree での編集はライブに反映されず、ライブ検証・`make validate` が成立しない。symlink デプロイのリポは「main checkout で作業 + dirty tree は部分 stash で隔離」が筋。
- **WezTerm は user-var 値を base64 デコードしてから Lua ハンドラに渡す**: CLI は base64 エンコード送信、ハンドラ受領時は復号済み文字列（live で実証。`ai_notify: test - hello` がログに出た）。PoC が `local decoded = value` と命名していた前提が正しいと確認。
- **`make lint` はハードフェイルしない**: ベースラインで多数の warning 既出・recipe が常に exit 0。新規 finding を出さないことが実質ゲート（SC2012 を残さない判断の根拠）。

## 4. Copilot レビュー（外部レビューレーン）

push のたびに Copilot が新 diff を再レビューし、計 **2 ラウンド・5 スレッド**を対応（全件「対応した」で返信）:

- **R1**（`99c3067`）: socket 選択を `-nt` 化（SC2012 解消） / パーサ match 失敗時フォールバック追加。
- **R2**（`97e4411`）: 存在チェック `-e`→`-S`（非ソケット回避） / 空 body 時 toast を title のみに / `if`→`elseif` 統合。

傾向: 各ラウンドは概ねスタイル/堅牢性の小粒で、ラウンドを追うごとに**収穫逓減**。R2 完了時点で未返信ゼロ、owner 判断でマージ。

## 5. 検証エビデンス（揮発ログの転記）

live toast は `~/.local/share/wezterm/wezterm-gui-log-*.txt`（揮発・ローカル）に出た以下を確認:

```text
lua: ai_notify: test - hello          # 通常
lua: ai_notify: title only -          # 空 body（DJ-3 修正の実証。body が空のままずれない）
lua: ai_notify: rawtest-nopipe -      # パイプ無し生値（フォールバック発火）
lua: ai_status: running               # elseif 分岐
```

- shellcheck: `.bashrc` の新規 finding は SC2012(info) のみ → `-nt` 化で **SC2012 ゼロ**（ベースライン一致）。
- socket ロジック（シェル）: 未設定→最新 export / 既設定→非上書き / socket 無し→ no-op / 非ソケットの同名ファイル→スキップ。
- `make validate`: `OK: .bashrc` / `OK: .wezterm.lua`。
- dotfiles コミット: `adcb13a`（feat）/ `09a3f7f`（chore）/ `99c3067`（fix R1）/ `97e4411`（fix R2）→ squash merge `0eb96e7`（PR #20）。

## 6. 振り返り（closure）

- **次の消費者**: Phase 3（`wez agent` 連携）設計時に Lua ハンドラ / socket export を前提として参照する人。dotfiles の `wez notify` 周りを再訪する人。
- **follow-up routing**: 残課題なし（#86 完了）。`allow-passthrough` は dotfiles #16 で既済のため #86 から除外（追わない）。ローカル `master` の sync とブランチ掃除は owner 環境の運用（追わない）。
- **蒸留シグナル（昇格候補）**: 「symlink デプロイのリポは worktree 不可・main checkout + 部分 stash で隔離」は転用可能な pattern。今回は episode に留め、Decision/skill 昇格は**なし**（単一事例。再発したら negative knowledge #62 へ）。
- **tier 逸脱の明示**: heavy トリガ（Copilot レーン・wt→通常ブランチの方針転回・複数の設計判断）に該当するが、owner が standard を選択。理由は本タスク全体で SO を使わない方針（heavy の Step 4 外部チェックと整合しない）で、self-reported closure とする。
- **status**: stable（達成 — toast 開通を実機確認、hub docs 反映済み）。
