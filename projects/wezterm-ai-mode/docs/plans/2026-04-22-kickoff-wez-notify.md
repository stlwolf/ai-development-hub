---
id: 019DB3A8D9BF294BACB5B6
title: "wez notify サブコマンド + Lua 統合方針確定（Phase 1 ステップ 1-3）"
date: 2026-04-22
type: kickoff
status: draft
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/30"
    reason: "本キックオフの対象 Issue"
  - type: parent_epic
    ref: "https://github.com/stlwolf/ai-development-hub/issues/20"
    reason: "Phase 1 Epic"
  - type: depends_on
    ref: "./2026-04-20-kickoff-wez-pane.md"
    reason: "1-2 で確立した pane 操作パターンを前提とする"
  - type: derived_from
    ref: "../../poc/wezterm-ai-mode/04-notification.sh"
    reason: "通知 PoC のコアロジック元"
  - type: derived_from
    ref: "../../poc/wezterm-ai-mode/wezterm-config/ai-mode-events.lua"
    reason: "Lua ハンドラの参考実装"
  - type: design_context
    ref: "../VERIFICATION_MATRIX.md"
    reason: "A-2-3 の検証項目"
  - type: design_context
    ref: "../decisions/ADR-001-cli-file-structure.md"
    reason: "lib/notify.sh 新設は ADR-001 の lib 分割方針に基づく"
  - type: evidence_for
    ref: "../episodes/2026-04-22-episode-wez-notify.md"
    reason: "本キックオフに基づく実装エピソード"
  - type: design_context
    ref: "../decisions/ADR-004-pane-design-decisions.md"
    reason: "send-text パターン、exit code 体系の前提"
  - type: design_context
    ref: "../decisions/ADR-005-bash-shell-standards.md"
    reason: "Bash 3.2 互換ルール"
  - type: reference
    ref: "../CONVENTIONS.md"
    reason: "ドキュメント規約・実行フロー"
  - type: evidence_for
    ref: "../../tmp/peer-review-20260422-135027/review-log.md"
    reason: "設計レビューの SO 比較ログ"
tags: [wez, cli, notify, phase1, bash, user-var, osc1337, lua]
keywords: [wezterm, wez, notify, user-var, SetUserVar, OSC 1337, toast_notification, ai_notify, base64]
use_when:
  - "wez notify サブコマンドを実装するとき"
  - "WezTerm user-var 通知経路の設計を確認するとき"
  - "Lua ハンドラ統合の方針を確認するとき"
---

# wez notify サブコマンド + Lua 統合方針確定（Phase 1 ステップ 1-3）

作業開始前に必ず以下を読むこと:
- `projects/wezterm-ai-mode/CONVENTIONS.md` — ドキュメント規約・Stage 分離フロー
- `projects/wezterm-ai-mode/bin/wez` + `lib/common.sh` + `lib/discover.sh` + `lib/pane.sh` — 既存の構造
- `projects/poc/wezterm-ai-mode/04-notification.sh` — 通知 PoC
- `projects/poc/wezterm-ai-mode/wezterm-config/ai-mode-events.lua` — Lua ハンドラ参考実装
- `projects/wezterm-ai-mode/docs/decisions/` — ADR-001〜005
- `projects/wezterm-ai-mode/docs/episodes/2026-04-20-retro-phase1-1-2.md` — #30 へのプロセス適用指針

## 背景

