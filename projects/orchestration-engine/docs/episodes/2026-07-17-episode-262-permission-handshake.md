---
id: "01KXQPRSZTVM4H55DNXCZHZT7V"
title: "#262 v0 — spawn 段 owner 承認ハンドシェイク（binding + audit + 3軸 doc）"
date: 2026-07-17
type: episode
status: draft
related:
  - type: derived_from
    ref: ".oe/plan-262-permission-handshake.md"
    reason: "plan-first の実装計画（設計SO refuted 反映後 rev.2・owner HG gate 3 通過）"
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/262"
    reason: "委譲 auto-mode 子の本番 mutation friction の事象フィードバック"
tags: [orchestration, permission, spawn, handshake, delegate, audit]
---

# #262 v0 — spawn 段 owner 承認ハンドシェイク

## なぜ始まったか

委譲フロー（親→子 spawn・子 auto-mode）で、親が elevated 権限（bypass / 本番アクセス）の子を spawn しようとすると、ハーネスの auto-mode classifier が親の Bash tool-call を評価して block する（安全機構として正しい）。しかし解決経路が非自明で「混乱した往復」が起きていた（issue #262 事象1）。v0 はこの spawn 段の friction を、分類器を尊重したまま **owner 承認ハンドシェイク**で構造的に解消する。

設計は plan-first で進め、設計SO（`oe-refute` 3 lane exploration）が当初案（skill のみ・helper なし・記録なし）を refuted。中核 gap は「承認↔実行の binding」で、owner HG で DJ-3=(b) engine 薄層採用が決まった。発火層は observation-based spike で「親の Bash tool-call を auto-mode classifier が評価」と結論（bypass / 本番アクセス子のみ発火・通常委譲は不変）。

## 設計判断（確定・plan §3 / gate 0-3）

- gate 0（反証外）: v0=spawn 段 / per-spawn clean escalation。
- DJ-3=(b): engine 薄層 `oe-delegate --print-approval`（spawn せず正規化 argv + digest を印字）+ 実 spawn 時 `--approved-digest` で digest 照合 → 承認↔実行を binding。
- DJ-4=yes: `child_spawned.extra.permission_mode` を追記（append-only・registry 非変更）。
- DJ-6: 3軸分離（規範=orchestration-toolkit / ゲート=doc-flow-guardrail routing 表 / 操作=delegate-task）。
- 発火層は分類器そのもの（ハーネス設計意図）で変更対象外。print は spawn しないので block されない・実 spawn は owner ゲートのまま。

## 実装ログ

- worktree `feat/#262_permission-handshake` を作成（子が自作・master 起点）。
- **`oe-delegate`**: `--print-approval`（spawn せず正規化 argv のダイジェスト + 承認パッケージを印字）/ `--approved-digest`（実 spawn 前に引数から digest を再計算して照合・不一致は exit 3）/ `--reason`（パッケージ注記）を追加。ダイジェストは workspace / label / claude 引数 / kickoff / task から決定論計算（`--reason` と ephemeral な `PARENT_TMUX_PANE` は含めない）。
- **audit**: `oe_event_child_spawned` に任意 4th 引数 `permission_mode` を追加し、`oe-delegate` が `extract_permission_mode` で抽出して渡す。`child_spawned.extra.permission_mode` に焼き込み（append-only・registry 非変更）。schema に optional property を additive 追記。
- **docs（3軸分離）**: 規範=`orchestration-toolkit`（なぜ owner 承認が要るか）/ 操作=`delegate-task`（print-approval → owner → approved-digest の 3 手順）/ ゲート=`doc-flow-guardrail` の routing 表に行 **S**（委譲操作軸・別軸・番号なし）。
- **落とし穴（実装中に発見・SO 前に自己修正）**: 初版で `jq ... --args ${CLAUDE_ARGS[@]}` を使ったが、claude 引数が `--permission-mode` 等 option 形のため jq が option と誤認して失敗した。`--argjson` で 1 要素ずつ配列 append する方式へ修正。smoke test で検出。
- **テスト**: `test_oe_delegate.sh` に [12]-[15]（print-approval 無 spawn + digest 印字 / matching digest で spawn / mismatch は exit 3 無 spawn / reason は digest 不変・task は digest 変化）。`test_event_bus.sh` に [1b]（permission_mode 焼込・省略時無し）。全 shellcheck clean。回帰: test_oe_delegate 28/0・test_event_bus 68/0・consumer（undelivered 54 / activity 70 / ack 41）0 fail。

## 実装SO（gate 4）ラウンド1 — refuted → 修正

`oe-review`（codex + cursor 2 lane）が **refuted**（2/2 material）。当初の binding は複数の迂回を許していた。指摘と修正:

