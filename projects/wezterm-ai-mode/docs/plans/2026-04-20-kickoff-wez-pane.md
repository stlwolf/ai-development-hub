---
id: 01KPNAJ2DWCE0DMQJ6MBH1ZJDV
title: "wez pane サブコマンド群（Phase 1 ステップ 1-2）"
date: 2026-04-20
type: kickoff
status: draft
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/29"
    reason: "本キックオフの対象Issue"
  - type: parent_epic
    ref: "https://github.com/stlwolf/ai-development-hub/issues/20"
    reason: "Phase 1 Epic"
  - type: depends_on
    ref: "./2026-04-19-kickoff-wez-entrypoint-discover.md"
    reason: "1-1 で確立した bin/wez + lib/ 構造を前提とする"
  - type: derived_from
    ref: "../../poc/wezterm-ai-mode/02-pane-operations.sh"
    reason: "pane 操作のコアロジック元"
  - type: derived_from
    ref: "../../poc/wezterm-ai-mode/03-output-capture.sh"
    reason: "出力キャプチャのコアロジック元"
  - type: design_context
    ref: "../VERIFICATION_MATRIX.md"
    reason: "A-2-2, A-2-5 の検証項目"
  - type: design_context
    ref: "../decisions/ADR-001-cli-file-structure.md"
    reason: "lib/pane.sh 新設は ADR-001 で規定済み"
  - type: design_context
    ref: "../decisions/ADR-002-socket-selection-strategy.md"
    reason: "ソケット取得パターンは ADR-002 で確定済み"
  - type: reference
    ref: "../CONVENTIONS.md"
    reason: "ドキュメント規約・実行フロー"
tags: [wez, cli, pane, phase1, bash, tmux]
keywords: [wezterm, wez, pane, split-pane, send-text, get-text, kill-pane, tmux, ANSI]
use_when:
  - "wez pane サブコマンド群を実装するとき"
  - "ペイン操作の設計判断を確認するとき"
---

# wez pane サブコマンド群（Phase 1 ステップ 1-2）

作業開始前に必ず以下を読むこと:
- `projects/wezterm-ai-mode/CONVENTIONS.md` — ドキュメント規約・Stage分離フロー
- `projects/wezterm-ai-mode/bin/wez` + `lib/common.sh` + `lib/discover.sh` — 1-1 で確立した構造
- `projects/poc/wezterm-ai-mode/02-pane-operations.sh` — pane 操作の PoC
- `projects/poc/wezterm-ai-mode/03-output-capture.sh` — 出力キャプチャの PoC
- `projects/poc/wezterm-ai-mode/docs/episodes.md` — PoC-02, PoC-03 の制約記録
- `projects/wezterm-ai-mode/docs/VERIFICATION_MATRIX.md` — 検証項目 A-2-2, A-2-5

## 背景

