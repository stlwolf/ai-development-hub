---
name: so-compare
description: so-compare.shでセカンドオピニオン（Codex/Claude/Cursor）を取得し、結果を比較する。ピアレビュー、修正方針の検証、設計判断の反証に使用する。プロンプト設計原則、結果読み込み手順、合意判定基準を含む。
depends:
  - cli: so-compare
---

# SO Compare — セカンドオピニオン比較

## スクリプトの場所

```
so-compare   (~/bin/ にシンボリックリンク。本体: scripts/so-compare.sh)
```

## 呼び出し方法

Shell ツールで実行する:

```bash
so-compare [OPTIONS] "プロンプト"
```

### オプション一覧

| オプション | 説明 | デフォルト |
|-----------|------|-----------|
| `-w PATH` | ワークスペースパス（推奨）。Codex/Claude にパス参照で渡す | なし |
| `-f FILE` | プロンプトをファイルから読み込み | - |
| `-c FILE...` | コンテキストファイル添付（**非推奨**。`-w` を使うこと） | - |
| `-o DIR` | 出力ディレクトリ指定 | `tmp/so-YYYYMMDD-HHMMSS` |
| `-s MODE` | Codex sandbox モード | `read-only` |
| `--codex-only` | Codex のみ実行 | 両方実行 |
| `--claude-only` | Claude のみ実行 | 両方実行 |
| `--cursor` | Cursor CLI (agent) も実行（デフォルト: 無効） | 無効 |
| `--cursor-only` | Cursor のみ実行 | 両方実行 |
| `--cursor-model MODEL` | Cursor で使用するモデル | `auto` |
| `--claude-model MODEL` | Claude で使用するモデル（エイリアス `opus`/`sonnet`/`haiku` 可） | CLI 既定 |
| `--codex-model MODEL` | Codex で使用するモデル | CLI 既定 |
| `--claude-effort LEVEL` | Claude のエフォート（`low`/`medium`/`high`/`xhigh`/`max`） | CLI 既定 |
| `--claude-web` | Claude Code に WebFetch を許可（`-p` で外部URL参照を要するタスク用） | 無効 |
| `--prev DIR` | 前回出力を追記（イテレーション用） | なし |

### 環境変数

| 変数 | 説明 | デフォルト |
|------|------|-----------|
| `SO_TIMEOUT` | 各ツールのタイムアウト秒数 | `240` |
| `PREV_MAX_BYTES` | `--prev` で追記する回答の上限バイト数 | `4000` |
| `SO_CURSOR_MODEL` | Cursor のデフォルトモデル（`--cursor-model` で上書き可） | `auto` |
| `SO_CLAUDE_MODEL` | Claude のデフォルトモデル（`--claude-model` で上書き可） | CLI 既定 |
| `SO_CODEX_MODEL` | Codex のデフォルトモデル（`--codex-model` で上書き可） | CLI 既定 |
| `SO_CLAUDE_EFFORT` | Claude のデフォルトエフォート（`--claude-effort` で上書き可） | CLI 既定 |

### 基本パターン

```bash
# 推奨: -w でワークスペースを渡す
so-compare -w "$(pwd)" "この修正方針を検証してください"

# プロンプトファイルから
so-compare -f prompt.txt -w "$(pwd)"

# イテレーション（前回の回答を踏まえて再質問）
so-compare --prev tmp/so-20260304-001234 -w "$(pwd)" "前回の指摘を踏まえて再評価してください"

# Codex のみ（claude-safe 未導入環境）
so-compare -w "$(pwd)" "プロンプト" --codex-only

# Cursor も含めた3者比較
so-compare --cursor -w "$(pwd)" "この設計方針を検証してください"

# Cursor でモデル指定
so-compare --cursor --cursor-model composer-1.5 -w "$(pwd)" "プロンプト"

# Cursor のみ
so-compare --cursor-only -w "$(pwd)" "プロンプト"

# Claude を上位モデル + 高エフォートで（設計判断など重い SO）
so-compare --claude-model opus --claude-effort high -w "$(pwd)" "この設計方針を検証してください"

# Codex のモデル指定
so-compare --codex-model gpt-5.5 -w "$(pwd)" "プロンプト"
```

## モデル / エフォート選択ガイド

セカンドオピニオンを投げるエージェント向けの選択指針。**動的なモデル一覧コマンドが実在するのは Cursor のみ**（`agent models`）。Claude / Codex は以下を目安にする。

