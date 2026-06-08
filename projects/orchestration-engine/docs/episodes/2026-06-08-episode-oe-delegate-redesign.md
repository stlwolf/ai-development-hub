---
id: "01KTKE9YF0S16AABWEG23DNXAG"
title: "親子委譲CLI(oe-delegate)の再設計 — 疎結合化とアドレッシングの設計経緯"
date: 2026-06-08
type: episode
status: draft
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/142"
    reason: "本再設計の傘 Issue"
  - type: source_material
    ref: "projects/orchestration-engine/docs/plans/2026-06-08-plan-oe-delegate-redesign.md"
    reason: "本 episode を Plan に展開した実行計画"
  - type: source_material
    ref: "https://github.com/stlwolf/ai-development-hub/issues/138"
    reason: "旧設計（#137 PoC → #138）。現行 oe-delegate/oe-report の出自"
  - type: design_context
    ref: "ideas/20260130/ai-middleware-cli-concept.md"
    reason: "「挙動はスキルでなく単機能コマンドに内包」の原則（auto-Enter のコマンド内包判断の根拠）"
tags: [orchestration, delegate, oe-delegate, oe-send, addressing, cli-redesign, decoupling, episode]
---

# 親子委譲CLI(oe-delegate)の再設計 — 疎結合化とアドレッシングの設計経緯

> question-driven-design で実フローを掘り下げ → so ゲート（Codex/Claude）で計画と実装を反証検証 → 実装（PR #143）→ 初期検証・dogfood、という1サイクルの駆動層記録。**追記予定**（親側所見・dogfood 継続結果は末尾「追記」へ）。

## Context / なぜ再設計したか

`oe-delegate` / `oe-report`（#137 PoC → #138 設計 → #139 実装 / #141）は、tmux `send-keys` でセッション間プロンプトに1行注入する薄いラッパー。「人間目視・ポーリングなし・1行注入・親1⇄子1・report 密結合」という **PoC 由来のプロトコルをそのままスクリプト化**したもので、`delegate-task` スキルから駆動していた。

実運用フローと照合した結果、いくつかの構造的な不適合が判明したため再設計した。

## 確定した実フロー（QDD で抽出）

- トポロジは **統括スレッド（親・作業しない）→ 子 N 個（2-3 並列）のスター型**。孫委譲は無い
- 子は 1 つの issue を merge + 後片付け完了まで担当し、基本そこで親へ戻る
- 子の報告が来るタイミングは作業待ち中が多く、**割り込みは問題ではない**
- 痛点は **親 → 子の送信（キックオフ／事前情報の受け渡し）**。最初はゼロベース調査で始め、プラン確定後に issue からブランチ / worktree を切って移行
  - 重いケース＝4層ドキュメント方式のキックオフ doc 既存 → パス渡しで足りる
  - 軽いケース＝キックオフを作るほどでもない → 親 AI に委譲用まとめプロンプトを生成させ手でコピペ。**コピペ痛点と誤送信の本体はここ**
- 既存ペイン（手で分割済み）へ投げたい用途（関連は薄いが本質的な側道会話）がある
- 子 → 親の戻し（report）は最悪不要

## 設計判断と、その「なぜ」

### 1. 送信のリッチ化 = パスポインタ正規化

全ペイロードを「ファイル + `<path> を読んで進めて。` の1行ポインタ」に正規化。`tmux send-keys -l` の改行途中送信問題は、`oe_send_line` の **改行 fail-fast** で根本封じ（除去でなく拒否し、呼び出し側に1行化を強制）。`lib/spawn.sh:48` の envelope パターン（子にパスを読ませる）を transport に転用。

### 2. 疎結合化 = delegate は report を内包しない（最重要判断）

レビュー中に「delegate が report 処理（oe-report 案内 suffix・`/tmp/oe-parent` 配線）を内包するのは **CLI レベルの密結合で Unix 哲学に反する**」と判断。決め手は **「ワンラリー（kick→report の1往復閉ループ）にするなら、それは Claude 組み込み subagent の劣化版でしかない」**。delegate の価値は *開いた・並列・人間が覗ける対話セッションへのキック* にあり、戻しを焼き付けると価値が消える。

