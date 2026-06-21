---
id: 01KVJYQAJFMRDB23RMMBE26MWS
title: "#179 通知からペインジャンプ — oe-jump 設計判断と探索証跡"
date: 2026-06-21
type: discussion
status: draft
claim: "通知→ペインジャンプは新規 oe-jump（focus 専用 verb・tmux substrate 専用）が担い、%N 素通し / #N・名前は oe_reg_resolve で tmux %N に解決して tmux 経路（select-pane 系）で focus、scope item 1 は record/replay（--record 形検証のみ + 無引数 replay）で実装するのが、#188 の identity 分裂下かつ kickoff 制約（notify 不改変・自動発火は #P2 スコープ外・tmux 子への wez activate 誤投を回避）の下で issue #179 のスコープに対し妥当な設計である。wez(engine)ペインの focus は既存 wez pane activate に委ね oe-jump の責務外とする。"
status_note: "設計SO(exploration) 3R + 実装SO(oe-review) 2R を実施。設計の方向性（substrate 分裂対応）は是認。実装SO で (1) --record の eager 解決 (2) test の mktemp 無ガード (3) wez:N と registry ラベルの衝突 を検出 → 形検証分離 / mktemp ガード / wez を oe-jump から除去（tmux 専用化）で反映。"
rubric: exploration
domain: orchestration-engine
related:
  - type: implements
    ref: "#179"
  - type: depends_on
    ref: "#188"
    reason: "2 基盤の identity 分裂（tmux %N ↔ wez 整数 pane_id）が activate 経路分岐の前提"
---

# #179 通知からペインジャンプ — 設計判断と探索証跡

## 問題

`wez notify` の通知から、入力待ちの対象ペインへワンアクションでフォーカス（activate）する導線が無い。プリミティブ（`wez notify` / ラベル解決 `oe_reg_resolve` / `wez pane activate`）は揃っているが束ねられていない。

## 一次情報で確定した制約（#188・verified）

2 つのオーケストレーション基盤は**別 identity 空間**を持つ:

| 基盤 | identity | フォーカス手段 | 出典 |
|---|---|---|---|
| engine `oe`（自律パイプライン） | **wez 整数** pane_id | `wez pane activate <int>`（`wezterm cli activate-pane`） | `lib/spawn.sh`（`wez pane split`）, `#188` [verified] |
| delegate（対話 Claude 子） | **tmux `%N`** | tmux 側（`select-pane`/`select-window`/`switch-client`） | `lib/delegate-registry.sh`（`tmux list-panes -F '#{pane_id}'`）, `oe-send`（`tmux send-keys -t %N`）, `#188` [verified] |

- `oe_reg_resolve` は `tmux list-panes` 起点でラベル（`#N`/名前）を解決し **tmux `%N` のみ**を返す。wez 整数 pane_id は返さない。[verified — `lib/delegate-registry.sh:71-121`]
- 罠: tmux 子（`%N`）に `wez pane activate` を投げると、`%N` の整数部 N を wez pane_id と誤解釈し**別ペインへフォーカス or 失敗**する（#188 の核心）。素朴な「全部 wez pane activate」は誤り。

## 設計判断（DJ）

### DJ-A: ジャンプの実装位置 = 新規 `oe-jump`（orchestration-engine）

- 採用理由: ラベル解決 `oe_reg_resolve` は orchestration-engine にあり、engine は既に `wez`（`spawn.sh` の `wez pane split`）に依存する＝両 substrate を知る層はここだけ。`oe-send`（resolve→tmux 操作）と同型で、oe-* one-verb-per-bin パターンに整合。
- 却下 1: `wez` CLI に `jump`/`focus` を追加 → wez が orchestration-engine（`oe_reg_resolve`）へ逆依存し**レイヤ違反**（wez は下層）。wez は wez ペインしか知らず tmux `%N` を扱えない。
- 却下 2: lib 関数のみ（入口 bin なし）→ acceptance の「1 アクション入口」を満たさない。

