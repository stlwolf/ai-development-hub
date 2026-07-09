---
id: "01KX33HHPXYFDA56KNKA9XGWPM"
title: "#239 段階0 episode — 報告未達検知 watchdog（oe-undelivered）実装記録"
date: 2026-07-09
type: episode
status: stable
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/239"
    reason: "統括 watchdog（liveness/異常検知）の段階0 do-less MVP。段階0=報告未達検知のみで keep-open"
  - type: design_context
    ref: "https://github.com/stlwolf/ai-development-hub/issues/220"
    reason: "report_received の frontier（未ack）計算を consume し時間次元を足す（再実装しない）"
  - type: pull_request
    ref: "https://github.com/stlwolf/ai-development-hub/pull/241"
    reason: "本 episode が閉じる実装 PR"
tags: [orchestration, watchdog, report-undelivered, read-only, cron, stage0, do-less, episode, reconstructed]
---

# #239 段階0 episode — 報告未達検知 watchdog（oe-undelivered）実装記録

`reconstructed`（closure 時に再構成。リアルタイム追記ログではない。tier=heavy）。

## Context / なぜ

統括（supervisor）スレッドの異常系が実運用「統括3〜4代」で反復顕在化し（context 肥大死・お見合い・チャネル脆弱・state 乖離）、engine に機械的 liveness/異常監視が無い。設計フェーズの設計 SO（`oe-refute` exploration/3）が「seat+mailbox+staleness 3点で MVP 確定」を **refuted → de-converge**し、owner の HG 決定は**段階0 do-less =「報告未達検知 cron + owner ping」だけ入れて運用観測**、上位アーキ（seat / heartbeat / topology / mailbox / observed projection）は保留。本 episode はその段階0（mode3 チャネル脆弱の検知のみ）を委譲子セッションとして実装した記録。

## 決定と根拠（コード/diff から復元できない「なぜ」）

### DJ-1: frontier をどう consume するか — S3（新 verb が read 規則を inline）

kickoff は「#220 frontier を consume・**再実装しない**」を課した。実体確認で判明した load-bearing な事実:

- #220 の frontier（未ack）計算は**共有 lib になっておらず**、writer `oe-ack`（`_ack_scan`）と reader `oe-activity`（`received_of`）に**2重 inline**。
- `oe-activity --inbox` は **self 中心**（`recipient==$self`・`$TMUX_PANE` 必須）で、**cron の watchdog は self を持たず全ペア横断が必要**。→ **既存 verb をそのまま呼べない**（S1 案は棄却）。加えて `--inbox` 出力は ts を落とすため「pending ペア + age」を一発で返す既存経路が無い。

選択肢:
- **S1**（既存 verb 出力を parse）→ 棄却（self 中心・cron 不可）。
- **S2**（frontier を共有 lib に抽出し oe-ack/oe-activity/新 verb を張替）→ do-less 逸脱・MERGED #220 の bin 2本を触る回帰リスクで**保留（follow-up）**。
- **S3**（新スタンドアロン verb が read-only で走査し #220 と同一の read 規則を inline・global・+age・+liveness）→ **採用**。reader が read 規則を持つのは reader の本質（oe-activity 自身が別 copy を持つ）。consume するのは #220 が emit する `report_received` イベントであって ack ループ本体は再構築しない。frontier read 規則が3つ目の copy になる点は正直なコストとして開示し S2 を follow-up に routing。

### DJ-2: 親子の向き解決 — 全ペア横断ゆえの新規ロジック（departed/role 空を落とさない）

self アンカーが無いので、message が report（child→parent）か kick（parent→child）かを global に判定する必要がある。`oe-activity` の inbox は self で錨を打つため向き誤判定が実害にならないが、watchdog はそれが使えない。**mode3 の主対象は「親が死んだ／send 失敗した departed 子」で、その report は registry GC 後に role 空で残る**（#220 の `_oe_event_ident` 修正が触れた「role 空 + label あり」経路）。素朴な role/parent_of 判定では departed の role 空 report が kick 扱いで**取りこぼされる**（実測: 単純 fallback だと %77→%59 が p=%77 に反転）。

→ 権威マップの複合で解決（強い順）: `child_spawned` の parent_of / `report_received` の acker / message role / **known-parent 集合**（spawn/ack で親として振る舞った pane。departed 子の report でも「宛先が既知親」なら report と判定）。判別不能な完全文脈欠落ペアは report と断定せず skip（誤検知回避側）。report なら常に child=from / parent=to で一貫。

### DJ-3: dedup は「実際に通知できたとき」だけ記録（実装 SO 指摘で是正）

