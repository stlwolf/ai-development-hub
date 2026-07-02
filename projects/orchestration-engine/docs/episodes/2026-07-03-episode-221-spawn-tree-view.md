---
id: "01KWJ0F80R40JRHTKQHDWB8D0C"
title: "#221 episode — spawn ツリー（親→子→孫）read-only トポロジ観測ビュー実装記録"
date: 2026-07-03
type: episode
status: draft
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/221"
    reason: "spawn トポロジの read-only ツリー表示（cockpit epic #169 配下）"
  - type: design_context
    ref: "https://github.com/stlwolf/ai-development-hub/issues/177"
    reason: "read-only 観測規律（oe-status と同クラス）の先行事例"
tags: [orchestration, cockpit, spawn-tree, topology, observation, read-only, episode]
---

# #221 episode — spawn ツリー（親→子→孫）read-only トポロジ観測ビュー実装記録

親（統括）からの委譲子セッションとして、#221「registry の `parent_pane` から spawn トポロジ（親→子→孫）を read-only でツリー表示」を実装する。`oe-list` は flat（PANE / SOURCE / LABEL）で世代・親子関係が見えず、multi-session 運用で「何が何を立てたか」「どのペインが孫か」の認知負荷が顕在化した — それを観測ビューで解くのが本作業。設計方向は issue で固定されておらず、ゼロベース設計（`predecision-exploration`）が親の明示指定。

## 着手時 grounding（2026-07-03・設計前の実測）

- kickoff（`.oe/kickoff-221.md`・揮発）読了 → issue #221 原文・`lib/delegate-registry.sh` 全文・`bin/oe-list` 全文・`bin/oe-activity` の liveness query（L86-98: `tmux list-panes -a` 突合、alive|gone|?、tmux 不在は ? で degrade）を読了してから設計に入った。
- registry 実データ実測（`~/.claude/state/oe-delegate/*.json`・2026-07-03 時点）: 6 entry。**親→子→孫の実連鎖が現存**: `%49(gone) → %83 → {%85 → %110, %94}` の 3 世代 + `%1(gone) → %3` + `%73 → %114(本セッション)`。
- 実測からの設計入力（issue 記載に加えて確認できた事実）:
  - **root 親は registry に entry を持たない**（`parent_pane` 参照としてのみ現れる）。root のラベルは pane-issue / pane-title fallback が必要。
  - **gone 親 × alive 子が実在する**（%49 は live panes に無いが子 %83 は alive）— 「stale の扱い」は葉ノードだけでなく中間/根ノードにも及ぶ。
  - **GC は write path**: `oe_reg_gc` は `oe_reg_record` 時のみ走る（delegate-registry.sh L64）。観測ツールから GC を呼ぶのは read-only 規律違反になる — 設計上「gone 表示」側に強い根拠。
  - **別 server_pid の entry は GC が消す**（`oe_reg_gc` L182: 現 server pid 以外の key を無条件 rm）。複数 tmux server 跨ぎの表示は「registry 上ほぼ存在し得ない状態」— 見せ方の論点は実質 degrade 表示の話に縮む。

## 設計フェーズ（2026-07-03）

