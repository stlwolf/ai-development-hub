---
title: "Phase 2 フック設計提案"
date: 2026-04-13
status: proposal
phase: "Phase 2 - Stage 3"
related_issues:
  - https://github.com/stlwolf/ai-development-hub/issues/67
  - https://github.com/stlwolf/ai-development-hub/issues/24
---

# Phase 2 フック設計提案

## 背景

Phase 1 の検証で、ルール（テキスト）だけでは行動変容の因果関係を確認できないことが判明。特に:

- implementation-gate: 例外の拡大解釈（「修正して」を明示的スキップ指示と読み替え）
- skill-first: ルールを認識しつつもスキルロードを省略（コスト最小化バイアス）
- Codex Default mode: 小スコープタスクでの即実行

これらはルール層の限界であり、フック/オーケストレーション層での機械的強制が必要。

## スコープ

**Phase 2 では設計提案のみ**。実装は [Epic #24](https://github.com/stlwolf/ai-development-hub/issues/24) で別途対応。

## 提案 1: スキルロード監査フック (post-response)

### 目的

コミット・PR・Issue 作成等の操作後に、対応スキルが参照されたか監査する。

### 設計

```
trigger: post-response (Claude Code) / post-turn (Codex)
対象操作: git commit, gh pr create, gh issue create
チェック:
  - セッション内でスキルファイル (SKILL.md) の読み込み痕跡を検索
  - 痕跡なし → 警告メッセージを出力（ブロックはしない）
```

### 制約

- Cursor: hooks は pre-command のみ。post-response 相当がないため、この方式は適用不可
- Claude Code: `settings.json` の hooks で post-response が可能
- Codex: `hooks.json` で post-turn が可能（ただしセッション内のスキル参照痕跡を外部から検出する手段が限定的）

### 判定

- 効果: 中（警告のみ、ブロックなし）
- 実装難度: 高（セッション内のスキル参照痕跡の検出がツール依存）
- 推奨: **保留** — 現状のツール API では痕跡検出が困難。オーケストレーションツール導入時に再検討

## 提案 2: コミットメッセージ形式チェックフック (pre-command)

### 目的

コミットメッセージが Conventional Commits 形式に準拠しているか機械的にチェック。

### 設計

```
trigger: pre-command
対象コマンド: git commit
チェック:
  - -m 引数からメッセージを抽出
  - ^(feat|fix|docs|chore|refactor|test|ci|style|perf|build)(\(.+\))?: .+ にマッチ
  - 不一致 → deny + 理由出力
```

### 制約

- 3ツール共通で pre-command hooks が利用可能
- 既存の `commit-gate.sh` と同じパスで実装可能

### 判定

- 効果: 高（機械的ブロック、CC スキル未ロードでも形式は強制）
- 実装難度: 低（正規表現マッチのみ）
- 推奨: **採用** — #24 の最初の実装候補

## 提案 3: implementation-gate の構造的強制

### 目的

「調査して修正して」のような指示で計画フェーズを省略するのを防ぐ。

### 設計の方向性

ルール単体では防げない（モデルが「修正して」を例外適用の根拠にする）。構造的に防ぐには:

- **オーケストレーションレベル**: ファイル変更前にプラン承認を必須とするワークフロー制御
- **フックレベル**: pre-command で `git add` / ファイル書き込みの前にプラン出力の痕跡をチェック

### 制約

- フックレベルでの「プラン出力の痕跡」検出は定義が曖昧
- オーケストレーションツール（自作 or 既存）の導入が現実的

### 判定

- 効果: 最高（構造的強制）
- 実装難度: 最高（オーケストレーションツール必要）
- 推奨: **設計のみ** — [orchestration-control-loop-challenges.md](../../draft/orchestration-control-loop-challenges.md) と合わせて検討

## 優先度まとめ

| 提案 | 効果 | 難度 | 推奨 |
|------|------|------|------|
| 1. スキルロード監査 | 中 | 高 | 保留 |
| 2. CC 形式チェック | 高 | 低 | **採用（#24 初期実装）** |
| 3. implementation-gate 構造的強制 | 最高 | 最高 | 設計のみ |
