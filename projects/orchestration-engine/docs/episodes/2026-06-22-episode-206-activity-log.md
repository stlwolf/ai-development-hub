---
id: "01KVQPVHZKTC5PGX3JF39GCSZ0"
title: "#206 親子活動ログ + oe-activity（report inbox 増分1）実装エピソード"
date: 2026-06-22
type: episode
status: stable
related:
  - type: implements
    ref: "#206"
  - type: decision
    ref: ../decisions/2026-06-22-decision-206-activity-log-self-contained-events.md
  - type: depends_on
    ref: "#188"
---

# #206 親子活動ログ + oe-activity（report inbox 増分1）実装エピソード

> `reconstructed`（締めで一括執筆＝後追い再構成・リアルタイム追記ではない＝証拠価値はその分低い）。
> 委譲子セッション（`%66`）が WORKTREE `feature/#206_report_inbox` で実装（親 `%59` から委譲）。

## コンテキスト / なぜ

親子委譲は「投げて忘れる」運用になりがちで、(1) 子が何を返したか中身を回収できない、(2) 送信が届いたか見えない、(3) 子ペインが消えると相互作用を追えない（departed children も後から見たい）という観測欠落があった。`#206`（report inbox）の増分1 として、親子相互作用を永続記録し read 時に投影する活動ログを最小実装する。

入口は v4 claim（`.oe/claim-206-increment1-v4.md`・question-driven-design で仕様確定・設計SO v1–v3 の 3 連続 refuted を経て確定）。本セッションでは親の指示でさらにスコープを縮小した（下記）。

## 決定と根拠（diff / ADR から復元しにくいコアのみ）