→ delegate は **spawn + kick に純化**。戻しは特定コマンドでなく **汎用 `oe-send "$PARENT_TMUX_PANE"`** で行う（`PARENT_TMUX_PANE` env は「親ペイン」汎用コンテキストとして子へ渡す）。`oe-report` は legacy 化（整理は論点E）。
※ `oe` 重いエンジンのような **フローコマンド**ならオーケストレーション内包は正しい。単機能 primitive の `oe-delegate` とは別。

### 3. auto-Enter はコマンドに内包（フラグ化）

Enter 発火の是非は **スキル（自然言語層）でなくコマンドが持つ**（`ai-middleware-cli-concept.md` の「各コマンドは単機能で composable・挙動は外部化」原則）。`oe_send_line` に `send_enter`（既定=発火）、`oe-send` に `--no-enter`。投入＝送信 と ステージ（人間が読んで Enter）を選べる。

### 4. アドレッシング = 親所有レジストリ + 既存 pane-issue の union

新規発明せず既存資産を流用: `~/.claude/state/pane-issue/`（`wt-pane-issue.sh` が `wt switch` 時に `pane→#issue` を永続化）を読み、親所有 spawn レジストリ（`~/.claude/state/oe-delegate/`）と union 解決。

- **生存ペイン起点の順引き**（filename 逆算しない）→ 孤児/別サーバ stale を踏まない
- `#N` は **トークン境界の完全一致**（`#14`≠`#142`）
- spawn レジストリは **`parent_pane` で現在の親にスコープ**（別親の同名誤着弾を防ぐ）。一方 `#N`（pane-issue）は **issue 大域同定で親スコープ外**
- 同一ペインに両ソースがあれば **pane-issue 優先**（子の issue 乗換ドリフトを吸収）
- GC は **`pane 不在 or 別サーバ pid`**（server 再起動の番号再利用リーク防止）
- ゼロベース調査期（issue 未確定）は spawn レジストリの仮ラベルでカバー、`wt switch` 後は pane-issue が引き継ぐ
- Bash 3.2 互換（連想配列不使用）

### 5. kickoff の可読性

対話型 claude は `--add-dir` 無しで `/tmp` を読めない（権限プロンプトで停止）。`oe-delegate --kickoff` は doc のディレクトリを `--add-dir` で開示。揮発 kickoff は workspace 配下に置く規約。

## 実装（PR #143 / 単一 Issue #142 / 論理単位コミット）

責務分離: `delegate` / `send` / `list` / `registry` が各1責務。**どのコマンドも "report" を特別扱いしない**。

- `bin/oe-delegate` — spawn + kick + registry 登録（`--kickoff`/`--label`、report 非内包、改行 task は spawn 前 preflight）
- `bin/oe-send` — 既存ペインへの汎用送信（`%N`/ラベル、`--kickoff`、`--no-enter`）
- `bin/oe-list` — 宛先候補を source 列付きで一覧
- `lib/delegate-send.sh` — 改行拒否の1行 safe-send（`oe_send_line`、tmux 存在チェック）
- `lib/delegate-registry.sh` — union 解決（record/resolve/list/gc）
- `bin/oe-report` — legacy（戻しは oe-send に一本化）
- `canonical/skills/delegate-task/SKILL.md` — 新体系に追従
- `tests/test_delegate_registry.sh` — resolve/list/gc の単体テスト（tmux モック・13 ケース）

## 検証ゲート（so + Copilot）

- **so v1（計画）**: Codex + Claude。穴 12 件 → 全反映（順引き化・#N 完全一致・互換・kickoff 可読化・parent scope・pid-aware GC 等）
- **so v2（疎結合化した実装）**: Codex + Claude とも「疎結合化は妥当・回帰なし」。指摘 → 全修正（oe-report help 整合・改行 task の spawn 前 preflight・skill の #N 非スコープ限定・`--kickoff` 可読ルート注記 等）
  - so 運用の学び: `--prev` は前回回答をバイト切りして日本語マルチバイトを分断 → 不正 UTF-8 で Codex が即死。worktree パスの `#` も両レーンに悪影響。`--prev` 除去 + `#`-free detached worktree + `SO_TIMEOUT=600` で解消
- **Copilot レビュー（PR #143）**: 3 件 → #1 `--` 混入懸念は実機検証で反証し見送り（`--` は消費され必須）、#2 tmux 存在チェック追加・#3 registry テスト追加で対応

## 初期検証スコープ（コード + 実 dogfood）

