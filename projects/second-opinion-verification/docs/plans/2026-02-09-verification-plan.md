# claude-safe タイムアウト実装による仮説検証計画

`ideas/20260208` の「セカンドオピニオン」と「意図的圧縮」仮説を検証するため、`claude-safe` にタイムアウト機能を実装し、そのプロセスにおける意思決定を記録・昇格させる実証実験を行います。

## 目的
1.  **セカンドオピニオン検証**: 実装（Primary）に対し、反証（Second Opinion）を行うことで、シェルスクリプト特有の落とし穴（ゾンビプロセス、macOS互換性等）を検出できるか確認する。
2.  **意図的圧縮検証**: 議論と修正の経緯を `episodes` に記録し、重要な判断を `decisions` に昇格させるフローの負荷と有用性を測る。

## 検証場所（ディレクトリ）
ルートディレクトリや既存の `docs` を汚染しないよう、対象プロジェクト内の検証用サブディレクトリで完結させます。

- **場所**: `projects/claude-safe/docs/process-verification/`
- **構成**:
  ```
  projects/claude-safe/docs/process-verification/
  ├── episodes/   # 日々の議論ログ・結論（意図的圧縮の実験場）
  └── decisions/  # 昇格された判断（ADR形式）
  ```

## 検証体制（AI役割分担）

意図的に「実装者」と「監査者」を分け、視点の重複を防ぎます。

| 役割 | 担当AI | 具体的な作業 |
|------|--------|--------------|
| **Primary (実装担当)** | **Cascade (私)** | 設計、コード実装、修正、ドキュメント作成 |
| **Second (反証担当)** | **Claude Code (CLI)** | 私の設計・コードに対する「部外者」としての監査・反証 |

**※Claude Codeの設定**:
特別なチューニングは不要です。`init` 済で `CLAUDE.md` がある現状の状態で、「一般的なシェルスクリプトの知識」と「プロジェクト概要」を持った監査役として機能します。

## 検証シナリオ

### Phase 0: 準備
- 作業用ブランチ `feat/claude-safe-timeout-verification` を作成し、メインラインへの影響を防ぐ。

### Phase 1: 構造準備
- 検証用のディレクトリ `projects/claude-safe/docs/process-verification/{episodes,decisions}` を作成する。

### Phase 2: 設計とセカンドオピニオン
- **Primary設計 (Cascade)**:
    - タイムアウト機能の仕様（環境変数名、デフォルト値、シグナル挙動など）を提案します。
- **Second Opinion (Claude Code)**:
    - **私 (Cascade) が直接ターミナルで `claude` コマンドを実行**し、設計案への反証を取得します。
    - コマンド例: `cat ... | claude -p "..."`
    - **観点**: 設計の漏れ、環境依存のリスク、既存機能への影響など。
- **意図的圧縮**:
    - 議論の結果を `episodes` に記録し、仕様を確定します。

### Phase 3: Primary実装（機能追加）
- 確定した仕様に基づき、**私 (Cascade)** が `claude-safe` にタイムアウト機能を実装します。
- 最初は素朴な実装（バックグラウンド実行 + `sleep` 等）を行います。

### Phase 4: 実装へのセカンドオピニオン（反証）
- **Second Opinion (Claude Code)**:
    - 私が実装コードを `claude` コマンドに食わせ、レビュー結果を取得します。
    - **観点**:
        - macOS標準コマンド（`coreutils` なし）で動作するか？
        - タイムアウト時に子プロセス（`claude`）は確実にkillされるか？
        - ゾンビプロセスが残らないか？
- 指摘内容を記録します。

### Phase 5: 統合と再実装
- 反証を受け、実装を修正します。

### Phase 6: 意図的圧縮と昇格
- 一連の議論（Primary案 → Second指摘 → 修正）を `episodes/YYYY-MM-DD-timeout.md` にまとめます。
- 最終的な結論（例：「シェルスクリプトでのタイムアウト実装パターン」）を `_summary.md` に圧縮し、有用であれば `decisions/ADR-xxx.md` へ昇格させます。