[Epic #20](https://github.com/stlwolf/ai-development-hub/issues/20) Phase 1 の2番目の実装ステップ。[#28](https://github.com/stlwolf/ai-development-hub/issues/28)（1-1: `wez discover`）で CLI エントリポイント + lib 構造 + ソケット検出基盤が確立済み。

本ステップでは AI エージェントが WezTerm 上でペイン操作を行うためのサブコマンド群を実装する。PoC-02（ペイン操作）・PoC-03（出力キャプチャ）で基本動作は PASSED だが、**新ペイン作成後の tmux auto-attach タイミング問題**（PoC-02 の Step 5 で空出力）が既知制約として残っている。

### #28 からの申し送り事項

- `bin/wez` dispatcher に `pane` を `case` に追加するだけで拡張可能
- ソケット取得パターン: `source lib/discover.sh` → `wez_discover_socket()` → `WEZTERM_UNIX_SOCKET` セット
- exit code 体系: 0=成功, 1=未検出, 2=接続失敗, 64=usage, 127=wezterm未インストール
- stderr 制御: `--json`/`--quiet`/`--verbose` の3フラグ体系を踏襲推奨
- `local -n` 禁止（bash 3.2 互換）
- Copilot レビュー対策: 修正は一括、対応不要のみの場合は push しない

## 目的

`wez pane` サブコマンド群（list / split / send / capture / kill）を実装し、AI エージェントが Cursor 統合ターミナルから WezTerm 上のペインを操作できるようにする。

## 成功基準

- [ ] `wez pane list` が WezTerm のペイン一覧を JSON で出力する
- [ ] `wez pane split` が新しいペインを作成し、pane_id を返す
- [ ] `wez pane send <pane-id> "command"` がペインにコマンドを送信する
- [ ] `wez pane capture <pane-id>` がペインの出力をキャプチャし、ANSI ストリップして返す
- [ ] `wez pane kill <pane-id>` がペインを削除する
- [ ] tmux auto-attach タイミング問題に対する設計判断が記録されている
- [ ] `shellcheck` が全ファイルで通る
- [ ] `wez pane --help` でサブコマンド一覧が表示される

## スコープ

### 対象

- `projects/wezterm-ai-mode/lib/pane.sh` — pane サブコマンド群の実装
- `projects/wezterm-ai-mode/bin/wez` — pane ルーティング追加
- `wez pane list` — ペイン一覧（JSON 出力）
- `wez pane split [--right|--bottom]` — ペイン分割
- `wez pane send <pane-id> "command"` — コマンド送信
- `wez pane capture [pane-id] [--lines N]` — 出力キャプチャ（ANSI ストリップ）
- `wez pane kill <pane-id>` — ペイン削除
- tmux タイミング対処の設計判断（ADR）
- `lib/common.sh` への pane 固有 exit code 追加（必要に応じて）

### 対象外

- `wez notify` サブコマンド（[#30](https://github.com/stlwolf/ai-development-hub/issues/30)）
- `sync-bin.sh` への `wez` 追加（Phase 1 ステップ 1-5）
- dotfiles 統合（Phase 2）
- タイミング問題の完全解決（ポーリング実装を含める場合は本 Issue、含めない場合は設計判断のみ記録して follow-up Issue 化）

## 設計判断が必要な事項

### DJ-1: tmux auto-attach タイミング問題への対処

PoC-02 で確認された問題: `wez pane split` → `wez pane send` の間に tmux auto-attach が完了していないと、コマンドがロストする。`wez pane capture` も同様に空出力になる。

| 選択肢 | メリット | デメリット |
|--------|---------|----------|
| A: sleep（固定ウェイト） | 最もシンプル。`sleep 2` 等で対処 | 環境依存で不安定。遅いマシンでは不十分、速いマシンでは無駄 |
| B: ポーリング（プロンプト検出） | 確実。`get-text` でプロンプト文字列が現れるまで待機 | プロンプト文字列の特定が難しい（starship, bash, zsh でパターンが異なる）。タイムアウト設計が必要 |
| C: AI Mode 専用ペイン（tmux スキップ） | タイミング問題自体が発生しない | `.bashrc` の `is_ai_ide()` を拡張する必要がある。dotfiles リポジトリへの変更を伴う |
| D: 何もしない（呼び出し側の責務） | `wez` CLI のスコープ最小化 | 呼び出し元（AI エージェント）が毎回自前で待機処理を書く必要がある |
| E: `--wait-ready` フラグ | opt-in でポーリング。デフォルトは即返却 | B の複雑さを opt-in で限定できるが、ポーリング実装自体は必要 |

**暫定方針**: E（`--wait-ready` フラグ）+ D を組み合わせ。`wez pane split` はデフォルトで即座に pane_id を返し、`--wait-ready` 指定時のみ出力が安定するまでポーリングして待機する。タイムアウトはデフォルト 10 秒。

**ポーリング判定ロジック（arena R1 + 実装設計レビューで改善）**: 行数変化のみの判定では split 直後の空出力時に「0行→0行=変化なし」で即 ready 誤判定するリスクがある（PoC-02 の空出力問題の再発）。以下の2条件を AND で判定する:
1. **非空条件**: `get-text` の出力に空白以外の文字が1文字以上存在する（pure bash: `[[ "$curr" == *[!$' \t\n']* ]]`。`grep -q` はサブシェル起動コストがポーリングループ毎に発生するため回避）
2. **内容安定**: `get-text` の取得結果（**末尾 N 行のみ**）が前回と同一で、これが連続2回続いたら ready。全体比較ではなく末尾限定とするのは、tmux ステータスバーの時計等が周期更新するため全体比較だと「安定」に到達しない可能性があるため

比較方式: 文字列比較 `[[ "$curr" == "$prev" ]]` で十分（diff/md5 は過剰）。比較対象は `get-text --start-line -5` 等で末尾を絞る。

ポーリング間隔: 0.5 秒、タイムアウト: デフォルト 10 秒。タイムアウト時は stderr に警告 + `WEZ_EXIT_TIMEOUT` で返却。`--wait-ready` は best-effort であり、完全な保証ではない（help / ADR に明記）。

**Scope creep 対策**: ポーリング実装が難航した場合は、固定 `sleep 2` による暫定対処にとどめ、高度なポーリングは別 Issue に切り出す。この場合、`--wait-ready` フラグ自体は実装せず、E2E の `--wait-ready` 検証項目はスキップ（エピソードにスキップ理由を記録）。成功基準の「タイミング問題に対する設計判断が記録されている」は ADR で満たす。

### DJ-2: pane サブコマンドのファイル構成

| 選択肢 | メリット | デメリット |
|--------|---------|----------|
| A: 単一 `lib/pane.sh` に全5サブコマンド | シンプル、discover.sh と同じパターン | 5コマンド + ヘルパーで 300-500 行になる見込み |
| B: `lib/pane.sh`（dispatcher）+ `lib/pane/*.sh` | コマンドごとに独立 | ディレクトリ増加、source チェーンが深くなる |

**暫定方針**: A（単一 `lib/pane.sh`）。discover.sh と同じパターンを踏襲。5コマンドは各 30-60 行程度で、1ファイルに収まるスケール感。肥大化したら Phase 2 で分割。ファイル内の配置順は **ヘルパー先頭・ディスパッチャ末尾**: `_wez_pane_exists` / `_wez_wait_pane_ready` / `_wez_strip_*` → `_wez_pane_list` / `_wez_pane_split` / ... → `wez_cmd_pane`（discover.sh と関数数が異なるため、前方参照を避ける構成）。命名: public は `wez_` prefix（`wez_cmd_pane`）、private は `_wez_` prefix（`_wez_pane_list` 等）で discover.sh と統一。

### DJ-3: 出力設計（discover パターンの踏襲度）

discover で確立した `--json`/`--quiet`/`--verbose` の3フラグ体系を pane サブコマンドでも踏襲するか。

| サブコマンド | デフォルト stdout | `--json` stdout | 特記 |
|-------------|------------------|-----------------|------|
| `pane list` | JSON そのまま（wezterm cli list --format json の出力） | 同左（デフォルトが JSON） | list は元々 JSON 出力なので `--json` フラグ不要？ |
| `pane split` | pane_id のみ（1行） | `{"pane_id": N}` | split 直後の情報 |
| `pane send` | なし（成功時は無出力） | `{"status": "sent", "pane_id": N}` | 送信確認 |
| `pane capture` | キャプチャ結果（テキスト） | キャプチャ結果（テキスト、JSON ではない） | `--json` で `{"output": "...", "lines": N}` とするか？ |
| `pane kill` | なし（成功時は無出力） | `{"status": "killed", "pane_id": N}` | 削除確認 |

**暫定方針**: 
- `--quiet`/`--verbose` は全サブコマンドで共通（stderr 制御パターン踏襲）
- `--json` は `pane list` ではデフォルト動作のため不要。`pane split`/`send`/`kill` では opt-in で提供
- `pane capture` の `--json` は Phase 1 では見送り（テキスト出力が自然な用途）

### DJ-4: ソケット取得の共通化

各 pane サブコマンドで毎回ソケットを discover するか、`wez pane` レベルで1回だけ取得するか。

| 選択肢 | メリット | デメリット |
|--------|---------|----------|
| A: `wez_cmd_pane()` で1回取得 → 各サブコマンドに渡す | discover 1回で済む。パフォーマンス良好 | `wez_cmd_pane` が全サブコマンドの前処理を一括で行う構造になる |
| B: 各サブコマンドが個別に `wez_discover_socket()` を呼ぶ | 独立性が高い。単体テスト容易 | 同じソケットを5回 discover する可能性。2重接続確認問題が悪化 |

**暫定方針**: A（`wez_cmd_pane` で1回取得）。`wez_cmd_pane()` 内で `socket=$(wez_discover_socket "$opt_socket") || exit_code=$?` → `export WEZTERM_UNIX_SOCKET="$socket"` とし、以降の各 `_wez_pane_*` 関数には引数で socket を渡さない。`wezterm cli` の各サブコマンドは `WEZTERM_UNIX_SOCKET` 環境変数を暗黙に参照する仕様なので、export だけで全コマンドに伝搬する。引数で回さないことで pane_id / command / options と混在しない。ADR-001 §「export 非伝搬の制約」は呼び出し元シェルへの伝搬の問題であり、wez プロセス内の export は問題ない。`--socket` オプションは `wez pane --socket <path> list` のようにサブコマンドより前に書く規約（`git --git-dir=X log` と同じ。help に明記）。

### DJ-5: ANSI ストリップの方式

`wez pane capture` で ANSI エスケープシーケンスを除去する方法。

| 選択肢 | メリット | デメリット |
|--------|---------|----------|
| A: `sed` ベース（PoC-03 方式） | 外部依存なし。`sed 's/\x1b\[[0-9;]*[a-zA-Z]//g'` | 複雑なシーケンス（OSC 等）のカバー漏れあり |
| B: `perl -pe` | 正規表現が強力。OSC も含めて除去可能 | perl 必須（macOS にはプリインストール） |
| C: `--raw` フラグでストリップをオプション化 | 用途に応じて選択可能 | デフォルトの挙動を決める必要がある |

**暫定方針（実装設計レビューで修正）**: `wezterm cli get-text` はデフォルトでエスケープシーケンスを含めない（`--escapes` フラグ指定時のみ含む）。そのため:
- **デフォルト**: `get-text`（エスケープなし）+ `strip_trailing_blank`（末尾空行除去）。ANSI strip 処理は不要
- **`--raw`**: `get-text --escapes`（エスケープ含む生出力）。末尾空行除去もスキップ
- PoC-03 の `strip_ansi` は `--escapes` 付き出力を前提としていた。Phase 1 のデフォルトでは不要だが、`_wez_strip_ansi` 関数は `lib/pane.sh` に用意しておく（将来の `--escapes` 対応用）。移植時に OSC ST 終端パターン（`ESC ] ... ESC \`）も追加推奨（PoC-03 は BEL 終端のみ対応）

### DJ-6: `pane send` の入力方式

| 選択肢 | メリット | デメリット |
|--------|---------|----------|
| A: 引数のみ: `wez pane send <pane-id> "command"` | シンプル、PoC-02 と同じ | 複数行コマンドが送れない。シェルのクォート処理が複雑になる |
| B: stdin: `echo "command" \| wez pane send <pane-id>` | パイプで柔軟に入力可能。複数行対応 | stdin がない場合のエラーハンドリングが必要 |
| C: 引数優先 + `--stdin` フラグ | 両方対応 | 実装が複雑になる |

**暫定方針**: A（引数のみ）。PoC-02 と同じパターンで `printf '%s\n' "$command" | wezterm cli send-text --pane-id "$pane_id" --no-paste` を内部で実行。`--no-paste` 必須（なしだと bracketed-paste で囲まれ、bash/zsh がペーストバッファとして蓄積し Enter 押下まで実行されない）。Phase 1 では単一行コマンドに限定し、**引数に改行・CR が含まれる場合は拒否**（改行があると複数コマンドが送信され意図しない挙動になるため）。バリデーション: `[[ "$command" == *$'\n'* || "$command" == *$'\r'* ]]` でチェック。制御文字（`\x03` 等）の送信は Phase 1 スコープ外（help に「plain text only」と明記）。

### DJ-7: pane 固有の exit code

| 用途 | コード | 既存との関係 |
|------|--------|-------------|
| 指定 pane_id が存在しない | 3 | 新規。1（未検出）はソケット用、2（接続失敗）もソケット用 |
| send/capture のタイムアウト | 4 | 新規。`--wait-ready` のタイムアウト |
| pane 操作失敗（kill 失敗、send 失敗等） | 5 | 新規。exit 1（ソケット未検出）との意味混線を回避 |

**暫定方針**: 3=pane not found, 4=timeout, 5=pane operation failed を追加。`common.sh` に `WEZ_EXIT_PANE_NOT_FOUND=3`, `WEZ_EXIT_TIMEOUT=4`, `WEZ_EXIT_PANE_OP_FAILED=5` を追加。exit 1 は「ソケット未検出」に固定し、pane 操作の失敗には使わない（ADR-002 の体系との一貫性）。

## ブランチ・コミット・PR 戦略

### ブランチ

```
feature/#29_wez_pane_subcommands
```

### コミット戦略

| Step | コミットメッセージ例 |
|------|---------------------|
| Step 0 | （コミットなし。ブランチ作成 + 前提調査のみ） |
| Step 1 | `feat(wez): add pane routing and lib/pane.sh skeleton` |
| Step 2 | `feat(wez): implement pane list and split subcommands` |
| Step 3 | `feat(wez): implement pane send, capture, and kill subcommands` |
| Step 4 | （コミットなし。E2E 検証。不具合は `fix(wez): ...` で修正コミット） |
| Step 5 | `docs(wez): add pane ADRs and update verification matrix` |
| Step 6 | （PR 作成） |

### PR

- タイトル: `feat(wez): pane サブコマンド群（list/split/send/capture/kill）`
- `Refs #29`
- `--assignee @me`

## 実装計画

### Step 0: 前提調査 + ブランチ作成（概算: 15分）

#28 の成果物が master に反映されていることを確認し、PoC-02/03 のロジックを精読する。

- [ ] master が最新か確認（`git pull`）
- [ ] ブランチ作成: `feature/#29_wez_pane_subcommands`
- [ ] `bin/wez` + `lib/common.sh` + `lib/discover.sh` の現状確認（#28 の成果物）
- [ ] PoC-02（`02-pane-operations.sh`）の全ロジックを精読
- [ ] PoC-03（`03-output-capture.sh`）の全ロジックを精読（特に `strip_ansi` / `strip_trailing_blank`）
- [ ] `wezterm cli split-pane --help` の出力確認（`--right`, `--bottom`, `--percent` 等のフラグ体系）
- [ ] `wezterm cli send-text --help` の出力確認（`--no-paste`, `--pane-id` 等）
- [ ] `wezterm cli get-text --help` の出力確認（`--pane-id`, `--start-line`, `--end-line` 等）
- [ ] `wezterm cli kill-pane --help` の出力確認
- [ ] `wezterm cli split-pane` が `--pane-id` で分割元ペインを指定できるか確認（指定不可の場合、GUI フォーカス依存で AI 利用時の再現性リスク）
- [ ] 新ペイン作成 → tmux auto-attach 完了までの所要時間を計測（`split-pane` → `get-text` で出力が現れるまで）
- [ ] `wezterm cli list --format json | jq '.[0]'` で JSON のフィールド構造を確認

!! GATE: 前提確認完了。wezterm CLI のフラグ体系が PoC と乖離していなければ続行。

### Step 1: pane ルーティング + lib/pane.sh 骨格（概算: 20分）

`bin/wez` に pane ルーティングを追加し、`lib/pane.sh` の骨格を作る。

- [ ] `lib/pane.sh` を作成（shebang + sourced-only ヘッダー）
- [ ] `common.sh` に pane 固有 exit code を追加: `WEZ_EXIT_PANE_NOT_FOUND=3`, `WEZ_EXIT_TIMEOUT=4`, `WEZ_EXIT_PANE_OP_FAILED=5`
- [ ] `bin/wez` に `source "$WEZ_ROOT/lib/pane.sh"` を追加
- [ ] `bin/wez` の case 文に `pane)` を追加 → `wez_cmd_pane "$@"` にディスパッチ
- [ ] `wez_cmd_pane()` 骨格: 2段階パース — 第1段で `--socket` 等の共通オプション + サブコマンド名を抽出し `break`、第2段でサブコマンドに残り引数を `"$@"` で丸渡し。`--socket` はサブコマンドより前に書く規約
- [ ] ソケット取得: `socket=$(wez_discover_socket "$opt_socket") || exit_code=$?` → `export WEZTERM_UNIX_SOCKET="$socket"` → サブコマンド分岐（list/split/send/capture/kill/help）
- [ ] set -e 対策方針: 全 `wezterm cli` 呼び出しを `if ! wezterm cli ...; then` または `result=$(...) || rc=$?` で囲み、`set -e` による即死を防止（discover.sh の `|| exit_code=$?` パターンを踏襲）
- [ ] `wez pane --help` / `wez pane help` の表示
- [ ] 各サブコマンド関数のスタブ作成（シグネチャ + `echo "not implemented"` + `return 0`）
- [ ] `wez help` のサブコマンド一覧に `pane` を追加
- [ ] `shellcheck` パス
- [ ] コミット: `feat(wez): add pane routing and lib/pane.sh skeleton`

### Step 2: pane list + pane split 実装（概算: 30分）

PoC-02 の split-pane ロジックと wezterm cli list の JSON 出力を実装。

- [ ] `_wez_pane_list()`: `WEZTERM_UNIX_SOCKET` セット済みの前提で `wezterm cli list --format json` を実行
  - デフォルト: JSON をそのまま stdout に出力（jq で整形）
  - `--quiet`: stderr 抑制
  - `--verbose`: pane 数を stderr に出力
- [ ] `_wez_pane_split()`: `wezterm cli split-pane` のラッパー
  - `--right`（デフォルト）/ `--bottom` / `--percent N`（デフォルト 50）
  - stdout: 新しい pane_id を出力
  - `--json`: `{"pane_id": N}` を出力
  - `--wait-ready`: split 後にペインの出力が安定するまでポーリング（DJ-1: E）
- [ ] ポーリングロジック（DJ-1 改善版）: 以下の2条件を AND で判定
  - 非空条件: `get-text` 出力に空白以外の文字が1文字以上
  - 内容安定: 前回の `get-text` 結果と同一が連続2回
  - タイムアウト: デフォルト 10 秒（bash 内部ループで実装。macOS に GNU `timeout` がないため）
  - ポーリング間隔: 0.5 秒
  - タイムアウト時は stderr に警告 + `WEZ_EXIT_TIMEOUT` で返却
- [ ] `shellcheck` パス
- [ ] コミット: `feat(wez): implement pane list and split subcommands`

### Step 3: pane send + capture + kill 実装（概算: 30分）

残りの3サブコマンドを実装。

- [ ] `_wez_pane_send()`: `if ! printf '%s\n' "$command" | wezterm cli send-text --pane-id "$pane_id" --no-paste 2>/dev/null; then` で set -e 即死を防止
  - 引数: `<pane-id> <command>`
  - 改行・CR バリデーション: `[[ "$command" == *$'\n'* || "$command" == *$'\r'* ]]` で拒否
  - pane_id 存在確認: 事前確認ではなく**まず本命操作を実行し、失敗時のみ `_wez_pane_exists` で存在確認して exit 3/5 を振り分ける**（成功パスのオーバーヘッド削減）
  - `--json`: `{"status": "sent", "pane_id": N}`
- [ ] `_wez_pane_capture()`: `wezterm cli get-text --pane-id "$pane_id"`
  - `--lines N`: `--start-line -N` で直近 N 行を取得（デフォルト: viewport 全体）
  - デフォルト: `get-text`（エスケープなし）+ 末尾空行除去（`strip_trailing_blank` 移植）
  - `--raw`: `get-text --escapes`（エスケープ含む生出力）。末尾空行除去もスキップ
- [ ] `_wez_pane_kill()`: `if ! wezterm cli kill-pane --pane-id "$pane_id" 2>/dev/null; then` で set -e 即死を防止
  - pane_id 存在確認: send と同様、失敗時のみ `_wez_pane_exists` で確認して exit code 振り分け
  - `--json`: `{"status": "killed", "pane_id": N}`
  - 非対話で即削除（PoC-02 の `read -p` による対話的確認は CLI ツールに不適切なため排除。ADR に理由記載）
- [ ] `shellcheck` パス
- [ ] コミット: `feat(wez): implement pane send, capture, and kill subcommands`

!! GATE（必須 — スキップ不可）: Step 2-3 完了後、`so-compare.sh` によるコードレビューを実施。`set -euo` 漏れ、引用処理、discover との一貫性、ポーリングロジックの健全性を検出。#28 で gate がスキップされ、`local -n` 互換性バグや stderr 漏出が事後発見された教訓に基づく（shellcheck + E2E では検出できない実行時・互換性の問題を so-compare が拾う）。

### Step 4: E2E 検証（概算: 20分）

```bash
WEZ="./projects/wezterm-ai-mode/bin/wez"
```

- [ ] `$WEZ pane list` でペイン一覧が JSON で出力されること（`jq .` でパース確認）
- [ ] `$WEZ pane split --right` で新ペインが作成され pane_id が返ること
- [ ] 作成されたペインが WezTerm 上に表示されていること
- [ ] `$WEZ pane send <id> "echo hello"` でコマンドが送信されること
- [ ] `$WEZ pane capture <id>` で "hello" を含む出力がキャプチャされること（tmux タイミングに注意: `--wait-ready` or `sleep` 後）
- [ ] `$WEZ pane capture <id> --raw` で ANSI シーケンスが含まれる出力が返ること
- [ ] `$WEZ pane capture <id> --lines 5` で直近5行のみ返ること
- [ ] `$WEZ pane kill <id>` でペインが削除されること
- [ ] 存在しない pane_id に対して `send`/`capture`/`kill` がエラーを返すこと（exit 3）
- [ ] `$WEZ pane split --wait-ready --timeout 1` で短いタイムアウトを設定し、タイムアウト時に exit 4 が返ること
- [ ] pane 操作失敗時に exit 5 が返ること（kill 済み pane への send 等）
- [ ] `$WEZ pane --help` でサブコマンド一覧が表示されること
- [ ] `$WEZ pane split --wait-ready` でポーリングが動作し、ready 後に返却されること（`--wait-ready` 実装の場合。sleep フォールバック時はこの項目をスキップし、エピソードにスキップ理由を記録）
- [ ] `shellcheck` が全ファイルで通ること

!! GATE: E2E 全項目パス。失敗がある場合は Step 2-3 に戻って修正。

### Step 5: ドキュメント・ADR・記録（概算: 15分）

- [ ] DJ-1（tmux タイミング対処）の判断結果を ADR に記録
- [ ] DJ-2〜DJ-7 で ADR 基準（2つ以上の選択肢比較）に該当するものを記録
- [ ] `docs/VERIFICATION_MATRIX.md` の A-2-2 を更新（pane 系 PASSED）
- [ ] A-2-5（tmux auto-attach 後のコマンド送信）を更新
- [ ] エピソード記録（`docs/episodes/2026-04-20-wez-pane.md`）
- [ ] コミット: `docs(wez): add pane ADRs and update verification matrix`

### Step 6: PR 作成（概算: 10分）

- [ ] `git fetch origin && git rebase origin/master`
- [ ] `shellcheck` 最終確認
- [ ] PR 本文作成（変更概要、DJ サマリ、E2E 結果、`Refs #29`）
- [ ] `gh pr create --assignee @me`
- [ ] Epic #20 に報告コメント

!! GATE: PR 作成 + CI パス。

## リスクと対処

| リスク | 影響 | 対処 |
|--------|------|------|
| tmux auto-attach の完了待ちが不安定 | `send`/`capture` の E2E が非決定的に失敗 | `--wait-ready` のポーリングで対処。タイムアウトあり |
| `wezterm cli get-text` の出力に tmux ステータスバーが含まれる | capture 結果にノイズが入る | PoC-03 で確認済み。`--start-line` でオフセット制御。Phase 1 では許容 |
| starship プロンプトの装飾文字が ANSI ストリップで残る | capture 結果が汚い | `sed` の正規表現を拡張。完全除去は Phase 2 |
| `wezterm cli split-pane` のフラグ体系が PoC-02 と異なる | 実装の前提が崩れる | Step 0 で `--help` 出力を確認 |
| pane_id の存在確認で `wezterm cli list` を毎回呼ぶ | パフォーマンス低下（特に send で連続呼び出し時） | Phase 1 では許容。Phase 2 でキャッシュ検討 |
| `local -n` 禁止による実装制約 | 関数間のデータ受け渡しが冗長 | グローバル変数 or stdout 返却パターン（#28 の `_WEZ_SORTED_SOCKETS` と同じ） |
| Copilot レビューの無限ループ | push のたびに新レビュー | #28 の学び: 修正は一括、対応不要のみの場合は push しない |
| PoC-02 の `python3 -m json.tool` 依存 | `jq` がない環境でフォールバックが必要 | `jq` 推奨。不在時は整形なしで raw JSON 出力 |
| macOS に GNU `timeout` コマンドが不在 | ポーリングのタイムアウト実装に使えない | bash 内部ループ（`while` + `sleep` + カウンタ）で自前タイムアウト管理。#28 の学び |
| `split-pane` の対象が GUI フォーカス依存の場合 | 意図しないペインに分割・操作してしまう | Step 0 で `--pane-id` 指定可否を確認。指定不可なら help/ADR にリスク明記 |

## peer-ai-review 実施ポイント

1. **Step 3 完了後（必須）**: pane 実装のコードレビュー（`so-compare.sh`）。`set -euo` 漏れ、引用処理、discover との一貫性、ポーリングロジックの健全性を検出
2. **Step 4 完了後（任意）**: E2E 結果を踏まえた全体レビュー

## ADR 作成チェックリスト

- [ ] DJ-1: tmux タイミング対処（`--wait-ready` + ポーリング方式の採否）→ `ADR-003-tmux-timing-strategy.md`
- [ ] DJ-2: pane ファイル構成 → ADR-001 の結果セクションに追記（新 ADR 不要の場合）
- [ ] DJ-4: ソケット取得の共通化 → ADR-001 に追記 or 独立 ADR
- [ ] DJ-5: ANSI ストリップ + 末尾空行除去方式 → 独立 ADR が妥当なら作成
- [ ] DJ-7: pane 固有 exit code（3/4/5） → ADR-002 に追記
- [ ] kill の非対話設計（PoC-02 の `read -p` 排除）→ ADR に理由記載

## 完了条件

- [ ] `lib/pane.sh` が存在し、5つのサブコマンド（list/split/send/capture/kill）が実装されている
- [ ] `bin/wez` に pane ルーティングが追加されている
- [ ] `wez pane list` が valid JSON を返す
- [ ] `wez pane split` が pane_id を返す
- [ ] `wez pane send` がコマンドを正常送信する
- [ ] `wez pane capture` が ANSI ストリップ済みテキストを返す
- [ ] `wez pane kill` がペインを削除する
- [ ] `shellcheck` が全スクリプトで通る
- [ ] tmux タイミング問題の設計判断が ADR に記録されている
- [ ] `docs/VERIFICATION_MATRIX.md` の A-2-2, A-2-5 が更新されている
- [ ] `wez pane --help` でサブコマンド一覧が表示される
- [ ] so-compare によるコードレビュー gate を実施し、指摘への対応を記録している（#28 の gate スキップ教訓）
- [ ] PR が作成され `Refs #29` で Issue と連携している
- [ ] Issue #29 の全チェックボックスが完了または設計判断で対処方針が決定している

## 実行フロー

CONVENTIONS.md §「フェーズ実行フロー」に従う。

### Stage 1: プラン策定（Agent mode）

1. **コンテキスト読み込み**: 本キックオフ + `CONVENTIONS.md` + PoC-02/03 + #28 成果物
2. **プラン作成**: Agent mode で `docs/plans/2026-04-20-plan-wez-pane.md` に作成
3. **peer-ai-review**: プランの合意を取得
4. **CP 確定**: 合意内容をプラン MD に反映し、ユーザーに報告

**← Stage 1 完了後、ここで停止してユーザーに報告する。**

### Stage 2: 実装（Plan mode）

5. **プラン変換**: 確定済みプランを Plan mode のプランに変換
6. **ビルド実行**: TODO に従って実装

### Stage 3: 成果物記録（Agent mode）

7. **成果物記録**: エピソード + ADR + VERIFICATION_MATRIX 更新
8. **キックオフ突合**: 成功基準・完了条件と実装結果を突合し、未達成項目を明示