- **ゼロベース設計**（`predecision-exploration`）: 探索木を `tmp/dj-221-tree.md`（gitignore・揮発）に外部化。DJ は 7 本: 表面（oe-list --tree / **新規 oe-tree** / oe-status 区画 / oe-activity --topology / JSON only）・データ源（**registry** / event log / hybrid）・ノード集合と root 合成・描画（**罫線** / インデント / flat+GEN 列）・列構成・stale（**gone 表示** / GC / 非表示）・server 跨ぎ（**現 server のみ + footer 開示**）。
- **ゼロベース発見（初期案セット外のカテゴリ）**: event log `child_spawned` からの歴史トポロジ再構成。実測で `~/.claude/state/oe-events.jsonl` に child_spawned 23 件（spawn 時ラベル両端付き）が実在し、oe-activity はこれを方向判定（`parent_of` 導出）にのみ使いツリー描画はしない — 「現在トポロジのツリー」だけが真の空白と確認。v1 棄却の根拠: event に server_pid が無く server 再起動跨ぎで pane-id 再利用の混同が起きる / 歴史フローは oe-activity の領分（レイヤ分離）。gone root のラベル補完 hybrid は follow-up として surface。
- **read-only の設計帰結**: `oe_reg_gc` は `oe_reg_record` 時のみ走る write path（delegate-registry.sh L64）で、別 server pid の entry を無条件 rm する副作用も持つ（L182）— 観測ツールから GC を呼ぶ選択肢は規律違反として棄却、stale は gone 表示に確定。
- 設計SO: claim doc `tmp/dj-221-claim.md` に探索木ごと固めて `oe-refute --rubric exploration`（弱SO・2レーン）を実行 →（結果は下に追記）
- 設計の実行可能性は SO 待機中に scratchpad プロトタイプで実データ検証: 現 registry から 3 世代チェーン（%49 gone → %83 → %85/%94 → %110）・gone root・self marker・ラベル優先順位（pane-issue > registry label）が設計どおり描画されることを確認。
- **SO#1**（audit_id 20260702181743X06TWAHYRPY8）: verdict=**refuted 2/2**。一次照合の結果、実質的発見として採用:
  - **role 列棄却の根拠が誤り**（両レーン指摘）: 「registry の role は常に child で情報ゼロ」は stored field としては正しいが、`oe-ident` が parent_pane 逆引きで parent/child を read-time 導出する家族概念が実在（oe-ident:60-72 + test_oe_ident.sh [3] を実照合）。v2 で根拠を差し替え: oe-ident は単一ペインの孤立表示だから role 列が要る・ツリーは関係を描くので木の形が role を搬送する。issue 文言との解釈差はユーザー承認ゲートに明示で晒す。
  - **tmux 不在 exit 2 は観測クラスの慣例と不整合**（codex 指摘）: oe-status は degrade 継続（L164-178 実照合）・oe-activity は `?`。v2 で degrade（liveness=? + 埋込 pid グループ表示）に差し替え。
  - **出力 sanitize 欠落**（cursor 指摘）: oe_reg_list の LF/CR 畳み（L155-162・#178 系）を oe-tree 出力にも継承。
  - **GC×gone の時間的意味論**（cursor 指摘）: gone entry は次の `oe_reg_record` の GC までしか残らない = 本ビューは現在の登記スナップショット・歴史は oe-activity の領分。明文化して受入判断に晒す（read-only では変えられないデータ源の性質）。
  - **テスト成果物**（両レーン指摘）: tests/test_oe_tree.sh をスコープに含める（fixture + TMUX 偽値注入 = test_oe_ident のイディオム）。
  - 採用しなかった指摘と理由は `tmp/dj-221-tree.md` v2 節に記録（oe-ident 再利用共通化=出力契約が表示向けでパース不能・workspace 表現比較=--json follow-up の領分・「SO未実行で最良確定」=本ラウンド自体がその SO という自己言及）。
- **SO#2**（v2 claim・audit_id 202607021823225DGRRQ4GM9TR）: verdict=**refuted 2/2**。指摘の分類と処置:
  - **artifact 欠陥（採用・即修正）**: v2 を探索木に追記形式で足したため、本文 DJ-221-5/7 に旧記述（exit 2・旧 role 根拠）が残り claim と自己矛盾（codex）。→ 探索木を v3 に統合書き直し。
  - **仕様化不足（採用・v3 で仕様化）**: 全森林走査は `oe_reg_list` で流用不能（生存ペイン起点 + self scoping）なのに森林構築・複数 root 順・orphan・cycle の仕様が無い（cursor #4）→ DJ-221-3 にアルゴリズム明記。テスト計画が列挙のみ（cursor #8）→ DJ-221-8 に 10 ケース仕様化。TAB sanitize の引用根拠が oe_reg_list の注記（TAB は scope 外）と矛盾（cursor #5）→ 根拠を「表示崩れ防止（oe-activity 前例）」に修正、挙動は維持。
  - **tmux 不在挙動の再統合（採用）**: v2 の「pid グループ degrade」は未探索の新カテゴリで oe-status の degrade（多区画中の 1 区画非表示）とも別物（cursor #3）→ 3 案比較の上「stderr note + exit 2」に確定。根拠 = oe-tree は単機能 verb で全投影が tmux 依存・「degrade で残せる部分価値」が構造的に無い・lib 家族の rc=2 規約と一致。
  - **手続き指摘（ゲートで解決 — SO では解決不能）**: role 列省略は issue 文言との deviation でユーザー承認未了のまま「確定」と扱えない（両レーン・最重要）／gone の時間的意味論の受入可否／workspace・self marker が issue 外の追加列（--json を棄却した最小スコープ判断が列追加側に未適用・cursor #6）→ これらは **DJ-OPEN 1-4 として明示し hg-1（このペインのユーザー承認）に晒す**。SO を追加で回しても人間の受入判断は代替できないため、弱SO 規律の「refuted なら確定保留」= 確定せずゲートへ、で処理。
  - プロトタイプ揮発性（cursor #2）は test_oe_tree.sh の fixture 化（DJ-221-8 ケース 1 が %49 チェーン型）で恒久化する。
