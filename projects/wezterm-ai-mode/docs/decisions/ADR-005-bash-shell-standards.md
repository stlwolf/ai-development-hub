---
title: "ADR-005: bash シェルスクリプト標準 — 互換性・移植性ルール"
date: 2026-04-20
type: decision
related:
  - type: evidence_for
    ref: ../episodes/2026-04-19-wez-entrypoint-discover.md
    reason: "local -n 禁止、mtime ソート区切りバグの発見元"
  - type: evidence_for
    ref: ../episodes/2026-04-20-wez-pane.md
    reason: "BSD sed、echo→printf、空配列展開の発見元"
  - type: depends_on
    ref: ADR-001-cli-file-structure.md
    reason: "ファイル構成・lib 構造の前提"
tags: [bash, compatibility, macos, shell, standards]
---

# ADR-005: bash シェルスクリプト標準 — 互換性・移植性ルール

## ステータス

Accepted

## コンテキスト

#28（discover）と #29（pane）の実装・レビュー過程で、bash 3.2 互換性と macOS 固有の移植性に関する問題が繰り返し検出された。so-compare と Copilot のレビューで合計7件以上の同カテゴリ指摘があり、事後修正コストが発生している。

本プロジェクトは macOS 専用だが、Homebrew bash（5.x）と macOS 標準 bash（3.2）の両方で動作する前提を維持する。理由: `wez` コマンドが `~/bin/` に sync され、ログインシェル環境（bash 3.2 の可能性あり）から呼ばれるケースがあるため。

## 判断

以下を `wez` CLI プロジェクトのシェルスクリプト標準とする。プラン策定時に本 ADR を参照し、実装方針に組み込むこと。

## bash 3.2 互換ルール

| 禁止パターン | 理由 | 代替 |
|-------------|------|------|
| `local -n` (nameref) | bash 4.3+ | グローバル配列 or stdout 返却 |
| `declare -A` (連想配列) | bash 4.0+ | 平行配列 or `case` 分岐 |
| `${!prefix@}` (間接展開) | bash 4.0+ の一部機能 | 明示的な変数名 |
| `readarray` / `mapfile` | bash 4.0+ | `while IFS= read -r` ループ |

### 空配列展開（`set -u` 対応）

```bash
# NG: 空配列で unbound variable エラー
"${arr[@]}"

# OK: bash 3.2 + set -u で安全
${arr[@]+"${arr[@]}"}
```

## macOS 固有の移植性ルール

| 問題 | 詳細 | 対処 |
|------|------|------|
| BSD sed の `\n` | 置換文字列に `\n` が使えない | `awk` で代替 |
| `echo` の非互換 | `-n`、バックスラッシュ解釈が環境依存 | `printf '%s\n'` に統一 |
| `timeout` 不在 | GNU coreutils の `timeout` がない | 未解決（Phase 2）。`perl -e 'alarm...'` or background + wait パターンを検討中 |
| `stat` フォーマット | macOS: `stat -f %m` / Linux: `stat -c %Y` | macOS 専用プロジェクトのため `stat -f %m` を使用。Linux 対応は不要 |
| `sed -i` | macOS: `sed -i ''` / Linux: `sed -i` | バックアップ拡張子の差異に注意。可能なら `awk` で回避 |

## 一般ルール（CLAUDE.md / AGENTS.md と整合）

- `set -euo pipefail` を全スクリプト冒頭に配置
- 変数は常にダブルクォート: `"$var"`
- 条件分岐は `[[ ]]` を使用
- `shellcheck` を全変更ファイルに実行

## 結果

- プラン策定時に本 ADR を参照し、禁止パターンの使用を事前に回避する
- so-compare / Copilot レビューで同カテゴリの指摘が減少することを期待
- 新たな互換性問題が発見された場合は本 ADR に追記する