- **D1（High・両 lane）相対 workspace 未正規化 → クロス cwd で binding 迂回**: `-w .` が別 cwd から同一 digest になり、owner が承認した作業ディレクトリと別のディレクトリで elevated 子が起動できた。→ WORKSPACE を実行前に絶対化（`cd && pwd`）し digest / パッケージ / spawn を一致。実測で別 cwd の digest が異なることを確認。
- **D2（High・cursor）空 `--approved-digest ""` で照合スキップ**: `-n` ガードが空文字を falsy 扱いし照合なしで spawn した。→ フラグ提供の有無を `APPROVED_DIGEST_SET` で追跡し、渡されたら空でも必ず照合。
- **D3（High・codex）elevated 経路が承認なしで到達可能**: engine が「必須」と謳う elevated ゲートを機構保証していなかった。→ `--elevated` 宣言（or `bypassPermissions` 自動検知）の spawn は承認済み digest を必須にし、無ければ exit 3。通常のローカル auto 委譲は対象外（不変）。auto + 本番アクセスは engine 非検知ゆえ呼び出し側が `--elevated` を宣言する。
- **D4（High・codex）承認表示への行注入**: workspace / kickoff が未検証で、改行入り値が承認パッケージへ偽の「承認ダイジェスト:」行を注入し owner 表示を spoof できた。→ workspace / kickoff の LF/CR を fail-fast 拒否。
- **D5（Med・codex）audit が elevated auto と通常 auto を区別できない**: permission_mode だけでは両者 auto で同じ。→ `child_spawned.extra.elevated` を追加（schema additive）。
- **付随**: kickoff は path だけでなく**内容 hash** も digest に含め、承認後の内容差し替え（TOCTOU）を捕まえる。

全修正後: shellcheck clean・test_oe_delegate 38/0（D1-D4 の反証テスト追加）・test_event_bus 71/0（elevated 焼込）・consumer 回帰 0 fail。

## 実装SO（gate 4）ラウンド2 — refuted → 具象修正 + 限界の明文化

再 `oe-review` が **refuted**（2/2）。核心の具象欠陥 1 件 + 固有の v0 限界。

- **R2 具象（両 lane）: elevated が digest に未束縛**。非 elevated の承認 digest に後から `--elevated` を付けて escalation（逆に downgrade）できた。→ `compute_spawn_digest` に elevated 宣言を束縛。反証テスト [22]（escalation/downgrade とも exit 3）。
- **R2 具象（codex）: skill の本番アクセス手順例に `--elevated` が無い** → 例どおりだと D3 強制に到達しない。→ delegate-task 例に `--elevated` を追加。
- **R2 具象（codex）: LF/CR のみ検証で ESC 等の制御文字で承認表示 spoof 可**。→ workspace / kickoff を制御文字全般で fail-fast 拒否 + パッケージ表示値を `_strip_cntrl` でサニタイズ。反証テスト [21]（ESC workspace → exit 2）。

### 明文化した v0 の限界（plan §8 の owner 承認済み defer と整合・SO で再浮上したが追加実装しない）

- **ダイジェストは owner 承認の暗号的証明ではない**（nonce / 期限 / 消費状態なし・自己発行/再利用が理論上可能）。**authZ の実体はハーネスの分類器**（agent は elevated spawn の block を自己解除できない）で、ダイジェストは「owner が見た内容 = 実行内容」を保証する drift-guard。別レイヤーであり、この設計の前提（分類器を迂回しない）そのもの。
- kickoff の read-time TOCTOU（spawn 後〜子読取までの差し替え）は束縛しない（承認時〜spawn の drift は内容 hash で捕捉）。
- `permission_mode` は CLI 引数からの best-effort 推定（継承 config 非反映）。enforcement は明示 `--elevated` を主ゲートにする。

これらは plan §8 で defer 済みの範囲。SO が「material」と再提起したが、追加実装は v0 スコープ外＝owner のマージ判断に surface する（gate 4 は 2 ラウンドで具象を潰し、残りは disclose）。

全修正後: shellcheck clean・test_oe_delegate 43/0・test_event_bus 71/0・consumer 回帰 0 fail。

## フィードバック（closure・heavy tier・マージ前・達成=v0 core 達成 + 限界 disclose）

### closure gate

- **Context / なぜ**: 冒頭「なぜ始まったか」に自己完結（委譲子 spawn 段の分類器 friction を分類器尊重のまま解消）。
- **次の消費者**:
  - owner（PR #269 のマージ判断＝v0 の受容限界を認めるか / 暗号的承認証明を pull-in するか）。
  - elevated 子を委譲する将来の統括（`delegate-task` の承認ハンドシェイク節を読んで `--elevated` + print-approval を使う）。
  - engine 保守者（durable pre-auth / generation-token を実装する後続フェーズ・#262 keep-open）。