- 設計SO 総括: 2 周とも refuted だが、SO#1 の実質的発見（role 概念・degrade 慣例・sanitize・意味論明文化・テスト）は v2/v3 に吸収済み。残余 refuted 核は「承認ゲート未了」という手続き項目に収束 — 設計は**未確定のまま** DJ-OPEN 4 点を添えて hg-1 に提示する（確定はユーザー判断後）。

## ユーザー承認（hg-1・2026-07-03）

- DJ-OPEN 4 点（role 列なし / workspace + (you) 追加列 / gone スナップショット意味論の受入 / tmux 不在 exit 2）を推奨付きで提示 →「推奨で OK」の明示承認。設計確定。
- 承認時の追加確認（ユーザー質問）: 「ビューアー自体はスコープに入っているか。C-Space g で開くウィンドウ/ペインのビューアーと似た感じか」→ 実物照合の上で回答: C-Space g の実体は `display-popup` + `~/bin/tmux-claude-picker`（fzf で現セッションのペイン一覧・preview・ジャンプ。tmux 構造が対象）。oe-tree は CLI 出力が本体で対話 UI はスコープ外（#221 は「観測・表示」限定）。picker が見せるのは tmux の window/pane 構造で、spawn の親子（誰が誰を委譲したか）は tmux が知らないデータ — oe-tree はその欠けた軸を registry から出す補完関係。popup バインド 1 行（dotfiles 側）や fzf 対話化（#176/oe-status -i の系譜）は follow-up として surface。

## 実装フェーズ（2026-07-03）

- `bin/oe-tree`（新規・実行可能）: 承認済み設計どおり。registry 現 server 走査（US 区切り内部プロトコル・jq 側で US/TAB/LF/CR を空白に畳む）→ root 合成（parent 参照のみの pane + parent 空 entry）→ 罫線再帰描画（兄弟は pane 番号昇順・visited set の cycle guard）。liveness は `tmux list-panes -a` 突合で query 失敗は `?` degrade・`$TMUX` 不在は stderr note + exit 2。異 server entry は非表示 + footer 件数。設計外の追加安全策 1 点: **純粋 cycle（root から到達不能な輪）は森林ループで描かれず無言で消える**ことに実装中に気づき、未到達 entry の sweep（最小 pane を擬似 root に描画・cycle guard が閉じで `[cycle]`）を追加 — 「登記に在るのに見えない」偽りの防止で read-only のまま。
- `tests/test_oe_tree.sh`（新規）: mock tmux（PATH 先頭差し替え・test_oe_jump/test_oe_select と同型）+ 実 jq + 隔離 state + TMUX 偽値 `,12345,0`。DJ-221-8 の計画 10 ケースを 11 ブロック 15 チェックに展開（3 世代チェーン=実測 %49 型 fixture・複数 root 数値順・pane-issue 優先・sanitize・cycle+`?` degrade・foreign footer・空登記・TMUX 不在 exit 2・pane_title fallback・gone 中間親・引数系）。**15/15 PASS**（初回実行）。
- shellcheck: `bin/oe-tree` / `tests/test_oe_tree.sh` とも指摘ゼロ（テスト側 SC2155 を 1 件修正）。
- 実データ検証: 実行のたびに登記が動く現場をそのまま捕捉 — プロトタイプ時に居た %110 が本実装の実行時には GC 済みで新 spawn %116 が出現。「gone は次の spawn 登記まで」のスナップショット意味論が実データで実演された（DJ-OPEN-2 で受入済みの性質そのもの）。
- doc: `bin/README.md` に oe-tree 節（意味論・root 合成・role 列なしの根拠・degrade/exit 規約・follow-up 明記）、`README.md` 構成ツリーに 1 行。

