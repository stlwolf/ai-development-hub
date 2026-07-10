---
id: "01KX3X4NXGX5AXKS6HKFNRY0KR"
title: "#239 段階1 PR-A statusLine 拍動 producer — 実装 closure"
date: 2026-07-10
type: episode
status: stable
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/239"
    reason: "本 episode の対象タスク（producer=PR-A・多段のため keep-open）"
  - type: artifact
    ref: "https://github.com/stlwolf/ai-development-hub/pull/245"
    reason: "本 episode が closure する PR（producer + sync 非破壊 merge）"
  - type: source_material
    ref: ".oe/ref-plan-stage1.md"
    reason: "実装計画の正本（§2 PR-A / §4 Q4）。worktree external・gitignore"
  - type: source_material
    ref: "projects/orchestration-engine/bin/oe-undelivered"
    reason: "段階0（#241）= sidecar 契約・observer family の template"
tags: [orchestration, statusline, heartbeat, producer, "239", episode, closure, reconstructed]
---

# #239 段階1 PR-A statusLine 拍動 producer — 実装 closure

> **reconstructed**: 本 episode はリアルタイム追記でなく、実装・レビュー完了後に会話・commit・SO/Copilot 出力から再構成した。追記ログと同じ証拠価値は持たない（時系列の精度は commit と PR スレッドに従う）。

## Context（なぜ）

統括（cockpit 4代目・親 pane `%144`）から委譲された #239 段階1 の **PR-A**。段階0（報告未達検知 `oe-undelivered`・#241・read-only）に、statusLine 拍動 producer を足して mode1（context 肥大死 / liveness）機械化の土台を作る。上位アーキは HG 確定済み（lean + sidecar・producer 表現 = (i) sidecar file）。producer は **sidecar 契約（パス + JSON 形）を正本として定義**し、後続の consumer（PR-B）がそれを read する前提。子セッション（`%155`）として実施。

## 経緯（時系列）

1. kickoff（`.oe/kickoff-pr-a.md`）+ plan §2 PR-A / §4 Q4 を読む。statusLine の一次仕様（`code.claude.com/docs/en/statusline.md`）をこのセッションで再確認 — `refreshInterval` は statusLine の field（秒・最小1）、context% は `.context_window.used_percentage`（null 早期あり）、`session_id` は top-level、tmux pane は stdin に無い。
2. 実装: producer script（best-effort・atomic write・非破壊出力）/ settings source / sync-claude.sh の統合。producer 単体テスト + sync merge の scratch HOME 検証。
3. **実装 SO**（`oe-review` impl・弱・1周）→ **refuted（3件 material）**。3件を修正・再検証（下記 §事実・失敗）。
4. commit → PR #245 作成 → 親 `%144` へ報告。
5. owner 判断で stage-1 標準フロー（Copilot → closure → owner マージ）へ。**Copilot review**（1ラウンド自律）→ 行コメント3件（C1/C2/C3）を修正・返信。
6. 本 closure（マージ前）。

## 事実・失敗（外部レビューが捕捉した欠陥・省略しない）

### 実装 SO（oe-review impl 弱1周・verdict=refuted・audit_id `20260709162511G5K8KAYDSJQW`・lanes codex/cursor 2/2）

いずれも到達可能な material 欠陥で、修正・再検証した:

- **(a) 未クォート `$HOME` の word-split**（codex）: `statusLine.command` は shell で実行される。`$HOME` を未クォートで置くと空白入り HOME（例 `/Users/John Doe`）で分割され producer が起動しない → heartbeat 皆無。→ command を二重引用符で囲む（`"$HOME/…"` は double-quote 内で展開され split しない）。`HOME='… space'` の `sh -c`/`bash -c` で rc=0・表示・beat 生成を確認。（lane 差: cursor は `claude.statusline.json` の `$HOME` を「hooks 群と同じ repo 慣習」として non-material に分類したが、codex が空白入り HOME での word-split 到達性を実証。oe-review の conservative 集約は material 側を採用。）
- **(b) `$HOME` リテラル substring による二重 wrap**（cursor）: sync の beat 判定が canonical の `$HOME/…` リテラル substring 依存で、既存 settings の command が絶対パス化済み（`/Users/eddy/…`）だと一致せず wrap 分岐へ再入 → producer 自身を `OE_HEARTBEAT_WRAP_CMD` に退避して二重 wrap（表示破壊・再帰 eval risk）。→ 安定 basename マーカー `statusline-oe-heartbeat.sh` 判定へ変更（展開・絶対パス化・wrap 済のいずれでも認識）。回帰テスト追加。
- **(c) `set -u` 下 HOME 未設定で exit 1**（cursor）: producer は非破壊契約（表示を出して exit 0）を掲げるが、`OE_HEARTBEAT_DIR` 未設定 + `HOME` 未設定で `${HOME}` が unbound → 即 abort。→ `${HOME:-}` で守る。HOME 未設定でも exit 0 + 表示を確認。