設計判断の正本は [#206 ADR](../decisions/2026-06-22-decision-206-activity-log-self-contained-events.md)。ここでは ADR に落ちない「なぜこの形に縮んだか」を残す:

- **session_id 主キー（#188 DJ-188-4 原案）→ 自己完結イベント（write 時 snapshot）へ精緻化**。きっかけは「delegate 子に session_id が無い」という #188 の確定事実。v1–v3 設計SO が反復で潰した「pane 主キー bus は GC/再利用で寿命ミスマッチ」も、emit 時に from/to の identity を焼き込めば read 時に live registry へ依存せず解消する。**識別の単一ソース（#188 の思想）を“永続化の鍵”でなく“write 時の投影”で満たした**のが非自明な接続。→ ADR で DJ-188-4 を部分 supersede、#188 にはステータス行のみ back-prop（本文不可触）。
- **親指示でのスコープ縮小（v4 claim からさらに削った）**: claim では viewer が lifecycle-end/stall を read 時推論（最終イベント + mux 生存 query で「終了 vs stall」分類）する設計だった。本セッションで **lifecycle/stall 推論を落とし**、viewer は 往復 / 配送 / preview / 送信元(子)生存 の 4 つだけに縮めた。理由＝**DJ-188-2 の category error（対話子の非対称 lifecycle を engine 完了 enum に押し込む）を観測側に持ち込まない**。liveness は「終了/stall」の解釈でなく `alive`|`gone`|`?` の生 fact に留める。これは「観測は honest な生データまで・解釈はしない」という #177/#188 の read-only 規律の延長。

## 検証（要点・SO 証跡）

- shellcheck rc=0 / **bash 3.2.57・5.2.37 で test_event_bus 31/31・test_oe_activity 24/24**（既存 test_delegate_send 36・test_oe_delegate 20 も green・emit は `OE_EVENT_LOG=0` で隔離）。
- **実装中に自己検出した bug**: `extra="${8:-{}}"` の default `{}` の `}` が展開閉じ括弧と衝突して `{}}`（不正 JSON）になり、jq が空を返して **emit が黙って no-op**。best-effort（常に return 0）ゆえテストで初めて「ファイルが出来ない」として顕在化。別代入 `extra="${8:-}"; [[ -n "$extra" ]] || extra='{}'` で修正。→ **負の知見**: best-effort で握り潰す経路は、パラメータ展開の罠を silent に飲み込む。emit 系は最小の happy-path テストを先に通すべき。
- **実装SO** `oe-review` 2 レーン（codex+cursor）: **refuted 2/2**（audit `20260622124724DX9W4KPGCM2Z` / diff_base master / reviewed_sha `36accbf`・SO 出力 `tmp/oe-review-20260622124724DX9W4KPGCM2Z/`）。1 ラウンド自律対応:
  - **[cursor・real・採用]** label 内 TAB が `_oe_event_ident` の `role<TAB>label<TAB>parent` 内部プロトコルを壊し parent/role の焼き込みを誤る（改行は畳むが TAB 未処理）。→ label の TAB も空白へ畳む + 回帰テスト [8b]。実機 repro で確認（`foo\tbar` → parent が `bar` に誤シフト）。
  - **[codex・false positive・不採用]** 「`jq -rs … @tsv` が raw でなく主要表示がパース不能」→ **直接検証で反証**（`jq -rs '…@tsv'` は raw TSV を出力。codex の repro は `jq '.|@tsv'` で `-r` 抜きの別 invocation。viewer テスト 22 件も実データで通過）。SO 指摘でも oracle 照合で却下した一次確認の例。
  - **[cursor・doc/degrade・採用]** 同一サーバ `%N` 再利用の混線 → 既知制約に明記（server-pid キー化は後続 defer）。壊れた JSONL 行で exit 1 → `jq -R 'fromjson? // empty'` 前段でスキップ + 回帰テスト [11]。reader 専用 `OE_EVENT_FILE` footgun は撤去し `OE_EVENT_DIR` 単一ノブに統一。
- **Copilot**: PR レビュー依頼済み（本 episode 締め時点で未返信／対応は別途）。

## closure

- status: `stable` / **達成度: 達成**（増分1 = emit 結線 + 自己完結ログ + read-only viewer + report inbox を実装・テスト・実装SO 1 ラウンド対応まで）。
- tier: **heavy**（意図的な実装SO 起動・非自明な設計判断＝DJ-188-4 精緻化と棄却理由・Decision 昇格あり）。
- 次の消費者: cockpit を見る人間（`oe-activity` / `--inbox`）+ **増分2**（B の turn 粒度 timeline・`report_received` 追加。additive schema が前提）+ #114/Stage-B 着手者（永続横断観測の鍵戦略を本 ADR が確定）。
- 蒸留シグナル: **Decision 昇格あり** → [#206 ADR](../decisions/2026-06-22-decision-206-activity-log-self-contained-events.md)（#188 DJ-188-4 を部分 supersede）。負の知見（best-effort emit の silent no-op）は #62 注入候補だが今回は本 episode 記録に留める。
- follow-up routing:
  - server-pid をレコードに含めず `%N` を関係キーにする → 同一サーバ再利用の混線。**後続増分**（ADR 残課題・viewer の既知制約に明記済）。
  - log rotation / retention → **defer**（`#185` raw-log retention と同様・viewer 既定窓で緩和）。
  - engine session_id 側との統合 / turn 粒度 timeline（B）→ **増分2**。
  - #144 reliability 再実装は **追わない**（境界・delivery_signal は #144 信号を読むのみ）。
- **Step4 辞退（heavy 外部チェック・advisory）**: 親指示の本タスクのフローは 実装→実装SO→episode→PR→Copilot で、episode の追加外部SO は指定プロセス外。closure 品質 4 観点を自己点検し低リスクと判断して辞退。覆った観点= 失敗の選択的省略なし（`${8:-{}}` bug / SO refuted / codex false positive を明記）／ routing 網羅（defer 4 件すべて行き先付与）／ evidence anchor（SO audit id・出力パスを本文転記）／ back-propagation（#188 にステータス行追記済・矛盾なし）。未実施観点と判断= so-compare 再チェックは指定フロー外 + 上記 4 観点を本文で自己点検済のため不実施。