### DJ-B: activate 経路 = oe-jump は tmux substrate 専用

| target トークン | 解決/経路 |
|---|---|
| `%N` | 素通し → tmux focus 系（`oe_reg_resolve` が `%N` をそのまま返す） |
| `#N` / 任意名 | `oe_reg_resolve` → tmux `%N` → tmux focus 系 |
| 裸の整数 `N` / `wez:N` | **拒否**（exit 2）。`%N`(tmux) か `wez pane activate N`(wez) を案内 |

- `oe_reg_resolve` は `tmux list-panes` 起点で**常に tmux `%N`** を返す（wez 整数は返さない）。よって oe-jump の解決結果は常に tmux であり、focus も tmux 経路（`select-pane` 系）に固定する＝tmux 子へ `wez pane activate` を投げる誤ターゲットを**構造的に排除**（#188・kickoff の核心懸念を満たす）。
- **wez(engine)ペインは oe-jump の責務外**。focus には既存の `wez pane activate <id>` を使う。kickoff の「activate 経路を分けるか、対象を明示する」は「oe-jump=tmux / wez=wez pane activate」という**ツール境界の明示**で満たす。
- 裸整数 / `wez:N` は wez ペイン指しとみなして**拒否+案内**（silent な誤 focus を出さない）。当初は oe-jump 内で wez も扱う設計（`--wez` → `wez:N`）だったが、実装SO（cursor）が「`wez:N` が registry ラベル `wez:N` と衝突し silent 誤 focus し得る」と反証。wez 焦点は既存ツールがあり #179 の主用途（入力待ち=tmux 子）にも不要なため、**Minimal Scope に基づき oe-jump から wez を除去**＝衝突クラスを構造的に消去（DJ-E）。

### DJ-C: tmux フォーカス系の idiom（リポジトリに既存パターン無し＝新規）

対象 tmux ペイン `%N` を現在のクライアントへ可視化＋フォーカスする手順:

```
read sid wid <<<"$(tmux display-message -p -t "$pane" '#{session_id} #{window_id}')"
tmux switch-client -t "$sid"      # クライアントを対象セッションへ
tmux select-window -t "$wid"      # そのセッションの active window を対象 window へ
tmux select-pane   -t "$pane"     # window 内で対象ペインをフォーカス
```

- session_id（`$N`）/ window_id（`@N`）/ pane_id（`%N`）の**ID 系**のみ使用＝セッション名に `#`/空白が混じる本環境（session-name hook）でも target 解釈が壊れない。
- 同一 window/session のときは各コマンドが no-op になり安全。別 window/session でも 3 段で確実に landing。
- **実証（隔離 tmux サーバ `tmux -L` で検証・verified）**: 非アクティブ window @1 のペイン %1 を対象に idiom を実行 → セッションの active window が @0→@1 へ遷移し、window @1 の active pane が %1 へ遷移することを確認。`switch-client` はクライアント未接続時 `no current client`(rc1) を返すが `|| true` で非致命（本番は接続クライアントあり）。`display-message -t %N '#{session_id} #{window_id}'` が `$N @N` を返すことも確認。
- 既知限界: tmux クライアントをホストする wez ペイン自体が非フォーカスのケース（tmux が別 wez ペイン/ウィンドウにある）は tmux 層だけでは前面化しない。wez↔tmux マッピングは #188 の未解決問題のため**スコープ外**（人間+子が同一 tmux クライアントを見る主用途では不要）。

### DJ-D: 通知ペイロード規約（scope item 1）= record/replay で target を「載せる」

scope item 1「通知ペイロードにペイン特定情報を**載せる**規約」を、表示文字列ではなく **record/replay** で実装する（設計SO の「target が実際に流れない / 1 アクション未達 / 表示ラベルと解決契約のズレ」反証への反映・DJ-E）:

- 通知を撃つ側が `oe-jump --record <target>` で対象トークンを state file（`~/.claude/state/oe-jump/last-target`・最後の1件・上書き）に記録する。
- 人間は `oe-jump`（**無引数**）で直近記録の target へ飛ぶ＝**真の 1 アクション**（ラベルを読んで打ち直さない）。
- **契約ズレの解消**: 記録した token をそのまま `oe_reg_resolve` に渡して解決するので、「トーストの表示文字列」と「解決される token」が分離・一致する（表示は自由文でよい）。
- **境界の尊重**: `wez notify` のペイロード/Lua ハンドラは**不改変**（record は別 state・notify に相乗りしない）。通知発火そのもの（誰が・いつ撃つか）は #179 **スコープ外**（状態検出による自動発火 = #P2/agent-deck）。本 PR は「載せる規約＋飛ぶ導線」を提供し、撃つ主体は将来（or 手動/agent）。
- **parent スコープの既知制約**: replay は jump 時に再解決する。pane-issue ラベル（`#N`・`wt switch` 子）はどのペインからも解決可。spawn-registry の任意名ラベル（`oe-delegate` 子）は **spawn した親ペインからのみ**解決可（`oe_reg_resolve` の parent スコープ）。主用途（人間が spawn 親で受信→飛ぶ）では成立。`%N` 直接トークンはスコープ非依存。

### DJ-E: 設計SO（oe-refute・exploration）2 ラウンドの反証への反映

設計SO（codex/cursor 2 レーン）を 2 ラウンド実施。**両ラウンド・両レーンとも substrate 分岐の方向性は #188 と整合**と認めた上で material gap を指摘。反映:

| ラウンド | 反証 gap | 反映 |
|---|---|---|
| 1 | tmux focus idiom 未検証 | 隔離 tmux サーバで cross-window 実証（DJ-C・verified） |
| 1 | 裸整数の cross-tool 衝突 | 裸整数→wez 自動を撤回し **拒否+案内**（DJ-B） |
| 1 | より小さい代替（oe-send 拡張等）未探索 | 「検討した代替」に記録。oe-send は "1 行送信" verb で focus と別 semantics → 拡張は contract を濁す。解決ロジックは `oe_reg_resolve` で共有済 → 新 verb 採用 |
| 1+2 | notify emitter 未接続 / target が流れない / 受け入れ「1 アクション」未達 | **record/replay を本 PR スコープに取り込み**（DJ-D）。当初の「doc 規約のみ + follow-up」では scope item 1 の "載せる" を満たさないと再反証されたため、`--record` + 無引数 replay を実装 |
| 2 | 表示ラベルと `oe_reg_resolve` 解決契約のズレ | record した token をそのまま解決＝表示文字列と分離・一致（DJ-D） |
| 2 | parent スコープと主用途の衝突 | DJ-D に既知制約として明文化（pane-issue は scope 非依存・spawn 名は spawn 親から） |
| 1 | claim 過大 | claim を「issue #179 スコープに対し妥当」へ縮小（断定 "最小かつ正しい" を撤回） |

残差: exploration rubric は doc-only/手動アクション設計に対し原理上「更に探索余地あり」を返しやすい。material な新 gap（上記）は全て反映済。

### DJ-E2: 実装SO（oe-review・impl レンズ・diff-bound）2 ラウンド

| ラウンド | 反証 gap | 反映 |
|---|---|---|
| R1（codex=survived / cursor=refuted） | `--record` がラベルを `oe_reg_resolve` で eager 解決し「解決は jump 時」契約と矛盾。tmux 一時不可で記録すら失敗（%N/wez:N と非対称） | `_oe_jump_validate_shape`（解決しない・形のみ）を切り出し `--record` はこれだけ使用。解決は jump 時の `_oe_jump_resolve` のみ。回帰テスト [12] 追加 |
| R2（codex=refuted / cursor=refuted） | (a) test の `mktemp -d` 無ガード→空パスで root 直下へ書込みの到達可能欠陥（codex） (b) `wez:N` が registry ラベル `wez:N` と衝突し silent 誤 focus し得る（cursor） | (a) `mktemp` 失敗ガード追加 (b) **oe-jump を tmux 専用化**し wez を除去（衝突クラスを構造的に消去）。wez focus は既存 `wez pane activate` に委譲 |