親 spot-check: (a) を一次（`statusline.md`）で再確認して SO 指摘の正確性を検証。

### Copilot review（1ラウンド・PR #245・行コメント3件）

- **C1 wrap の意味変化**: `%q` 退避が `~/` / `$VAR` 展開を壊す懸念 → 分析の結果、`%q` → outer shell の語 parse → producer の `eval` 再 parse を経て展開は**保たれる**（`MYTAG=$LOGNAME ~/mybar.sh` を wrap→実行し確認）。残差は producer の `set -u` が eval に及ぶ点 → wrap eval を `( set +u; eval … )` subshell 化して元コマンドの意味を変えないようにした。
- **C2 壊れ settings で sync 全体 abort**: `existing_cmd` の jq 読みが未ガード → 壊れた settings.json で `set -e` により abort。→ jq 読みをガードし parse 不能なら statusLine merge のみ warn+skip。**非自明な発見**: 実測では malform settings は本 statusLine step の手前の**既存** hooks merge step（`sync_claude_hooks`）が先に return 1 → sync 全体が abort する。これは PR-A 範囲外の既存挙動として本 PR では触らず follow-up に routing（PR スレッドへ back-propagation 済み）。
- **C3 wrap 実行の未カバー**: wrap 済 command を実際に実行する E2E テストが無い → `~/` 展開・表示保持・beat write を検証する E2E ケースを追加。

## 決定と根拠（diff から復元しにくい「なぜ」）

- **sidecar 契約を PR-A が正本定義**: パス `${OE_HEARTBEAT_DIR:-~/.claude/state/oe-heartbeat}/<session_id>.json`（session_id はパスに焼く）、body `{ts, context_pct, pane}`。`context_pct` は常に数値化（`tonumber? // 0`）— consumer（PR-B）が数値比較する契約保証（SO cursor が non-material として挙げた「`used_percentage` が string なら `context_pct` も string 化」への予防も兼ねる）。`pane` は best-effort（`$TMUX_PANE` 未伝播なら空・session_id 主キーで契約は保たれる）。body に session_id を重複させないのは path が主キーだから（最小）。
- **非破壊 merge（Q4）の3分岐**: (1) statusLine 未設定 → producer 設定 (2) 既に producer（wrap 済含む）→ command 保持で他フィールドのみ更新（二重 wrap 防止） (3) ユーザー独自 statusLine → 元コマンドを `OE_HEARTBEAT_WRAP_CMD` に退避し wrap（call-through で表示保持・`padding` 等の既存フィールドも保持）。「beat 常時配備 + 既存表示を壊さない」（Q4）の両立を wrap で解く。
- **`refreshInterval=10`**: plan §5 の A→B 契約 `W ≫ N`（W=1800s ≫ N=10s ≈ 180 beat 余裕）に沿う。docs 上の最小は 1 だが毎秒 write は不要 I/O。settings.json 直値のため env 上書き不可・運用チューニングは値差し替え。
- **配置**: producer は canonical 配下（harness config として sync 配布）。`lib/constants.sh` には足さない（あそこは engine/project-relative 専用）。既定パスは verb 内インライン + env 上書き（`lib/event-bus.sh:44-46` idiom）。

## わかったこと（W）

- statusLine `command` は shell 実行のため、`$HOME` を含むパスは**引用符で囲む**必要がある（tilde `~` は double-quote 内で展開されないので `$HOME` + quote が空白安全な唯一の形）。既存 hooks 群の未クォート `$HOME/.claude/hooks/…` は同種の潜在バグ（PR-A スコープ外・「残課題」(ii) へ routing 済み）。
- `%q` 退避 → outer shell 語 parse → `eval` 再 parse の往復は、`~/` と `$VAR` 展開を**保つ**（両者は eval 側で再展開される）。wrap の意味保存はこの往復に依存する。

## 原則（Pattern / Anti-pattern）

