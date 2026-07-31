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
- **選別の母集団を「作業層4本の目次」でなく「この arc で何が決まったか」から取った**（採用 NK `01KYJ76D830X…` の適用）。その結果、**gate 0 の決定4件と条件2 の弱読み追補が issue #290 に未正本化（コメント0件）で、board と委譲 brief（どちらも作業層）にしか無い**ことが判明し、§2 への転記が最優先の保全対象になった。作業層 doc の目次から拾っていたら「plan の前提節に書いてあるから在る」と誤認して落としていた可能性が高い（plan も gitignored である）。
- 落とした側の判断で迷った1件: 撤回30件の逐条一覧。plan §15 が正本だが gitignored。brief の指定（全件列挙はしない・型と経緯の要約）に従い、§4 の要約 + 6回の同型再生産の系列だけ残した。落とす根拠は指定粒度と「判定の要点は §4・§7 に転記済み」であることに置く（`tmp/`・raw log は gitignored で、将来の復元可能性は durable な根拠にならない — W4 の SO 指摘で言い直した）。
- 書き方の自己規律: §0 に「読み方の注意」（設計要素は反証の生存記録であって規範ではない）を置き、§9 の各要素に成立条件を併記した。§5 の一般化は「同一 arc・同一問題領域・同一観測者系統の6例」に範囲を固定し、一般法則として書いていない（brief 採用 NK `01KYMRE1NE4H…` の教訓と、brief 本文の明示注意に従った。初稿はこの item を「採用リストに無い」と書いており、**W4 の両レーンが事実誤認として捕まえた** — brief:100 に採用1件目として明記されている）。

## W3 — NK item + 観測の書き戻し

- 新 item: `projects/orchestration-engine/docs/knowledge/items/01KYW0BPJNHP94TNX0VG4G11TX.md`（失敗の型は位置に付く — 検出者が書き手に回っても免れない）。**landing = `nl` と自己判定**。理由: 対象の失敗（成立条件を落として効果を言い切る）は意味判定であり、機械 guard（validator・deny-list）に落ちない。行動変更の実効形「反証プロンプトに『成立条件を落として効果を言い切る型を探せ』を1行入れる」は #290 の各ラウンドで実際に機能した経路であり、NL 注入で運用に乗る。
- 書き戻し: `01KYSKQHDT86GZW87E8EDMSE46` に observation 1件（`state: followed`）。盲検の遮断が読了指定リスト（board in-flight 節・#293 本文）の2経路で破れた件 — slot・引数でなく「読ませる資料の一覧」が下流の口だった変種。
- **validator が1回 WARN を出し、修正した**: observations の `ref` に discussion の repo 相対パスを書いたら「durable な参照形（`#N` / `owner/repo#N` / URL）に限る」と弾かれた（`validate-knowledge` の enum 制約）。`ref: "#290"` に直し、discussion のパスは `note` 内に残した。修正後 `OK`。
- 重複確認（対照つき）: `knowledge-list --strict` = **14件 listed / skipped 0**（計測器が新 item を現に列挙している = 0件誤読の対照）。全14 trigger を並べて突合し、最近傍は `01KYMRE1NE4H…`（一般化の根拠の帰属）と `01KYMRE1NC7X…`（上流の断定）だが、どちらも「検出者→書き手の位置替わりで免疫を仮定する」を覆っていない。重複なし。

## W4 — 実装SO（弱・他族2レーン・1ラウンド）

- 出力: `tmp/so-290-w4/`（worktree 側・codex `exit 0` 8,516 bytes〔初回 timeout → リトライ成功〕 / cursor `exit 0` 6,864 bytes）。判定は **codex `conditional-yes` / cursor `conditional-yes`**。0レーンでない。
- **最重要の指摘（cursor・必須）**: §7.2 の「生き残り」括弧に**撤回29 の部分撤回（「どの spawn が succession かの分類が要らない」）が生きたまま残っていた** — 本単位の最大リスク（撤回済み主張の復活）そのものを、昇格 doc が1箇所で再演していた。修正済み。
- **同型の言い切りの検出（codex）**: §5「賢くしても・教育しても消えなかった」（測定していない語への拡張）/「個体の能力が変わったのではなく、位置が変わった」（因果の確定）/ §9 C1「書き手の外の集合」（撤回18 の再混同）/ §9 訂正3要素「自己申告でなく集計可能」（記録の正確性という成立条件の欠落）/ §0「併記してある」（自己認証）/ NK prediction・exclusions・「毎ラウンドこれで捕まった」。**全て修正済み**（観測語への置換・成立条件の併記・方針宣言への降格）。
- **事実誤認2件（両レーン）**: episode の「gate 0 決定は board にしか無い」（正: board と委譲 brief）と「NE4H は brief 採用リストに無い」（正: 採用1件目に明記）。**修正済み・後者は本文に検出経緯ごと残した**。
- 崩れなかったもの（両レーンが明示）: §5 冒頭の範囲固定・brief 候補6件のカバレッジ・gate 0 転記の追加保全・NK trigger の非重複（全14件突合）・`followed` の state 選択・`.oe/` への根拠依存なし。
- 位置に付く失敗の型の**7例目に相当する再演が本単位でも起きかけた**（§7.2 の復活 + 言い切り群）ことは、新 NK item の prediction を裏書きする実測として本 episode に記録する。今回も自己検出はゼロで、捕まえたのは外部の2レーンである。

## W5 — PR + Copilot（追記中）

（実行時に追記する）

## 蒸留シグナル / 昇格候補

- 本単位そのものが昇格であるため、さらなる昇格は原則不要（brief の W6 規定）。新たに出た設計級があればここに追記する。

## Closure（W6 で記入）

（マージ前に `episode-retrospective` に従って記入する）