R2 の wez 除去は Minimal Scope の判断（wez focus は既存ツールがあり #179 主用途に不要・予約プレフィックス等の規約で papering するより構造的に消す方が堅牢）。issue 原文の「wez pane activate の束ね」からの shape 変更にあたるため %32 へ明示報告する。

### 検討した代替（exploration 痕跡）

- **oe-send 拡張**（`--focus` 等）: 却下。oe-send の contract は「既存ペインへ 1 行を安全送信」。focus（テキスト無し・別作用）を相乗りさせると verb semantics が濁る。共有は解決ロジックのみで、それは既に `oe_reg_resolve` として lib 化済 → 新 verb でも実装重複は無い。oe-* の one-verb-per-bin に整合。
- **wez 側に jump 追加**: 却下（DJ-A・レイヤ違反）。
- **oe-jump に wez substrate を内包**（`--wez` / `wez:N`）: 一旦採用→**却下**（DJ-E2 R2）。裸整数の曖昧・`wez:N` の registry ラベル衝突を生み、wez focus は既存 `wez pane activate` で足り #179 主用途に不要。予約プレフィックス規約で papering するより tmux 専用化で衝突クラスを構造的に消す方が堅牢（Minimal Scope）。
- **notify 4th フィールド + Lua クリック起動**: 却下（クリックは url を開くのみ・scope item 3 検証／notify 作り替え禁止）。

## scope item 3 の検証結果（クリック起動可否）

- WezTerm の `window:toast_notification(title, message, url, timeout_ms)` は**クリックで url を開くだけ**。任意コマンド/コールバックの実行は非対応。[verified — 公式ドキュメント https://wezterm.org/config/lua/window/toast_notification.html ＋ ローカル handler `ai-mode-events.lua:30` が第3引数 url=nil]
- 帰結: トーストのクリック/キーから tmux/wez のフォーカスコマンドを直接起動するのは**不可**（OS レベルの独自 URL スキームハンドラ登録が要り、プラットフォーム依存・スコープ外）。
- → 採用する「1 アクション」は**コマンド経由 `oe-jump <target>`**（issue が言う「不可ならコマンド経由のフォールバック」そのもの）。

## ラベル未解決時の挙動（acceptance）

`oe_reg_resolve` の契約を踏襲: 0 件 → exit 1 + `oe-list` 案内、複数件（曖昧）→ exit 1 + 候補列挙 + `%N` 指定案内。tmux 不在/接続不可 → exit 2（環境エラー）。

## 探索証跡（predecision-exploration / exhaustion）

- ゼロベース代替の列挙と却下: wez-only（tmux 子で誤ターゲット・却下）/ tmux-only（engine wez ペインを扱えない・却下）/ wez↔tmux 統一マッピング（#188 未解決・スコープ外）/ oe-send 拡張（verb semantics 濁す・却下 DJ-E）/ wez 内包（実装SO 衝突→却下 DJ-E2）/ **oe-jump=tmux 専用 + wez は既存 wez pane activate（採用）**＋ record/replay（scope item 1 を満たすため取り込み）。
- 早期収束の実例: 本タスクの調査子エージェントが「フォーカスは全部 `wez pane activate`、tmux ロジック不要」と結論したが、これは #188 の substrate 分裂を見落とした誤収束。一次情報（#188 verified・delegate-registry.sh・oe-send）で反証し、substrate 分岐へ再構成した。
- 残した未検証域: tmux クライアントが非フォーカス wez ペインにあるケース（DJ-C 既知限界・#188 スコープ外）。
