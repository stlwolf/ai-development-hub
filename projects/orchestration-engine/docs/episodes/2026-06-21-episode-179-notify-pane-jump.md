---
id: 01KVJYQAK8B1RN17TCYT78QKBP
title: "#179 通知からペインジャンプ（oe-jump）実装エピソード"
date: 2026-06-21
type: episode
status: stable
related:
  - type: implements
    ref: "#179"
  - type: discussion
    ref: ../discussions/2026-06-21-discussion-179-notify-pane-jump.md
  - type: depends_on
    ref: "#188"
---

# #179 通知からペインジャンプ（oe-jump）実装エピソード

> `reconstructed`（子セッション執筆・closure 一括執筆と推定／追記タイミングは親で未検証・real-time とは断定しない）。親 `%32` からの委譲子セッションが WORKTREE
> `feature/#179_notify_pane_jump` で自律実行。

## コンテキスト / 動機

`wez notify` の通知から、入力待ちの子ペインへワンアクションで focus する導線が無かった。
プリミティブ（`wez notify` / ラベル解決 `oe_reg_resolve` / `wez pane activate`）は揃うが束ねられていない。
人間介入を速くするのが狙い（#179）。

## 鍵となった一次情報（#188 の identity 分裂）

2 基盤は別 identity 空間（verified）:
- engine `oe`: **wez 整数** pane_id（`wez pane activate <int>`）
- delegate（対話子）: **tmux `%N`**（tmux `select-pane` 系）

`oe_reg_resolve` は `tmux list-panes` 起点でラベルを **tmux `%N`** に解決する（wez 整数は返さない）。
→ tmux 子に `wez pane activate` を投げると別ペイン誤ターゲット。素朴な「全部 wez activate」は誤り。

### 早期収束の実例（reframe で訂正）

調査委譲した Explore 子が「focus は全部 `wez pane activate`、tmux ロジック不要」と結論したが、
これは #188 の substrate 分裂を見落とした誤収束だった。一次情報（#188・delegate-registry.sh・oe-send）で
反証し substrate 分岐へ再構成（`exhaustion-before-conclusion` / `reframe-on-stall` の作動例）。

## 設計（正本は discussion doc）

- DJ-A: 新規 `oe-jump`（orchestration-engine）。wez 側追加はレイヤ違反、oe-send 拡張は verb semantics を濁す。
- DJ-B: oe-jump は **tmux substrate 専用**（`%N`=tmux 素通し / `#N`・名前=label→tmux %N）。`oe_reg_resolve` が常に tmux %N を返すので focus も tmux 経路に固定＝wez activate 誤投を構造排除。裸整数 / `wez:N` は wez ペイン指しとみなし拒否+案内（wez focus は既存 `wez pane activate`）。当初は oe-jump 内に wez を内包したが実装SO の衝突指摘で除去（DJ-E2）。
- DJ-C: tmux focus idiom = `switch-client`(session_id) → `select-window`(window_id) → `select-pane`(pane_id)。ID 系のみ使用。
- DJ-D: scope item 1（ペイロードに target を載せる）を **record/replay** で実装。`oe-jump --record <target>` が記録、
  無引数 `oe-jump` が replay ＝真の 1 アクション。`wez notify` は不改変。
- scope item 3: WezTerm トーストはクリックで url を開くのみ（verified・公式 doc + ローカル handler url=nil）→
  コマンド経由 focus が採用（issue の「コマンド経由フォールバック」）。

## 検証

### tmux focus idiom（隔離 tmux サーバで実証・verified）

`tmux -L` の隔離サーバで cross-window を実証: 非アクティブ window @1 のペイン %1 を対象に idiom を実行 →
session の active window が @0→@1、window @1 の active pane が %2→%1 へ遷移。`switch-client` は
クライアント未接続時 `no current client`(rc1) だが `|| true` で非致命（本番は接続あり）。

### e2e（実 oe-jump バイナリ × 実 tmux・隔離サーバ・verified）