当初は seen cache を notify の前に無条件追記していた。実装 SO（cursor）が「wez 不在 / notify 失敗 / 中断で先行追記すると owner ping が**永続抑止**される」と指摘。→ **通知成功時のみ seen 追記**へ是正。wez 不在なら記録せず次回再通知（stdout は毎回 durable 表示・wez 復帰時に通知）。dedup の目的は「同じ通知の spam 抑止」であって「通知していないのに抑止」ではない、という不変条件を明文化した。

## 事実・失敗（実行ログに残る失敗を選択的に省略しない）

### 実装 SO（`oe-review` impl）を 2 周実施した — mandate は 1 周（honest 開示）

kickoff/HG は「実装 SO 1周」を課した。だが round1 が material な欠陥を出したため確認として round2 も回した（1周 mandate の超過）。**両ラウンドとも verdict は refuted のまま**で「survived」判定には到達していない。ただし surface した material 指摘は**全て修正し、各々に回帰テストを付けて独立検証**した（SO verdict でなくテストで確証）。弱 SO 規律（1周・partial は disclose・iterate しない）に従い round2 修正後は再周回せず停止した。

- round1 refuted(2/2): **(a) 非実行ビット** — verb が `100644` で追加され README/cron の直接実行経路が不達（テストは `bash bin/...` 起動なので緑のまま隠れていた）→ `chmod +x`。 **(b) dedup 永続抑止**（DJ-3）。
- round2 refuted(1/2・他 1 レーンは出力不正で verdict 取得できず): **(c) label 未サニタイズ** — `clab`/`plab` が無害化されず stdout / wez notify へ到達し ESC/CSI/OSC 注入・視覚偽装の余地。preview は #224/#233 で sanitize 済だったが label は漏れていた → preview と同様に jq cntrl 畳み + `oe_sanitize_conversation`。

### 制御文字混入の tooling gotcha（プロセス失敗・再発防止に有効）

ファイル書き込み時、ANSI 風トークン（`U+001B` を伴う CSI）や `U+001F`（US 区切り）を**生バイトとして意図せず挿入**する事象が複数回発生した。症状: (1) テスト fixture の JSON 文字列に生 `U+001B` が入り、`jq fromjson?` が JSON 不正で行ごと drop → テスト [13] が「制御文字が畳まれた」でなく「行が消えた」で fail。(2) bin の `join()` の US 区切りが生 `U+001F` バイトで書かれ（`oe-ack` は文字列エスケープ `\u001f` を使う）hygiene 違反。

- **検知**: `LC_ALL=C grep -nP '[\x00-\x08\x0b-\x1f\x7f]'` で全ファイル走査 + `od -c` でバイト確認。shellcheck では検知できなかった。
- **是正**: (1) fixture の制御文字は**ソースに生バイトを置かず** runtime に `printf` で生成し `jq` に JSON エスケープさせて書く。(2) 生 US バイトは `perl -i -pe 's/\x1f/\\u001f/g'` で文字列エスケープへ変換し `oe-ack` と揃えた。

### Copilot review（自動 bot）

依頼（`gh pr edit 241 --add-reviewer @copilot`）→ 非同期で summary review（state COMMENTED・inline コメント 0 件）を返した。**"reviewed 1 out of 3 changed files and generated no comments."** 実質指摘ゼロ・scope 拡大の push back も無し。返信対象スレッド無し・コード変更無し・再リクエストせず（1ラウンド自律規律）。

## わかったこと（W）

- ISO-8601（event-bus は常に `+00:00`）→ epoch は **jq の `fromdateiso8601` + `now` 引数注入**で可搬に計算でき、BSD/GNU `date` の parse 差を回避できる。テストは `OE_UNDELIVERED_NOW_EPOCH` で now を固定して age を決定論化した。
- `bin/oe` は verb dispatcher でなく engine 実行本体。`oe-*` verb は個別実行ファイルなので新 verb 追加に dispatcher 改変は不要。
- `lib/oe-viewer.sh` は `oe-view` 専用で frontier ロジックの置き場ではない → S3 は inline（`oe-ack` の `_ack_scan` 前例に整合）。

## 原則（Pattern / Anti-pattern）

- **Anti-pattern**: dedup/抑止キャッシュを「作用（通知/送信）の前」に無条件で書く → 作用が失敗した経路で**永続抑止**になる。**Pattern**: 抑止キャッシュは作用が成功したときだけ記録する（作用と記録の順序を作用側に寄せる）。
- **Anti-pattern**: 会話/端末到達面へ出す文字列のうち一部（preview）だけ sanitize し、隣接する同類（label）を見落とす。**Pattern**: 「到達面へ出る文字列」を型として洗い出し、同一チョークポイントを全経路に通す（#224/#233 norm）。
- **Anti-pattern**: self 中心の既存 view をそのまま global 用途へ流用しようとする。**Pattern**: アンカー（self）の有無で必要ロジックが変わることを先に確認し、無い側の権威情報（spawn/ack/known-parent）から再構成する。