- 全シェル `shellcheck` clean／`oe_send_line` ガード・実送信・`--no-enter` ステージ／`oe-send` 着弾・ラベル解決／registry 13 ケース／oe-delegate 改行 preflight・疎結合キック／子の `PARENT_TMUX_PANE` env 継承
- **実 dogfood（別スレッド・read-only 裏取り）**: 親 `%88` が 別リポ の `#N` を子 `%162` に委譲。registry に `{pane:%162,label:#N,parent_pane:%88,workspace:.../別リポ}` を正しく記録。親 `%88` 視点で `resolve "#N" → %162`、`oe-list` に `%162 spawn-registry #N`。非親（`%144`）からは `#N` 未解決＝**親スコープの誤送信防止が実機で機能**。子は pane-issue 無し（未 wt switch）＝ゼロベース期を仮ラベルでカバー、の設計どおり

## 残論点 / follow-up

- **論点E**: `oe-report` のコード整理（薄い alias 化 / 廃止）。戻しは `oe-send "$PARENT_TMUX_PANE"` に一本化済み。alias 化すると `申し送り:`/`レビュー依頼:` プレフィックスの扱いが論点
- **pane-id 2系統の統一（→ #114）**: `oe-capture`（wez 整数前提）が tmux 子（`%N`）を取得できない。クリーン出力チャネルの tmux 統一が未達。dogfood で顕在化（詳細は末尾「追記」）
- **[重要] send-keys → Claude TUI ingestion の不安定さ**（dogfood で顕在化・詳細は末尾「追記」）。2症状: ①mid-session(auto-mode/plan-wait)で stage しない ②idle でも Enter が吸収され未 submit（間欠）。候補対策＝oe_send_line でリテラル送信と Enter の間に小休止（`OE_SEND_ENTER_DELAY`）。受け手 TUI 依存ゆえ根治には bracketed-paste/入力モード調査が要る
- 本リポを workspace に使う際の `.oe/` 一時 kickoff dir の gitignore（必要時）
- 実地未検証: 親からの `oe-send "#N"` 追送（解決は検証済み）／子からの戻し `oe-send "$PARENT_TMUX_PANE"`／`--kickoff` の既存ペインへの送信

---

## 追記（dogfood 継続・親側所見）

### 2026-06-08 kick パス end-to-end PASS（親側 dogfood）

子スレッド（別リポ `%162`）の試用報告。**kick パスは end-to-end で PASS**（deferred だった実 claude 完全 E2E に相当）:

| 項目 | 結果 |
|------|------|
| 子ペイン spawn（cwd=workspace） | ✅ `%162` 起動・parent `%88` 記録 |
| registry ラベル | ✅ `oe-list` で `%162 = #N`（source spawn-registry） |
| kickoff doc 読込 + task 注入 + Enter | ✅ 子が doc を読み `#N`/Epic `#18`/`関連 issue` を正しく参照したプラン生成（**`--add-dir` 可読化が実機で機能**・kickoff 整合性 OK） |
| 子の状態 | ✅ プラン提示 → オーナー承認待ち（❯ auto mode・Crunched 4m15s） |

`oe-delegate` の stdout（child started / task injected）、`oe-list` のラベル表示も実用的との所見。addressing 記録・解決・親スコープ誤送信防止は read-only でも裏取り済み（上記「初期検証スコープ」）。

### 発見: pane-id 規約の2系統混在（→ #114 / #142 申し送り）

- `oe-capture`（重いエンジン側のペイン取得）は **WezTerm 前提**（usage: WezTerm ペイン ID＝非負整数 + `@@OE_EXIT` マーカー）。一方 redesign の `oe-delegate`/`oe-send`/`oe-list` は **tmux ベース**（`%N` 形式）
- → tmux 子ペインを `oe-capture` でクリーン取得できない（`%162` は形式エラー、`162` は別物の wez pane 扱い）。tmux 子の確認は `tmux capture-pane` が実経路
- **クリーン出力チャネルの tmux 統一（#114）が未達**という発見。pane-id 規約が tmux `%N` / wez 整数の2系統で利用者が混乱しうる

### 観察: 疎結合の「opt-in 戻し」が新旧モデルのギャップを露呈