- **Claude**: エイリアス `opus` / `sonnet` / `haiku` で指定する。**エイリアスはそのティアの最新を指す**ため、バージョン ID（`claude-opus-4-8` 等）を追いかける必要はない（フル ID も透過で渡せる）。エフォートは `--claude-effort` に `low`/`medium`/`high`/`xhigh`/`max`
- **Codex**: 既定モデルは `~/.codex/config.toml` の `model`。任意のモデル名はそのまま透過で渡る
- **Cursor**: `agent models` で「アカウントで使えるモデル一覧」を取得できる。`--cursor-model` に渡す

### 使い分けの目安

- 設計判断・反証など重い SO → Claude を `--claude-model opus --claude-effort high`（必要なら `max`）に上げる
- 軽い確認 → 既定モデルのまま（フラグ未指定＝従来挙動）
- 指定したモデル名が無効・未契約の場合、そのレーンはエラー（`error` / `error_partial`）として結果サマリに現れる

未指定なら各 CLI の既定モデルで動作し、従来と挙動は変わらない。

## 出力ディレクトリ構成

```
tmp/so-YYYYMMDD-HHMMSS/
├── prompt.txt          # 最終プロンプト全文
├── codex-stdout.txt    # Codex の回答
├── codex-stderr.txt    # Codex の stderr
├── codex-meta.txt      # メタデータ（tool, model_requested, model_resolved, exit_code, timeout_status, elapsed_seconds, stdout_lines, stdout_bytes）
├── claude-stdout.txt   # Claude の回答
├── claude-stderr.txt   # Claude の stderr
├── claude-meta.txt     # メタデータ（model_requested, effort_requested を含む）
├── cursor-stdout.txt   # Cursor の回答（--cursor 時のみ）
├── cursor-stderr.txt   # Cursor の stderr（--cursor 時のみ）
└── cursor-meta.txt     # メタデータ（model_requested 含む。--cursor 時のみ）
```

## 結果読み込み手順

1. 実行完了後、出力ディレクトリパスを確認する
2. `codex-stdout.txt`、`claude-stdout.txt`（`--cursor` 時は `cursor-stdout.txt` も）を Read ツールで読み込む
3. 両回答を比較テーブルにまとめる

```markdown
| 観点 | 自分 | Codex | Claude | Cursor | 合意? |
|------|------|-------|--------|--------|-------|
| 問題認識 | ... | ... | ... | ✅/❌ |
| 修正方針 | ... | ... | ... | ✅/❌ |
| リスク対応 | ... | ... | ... | ✅/❌ |
```

## プロンプト設計原則

### やってはいけないこと

- **`-c` でファイル全文を渡す** → アンカリングが起き、渡したコードしか見ない。95KB超のプロンプトで278秒/414秒のタイムアウト実績あり
- **結論を含むプロンプト** → 追認を誘発する。「Xが正しいことを確認して」ではなく「Xを検証して」
- **1回のプロンプトに複数の質問を詰め込む** → 回答が散漫になる

### やるべきこと

- **`-w` でワークスペースパスを渡し、エージェントに自分で読ませる**
- **検証ポイントを具体的に列挙**（「X, Y, Z を検証して」）
- **事実と仮定を分離**（「確認済み: A。未検証の仮定: B」）
- **反証可能性を確保**（「違う可能性はあるか？」）

### プロンプト品質チェック

SO 実行前に以下を確認する:

1. 具体的な検証対象が列挙されているか
2. 確認済みの事実と未検証の仮定が区別されているか
3. SO がプロンプトだけで回答できる十分なコンテキストがあるか
4. SO が「違う」と言える余地があるか

## 合意判定基準

以下の**すべて**を満たした場合に「3者合意」とする:

1. **問題認識が一致**: 3者が同じ問題を認識している
2. **修正方針の方向性が一致**: 具体的な実装は異なっても、アプローチの方向性が同じ
3. **重大なリスク指摘が未解決でない**: いずれかが指摘したリスクに対して、反論または対策が示されている

### 合意に至らない場合

1. 差異の特定と原因分析
2. 修正案の改善
3. プロンプトの改善（不足コンテキスト追加）
4. `--prev` を使って再実行（最大3イテレーション）

### フォールバック

`claude-safe` 未導入等で2者しか参加できない場合、「2者合意 + ユーザーの明示承認」で代替可。

## 注意事項

- 実行には `codex` CLI と `claude-safe` が PATH 上に必要（片方のみの場合は `--codex-only` / `--claude-only`）
- Cursor レーンは `--cursor` でオプトイン。`agent` CLI が PATH 上に必要（未インストール時はエラー終了）
- `SO_TIMEOUT` のデフォルトは240秒。大きなプロンプトでタイムアウトする場合は値を増やす
- 出力は `tmp/` 配下で gitignore 対象