PATH wrapper で実 tmux を隔離サーバ（`tmux -L`）へ向け、`oe-jump` 本体を駆動して受け入れを実証:
- `oe-jump %1`（明示）: window @1 の active pane が %2→**%1**（`focused tmux pane %1` / rc=0）。
- `oe-jump --record %1` → 無引数 `oe-jump`（**1 アクション replay**）: active pane が %2→**%1**（`focused tmux pane %1 (replay of '%1')` / rc=0）。
- 注: 初回 e2e 試行は test wrapper の PATH 自己再帰バグ（`tmux` 名ラッパが `env tmux` で自分を再解決）で `Argument list too long` となり空出力だった。oe-jump は空 target を正しく exit 2 で弾いており（不具合ではない）、ラッパを実 tmux 絶対パス呼びに修正して上記を取得。

### ユニットテスト（`tests/test_oe_jump.sh`・38 アサーション PASS）

実 tmux/wez/jq を PATH 先頭 mock し、substrate 判別・解決・focus 経路・record/replay・各 exit code を検証。
test_oe_select.sh と同型（mock + ck アサーション）。`shellcheck` は bin/test とも PASS。

### 設計SO（oe-refute・exploration・2→3 ラウンド）

- R1 refuted: tmux idiom 未検証 / 裸整数衝突 / emitter 未接続 / oe-send 拡張未探索 / claim 過大。
- R2 refuted: emitter 未接続・1 アクション未達 / 表示ラベルと解決契約のズレ / parent スコープ衝突。
- 反映: idiom 実証 / 裸整数拒否+案内 / **record/replay を本 PR に取り込み**（当初 follow-up 送りを撤回）/
  record token = 解決 token で契約ズレ解消 / parent スコープを既知制約として明文化 / claim 縮小。
- R3: （結果は本エピソード closure で確定）。両ラウンドとも substrate 分岐の方向性は #188 と整合と是認。

## scope ↔ acceptance マッピング

- scope1（ペイロードに target を載せる規約）→ `--record`/replay（DJ-D）。
- scope2（notify→resolve→activate 束ね）→ oe-jump 本体（substrate 分岐）。
- scope3（クリック起動可否検証）→ 不可（verified）→ コマンド経由。
- acceptance「1 アクションで focus」→ 無引数 `oe-jump`（replay）/ ラベル未解決挙動 → exit 1 + oe-list 案内 / shellcheck PASS。

## 実装SO（oe-review・diff-bound・impl レンズ）

- R1（reviewed_sha 9ad6df0）: **refuted 1/2**。codex=survived（substrate 分岐/focus 経路/record-replay/exit code に material 欠陥なし）。cursor=refuted（material）:
  「`--record` がラベル target で `oe_reg_resolve` を実行し『解決は jump 時』契約と矛盾。tmux 一時不可時に token 記録すら失敗して replay 不能（%N/wez:N と非対称）」。
- 修正: `_oe_jump_validate_shape`（解決しない・形のみ検証）を切り出し、`--record` はこれだけを使う。
  解決（`oe_reg_resolve`）は jump/replay 時の `_oe_jump_classify` でのみ実行。これで `--record #N` が
  tmux/生存ペイン非依存になり `%N`/`wez:N` と対称化（契約通り）。回帰テスト [16] を追加（解決不能でも record 成功）。