子側は「完了/レビュー時に親ペインへ **自動着信するはず**」と認識していた（＝旧 suffix ベースの auto-report モデル）。疎結合化後は **戻しは opt-in**（`oe-send "$PARENT_TMUX_PANE"` を明示）。この期待ギャップ自体が、opt-in 戻しのオンボーディング/ドキュメントを要することを示す（論点E の入力）。バグではなく設計どおり。

### 2026-06-08 横+縦+戻し チェーン検証（%144→%88→%162）+ `--no-enter` の状態依存

「横移動（関連薄い既存ペインへの送信）」と「縦移動（親→子）」を1チェーンで検証。指示に provenance（"検証ペイン %144 から・人間の直接指示でない"）を inline で front-load。

| leg | 経路 | 結果 |
|-----|------|------|
| 横 | %144(検証) → %88(統括) 生 `%N` | ✅ 着弾。親が provenance を認識して実行（即実行でなく思考＝フレーム有効） |
| 縦 | %88 → %162 ラベル `#N` `oe-send --no-enter` | △ resolve+send EXIT=0 だが %162 入力欄に着弾せず（stage-test 不在を確認） |
| 戻し | %88 → %144 生 `%N` | ✅ 報告がこの会話に1ターンとして着信 |

**`--no-enter` の状態依存（切り分け済み）**:
- **fresh/settled** な claude では `--no-enter` は正しく機能（`❯ STAGE_MARKER` が視認・手動 Enter で submit を確認）
- だが %162（**auto mode + プラン承認待ち = mid-session**）には**ステージ着弾しなかった**（入力欄空・stage-test 不在を read-only 確認）
- → `--no-enter` のリテラル投入バグではなく **受け手の入力状態に依存**。mid-session の claude は注入された未送信キーが残らない疑い [speculation: 差分要因が「Enter 有無」か「fresh vs mid-session」か未分離]

**含意**: コア経路（fresh 子への kick・fresh/settled ペインへの送信・戻し）は全て動く。ギャップは「**稼働中(mid-session)の claude に未送信でステージする**」という狭い use case。provenance を inline で front-load する設計（人間直接でないと認識させる）は有効だった＝エージェント間メッセージの出所明示の価値を実証。

### 2026-06-08 [重要] send-keys → Claude TUI ingestion の不安定さ（2症状）

再送（%144→%88）で**新症状を確認**: oe-send（Enter 付き）が **submit されずメッセージが %88 の入力欄にステージされたまま**（処理インジケータ無し）。手動で `tmux send-keys -t %88 Enter` を撃つと submit された＝**最初の Enter が吸収されていた**。前回 %88 は submit 成功 → **間欠的**。

- これは %88 のトークナイザ/tool-call 整形崩れ（モデル側）とは**別レイヤー＝送信機構の問題**
- 根本仮説 [speculation]: Claude TUI の paste 検知で、`send-keys -l` のリテラル burst 直後の `send-keys Enter` が「paste 内の改行」として吸収され submit にならない（wez 版が `--no-paste` を使う動機と同型）

**共通の根**: `tmux send-keys` → Claude Code TUI への入力 ingestion が **状態/タイミング依存で不安定**。2症状:
1. **mid-session で stage しない**（%162・auto-mode/plan-wait）— テキストすら入力欄に残らない
2. **Enter 吸収で未 submit**（%88・idle）— テキストは入るが Enter が効かずステージのまま

ツール（oe-send/oe_send_line）は tmux レベルでは正しい（send-keys 実行・EXIT=0）が、受け手 TUI の取り込みが弱点。#137 PoC は「届く」を確認したが、dogfood で**エッジの不安定さ**が顕在化。

**候補対策**: oe_send_line で リテラル送信と Enter の間に小休止（`sleep` / `OE_SEND_ENTER_DELAY`）を入れ paste 検知窓を閉じてから Enter。mid-session stage 不達は別途要調査（bracketed-paste / 入力モード）。

### 未検証 / 次サイクル候補
- 上記 Enter-race の delay 緩和が間欠失敗を消すか（間欠ゆえ計測が難しい）
- 追送 `oe-send "#N" "<指示>"` の **Enter 付き** inject（mid-session %162 に Enter 付きなら届くか＝差分要因の分離）
- `--no-enter` の mid-session 挙動の再現（plan-wait 状態の throwaway claude で確証）
- 並行2子 kick（registry 多重）／issue 番号のみ kick（`--kickoff` 無し）／不正 workspace エラー処理