## 行動変更（トリガ・機構・着地先）

- なし（本 episode で新規 hook/skill 化はしない）。制御文字混入の gotcha は再発防止機構化の候補だが機構未確定 → 残課題へ降格（下記 routing）。

## 蒸留シグナル（昇格候補）

- **なし**（段階0 の実装知見。Decision/skill/rule への即時昇格候補は無し）。frontier 共有 lib 化（S2）は段階が進み copy が増えるなら Decision 化の余地。

## follow-up routing（全項目に行き先）

- frontier read 規則 3-copy（oe-ack/oe-activity/oe-undelivered）の共有 lib 統合（S2 相当）→ **PR #241 本文に記録・段階が進む時に別 Issue 化**（今は追わない）。
- `wez notify` の cron（no TTY / mux socket）到達性未検証 → **README に注記済み・stdout fallback で durable**。代替（tmux display-message / alert ファイル）は段階外 defer。実機確認は運用観測フェーズ。
- **out-of-scope 発見（back-propagation）**: 既存 `oe-activity` / `oe-ack` も label を無害化していない（preview のみ）→ **PR #241 follow-up に記録・label hardening の横展開は別 PR**（本 PR では実装しない）。
- 制御文字混入 gotcha の機構的検知（pre-commit / CI での `grep -P` 走査）→ **機構未確定・追わない宣言**（必要になれば別途）。
- owner musing（将来候補）: (i) viewer の gone 親以下/親移譲表示（PR-9 候補据え置き）、(ii) 並列の親での異常蓄積の可視化（段階2/3 or viewer follow-up）→ **PR #241 に記録・段階1+**。
- W=1800s の妥当値 → **運用観測で調律**（段階0 の目的そのもの）。

## 残課題（証明できなかったことは書く）

- 実装 SO は 2 周とも **refuted のまま**で「survived」verdict には到達していない（material 指摘は全て fix + テスト検証済だが、SO 自身の合格印は取れていない）。round2 は 1 レーンが出力不正だった。
- `wez notify` が cron 環境で実際に owner へ届くかは**未検証**（stdout fallback が durable な保険）。

## 次の消費者

- **段階1+ の担当（seat/heartbeat 等）**: 本 verb の frontier consume パターン（S3）と向き解決ロジックを前提にできる。S2（共有 lib 化）を判断する起点。
- **owner/親（%144）**: PR #241 のマージ判断・#239 の段階0 landed コメント（keep-open）投稿・運用観測での W 調律。

## status

- status: **stable** / 達成度: **達成**（段階0 do-less の scope=報告未達検知のみを実装・PR #241 作成・レビュー通過）。
- **#239 は段階0 のみで keep-open**（多段の最終段まで close しない・#233 close hygiene 教訓の前向き適用）。マージ・worktree 掃除・#239 close・段階0 landed コメントは owner/親の責務。

## evidence anchor

- PR: https://github.com/stlwolf/ai-development-hub/pull/241 ・実装 commit `ca15a52`（amend 済・最終）。
- test: `tests/test_oe_undelivered.sh` 20 節/54 assert・bash 5.2.37 / 3.2.57 両系 green・shellcheck PASS。
- 実装 SO audit_id: round1 `20260709081753830DZ6YHF19C`（refuted 2/2）/ round2 `202607090842374RNY53D40Y0Z`（refuted 1/2・1 レーン出力不正）。出力は揮発（`tmp/oe-review-*`）につき要点を本 episode に転記。
- 設計提案（写し）・plan: `.oe/ref-proposal-238-239.md` / `.oe/plan-stage0.md`（揮発・worktree 内）。設計判断（S1/S2/S3 の採否・向き解決ロジック）の要点は §決定と根拠に転記済で単独依存しない。
- **closure Step4 外部チェック（heavy tier・`so-compare` codex+claude 2レーン成功）**: closure 品質の4観点（選択的省略／follow-up routing／evidence anchor／back-propagation）を検証 → **両レーン「問題なし」**。両レーンは episode の主張（chmod / dedup 是正 / label 未サニタイズ是正 / SO 2周 refuted・survived 未到達 / back-prop 実在）を repo 実体と突合し独立確認した。出力は揮発（`tmp/so-*`）につき結論を本行へ転記。