[Epic #20](https://github.com/stlwolf/ai-development-hub/issues/20) Phase 1 の3番目の実装ステップ。[#28](https://github.com/stlwolf/ai-development-hub/issues/28)（1-1: `wez discover`）で CLI 基盤、[#29](https://github.com/stlwolf/ai-development-hub/issues/29)（1-2: `wez pane`）でペイン操作が確立済み。

本ステップでは AI エージェントが WezTerm のデスクトップ通知を発行するための `wez notify` サブコマンドを実装する。PoC-04 で user-var（OSC 1337 `SetUserVar`）送信は PASSED だが、**Lua イベントハンドラが `.wezterm.lua` 未適用のため PARTIAL PASS**。

### プロセス方針（retro より）

#30 は **#28 寄りの軽量スコープ**（サブコマンド1つ + Lua 統合方針）。arena 不要、キックオフ → so-compare の最短パスで進める。

### #29 からの申し送り事項

- `bin/wez` dispatcher への新 case 追加パターン確立済み
- ソケット取得: `wez_discover_socket()` → `export WEZTERM_UNIX_SOCKET`
- exit code 体系: 0/1/2/3/4/5/64/127（common.sh に定義済み）
- `send-text --no-paste` パターン（`_wez_pane_send` の `printf '%s\n' | wezterm cli send-text`）
- naming: public `wez_` / private `_wez_`
- bash 3.2 互換: `local -n` 禁止、`printf` 優先、空配列展開パターン（ADR-005）

### 確定済みの大方針（peer-ai-review で合意）

- **Phase 1 = CLI のみ**: `wez notify` は user-var を WezTerm ペインに送信するところまでが責務
- **Lua ハンドラは Phase 2**: `.wezterm.lua` への `ai-mode-events.lua` 統合は Phase 2（dotfiles 統合）で実施
- **Lua 統合方針の ADR を作成**: Phase 2 先送りの判断根拠を記録

## 目的

`wez notify "title" "body"` で WezTerm ペインに user-var (`ai_notify`) を送信し、Phase 2 の Lua ハンドラと互換のペイロード形式であること。toast 通知の表示は Phase 2 の検証対象。

## 成功基準

- [ ] `wez notify "title" "body"` が WezTerm ペインに user-var を送信する
- [ ] 送信方式の選定が検証に基づいて決定されている（DJ-1）
- [ ] ペイロード形式が Phase 2 の Lua ハンドラと互換
- [ ] `--pane-id` でペイン指定可、未指定時は auto-detect
- [ ] `--json` で機械可読な結果出力
- [ ] `shellcheck` が全ファイルで通る
- [ ] Lua 統合方針の ADR が作成されている
- [ ] `wez notify --help` でヘルプが表示される

## スコープ

### 対象

- `projects/wezterm-ai-mode/lib/notify.sh` — notify サブコマンドの実装
- `projects/wezterm-ai-mode/bin/wez` — notify ルーティング追加
- `wez notify [options] <title> [body]` — user-var エンコード + WezTerm ペインへ送信
- ペイロード形式: `title|body|timeout`（base64 エンコード、OSC 1337 `SetUserVar`）
- Lua 統合方針の ADR 作成
- `README.md` 更新（notify セクション追加）

### 対象外

- `.wezterm.lua` への Lua ハンドラ統合（Phase 2）
- `.bashrc` の `WEZTERM_UNIX_SOCKET` 自動 export（Phase 2）
- `.tmux.conf` の `allow-passthrough`（Phase 2）
- `sync-bin.sh` への `wez` 追加（Phase 1 ステップ 1-5）
- `wez notify` への user-var 名の汎用化（`ai_status` 等は Phase 2 で検討）

## 設計判断が必要な事項

### DJ-1: 送信方式 — TTY 直接書き込み（実機検証済み・確定）

3 方式を実機検証し、option C（TTY 直接書き込み）を採用。

**実機検証結果（2026-04-22）**:

| 選択肢 | 検証結果 | history 汚染 | プロンプト依存 | Phase 3 互換 |
|--------|---------|-------------|-------------|------------|
| A: command string（PoC 踏襲） | OK | **あり** | **あり** | 致命的制約（agent 作業中のペインで機能しない） |
| B: raw OSC via send-text | **NG** | - | - | - |
| **C: TTY 直接書き込み** | **OK** | **なし** | **なし** | **問題なし** |

**option B が NG の理由**: `send-text` は PTY 入力（キーボード側）にバイトを書き込む。WezTerm は PTY 出力のみで OSC を解釈するため、原理的に動作しない。ESC がシェルの readline に消費され、残りが可視テキストとしてシェルに入力された。

**option C の原理**: `wezterm cli list --format json` の `tty_name` フィールドからペインの TTY デバイス（例: `/dev/ttys013`）を取得し、直接 OSC バイト列を書き込む。TTY slave への書き込みは PTY master 側に転送され、WezTerm のターミナルエミュレータが直接 OSC を解釈する。シェルの stdin を経由しないため、history 汚染もプロンプト状態依存も発生しない。

```bash
# 検証で実行（OK）
TTY=$(wezterm cli list --format json | jq -r '.[0].tty_name')
printf '\033]1337;SetUserVar=ai_notify=%s\007' "$(printf 'Test|Body|5000' | base64 | tr -d '\n')" > "$TTY"
# → history 汚染なし、ペイン表示に汚染なし、exit 0
```

**確定方針**: C（TTY 直接書き込み）を primary。command string（A）を fallback。

**fallback が必要なケース**:
- `tty_name` が JSON に含まれない古い WezTerm バージョン
- SSH セッション経由のペイン（local TTY を持たない）
- TTY デバイスへの書き込み権限がない場合

**option C の注意点**（SO レビューより）:
- vim 等の curses プロセスが前景にある場合、描画上の一時的な干渉の可能性あり（WezTerm の OSC パーサ自体は正常動作するが、curses のカーソル位置管理に影響しうる）
- SSH 経由のリモートペインでは local TTY がないため不可 → command string fallback

### DJ-2: ペイン選択のデフォルト挙動

| 選択肢 | メリット | デメリット |
|--------|---------|----------|
| A: `--pane-id` 必須（Codex 提案） | `pane send` と整合。誤配送防止 | Phase 3 agent 利用時に毎回 pane-id を渡す手間 |
| B: auto-detect フォールバック（Claude 提案） | 手軽。`user-var-changed` は window 単位なのでどのペインでも通知は届く | first pane の決定論性が弱い |

**確定方針**: 2段階フォールバック。

1. `--pane-id <ID>`（明示指定）
2. `wezterm cli list --format json` の最初のペイン（auto-detect）

根拠: notify は「WezTerm ウィンドウへの通知」であり、`pane send`（特定ペインでコマンド実行）とは意味が異なる。`user-var-changed` イベントはペイン単位ではなく window 単位で発火するため、送信先の厳密さは不要。

`$WEZTERM_PANE` について: 実機検証で WezTerm ペイン内に `WEZTERM_PANE=0` が設定されていることを確認済み。ただし primary use case は Cursor → WezTerm（外部）であり、`WEZTERM_PANE` は未設定。YAGNI の観点から Phase 1 では組み込まない。需要が確認されれば Phase 2 以降で追加。

### DJ-3: ペイロード区切り `|` の脆弱性対応

peer-ai-review で Codex・Claude 両者が指摘。Lua ハンドラの `gmatch('[^|]+')` は:
- 空セグメントを消失させる: `"title||4000"` → body が消え timeout が body にずれる
- `|` を含む title/body で壊れる

| 選択肢 | メリット | デメリット |
|--------|---------|----------|
| A: `|` を入力バリデーションで拒否 | 最小変更。Phase 1 で完結。既存 Lua と互換 | UX 制限（`|` を含むメッセージが書けない） |
| B: 区切りを `\x1f` に変更 | 堅牢 | Lua 側の修正が必要 → Phase 2 スコープ越境 |
| C: ペイロードを JSON 化 | 最も拡張性が高い | Lua パーサ書き直し。Phase 1 の CLI 責務を超える |

**暫定方針**: A（Phase 1）。title/body に `|` が含まれる場合は `WEZ_EXIT_USAGE` で拒否。Phase 2 の Lua 統合時に B or C を検討。

空 body の扱い: CLI 側で body が空の場合もペイロードを `title||timeout` として**3フィールド固定**で生成し、Lua 側の `gmatch` パターン修正（`[^|]*` への変更）は Phase 2 の Lua 統合と同時に対応する。Phase 1 では空 body でも Lua ハンドラの既存パーサが `timeout` を `body` と誤認する可能性があるが、Phase 1 では Lua ハンドラ未適用なので**実害なし**。

### DJ-4: タイムアウトフラグの命名

| 選択肢 | メリット | デメリット |
|--------|---------|----------|
| A: `--timeout` | シンプル。PoC 踏襲 | `pane split --timeout`（秒単位）との単位混同リスク |
| B: `--timeout-ms` | 単位が明示的 | フラグ名が長い |

**暫定方針**: A（`--timeout`）。help に `(milliseconds, default: 4000)` と明記。notify の timeout は toast 表示時間であり、`pane split --timeout`（待機タイムアウト）とは用途が異なるため混同リスクは低い。

### DJ-5: base64 エンコーディングの改行対策

macOS の `base64` は長い入力で 76 文字ごとに改行を挿入する。OSC シーケンス内に改行が入ると破損する。

**暫定方針**: エンコード結果を `tr -d '\n'` でストリップ。PoC には対策なし（短い入力で発生しなかったため）。本実装では明示的に対処する。

## ブランチ・コミット・PR 戦略

### ブランチ

```
feature/#30_wez_notify
```

### コミット戦略

| Step | コミットメッセージ例 |
|------|---------------------|
| Step 0 | （コミットなし。検証 + 前提調査のみ） |
| Step 1 | `feat(wez): add notify subcommand with user-var injection` |
| Step 2 | （コミットなし。E2E 検証。不具合は `fix(wez): ...` で修正コミット） |
| Step 3 | `docs(wez): add notify ADR and update verification matrix` |
| Step 4 | （PR 作成） |

### PR

- タイトル: `feat(wez): notify サブコマンド + Lua 統合方針 ADR`
- `Refs #30`
- `--assignee @me`

## 実装計画

### Step 0: 実機検証 + 前提調査（概算: 20分）

**目的**: DJ-1（送信方式）と DJ-2（`WEZTERM_PANE`）の未検証項目を実機で確認し、設計判断を確定させる。

#### 0-1: raw OSC 直接送信の検証（実機検証済み — NG）

raw OSC バイト列を `send-text --no-paste` で直接送信したが、WezTerm は user-var を受理しなかった。`send-text` は PTY 入力（キーボード）にバイトを書き込むため、WezTerm のターミナルエミュレータは OSC を解釈しない（PTY 出力のみで解釈）。ESC がシェルの readline に消費され、残りが可視テキストとしてシェルに入力された。

```
# 検証で実行（NG）
printf '\033]1337;SetUserVar=...\007' | wezterm cli send-text --pane-id 0 --no-paste
# → ペインに「q1337;SetUserVar=ai_notify=...」が可視テキストとして入力
# → -bash: q1337: コマンドが見つかりません
```

command string 方式（option A）は正常動作を確認。その後 SO ゼロベースレビューで option C（TTY 直接書き込み）が提案され、実機検証で成功。**DJ-1 は option C（TTY 直接書き込み）を primary、option A（command string）を fallback に確定。**

#### 0-2: `WEZTERM_PANE` 環境変数の確認（実機検証済み — 存在確認）

WezTerm ペイン内で `WEZTERM_PANE=0` を確認。Cursor 統合ターミナルでは未設定。**存在は確認したが、Phase 1 の DJ-2 優先順位には組み込まない（YAGNI）。**

#### 0-3: 前提確認

- [ ] master が最新か確認（`git pull`）
- [ ] ブランチ作成: `feature/#30_wez_notify`
- [ ] `bin/wez` + `lib/common.sh` の現状確認
- [ ] `lib/pane.sh` の `_wez_pane_send` 実装を精読（send-text パターンの参照）
- [ ] PoC-04（`04-notification.sh`）のロジック精読

!! GATE: 実機検証完了（DJ-1: TTY direct write primary + command string fallback に確定、DJ-2: 2段階フォールバックに確定）。前提確認後に続行。

### Step 1: notify サブコマンド実装（概算: 30分）

`lib/notify.sh` を新規作成し、`bin/wez` にルーティングを追加する。

#### 1-1: 骨格

- [ ] `lib/notify.sh` 作成（shebang + sourced-only ヘッダー）
- [ ] `bin/wez` に `source "$WEZ_ROOT/lib/notify.sh"` 追加
- [ ] `bin/wez` の case 文に `notify)` 追加 → `wez_cmd_notify "$@"` にディスパッチ
- [ ] `wez help` のサブコマンド一覧に `notify` を追加

#### 1-2: `wez_cmd_notify()` 実装

```
Usage: wez notify [options] <title> [body]

Options:
  --pane-id <ID>    Target pane (default: auto-detect first pane)
  --timeout <MS>    Toast duration in milliseconds (default: 4000)
  --socket <path>   WezTerm socket path (default: auto-detect)
  --json            Output result as JSON
  -h, --help        Show help
```

処理フロー:
1. オプションパース（`--socket`, `--pane-id`, `--timeout`, `--json`, `--help`）
2. ソケット解決: `wez_discover_socket "$opt_socket"` → `export WEZTERM_UNIX_SOCKET`
3. title バリデーション: 必須、`|` 禁止、改行禁止
4. body バリデーション: 省略可、`|` 禁止、改行禁止
5. timeout バリデーション: 正の整数（100〜60000）
6. ペイン解決: `--pane-id` 指定あり → そのまま使用。なし → `_wez_notify_auto_pane` で auto-detect
7. ペイロード構築: `title|body|timeout` → base64（`tr -d '\n'`）
8. user-var 送信: `_wez_notify_send_user_var` で OSC 1337 を送信（primary: TTY 直接書き込み、fallback: command string via `send-text`）
9. 結果出力: 成功時は無音。`--json` 時に `{"pane_id": N, "status": "sent", "method": "tty"|"send-text", "title": "...", "timeout": N}`

#### 1-3: ヘルパー関数

- [ ] `_wez_notify_resolve_pane(opt_pane_id)`: `--pane-id` 指定時はその値を使用。未指定時は `wezterm cli list --format json` から最初のペインの `pane_id` と `tty_name` を同時に取得。jq フォールバック（`grep -o` パターン）付き。取得失敗 → `WEZ_EXIT_PANE_NOT_FOUND`
- [ ] `_wez_notify_encode_payload(title, body, timeout)`: `title|body|timeout` を base64 エンコード。`tr -d '\n'` で改行除去
- [ ] `_wez_notify_send_user_var(pane_id, var_name, encoded_value)`: DJ-1 に基づく2段階送信。primary: `wezterm cli list` から `tty_name` を取得し、OSC バイト列を TTY デバイスに直接書き込む。fallback（`tty_name` 取得不可時）: command string 方式で `_wez_pane_send` と同じ `send-text --no-paste` パターンを使用

#### 1-4: 品質チェック

- [ ] `shellcheck` パス（全ファイル）
- [ ] コミット: `feat(wez): add notify subcommand with user-var injection`

### Step 2: E2E 検証（概算: 15分）

```bash
WEZ="./projects/wezterm-ai-mode/bin/wez"
```

- [ ] `$WEZ notify "Test Title" "Test Body"` が正常終了（exit 0）
- [ ] WezTerm debug overlay で user-var `ai_notify` が受信されたことを確認
- [ ] TTY direct write 時: 送信先ペインの shell history に痕跡が**残らない**ことを確認
- [ ] fallback（command string）時: shell history に `printf` コマンドが残ることを確認
- [ ] `$WEZ notify "Title Only"` — body 省略で正常動作
- [ ] `$WEZ notify --pane-id <id> "Test" "Body"` — ペイン指定で正常動作
- [ ] `$WEZ notify --timeout 8000 "Test" "Body"` — timeout 指定
- [ ] `$WEZ notify --json "Test" "Body"` — JSON 出力
- [ ] `$WEZ notify` — title なしで exit 64
- [ ] `$WEZ notify "Bad|Title" "Body"` — `|` 含みで exit 64
- [ ] `$WEZ notify --timeout 0 "Test"` — 範囲外 timeout で exit 64
- [ ] `$WEZ notify --timeout abc "Test"` — 非数値 timeout で exit 64
- [ ] `$WEZ notify --pane-id 99999 "Test"` — 存在しないペインで exit 3
- [ ] `$WEZ notify --help` — ヘルプ表示
- [ ] `shellcheck` が全ファイルで通ること
- [ ] Lua ハンドラ適用済み環境での toast 通知表示（Phase 1 では参考確認。成功基準には含めない）

!! GATE: E2E 全項目パス。失敗がある場合は Step 1 に戻って修正。

!! GATE（必須・停止）: E2E パス後、**ここで停止しユーザーに報告する**。`so-compare` によるコードレビューを実施する。検証観点: DJ-1 の TTY direct write + fallback 実装、base64 エンコード、入力バリデーション、`pane.sh` との一貫性。テスト済みコードに対してレビューすることで、レビュー指摘の手戻りを最小化する。so-compare の指摘対応が完了するまで Step 3 に進まない。

### Step 3: ドキュメント・ADR・記録（概算: 15分）

- [ ] ADR-006: Lua 統合方針（Phase 2 先送りの判断根拠。`require` パターン vs インライン vs Phase 2 dotfiles 統合の比較）
- [ ] ADR-007: notify 送信方式（DJ-1 の検証結果と採用判断）
- [ ] DJ-2〜DJ-5 の判断を ADR-007 に統合 or 個別 ADR 判断
- [ ] `docs/VERIFICATION_MATRIX.md` の A-2-3 を更新
- [ ] `README.md` に notify セクション追加
- [ ] エピソード記録（`docs/episodes/2026-04-22-wez-notify.md`）
- [ ] コミット: `docs(wez): add notify ADR and Lua integration policy`

### Step 4: PR 作成 + Copilot レビュー（概算: 10分 + Copilot 対応）

- [ ] `git fetch origin && git rebase origin/master`
- [ ] `shellcheck` 最終確認
- [ ] PR 本文作成（変更概要、DJ サマリ、E2E 結果、`Refs #30`）
- [ ] `gh pr create --assignee @me --reviewer @copilot`
- [ ] Copilot レビュー対応（3ラウンド上限。収束しない残件は Phase 2 バックログへ）
- [ ] Epic #20 に報告コメント

!! GATE: PR 作成 + CI パス + Copilot 対応完了。

## リスクと対処

| リスク | 影響 | 対処 |
|--------|------|------|
| TTY direct write の画面描画干渉 | vim 等の curses プロセス前景時に一時的な描画乱れの可能性 | README に注意書き。Phase 2 で詳細調査 |
| `tty_name` 取得不可時の fallback 品質 | command string fallback では history 汚染・プロンプト依存が発生 | fallback であることをログ/JSON 出力に明示。Phase 2 で SSH 対応を検討 |
| base64 改行混入が長文 body で OSC を破壊 | 通知が届かない | `tr -d '\n'` で明示的にストリップ（DJ-5） |
| `|` バリデーションで UX が制限される | title/body に `|` が書けない | Phase 1 は許容。Phase 2 で区切り文字変更を検討 |
| Lua ハンドラ未適用で toast が出ない | ユーザー混乱 | README + help に「`.wezterm.lua` に Lua ハンドラが必要」と明記。CLI の責務は user-var 送信まで |
| tmux 内ペインで OSC 1337 が吸収される | tmux 配下では通知が届かない | README に `.tmux.conf` の `allow-passthrough on` 要件を記載。Phase 2 で対応 |

## レビュー戦略（retro #28/#29 準拠）

レビュー順序: so-compare（コードレビュー gate）→ push → PR + Copilot → 最終判断

| タイミング | ツール | 特性 | 上限 |
|-----------|--------|------|------|
| **Step 2 完了後（E2E パス後・PR 前・必須・停止）** | `so-compare` | 少数・構造的（bash 3.2 互換、設計整合性等） | 指摘対応完了まで |
| **Step 4 PR 作成時** | Copilot (`--reviewer @copilot`) | 多数・局所的（バリデーション漏れ、ドキュメント整合等） | 3ラウンド |

so-compare と Copilot の重複はほぼゼロ（#29 retro で確認済み）。so-compare は E2E 完了後のテスト済みコードに対して実施する。未テストコードのレビューは手戻りを生むため、E2E パスを前提条件とする。

## ADR 作成チェックリスト

- [ ] ADR-006: Lua 統合方針（Phase 2 先送り判断の根拠）→ Step 3
- [ ] ADR-007: notify 設計判断（DJ-1 送信方式 + DJ-2〜DJ-5 の統合記録）→ Step 3

## 完了条件

- [ ] `lib/notify.sh` が存在し、`wez notify` サブコマンドが実装されている
- [ ] `bin/wez` に notify ルーティングが追加されている
- [ ] `wez notify "title" "body"` が WezTerm ペインに user-var を送信する
- [ ] ペイロード形式が `title|body|timeout`（base64 エンコード）で Lua ハンドラ互換
- [ ] `--pane-id` でペイン指定可、未指定時は auto-detect
- [ ] `--json` で機械可読な結果出力
- [ ] `--timeout` でタイムアウト指定可（デフォルト 4000ms）
- [ ] title/body の `|` 含有が拒否される
- [ ] `shellcheck` が全スクリプトで通る
- [ ] Lua 統合方針の ADR（ADR-006）が作成されている
- [ ] notify 設計判断の ADR（ADR-007）が作成されている
- [ ] `docs/VERIFICATION_MATRIX.md` の A-2-3 が更新されている
- [ ] `README.md` に notify セクションが追加されている
- [ ] so-compare によるコードレビュー gate を実施し、指摘への対応を記録している
- [ ] PR が作成され `Refs #30` で Issue と連携し、`--reviewer @copilot` でアサインされている
- [ ] Copilot レビュー対応が完了している（3ラウンド上限）

## 実行フロー

CONVENTIONS.md §「フェーズ実行フロー」に従う。

### Stage 1: プラン策定（Agent mode）

1. **コンテキスト読み込み**: 本キックオフ + `CONVENTIONS.md` + 既存コード + PoC-04
2. **プラン作成**: Agent mode で `docs/plans/2026-04-22-plan-wez-notify.md` に作成
3. **peer-ai-review**: プランの合意を取得
4. **CP 確定**: 合意内容をプラン MD に反映し、ユーザーに報告

**← Stage 1 完了後、ここで停止してユーザーに報告する。**

### Stage 2: 実装（Plan mode）

5. **プラン変換**: 確定済みプランを Plan mode のプランに変換
6. **ビルド実行**: TODO に従って実装

### Stage 3: 成果物記録（Agent mode）

7. **成果物記録**: エピソード + ADR + VERIFICATION_MATRIX 更新
8. **キックオフ突合**: 成功基準・完了条件と実装結果を突合し、未達成項目を明示