## 実装SO（oe-review・2026-07-03）

- **SO#1**（audit_id 20260702193221P5S74SS5ARP5・reviewed_sha a71b587・2レーン）: codex=survived / cursor=**refuted** → conservative 集約で refuted・PR 保留。cursor の material 指摘 2 件を実コード照合の上で両方採用:
  - **failure propagation**: 読めない/不正な現 server entry を `continue` で無言スキップ → 全滅時に「(no spawn entries)」と事実に反する断言・部分スキップ時は不完全ツリーが完全に見える。foreign には footer note を出す非対称は「honest degrade」の自己矛盾 — 指摘どおり。→ SKIPPED カウンタ + footer 開示 + 全滅時は `(no readable spawn entries ...)` に変更。
  - **偽 [cycle]**: 同一 `.pane` の重複 entry（key と .pane の不整合＝write 側不変条件違反データ）を dedup せず、2 回目の render が visited に当たり正当な子でないのに `[cycle]` と誤表示 — 到達可能（ファイル操作で作れる）。→ 収集時に先勝ち dedup し skipped として開示。
  - 非 material 指摘（pane-issue 経路 label の US 未畳み）も安価なので同時に畳んだ。cursor が反証して潰した候補（VISITED 境界一致・cycle sweep・sanitize・degrade 同型）は実装の妥当性の裏取りとして episode に残る。
  - 修正 commit: 56ce2c5（tests 18 チェックに拡張・shellcheck クリーン維持）。
- **SO#2**（audit_id 202607021939281V98DFA6052R・reviewed_sha 56ce2c5）: cursor=**survived**（SO#1 指摘の修正を確認・新規 material なし）/ codex=**refuted**（新規指摘）→ conservative 集約で refuted。codex 指摘を一次照合の上採用:
  - **ESC 等の端末制御文字の直出し**: sanitize が LF/CR/TAB/US のみで、`oe-delegate --label $'\e[2J...'` 経由で ESC が registry に到達し（oe-delegate は LF/CR しか拒否しない — 実照合済み）、人間向け cockpit 表示に画面消去・視覚偽装・OSC 端末制御が通る。`oe_reg_list` は ANSI を「別軸・scope 外」と注記するが（宛先表の脅威モデル＝レコード境界偽造）、oe-tree は表示そのものが製品なので視覚偽装が本ツールの脅威モデルに入る — material と判断。→ C0 全域 + DEL + C1（U+0000-001F/007F/0080-009F）を jq の codepoint gsub で空白へ畳む（収集経路の clean + pane-issue/pane_title 経路の `sanitize_out` チョークポイント。C1 は UTF-8 符号化形も畳めるよう byte-wise でなく codepoint 処理・jq 不能時は C0+DEL の tr へ縮退）。修正 commit: edc7fa2（tests 19 チェック・OSC/BEL タイトル偽装ケース含む）。
  - 教訓（レーン別レンズの差）: SO#1 で cursor が「pane-issue 経路の US 未畳みは非 material」と流した箇所の上位集合を SO#2 で codex が material として拾った — 2 レーンの独立性が働いた形。
- **SO#3**（audit_id 202607021947362XW6QQHR5P69・reviewed_sha edc7fa2）: **survived 2/2**（codex/cursor とも material なし。cursor は 19/19 テスト・shellcheck・cycle/dedup/sanitize/foreign 経路の手動追跡を明記）。実装SO ゲート通過 — PR 作成へ。