- **Pattern**: harness config を canonical → `~/.claude` へ配る merge は、丸ごと置換でなく**既存を土台に overlay**（`(.statusLine // {}) + $desired`）し、ユーザー設定フィールドを保持する。冪等性は**展開形に依存しない安定マーカー**（basename）で判定する。
- **Anti-pattern**: shell で実行される設定値（command）の path を未クォートで置く / 冪等判定を `$HOME` リテラル substring で行う（展開・絶対パス化で崩れる）/ 非破壊を謳うスクリプトで `set -u` の unbound（HOME 等）を放置する。

## 蒸留シグナル（昇格候補）

- 上記 Pattern/Anti-pattern（statusLine.command の quote / 安定マーカー冪等 / 非破壊スクリプトの `${VAR:-}` 規律）は将来 skill / rule 候補になりうるが、単発では弱い。**現時点は昇格しない**（負の知識 #62 の候補としてメモに留める）。
- Decision 昇格: なし（上位アーキは既存 decision doc に durable 化済み・本 PR はその実装）。

## 残課題（routing 付き）

- **既存 hooks step の scope 外課題（2件）**: いずれも PR-A（producer + statusLine merge）の外の既存 `sync_claude_hooks` / hooks 設定に属す。**disposition = 本 PR では修正しない・owner へ surface 済**（PR #245 C2 スレッド + 本 closure の `%144` 報告）。owner が別 Issue 化を判断する（子は Issue を切らない）:
  - (i) **`sync_claude_hooks` の malform-target abort**: 壊れた settings.json で hooks step が先に `return 1` → `set -e` で sync 全体 abort。本 PR の statusLine guard は full sync 経路では手前で落ちるため実質到達せず、**関数単独呼び出し時のみ有効**（この帰結は C2 返信では明示していない）。
  - (ii) **hooks command の未クォート `$HOME`**: `$HOME/.claude/hooks/…` が未クォートで、SO 指摘(a)と同種の空白入り HOME での word-split リスク（既存パターン）。
- **実機（Claude Code runtime）未検証**（配備/PR-B フェーズで実測）: (i) `$TMUX_PANE` が statusLine 実行 env に伝播するか（未伝播でも `pane` 空で契約成立・producer 修正不要／pane 解決を board 突合へ倒すのは PR-B 側） (ii) statusLine 設定（`refreshInterval:10` の**受理**・`$HOME` 展開）が実 runtime で効くか（SO cursor が「公式 runtime 上で E2E 未実施」と明示）。
- **`refreshInterval` の実値チューニング**: 運用観測で調整 → **運用マター（追わない・settings.json 値差し替えで対応）**。受理自体の未検証は上の「実機未検証」に属す（値調整とは別）。

## closure gate

- **次の消費者**: #239 PR-B の実装者（sidecar 契約 = パス + `{ts, context_pct, pane}` を read する consumer verb を作る）。および PR #245 のレビュー/マージを行う owner。
- **status**: stable / **達成度=達成**（PR-A core = producer + 配備3点セット + テスト + 実装SO + Copilot 対応まで完了）。マージ・worktree 掃除・#239 close は owner/親の責務で未実施（#239 は多段のため keep-open）。
- **evidence anchor**: SO 生出力は `tmp/oe-review-20260709162511G5K8KAYDSJQW/`（揮発・gitignore）。要点は本文へ転記済み（verdict/audit_id/3件）。durable アンカー = commit `f66e5e3`（実装 + SO 修正）/ `e9a0ad0`（Copilot 対応）・PR #245・テスト（producer 31 / sync merge 17・bash 5.2.37/3.2.57 両系 + shellcheck PASS）。
- **Step4 外部チェック（heavy tier・closure 品質の SO）**: `so-compare`（codex/claude・出力 `tmp/so-20260710-020400/`・揮発）を closure の4観点（選択的省略 / routing 網羅 / 揮発パス / back-propagation）に絞って実施。結果 = 省略なし・(3)(4) 問題なし・**(2) routing 抜け1件**（「既存 hooks 未クォート `$HOME`」が routing 先なしで宙に浮く）+ 開示強度差2点（lane 差の平坦化 / refreshInterval 受理の未検証と値調整の混同）を指摘 → 本 closure で全て反映（残課題を2区分へ再構成・lane 差と `context_pct` の SO 出所を注記）。
- **形式メモ（#113 効果測定）**: 出力型×消費チャネル骨格は「事実・失敗」「決定と根拠」「残課題(routing)」で material を漏れなく拾えた。拾えなかったのは *routing の確定度*（「別 Issue 候補」の曖昧さ）と *lane 間評価差の平坦化* — Step4 SO が捕捉。KPT 皮は未使用。摩擦: heavy Step4 の so-compare は 2〜3分の非同期待ちが1回。
