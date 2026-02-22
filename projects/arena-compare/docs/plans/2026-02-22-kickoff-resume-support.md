---
title: "キックオフ: arena-compare.sh に resume サポートを組み込む"
date: 2026-02-22
type: plan
related:
  - type: derived_from
    ref: ../episodes/2026-02-22-prototype-verification.md
    reason: "プロトタイプ検証で resume 動作を確認済み。スクリプトへの組み込みが次の必須ステップ"
  - type: depends_on
    ref: ../../arena-compare.sh
    reason: "改修対象"
tags: [arena-compare, resume, session, cursor-cli, iteration]
---

# キックオフ: arena-compare.sh に resume サポートを組み込む

## 背景

プロトタイプ検証で以下を確認済み:

- `agent create-chat` → UUID 取得（プログラマティック）
- `agent --resume=UUID` → セッション維持（コンテキスト保持）
- 各チャットは `~/.cursor/chats/{hash}/{uuid}/store.db` に永続化

現状の `arena-compare.sh` は1回きりの fire-and-forget で、イテレーション（「前の回答を踏まえて再質問」）ができない。`so-compare.sh` の `--prev` オプション（前回の回答をプロンプトに追記）より強力なネイティブセッション維持を組み込む。

## 成功基準

1. 初回実行時に各モデルのチャットIDが出力ディレクトリに保存される
2. 2回目以降は `--resume-from DIR` で前回のチャットIDを読み込み、同一セッションで追加質問できる
3. 各モデルが前回の回答を踏まえた応答を返す（コンテキスト保持の確認）

## 設計

### チャットID の保存

初回実行時、各モデルの `run_model()` 内で `agent create-chat` を呼び、取得した UUID を `{out_dir}/{model}-chat-id.txt` に保存する。

```
tmp/arena-YYYYMMDD-HHMMSS/
├── prompt.txt
├── opus-4.6-chat-id.txt       # ← 新規
├── opus-4.6-stdout.txt
├── opus-4.6-stderr.txt
├── opus-4.6-meta.txt
├── gpt-5.2-chat-id.txt        # ← 新規
├── ...
```

### resume フロー

```bash
# 初回
./arena-compare.sh -m "opus-4.6,gpt-5.2" -o tmp/arena-session1 "最初の質問"

# 2回目（resume）
./arena-compare.sh -m "opus-4.6,gpt-5.2" --resume-from tmp/arena-session1 -o tmp/arena-session1-r2 "前の回答を踏まえて深掘り"
```

`--resume-from DIR` 指定時:
1. `DIR/{model}-chat-id.txt` を読む
2. `agent --resume=UUID` で同一セッションに投入
3. 新しい出力は `-o` 指定のディレクトリに保存（チャットIDも引き継ぎコピー）

### チャットID が見つからないモデルの扱い

`--resume-from` 指定時に対象モデルのチャットIDファイルがない場合、新規チャットとして実行する（部分 resume）。

## 実装ステップ

### Step 0: 前提調査（5分）

- `agent create-chat` が `--model` を受け付けるか確認
- `agent --resume` 時に `--model` の指定が必要/有効か確認

### Step 1: チャットID 保存の追加（15分）

- `run_model()` 内で `agent create-chat` を呼び、UUID を取得
- `{out_dir}/{model}-chat-id.txt` に保存
- `agent` 実行時に `--resume=UUID` を使用

### Step 2: `--resume-from` オプションの追加（20分）

- 引数解析に `--resume-from DIR` を追加
- 指定時に `DIR/{model}-chat-id.txt` を読んで UUID を取得
- 新規出力ディレクトリにチャットIDファイルをコピー（連鎖可能に）

### Step 3: 検証（15分）

- 初回実行 → チャットIDファイルが保存されることを確認
- resume 実行 → コンテキスト保持を確認（前回の回答を踏まえた応答が返るか）
- 部分 resume（一部モデルのみチャットIDあり）の動作確認

### Step 4: エピソード記録（10分）

- 検証結果と発見をエピソードに記録

## 完了条件

- [ ] `arena-compare.sh` が初回実行時にチャットIDを保存する
- [ ] `--resume-from` で2回目以降のイテレーションが動作する
- [ ] 検証エピソードが記録されている
- [ ] README.md の resume セクションが更新されている

## 実行フロー

Stage 1〜3 を本スレッドで連続実行する想定（小規模改修のため Stage 分離は不要）。
