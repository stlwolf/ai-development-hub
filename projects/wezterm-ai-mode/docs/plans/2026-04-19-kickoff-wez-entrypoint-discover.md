---
id: 01KPJE9Q7ZQG8BJ65N0SQ41P8P
title: "wez エントリポイント + wez discover（Phase 1 ステップ 1-1）"
date: 2026-04-19
type: kickoff
status: draft
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/28"
    reason: "本キックオフの対象Issue"
  - type: parent_epic
    ref: "https://github.com/stlwolf/ai-development-hub/issues/20"
    reason: "Phase 1 Epic"
  - type: derived_from
    ref: "../../poc/wezterm-ai-mode/01-socket-discovery.sh"
    reason: "discover のコアロジック元"
  - type: design_context
    ref: "../VERIFICATION_MATRIX.md"
    reason: "A-2-1, A-2-4 の検証項目"
  - type: reference
    ref: "../../CONVENTIONS.md"
    reason: "ドキュメント規約・実行フロー"
tags: [wez, cli, socket-discovery, phase1, bash]
keywords: [wezterm, wez, gui-sock, WEZTERM_UNIX_SOCKET, subcommand-dispatch]
use_when:
  - "wez CLI のエントリポイントを実装するとき"
  - "wez discover サブコマンドを実装するとき"
---

# wez エントリポイント + wez discover（Phase 1 ステップ 1-1）

作業開始前に必ず以下を読むこと:
- `projects/wezterm-ai-mode/CONVENTIONS.md` — ドキュメント規約・Stage分離フロー
- `projects/poc/wezterm-ai-mode/01-socket-discovery.sh` — discover のコアロジック元
- `projects/wezterm-ai-mode/docs/VERIFICATION_MATRIX.md` — 検証項目 A-2-1, A-2-4

## 背景