- **follow-up routing**（全て #262 keep-open へ）: 実行段 friction（auto-approve flag 自己付与）/ durable pre-auth（親 bypass mode-flip）/ 暗号的承認証明（nonce・期限・消費状態）/ kickoff read-time TOCTOU の厳密束縛。いずれも plan §8 で defer 済み・v0 スコープ外と宣言。
  - **追わない（宣言）**: `permission_mode` の継承 config 非反映は follow-up にしない。enforcement は明示 `--elevated` を主ゲートにするので本番判定は mode 推定精度に依存せず、推定は audit の補助情報どまり（load-bearing でない）。
- **status 確定**: draft → stable（v0 core 達成。PR #269 レビュー中・マージは owner HG）。
- **evidence anchor**: 設計SO（`oe-refute` audit_id `20260717055324WKAECVQX64RG`）・実装SO R1（`202607170947064J99GK77YTMR`）/ R2（`20260717100600AKC452WSC83N`）。verdict/主要指摘は本 episode 本文へ転記済み（output_dir は tmp/ で揮発するためパス依存にしない）。

### 出力型

- **事実・失敗**（**R1/R2 詳細節〔上〕が全件の正本**。本要約は圧縮）: 初版で `jq --args` が claude option を誤解して digest 計算失敗 → smoke で自己検出し `--argjson` 逐次 append へ。実装SO は R1/R2 とも refuted。潰した具象は binding 迂回系（相対 ws / 空 digest / elevated 未束縛 / 表示注入 / 承認なし到達）に加え、**D5 audit の elevated/通常 auto 非区別・kickoff 内容の digest 未束縛・公式手順の `--elevated` 欠落**（要約に圧縮しきれない別カテゴリ。詳細節に全件）。
- **決定と根拠**: engine-vs-skill は skill-only（設計SO で refuted）を棄却し engine 薄層 binding を採用。核心の layering＝**authZ はハーネス分類器・digest は drift-guard**（別レイヤー）。elevated は明示 `--elevated`（engine が本番アクセスを検知不能なため）+ bypass 自動検知で enforce。
- **わかったこと**: 発火層 = auto-mode classifier が親の Bash tool-call を評価（spike 結論）。trigger は auto そのものでなく **bypass / 本番アクセス**。
- **原則（pattern / anti-pattern）**:
  - Pattern: owner 向けセキュリティ表示は制御文字を拒否/サニタイズし、**セキュリティ関連属性（elevated 含む）を全て整合性 digest に束縛**する（一部でも外すと後付け改ざんの穴）。
  - Anti-pattern: enforcement 無しの opt-in binding は theater（elevated が承認を経ず到達可能）。「必須」と謳うゲートは機構で強制する。
- **行動変更**: 委譲統括は elevated（bypass / 本番アクセス）子を spawn する前に承認ハンドシェイクを通す。トリガ=elevated 子 spawn・機構=`oe-delegate --print-approval` / `--approved-digest`・着地=`delegate-task` skill 節 + `doc-flow-guardrail` routing 行 S。
- **蒸留シグナル**: **ADR 昇格済み**（§13・マージ前）→ `projects/orchestration-engine/docs/decisions/2026-07-17-decision-spawn-permission-handshake.md`。durable な決定 (a) 発火層の結論 (b) authZ↔binding layering (c) engine 薄層採用と却下案 (d) 汎用原則 (e) v0 受容限界と defer を収録。本 episode は実装・SO 反証履歴の**実行詳細 pointer**（ADR は決定に絞り §13.2 で重複回避）。
- **残課題**: 上記 follow-up routing（全て #262 keep-open）。

### Step 4（外部チェック・実施済み）

`so-compare`（codex + claude・出力 `tmp/so-20260717-192148/`）で closure 品質の focused check を実施。claude は 4 観点すべて合格判定。codex が 2 点指摘し、いずれも反映済み:

- 「事実・失敗」要約が D5 / kickoff 内容束縛 / 手順 `--elevated` 欠落を圧縮していた → 要約に別カテゴリとして明記 + 「R1/R2 詳細節が全件の正本」と宣言。
- `permission_mode` 継承 config 非反映が follow-up に無かった → 「追わない」を理由付きで明示（enforcement は `--elevated` 主ゲートで mode 推定非依存）。

両者の一致点: 揮発パス放置なし（audit_id で anchor）・back-propagation は 3軸 doc へ反映済み・ADR 昇格候補は握りつぶさず §13 へ回付。省略は隠蔽性のものではないと判定。
