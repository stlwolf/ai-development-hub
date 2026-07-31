---
id: "01KYW0BPJK8HG58WWYNT9YAAHX"
title: "#290 探索の昇格 — 5ラウンドの反証史と「失敗の型は位置に付く」観測の保全（規範は積まない）"
date: 2026-07-31
type: episode
status: draft
related:
  - type: derived_from
    ref: "projects/orchestration-engine/docs/discussions/2026-07-31-discussion-290-canon-verification-exploration.md"
    reason: "本単位の昇格先 discussion。作業層（gitignored）の plan rev.5・探索木・独立監査2本から、実装差分から復元できない知見を選別して移した正本"
  - type: refs
    ref: "https://github.com/stlwolf/ai-development-hub/issues/290"
    reason: "本 issue。owner の gate 3 判断 = 止めて keep-open + 昇格（規範を積まない）"
  - type: refs
    ref: "https://github.com/stlwolf/ai-development-hub/issues/291"
    reason: "機構による起動保証の領分（#290 の条件ではない、という境界を discussion に保全）"
tags: [orchestration, canon-verification, negative-knowledge, promotion]
---

# #290 探索の昇格 — 実行記録（W 系単位）

## Context（なぜこの作業が始まったか）

#290「親しか書かない正本（board / handoff / 親の訂正）に検証を乗せる」の探索は、plan rev.1〜rev.5・設計SO 5ラウンド・撤回30件・独立監査1式（A 系）を経て、owner の gate 3 判断「**止める・規範を積まない・keep-open**」で終わった。成果物はすべて gitignored の作業層（`.oe/` 4本）にあり、放置すれば失われる（#284 で同じ形の破棄が起き、復元に別 PR 1本を要した前例がある）。本単位（W1〜W6）は、**実装差分から復元できないものだけ**を committed 層へ昇格する。canonical は1行も変更しない。

## W1 — worktree と episode 枠

- worktree: `ai-development-hub.docs-#290_promotion-position-bound-failure`（branch `docs/#290_promotion-position-bound-failure`・master `c46f92f` から作成）
- 本 episode 枠を作成。以後の判断・撤回・棄却はその場で追記する。

## W2 — discussion の起草

- 正本: `projects/orchestration-engine/docs/discussions/2026-07-31-discussion-290-canon-verification-exploration.md`（11節）。
- **選別の母集団を「作業層4本の目次」でなく「この arc で何が決まったか」から取った**（採用 NK `01KYJ76D830X…` の適用）。その結果、**gate 0 の決定4件と条件2 の弱読み追補が issue #290 に未正本化（コメント0件）で board にしか無い**ことが判明し、§2 への転記が最優先の保全対象になった。作業層 doc の目次から拾っていたら「plan の前提節に書いてあるから在る」と誤認して落としていた可能性が高い（plan も gitignored である）。
- 落とした側の判断で迷った1件: 撤回30件の逐条一覧。plan §15 が正本だが gitignored。brief の指定（全件列挙はしない・型と経緯の要約）に従い、§4 の要約 + 6回の同型再生産の系列だけ残した。**逐条が必要になる読者は SO 生出力（`tmp/`）と raw log から復元可能**（#289 の前例で実証済みの経路）と判断した。
- 書き方の自己規律: §0 に「読み方の注意」（設計要素は反証の生存記録であって規範ではない）を置き、§9 の各要素に成立条件を併記した。§5 の一般化は「同一 arc・同一問題領域・同一観測者系統の6例」に範囲を固定し、一般法則として書いていない（採用 NK `01KYMRE1NE4H…` は brief 側の採用リストに無いが、brief 本文が同じ注意を明示している）。

## W3 — NK item + 観測の書き戻し

- 新 item: `projects/orchestration-engine/docs/knowledge/items/01KYW0BPJNHP94TNX0VG4G11TX.md`（失敗の型は位置に付く — 検出者が書き手に回っても免れない）。**landing = `nl` と自己判定**。理由: 対象の失敗（成立条件を落として効果を言い切る）は意味判定であり、機械 guard（validator・deny-list）に落ちない。行動変更の実効形「反証プロンプトに『成立条件を落として効果を言い切る型を探せ』を1行入れる」は #290 の各ラウンドで実際に機能した経路であり、NL 注入で運用に乗る。
- 書き戻し: `01KYSKQHDT86GZW87E8EDMSE46` に observation 1件（`state: followed`）。盲検の遮断が読了指定リスト（board in-flight 節・#293 本文）の2経路で破れた件 — slot・引数でなく「読ませる資料の一覧」が下流の口だった変種。
- **validator が1回 WARN を出し、修正した**: observations の `ref` に discussion の repo 相対パスを書いたら「durable な参照形（`#N` / `owner/repo#N` / URL）に限る」と弾かれた（`validate-knowledge` の enum 制約）。`ref: "#290"` に直し、discussion のパスは `note` 内に残した。修正後 `OK`。
- 重複確認（対照つき）: `knowledge-list --strict` = **14件 listed / skipped 0**（計測器が新 item を現に列挙している = 0件誤読の対照）。全14 trigger を並べて突合し、最近傍は `01KYMRE1NE4H…`（一般化の根拠の帰属）と `01KYMRE1NC7X…`（上流の断定）だが、どちらも「検出者→書き手の位置替わりで免疫を仮定する」を覆っていない。重複なし。

## W4 — 実装SO（追記中）

（実行時に追記する）

## W5 — PR + Copilot（追記中）

（実行時に追記する）

## 蒸留シグナル / 昇格候補

- 本単位そのものが昇格であるため、さらなる昇格は原則不要（brief の W6 規定）。新たに出た設計級があればここに追記する。

## Closure（W6 で記入）

（マージ前に `episode-retrospective` に従って記入する）
