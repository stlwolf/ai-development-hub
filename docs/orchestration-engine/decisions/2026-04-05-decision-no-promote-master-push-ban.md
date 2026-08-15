---
id: "01KNE8KA2TDH1AJ1T1G1EC7CP2"
title: "master 直 push 禁止をルールに昇格しない"
date: 2026-04-05
type: decision
status: stable
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/27"
    reason: "Issue #27: worktrunk-worktrees スキル追加時の判断"
  - type: evidence_for
    ref: "canonical/rules/careful-operations-rule.md"
    reason: "同系統のガードレール設計判断"
  - type: evidence_for
    ref: "canonical/hooks/README.md"
    reason: "機械的強制の設計思想"
tags: [branch-naming, master-push, rule-promotion, worktree]
---

# master 直 push 禁止をルールに昇格しない

## コンテキスト

branch-naming スキルの運用ルールに「master への直接 push は禁止」が記載されている。Issue #27 で worktrunk-worktrees スキルを追加するにあたり、この規約を canonical/rules/ に昇格すべきか検討した。

## 決定

���格しない。スキル内の運用規約として維持する。

## 根拠

1. **機械的ゲート > 行動ルール**: careful-operations-rule と hooks の設計思想に沿えば、「push を禁止する」はルール（行動指��）では��くフック（機械的強制）で実装すべき対象。ルールに昇格しても機械的に防止できない
2. **実効性**: AI エージェントは issue-conventions → branch-naming → worktrunk-worktrees のワークフローに沿って動作する���め、デフォルトブランチに直接 push する経路が生じにくい
3. **コンテキスト効率**: rules/ は全セッションでロードされる。marginal なケースのために常時コンテキストを消費するのは非効率
4. **将来の対処パス**: 必要が生じた場合は `block-push-to-default.sh` フックとして実装可能。`git push` + `master`/`main` のパターンマッチで hooks/README.md の「新規フック追加手順」に沿って3ツール分の設定を追加する

## 結果

- branch-naming SKILL.md: 「master への直接 push は禁止」を運用ルールとして維持
- worktrunk-worktrees SKILL.md: エージェント開始前チェックに「デフォルトブランチの worktree で作業していないか確認」を含める
- ルール昇格は行わない。将来必要が生じた場合はフック（C案）で対応する