[Epic #20](https://github.com/stlwolf/ai-development-hub/issues/20) Phase 1 の最初の実装ステップ。`wez` CLI ツールキットの全サブコマンドは WezTerm ソケットへの接続を前提とするため、`wez discover` は他の全コマンド（`pane`, `notify` 等）の土台になる。

PoC-01（`01-socket-discovery.sh`）で `gui-sock-*` からのソケット自動検出は PASSED 済み。本ステップでは PoC のロジックを `wez` CLI のサブコマンド体系に統合し、将来のサブコマンド追加（#29 `pane`, #30 `notify`）に備えた構造を整える。

## 目的

`wez` CLI のエントリポイントスクリプトを作成し、最初のサブコマンド `wez discover` を実装する。

## 成功基準

- [ ] `./projects/wezterm-ai-mode/bin/wez discover` を実行すると、WezTerm ソケットを自動検出し、`wezterm cli list` で接続確認できる
- [ ] `./projects/wezterm-ai-mode/bin/wez help` でサブコマンド一覧が表示される
- [ ] `./projects/wezterm-ai-mode/bin/wez --version` でバージョン情報が表示される
- [ ] `./projects/wezterm-ai-mode/bin/wez discover --json` で機械可読な出力が得られる（`jq .` でパース可能）
- [ ] 複数ソケット存在時の選択ロジックについて設計判断が記録されている
- [ ] `shellcheck` が全ファイルで通る
- [ ] `bin/wez` に実行権限 (`chmod +x`) が付与されている

## スコープ

### 対象

- `projects/wezterm-ai-mode/bin/wez` — エントリポイント（サブコマンドディスパッチ）
- `projects/wezterm-ai-mode/lib/common.sh` — 共通ユーティリティ（ログ、カラー、エラーコード）
- `projects/wezterm-ai-mode/lib/discover.sh` — discover ロジック（lib 関数としてサイレント実装）
- `wez discover` サブコマンド — ソケット自動検出 + 接続確認
- `wez help` / `wez --version` — 基本ユーティリティ
- 複数ソケット選択ロジックの設計判断（ADR）

### 対象外

- `wez pane` サブコマンド群（[#29](https://github.com/stlwolf/ai-development-hub/issues/29)）
- `wez notify` サブコマンド（[#30](https://github.com/stlwolf/ai-development-hub/issues/30)）
- `sync-bin.sh` への `wez` 追加（Phase 1 ステップ 1-5）
- dotfiles 統合（Phase 2）

## 設計判断が必要な事項

以下の各項目について、実装中に判断し ADR に記録する。

### DJ-1: ファイル構成（単一ファイル vs 分割）

| 選択肢 | メリット | デメリット |
|--------|---------|----------|
| A: 単一 `bin/wez` | シンプル、依存なし、sync 容易 | Phase 1 完了時点で 500行超の見込み |
| B: `bin/wez`（dispatcher） + `lib/*.sh` | サブコマンドごとに独立、テスト・差分が明瞭 | source パス解決が必要、sync 対象が複数に |
| C: `bin/wez` + `commands/*.sh`（git方式） | サブコマンド追加が容易 | PATH 解決が複雑、Phase 1 には過剰 |

**暫定方針**: B（dispatcher + lib）。Phase 1 のスコープ（discover + pane 5つ + notify）を考慮すると単一ファイルでは大きくなりすぎる。ただし本Issue（1-1）では `wez` 本体 + discover のみ実装し、lib 分割の構造だけ整える。

### DJ-2: 複数ソケット選択ロジック

| 選択肢 | メリット | デメリット |
|--------|---------|----------|
| A: 最新 mtime | シンプル、PoC-01 で検証済み | stale ソケットを誤選択するリスク |
| B: PID ベース（`pgrep wezterm-gui`） | プロセス状態と連動 | 複数 GUI プロセスの場合にどれを選ぶか未定 |
| C: `wezterm cli list` で応答するものを選択 | 実際に接続可能なソケットを確実に選ぶ | 全ソケットに接続試行するためオーバーヘッド |
| D: ユーザー選択（`--socket` フラグ + 対話的選択） | 確実 | 自動化に不向き |
| **A+C: ハイブリッド** | mtime で優先順位付け + 接続確認で確定。信頼性が高い | 微小なオーバーヘッド（1-3ソケットなら数百ms以下） |

**暫定方針**: A+C ハイブリッド。mtime 降順でソートし、`wezterm cli list` が成功した最初のソケットを採用する。失敗したら次候補へフォールバック。`--socket <path>` と環境変数 `WEZTERM_UNIX_SOCKET` によるオーバーライドも提供。

**根拠**: arena-compare レビューで「mtime のみでは stale ソケット誤選択リスクがある」「1-3 ソケット程度なら接続試行のオーバーヘッドは実用上問題ない」と 3 モデルが合意。PoC-01 には mtime 取得が全失敗時に newest が空になるバグもあり、接続確認による確定が安全。

### DJ-3: discover の出力設計と内部呼び出しアーキテクチャ

**重要な制約**: `wez discover` を外部コマンド（サブプロセス）として実行しても、`export WEZTERM_UNIX_SOCKET` は親シェルに伝搬しない。そのため、**他サブコマンドからの内部利用は `lib/discover.sh` を `source` して関数を直接呼ぶ設計**とする。

| モード | 用途 | 仕組み |
|--------|------|--------|
| CLI 実行・デフォルト（人間向け） | ターミナルで手動実行 | stderr にステータス、stdout にソケットパス |
| CLI 実行・`--json` | スクリプト連携・デバッグ | stdout に JSON のみ、stderr は原則無音（`--verbose` で有効化） |
| 内部呼び出し（他サブコマンドから） | `wez pane list` 等の前処理 | `bin/wez` が `source lib/discover.sh` し、関数を同一プロセス内で呼ぶ。変数 `WEZTERM_UNIX_SOCKET` をセットし、終了コードで結果を返す |

**暫定方針**:
- **lib 関数（`wez_discover_socket` 等）はデフォルトでサイレント。** stderr への出力は行わず、終了コードと変数のセットのみ。これにより、将来 `pane` 等が JSON 出力する際にログが混入しない
- **stderr への状態出力や JSON へのパースはエントリポイント（`bin/wez`）側の責務**として分離
- `--json` は暗黙に quiet（stderr 無音）。`--verbose` で明示的にステータスを有効化
- JSON スキーマ: `{"socket": "<path>", "pane_count": <int>}` を Phase 1 で固定。将来のフィールド追加は許容するが、既存キーの型変更は不可

**lib 契約（将来のサブコマンド実装者向け）**:
- lib 関数は stdout/stderr に出力しない
- 結果は終了コード + シェル変数のセットで返す
- JSON 整形・人間向けメッセージは caller（`bin/wez`）が行う

**オーバーライド優先順位**: `--socket` > `WEZTERM_UNIX_SOCKET` 環境変数 > 自動検出（ハイブリッド）。明示指定（`--socket` / 環境変数）が接続失敗した場合は**フォールバックせず即エラー**（意図しないソケットへの接続を防止）。

**スコープ注記**: `--quiet` と `--verbose` は DJ-3 の設計から自然に導かれるオプションだが、Issue #28 の最小スコープ（4チェックボックス）には含まれない。実装の自然な帰結として含めるが、成功基準の必須項目ではなく、実装時の判断で省略可。

### DJ-4: エラー処理方針

- ソケット未検出: exit 1 + stderr メッセージ
- `wezterm` コマンド未インストール: exit 127 + インストール案内
- 接続失敗（ソケットはあるが応答なし）: exit 2 + stderr メッセージ + stale ソケット警告

## ブランチ・コミット・PR 戦略

### ブランチ

```
feature/#28_wez_entrypoint_discover
```

デフォルトブランチ（master）の最新版から切る。`wt` インストール済みの場合は `wt switch --create feature/#28_wez_entrypoint_discover` を推奨。

### コミット戦略

1コミット1論理変更。各 Step 完了時にコミットする。

| Step | コミットメッセージ例 |
|------|---------------------|
| Step 0 | （コミットなし。ブランチ作成 + 前提調査のみ） |
| Step 1 | `feat(wez): add entrypoint and lib skeleton` |
| Step 2 | `feat(wez): implement discover subcommand with hybrid socket selection` |
| Step 3 | （コミットなし。E2E 検証で不具合が出た場合は `fix(wez): ...` で修正コミット） |
| Step 4 | `docs(wez): add ADRs and update verification matrix` |
| Step 5 | （コミットなし。PR 作成） |

### PR

- タイトル: `feat(wez): エントリポイント + wez discover サブコマンド`
- `Refs #28`（`Closes` は使わない — クローズは検証後に手動）
- `--assignee @me`
- `.github/PULL_REQUEST_TEMPLATE.md` が存在すればテンプレートに従う
- Draft PR → E2E 確認後に Ready for review

## 実装計画

### Step 0: 前提調査 + ブランチ作成（概算: 15分）

PoC-01 のロジックと現在のプロジェクト構造を確認し、変更が必要な前提を検証する。

- [ ] ブランチ作成: `feature/#28_wez_entrypoint_discover`（master 最新版から）
- [ ] PoC-01（`01-socket-discovery.sh`）の全ロジックを精読
- [ ] `command -v wezterm` で wezterm CLI の存在を確認
- [ ] `command -v jq` で jq の有無を確認（不在時は `grep -c` フォールバックで実装）
- [ ] `wezterm cli list --format json` の出力フォーマットを確認（PoC-01 では `grep -c '"pane_id"'` でパース。正式な JSON 構造を確認し、`jq` による安全なパースに切り替え可能か判断）
- [ ] `stat -f %m`（macOS）と `stat -c %Y`（Linux）の互換性を確認（PoC-01 のフォールバック実装が十分か）
- [ ] 現環境でソケットが `~/.local/share/wezterm/gui-sock-*` に配置されていることを確認（PoC-01 の前提がずれていないか）
- [ ] デッドソケット（プロセスなしのソケットファイル）に対して `wezterm cli list` がハングせず直ちにエラーを返すか確認（ハングする場合はタイムアウト実装を設計に積む）
- [ ] `projects/wezterm-ai-mode/bin/` ディレクトリが存在しないことを確認

!! GATE: Step 0 の結果、PoC-01 のロジックに問題がなく、前提が崩れていなければ続行。問題があればプランを修正。

### Step 1: エントリポイント + lib 骨格作成（概算: 30分）

`bin/wez` と `lib/` の骨格を最初から作る（DJ-1: B を前提）。discover のロジックは Step 2 で実装するが、ファイル構造と source チェーンは本 Step で確立する。

- [ ] `projects/wezterm-ai-mode/bin/wez` を作成
- [ ] shebang: `#!/usr/bin/env bash`
- [ ] `set -euo pipefail`
- [ ] `WEZ_VERSION="0.1.0"` を定義
- [ ] `WEZ_ROOT` のパス解決: macOS 非互換の `readlink -f` を避け、`BASH_SOURCE` の symlink を再帰的に辿る bash イディオム（`while [ -L "$source" ]; do ... done` + `cd "$(dirname "$source")/.." && pwd`）で解決。sync-bin.sh による symlink 経由実行に対応
- [ ] `lib/common.sh` を作成（カラー定義、ログ関数、エラーコード定数）
- [ ] `lib/discover.sh` を作成（スタブ: 関数シグネチャのみ、中身は Step 2 で実装）
- [ ] `bin/wez` から `source "$WEZ_ROOT/lib/common.sh"` / `source "$WEZ_ROOT/lib/discover.sh"` で読み込み
- [ ] サブコマンドディスパッチ（`case "$1"` 方式）: `discover`, `help`, `version`
- [ ] 未知のサブコマンドに対するエラーメッセージ + `wez help` への誘導
- [ ] `wez help`: サブコマンド一覧と概要を表示
- [ ] `wez --version` / `wez version`: バージョン表示
- [ ] `chmod +x bin/wez`
- [ ] `shellcheck bin/wez lib/*.sh` パス

### Step 2: discover サブコマンド実装（概算: 45分）

PoC-01 のロジックを `lib/discover.sh` に実装し、`bin/wez` の discover サブコマンドとして統合する。DJ-2（ハイブリッド）、DJ-3（サイレント lib）の設計判断を反映。

- [ ] `lib/discover.sh` に `wez_discover_socket()` を実装（PoC-01 ベース、ただしデフォルトでサイレント — stderr 出力なし）
- [ ] `lib/discover.sh` に `wez_verify_connection()` を実装（接続確認。pane_count は `jq` 使用可否を Step 0 の結果に基づいて決定。`jq` 不在時は `grep -c` フォールバック）
- [ ] ハイブリッドソケット選択: mtime 降順でソートし、`wez_verify_connection` が成功した最初のソケットを採用。失敗したら次候補へフォールバック
- [ ] `--socket <path>` オプション: 明示的にソケットパスを指定
- [ ] 環境変数 `WEZTERM_UNIX_SOCKET` の優先チェック（PoC-01 踏襲）
- [ ] `bin/wez` 側で CLI 出力を制御: デフォルトは stderr にステータス + stdout にソケットパス
- [ ] `--json` オプション: stdout に `{"socket": "...", "pane_count": N}` のみ、stderr は原則無音
- [ ] `--verbose` オプション: `--json` と併用時に stderr のステータスを有効化
- [ ] `--quiet` オプション: デフォルトモードでも stderr を抑制
- [ ] `wezterm` コマンドの存在チェック（`command -v wezterm`）
- [ ] エラーコード: 0（成功）, 1（ソケット未検出）, 2（接続失敗）, 127（wezterm 未インストール）
- [ ] PoC-01 の `newest` が空になるバグを修正（mtime 取得全失敗時のガード）
- [ ] `shellcheck lib/discover.sh bin/wez` パス

### Step 3: E2E 検証（概算: 15分）

実際の WezTerm 環境で動作を確認する。sync-bin.sh 未実施のため、全コマンドは明示パスで実行する。

```bash
WEZ="./projects/wezterm-ai-mode/bin/wez"
```

- [ ] Cursor 統合ターミナルから `$WEZ discover` を実行し、ソケットが検出されること
- [ ] `$WEZ discover --json` の出力が valid JSON であること（`jq .` でパース確認）
- [ ] `$WEZ discover --quiet` で stderr 出力がないこと
- [ ] `$WEZ discover --json` で stderr にログが混入しないこと（`2>/dev/null` なしで JSON のみ出力）
- [ ] `$WEZ help` でサブコマンド一覧が表示されること
- [ ] `$WEZ --version` でバージョンが表示されること
- [ ] 存在しないサブコマンド `$WEZ foo` でエラーメッセージが表示されること
- [ ] `WEZTERM_UNIX_SOCKET` を手動設定した状態で `$WEZ discover` がそれを優先すること
- [ ] `$WEZ discover --socket /nonexistent` で適切なエラーが返ること

!! GATE: E2E 全項目パス。失敗がある場合は Step 2 に戻って修正。

### Step 4: ドキュメント・ADR・記録（概算: 15分）

- [ ] DJ-1（ファイル構成）の判断結果を ADR に記録（`docs/decisions/ADR-001-cli-file-structure.md`）
- [ ] DJ-2（ソケット選択）の判断結果を ADR に記録（`docs/decisions/ADR-002-socket-selection-strategy.md`）
- [ ] `docs/VERIFICATION_MATRIX.md` の A-2-1, A-2-4 を更新
- [ ] エピソード記録（`docs/episodes/2026-04-19-wez-entrypoint-discover.md`）
- [ ] コミット: `docs(wez): add ADRs and update verification matrix`

### Step 5: PR 作成（概算: 10分）

- [ ] `git fetch origin && git rebase origin/master` で最新を取り込み
- [ ] `shellcheck` が全ファイルでパスすることを最終確認
- [ ] PR テンプレート（`.github/PULL_REQUEST_TEMPLATE.md`）の有無を確認し、あればテンプレートに従って本文を作成
- [ ] PR 本文に以下を含める:
  - 変更概要（`wez` エントリポイント + discover サブコマンド + lib 骨格）
  - 設計判断の要約（DJ-1〜DJ-4 の採用方針）
  - E2E 検証結果のサマリ
  - `Refs #28`
- [ ] `gh pr create --assignee @me --title "feat(wez): エントリポイント + wez discover サブコマンド" --body-file /tmp/pr_body.md`
- [ ] PR URL を親スレッド（Epic #20 統括）に報告

!! GATE: PR が作成され、CI（shellcheck 等）が通ること。

## リスクと対処

| リスク | 影響 | 対処 |
|--------|------|------|
| WezTerm が起動していない状態でのテスト | discover が常に失敗する | E2E は WezTerm 起動状態で実施。CI 向けにはモック不要（Phase 1 は手動検証） |
| `stat` コマンドの macOS/Linux 差異 | mtime 取得が片方で失敗 | PoC-01 のフォールバック実装（`stat -f %m` → `stat -c %Y`）を踏襲 |
| `shellcheck` で PoC-01 由来のコードに警告 | CI ではないが品質基準未達 | 警告を修正してから進む。`shellcheck` パスは完了条件 |
| macOS の `readlink -f` 非互換 | `WEZ_ROOT` のパス解決が失敗し、`lib/` の source が壊れる | `BASH_SOURCE` の symlink を再帰的に辿る bash イディオム（`while [ -L "$source" ]` + `dirname`）で解決。`readlink -f` / `realpath` は使わない |
| `wezterm cli list` がデッドソケットでハングする | discover 全体が無限待ちになり CLI が止まる | Step 0 で挙動を手動検証。ハングする場合は bash ネイティブ watchdog（子プロセス kill）を検討し ADR 化。macOS に `timeout` コマンドがないため外部依存は避ける |
| 内部呼び出し時の stderr 漏出 | `pane` 等の JSON 出力に discover のログが混入し機械可読性が壊れる | lib 関数はデフォルトでサイレント。出力制御は `bin/wez` の責務として分離（DJ-3） |
| PoC-01 の `newest` 変数が空になるバグ | mtime 取得が全失敗すると `WEZTERM_UNIX_SOCKET=""` で export され、以降の挙動が不可解になる | ハイブリッド選択（DJ-2）で接続確認を必須化。加えて空チェックのガードを追加 |
| JSON パースの脆弱性 | `grep -c '"pane_id"'` は minified JSON やフォーマット変更で壊れる | `jq` 使用可否を Step 0 で判断。不在時は `grep -c` フォールバックを維持しつつ、将来 `jq` 推奨に移行 |

## peer-ai-review 実施ポイント

1. **Step 2 完了後**: discover 実装のコードレビュー（`so-compare.sh`）。`set -euo` 漏れ、引用処理、既存シェル規約との乖離を検出
2. **Step 3 完了後（任意）**: E2E 結果を踏まえた全体レビュー

## ADR 作成チェックリスト

- [ ] DJ-1: ファイル構成の選択（Step 1 完了時）→ `ADR-001-cli-file-structure.md`
- [ ] DJ-2: 複数ソケット選択ロジック（Step 2 完了時）→ `ADR-002-socket-selection-strategy.md`
- [ ] DJ-3: 内部呼び出しアーキテクチャ（source + サイレント関数）— DJ-1 に統合可。ただし「外部コマンドとして export しても親シェルに伝搬しない」制約と、その対処設計は明記必須
- [ ] DJ-4: エラーコード体系 — DJ-2 に統合可

## 完了条件

- [ ] `projects/wezterm-ai-mode/bin/wez` が存在し、実行権限がある
- [ ] `projects/wezterm-ai-mode/lib/common.sh` と `lib/discover.sh` が存在する
- [ ] `./projects/wezterm-ai-mode/bin/wez discover` が Cursor 統合ターミナルから WezTerm ソケットを検出・接続確認できる
- [ ] `./projects/wezterm-ai-mode/bin/wez discover --json` が valid JSON を返す（`jq .` でパース可能）
- [ ] `./projects/wezterm-ai-mode/bin/wez help`, `./projects/wezterm-ai-mode/bin/wez --version` が動作する
- [ ] `shellcheck` が全スクリプト（`bin/wez`, `lib/*.sh`）で通る
- [ ] DJ-2（ソケット選択）を含む必要な ADR が記録されている
- [ ] `docs/VERIFICATION_MATRIX.md` の A-2-1, A-2-4 が更新されている
- [ ] PR が作成され `Refs #28` で Issue と連携している
- [ ] Issue #28 の全チェックボックスが完了している

## 実行フロー

CONVENTIONS.md §「フェーズ実行フロー」に従う。

### Stage 1: プラン策定（Agent mode）

1. **コンテキスト読み込み**: 本キックオフ + `CONVENTIONS.md` + PoC-01
2. **プラン作成**: Agent mode で `docs/plans/2026-04-19-plan-wez-entrypoint-discover.md` に作成
3. **peer-ai-review**: プランの合意を取得
4. **CP 確定**: 合意内容をプラン MD に反映し、ユーザーに報告

**← Stage 1 完了後、ここで停止してユーザーに報告する。** ユーザーが Plan mode に切り替えてから Stage 2 に進む。

### Stage 2: 実装（Plan mode）

5. **プラン変換**: 確定済みプランを Plan mode のプランに変換
6. **ビルド実行**: TODO に従って実装

### Stage 3: 成果物記録（Agent mode）

7. **成果物記録**: エピソード + ADR + VERIFICATION_MATRIX 更新
8. **キックオフ突合**: 成功基準・完了条件と実装結果を突合し、未達成項目を明示