- R2（reviewed_sha 0d70874）: **refuted 2/2**。codex=「追加テストの `mktemp -d` 無ガードで空パス継続→root 直下へ書込みの到達可能欠陥」。cursor=「`wez:N` が registry ラベル `wez:N` と衝突し裸整数同型の拒否がなく silent 誤 focus し得る」。
- 修正: (a) `mktemp` 失敗ガード追加 (b) **oe-jump を tmux 専用化**し wez substrate を除去（`--wez`/`wez:N` を撤廃・裸整数/wez:N は wez 案内で拒否）。wez focus は既存 `wez pane activate` に委譲＝衝突クラスを構造的に消去（Minimal Scope）。issue 原文の shape 変更のため %32 へ報告。
- R3（reviewed_sha 6095966）: **refuted 1/2**。cursor=survived。codex=「明示空文字 target が省略扱いになり replay の stale pane へ誤 focus し得る／空文字後の余剰引数を黙って捨てる parser 欠陥」。
- 修正: 位置引数の有無を `$#`（HAVE_ARG）で判定するよう変更（`-z "$TARGET"` での replay 判定を撤廃）。明示空文字は replay せず resolve→validate で usage エラー。回帰テスト [14] 追加。
- R4（reviewed_sha 4cb406f・audit 20260620173759VEP9MAPT6RXV）: **survived 2/2**（codex/cursor とも material 欠陥なし・残存は設計上の既知制約のみ）。
- アサーション数 **38 PASS** / shellcheck PASS。
- SO 証跡: 各 `tmp/oe-review-<ULID>/`・`tmp/oe-refute-<ULID>/`（揮発・gitignore）。要点（verdict / reviewed_sha / audit_id / 指摘）は本エピソード本文に転記済（evidence anchor）。

## closure（episode-retrospective・heavy tier）

- **tier: heavy**（実行中の方針転回=wez 除去 / 意図起動の外部レーン oe-refute 3R + oe-review 4R / 非自明な設計判断と棄却案あり）。
- **Context / なぜ**: 冒頭「コンテキスト / 動機」に自己完結（通知から入力待ちペインへ飛ぶ導線が無い）。
- **次の消費者**:
  - `%32`（親）— PR レビュー / マージ判断。特に wez 除去（issue 原文「wez pane activate の束ね」からの shape 変更）の是非。
  - 将来 #P2 / agent-deck — 状態検出による自動通知発火が `oe-jump --record` 規約を消費する（emitter 配線側）。
  - oe-jump 利用者 — `oe-jump <#N|%N>` / 無引数 replay で入力待ち子へ focus。
- **follow-up routing**:
  - 状態検出ベースの自動 `--record` + 通知発火 → **#P2 / agent-deck**（本 PR 外・issue「やらないこと」）。
  - tmux クライアントをホストする wez ペイン非フォーカス時の前面化 → **#188 の未解決マッピング問題**（スコープ外・追わない）。
  - wez(engine)ペインへの jump → **既存 `wez pane activate`**（oe-jump 責務外・追加実装なし）。
  - 行き先なしの残課題は無し。
- **status: stable / 達成度: 達成**（acceptance 3 点 — 1 アクション focus / ラベル未解決挙動明記 / shellcheck — を満たす。設計 SO/実装 SO/手動 idiom 実証で裏付け）。
- **棄却した案**（決定と根拠）: wez 側に jump 追加（レイヤ違反）/ oe-send 拡張（verb semantics 濁す）/ oe-jump に wez 内包（`wez:N` の registry ラベル衝突・実装SO 反証）/ notify 4th フィールド + Lua クリック起動（クリックは url のみ・notify 不改変）。詳細は discussion DJ-A/B/E/E2。
- **蒸留シグナル**: 昇格候補 = **なし**（PoC 的な 1 verb 追加。#188 の identity 設計は既存 decision doc にあり、本 episode は新規 Decision を生まない）。
- **Step4（closure 外部チェック）辞退**: 理由 = 本 episode は全 SO ラウンド（design 3R / impl 4R）の verdict・reviewed_sha・指摘を逐次記録した透明な失敗ログで、選択的省略リスクが構造的に低い。覆った観点: 失敗の省略チェック（全 SO 指摘を記載）/ routing 網羅（上記・全件行き先付与）/ evidence anchor（verdict/SHA/audit_id を本文転記）/ back-propagation（design SO が検出した stale-claim を discussion frontmatter で是正済）。未実施観点と判断: なし（4 観点とも低リスクで充足）。

## closure: PR

- PR: [#207](https://github.com/stlwolf/ai-development-hub/pull/207)（self-complete・委譲子のためマージ/掃除はしない）。
- Copilot ラウンド: 1 ラウンド実施。Copilot は COMMENTED レビュー（概要のみ・**generated no comments**=インライン指摘 0）。返信対象スレッド無し＝修正不要で round 完了（再リクエストはしない）。
