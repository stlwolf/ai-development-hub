---
title: "arena-compare.sh resume サポート実装と検証"
date: 2026-02-23
type: episode
related:
  - type: derived_from
    ref: ../plans/2026-02-22-kickoff-resume-support.md
    reason: "キックオフプランに基づく実装"
  - type: derived_from
    ref: ./2026-02-22-prototype-verification.md
    reason: "プロトタイプ検証で確認済みの resume 動作を本実装に組み込み"
tags: [arena-compare, resume, session, cursor-cli, agent-cli]
---

# arena-compare.sh resume サポート実装と検証

## 背景

キックオフプラン（2026-02-22）で設計した resume サポートを `arena-compare.sh` に組み込む。プロトタイプ検証で `agent create-chat` + `--resume` の動作は確認済みだが、スクリプトへの統合と `--mode` との併用に未知の問題があった。

## 実施内容

### Step 0: dry-run バグ修正

dry-run パスのメタデータ書き込みに `exit_code`, `elapsed_seconds` 等が欠損しており、`set -u` でサマリー表示がクラッシュしていた。ダミー値の書き込みを追加して修正。

### Step 1: 基本動作確認

| テスト | モデル | 結果 |
|--------|--------|------|
| 1モデル実行 | gemini-3-flash | 21秒で成功。`--workspace` 経由でユーザールール適用を確認 |
| 3モデル並列 | gemini-3-flash, sonnet-4.6, gpt-5.2 | 3/3 全成功（16〜44秒） |

### Step 2: resume 前提調査

| 確認事項 | 結果 |
|----------|------|
| `agent create-chat` | UUID 返却 OK |
| `nohup` + `--resume` 1発目 | OK |
| 同じ UUID で 2発目 | コンテキスト保持確認 |
| `nohup` なし | ハング（`nohup` 必須を再確認） |
| `--mode ask` + `--resume` | ハング |

### Step 3: 実装

- `run_model()` 内で `agent create-chat` → UUID 取得 → `{model}-chat-id.txt` に保存
- `--resume-from DIR` オプション追加（引数解析 + `get_chat_id()` 関数）
- resume 時は `--mode` を自動省略（ハング回避）
- セッション継続ヒントの表示を追加

### Step 4: 統合検証

| テスト | 結果 |
|--------|------|
| dry-run（新機能含む） | チャットID表示、resume ヒント表示 OK |
| 初回実行 → チャットID保存 | `gemini-3-flash-chat-id.txt` に UUID 保存 OK |
| `--resume-from` でフォローアップ | 前回の文脈を正しく参照した回答 OK |
| 部分 resume（dry-run） | チャットIDあり→既存UUID使用、なし→新規 `create-chat` のフォールバック OK |

## 発見した制約

### `--resume` と `--mode` の非互換（新規）

`agent --resume=UUID --mode ask` を指定するとプロセスがハングし、出力が一切得られない。`--mode` なし（デフォルト = agent モード）でのみ `--resume` が動作する。

対処: resume 時は `--mode` 引数を自動的に省略する実装にした。初回実行時のみ `--mode` を付与。

### `nohup` 必須（再確認）

Cursor 統合ターミナルから `agent` CLI を実行する場合、`nohup` なしだとプロセスがハングする。これはプロトタイプ検証時から変わらない制約。

### `--workspace` によるルール自動適用（新規発見）

`agent --workspace PATH` を指定すると、そのワークスペースの `.cursor/rules/` やユーザールールが CLI 実行時にも適用される。gemini-3-flash の出力がユーザールールの「Output Format」に従っていたことで判明。

## 成果物

- `arena-compare.sh`: resume サポート追加済み
- `README.md`: resume 使い方・制約を更新

## キックオフプラン完了条件の達成状況

- [x] `arena-compare.sh` が初回実行時にチャットIDを保存する
- [x] `--resume-from` で2回目以降のイテレーションが動作する
- [x] 検証エピソードが記録されている（本ドキュメント）
- [x] README.md の resume セクションが更新されている
