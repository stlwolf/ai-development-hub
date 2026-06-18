# remote ハーネス — クラウド基板へのハーネス拡張構想

- 日付: 2026-06-18
- 性質: アイデアスナップショット。Claude Code (Opus 4.8 / 1M) との壁打ち（3ターン）の統合。セカンドオピニオン（Web Claude + ChatGPT 手動クロスレビュー）は今後 [discussion-logs/](discussion-logs/) に追加予定。
- 着想元: Claude Code Routines の一般提供（2026-04）。「ローカルに閉じたハーネスをクラウド基板へ延ばせるか」という問いから。
- derived_from:
  - Routines 一次情報（後述「一次情報」節）
  - Claude Code (Opus 4.8) との壁打ち（本ファイルが統合結果）
- related_ideas:
  - [../20260414/harness-architecture-layer-separation-control-loop.md](../20260414/harness-architecture-layer-separation-control-loop.md) — **直接の先祖**。canonical 4層分離を「決定性の境界」で再整理し、最大ギャップを「制御ループの不在」と特定。本構想はその制御ループ／ラフループの弱さへの回答にあたる
  - [../20260329/metadata-layer-mirror-repo-synthesis.md](../20260329/metadata-layer-mirror-repo-synthesis.md) — Decision Ledger + post-commit hook 自動抽出 + Ralph Loop 接続。state-in-artifact（成果物に状態を置く）の先行形
  - [../20260224/orchestration-design-principles-bath-brainstorm.md](../20260224/orchestration-design-principles-bath-brainstorm.md) — 3設計原則（ベンダー非依存・直列プリミティブ合成・拡張可能）。「薄く大きく」の源流
  - [../20260208/hypothesis-second-opinion-review-flow.md](../20260208/hypothesis-second-opinion-review-flow.md) — 反証担当固定の並列探索。強制フローとしての SO の位置づけに接続
- related_issues:
  - [#37 epic: Harness Engineering 基盤整備](https://github.com/stlwolf/ai-development-hub/issues/37)
  - [#24 chore: フック拡充エピック](https://github.com/stlwolf/ai-development-hub/issues/24) — hard/決定的トリガの defer 先。remote トリガはその外延
  - [#185 oe 結合の episode lifecycle 機械制御](https://github.com/stlwolf/ai-development-hub/issues/185) — 「必ず episode」を trigger→存在チェック→nudge/block する強制フローの本命
  - engine Phase5 配送セマンティクス軸（push/poll 分離、agmsg）— [#105](https://github.com/stlwolf/ai-development-hub/issues/105) / [#108](https://github.com/stlwolf/ai-development-hub/issues/108) / [#114](https://github.com/stlwolf/ai-development-hub/issues/114)。remote の Trigger 行が push/poll の問いに直結
- related_docs:
  - `canonical/rules/subagent-strategy-rule.md` — routing gate（同期ゲート vs fire-and-forget の切り分け）。remote ハーネスのゲート面はこの軸の延長
  - `projects/orchestration-engine/` — oe-* 駆動層。強制フローの判断側を担う

---

## 構想の核心（一文）

ローカルに閉じたハーネス（hook = 機械的ゲート、skill = 手続き、人間 = 同期ゲート）を、Routines / Claude Code on the web を基板にして **ラップトップの外（GitHub 側・クラウド側）まで延ばす**。重い部分（スケジューラ・サンドボックス・永続化）はマネージドクラウドに外出しされるため、**リポジトリは markdown のまま「薄く大きく」reach だけ広げられる**。

## 背景・動機（今のハーネスの弱点）

- hook は強制力（決定論）はあるが、**機械的述語しか入らない**。「必ず SO」「この条件ならレビュー」「この条件なら episode 必須」のような非機械的フローを入れづらい。
- bash + 薄ラッパー設計ゆえに、**自己改善 / ラフループ（持続的な自己反復ループ）が弱い**。重い Python/TS フレームワークなら制御できるが、それは設計哲学に反する。
- 20260414 で特定した「制御ループの不在」が未解決のまま。

## ハーネスの面分解（4面）

ローカルハーネスを remote に写したとき、面ごとに越境の度合いが違う。

| 面 | ローカル | remote（Routines）| 越境 |
|---|---|---|---|
| トリガ面 | 打鍵 / `/loop` / hook | cron / API POST / GitHub event | 一般化される |
| 実行面 | ラップトップ | クラウドサンドボックス（毎回 clone・揮発）| 移設される |
| 設定面 | `~/.claude/` に sync した正本 | **リポジトリにコミットされた分のみ** + account connector | 部分のみ |
| ゲート面 | 同期的な人間ゲート（承認・hook 割込）| 自律実行 + 事後レビュー（非同期）| 質が変わる |

- 設定面の越境問題: `~/.claude/`（sync.sh で配布したローカル正本）はクラウドに行かない。remote で使える skill/CLAUDE.md/hook は「クローン対象リポにコミットされた分」のみ。MCP も account-level connector のみで `claude mcp add` のローカル MCP は不可。
- 幸い hub の資産は markdown で軽いので、リポへの vendor / routine prompt への inline は重くない（薄さの配当）。

## 構築の座標系（1フロー = 5スロット）

新規フローを組むとは、各スロットから1つずつ選ぶこと。右列（remote）が**今回新しく入ってくる選択肢**。

| スロット | 役割 | local（既存）| remote（新規）|
|---|---|---|---|
| Trigger | 何が起こすか | 打鍵 / `/loop` / hook | cron / API POST / GitHub event |
| Driver | 誰が反復を回すか | bash loop / Workflow / 親子 tmux（in-session）| cron 再 fire / event 再 fire（時間をまたぐ）|
| Work | 柔軟な中身（判断）| skill + LLM セッション + so-compare（ローカル CLI）| committed skill + cloud セッション + MCP connector |
| Gate | 止める力 | hook deny / 人間承認（同期）| branch protection + required check（非同期だがブロック）|
| State | 反復をまたぐ記憶 | bash 変数 / tmp ファイル / session context（揮発）| repo ファイル / PR ラベル / commit status（永続）|

既定フロー（今の skill 群）はほぼ全部 local 列だけで組まれている。**新規フロー = 右列を混ぜた組み合わせ**。

## 核心の補正：「強制力」は Routine からは出ない

hook は PreToolUse で**ブロックできる**から強制力がある。Routine は **react するだけでブロックしない**——push はもう起きてるし PR はもう開いてる。横で走ってコメント / PR / go-no-go を**置く**ことはできるが merge は止められない。

- 「確認のタイミングだけ同期で待つ」の正体 = **PR そのものが同期確認点**。remote が非同期で結果を PR に積む → PR は merge クリックを永遠に待つ。
- その「待ち」を advisory から**壁**に変えるのは Routine ではなく **GitHub の branch protection / required check**。

```text
push/PR (決定論トリガ)
  → Routine (柔軟判断: SO/レビュー/episode 要否を分岐)
  → 結果を PR に積む (status / check / comment)
  → branch protection が required check 未達なら merge ブロック   ← ここが強制力
  → 人間が merge クリックで同期確認 (ボタンを押す作業は残る)
```

役割分担案: **判断は Routine、ブロックは GitHub Actions の required check**（Routine が commit status を立てられるかが未確認のため）。

## (A) 強制フロー と (B) ラフループ は別問題

| | (A) 非機械的な強制ゲート | (B) 自己改善 / ラフループ |
|---|---|---|
| 例 | 必ず SO / 条件レビュー / episode 必須 | Copilot レビュー応答ループ、自己監査 |
| remote の効き方 | 「決定論の発火 + 柔軟な判断 + branch protection のブロック」で成立 | **本命**。閉じても走る・event-driven な持続ループ |
| 限界 | 真ん中の判断は LLM で**確率的なまま**。remote にしても非機械的フローが決定論にはならない | 最小スケジュール間隔 1 時間 → サブ時間は polling ではなく event-driven 必須 |
| ブロッカー | so-compare は**ローカル CLI 依存**。remote 化は SO を cloud 到達手段（MCP/API）で作り直す必要 | 停止条件（3回まで / 低重要度だけになったら止める）は bash 変数でなく PR ラベル / 状態ファイルから読む round カウンタに |

- (B) の重要な気づき: 「ループに重いフレームワークが要る」前提は remote だと**半分溶ける**。各 fire は stateless、状態は repo/PR/check に置く（idempotent + state-in-artifact）。in-memory フレームワークループより text/bash と相性がいい。
- session 内で完結する決定論オーケストレーション（fan-out / N 回 verify）は local の Workflow 的手段で薄いまま回る。remote が要るのは**持続・時間をまたぐ・外から来る**ループの方。境界はそこ。

## remote で初めて可能になる4フロー原型（= 今実現してない部分）

1. **Ambient / 持続フロー** — 閉じてても何日も watch して react。doc-drift、backlog hygiene、「この episode 結局書かれた?」定期 sweep。
2. **Event-sourced フロー** — 外部 event に反応（PR opened / release / alert webhook）。手動トリガの擬似をネイティブ化。
3. **Self-improvement / メタフロー** — **ハーネスがハーネスを育てる**。episode/PR を読んで rule/skill 改善案、ゲート発火の自己監査。hub 自身を clone 対象にすれば hub が自分にフローを走らせる substrate になる。
4. **Cross-boundary フロー** — 版図をラップトップの外まで延ばす（「ネットワーク外もハーネスの版図に」の最大形）。

1・3・4 は Trigger/Driver/State を remote にしないと組めない。

## 「薄く大きく」が成立する理由

重い部分（スケジューラ・サンドボックス・セッション管理・永続化）はマネージドクラウドに外出しされ、リポジトリに入るのは markdown（prompt/skill/rule）＋せいぜい薄い Actions yaml だけ。**remote は「薄いまま大きくする」唯一の現実解**で、hub の bash + 薄ラッパー哲学と矛盾しない。

## 長期の到達点の選択肢空間（半径・未決定）

```text
(i)  個人ハーネス toolkit（現状）       assets を ~/ に sync、人が駆動
(ii) 自己ホスト型ハーネス              hub が自分自身に remote フローを走らせる（自己監査・自己改善・#185）
(iii)配布可能ハーネス                  薄い markdown 資産を任意リポに vendor/inline + マネージド remote ランタイム
(iv) engine-as-substrate              oe-* + remote を他者も載せられる汎用ハーネスへ
```

- 「もっと大きく薄く」は (ii)→(iii) に寄っている、という読み。
- 右に行くほど設定面の越境問題（`~/.claude` は cloud に行かない）が効くが、markdown の軽さで緩和される。

## 未検証事項（要実機確認）

- [ ] Routine が branch-protection の読む commit status / check を立てられるか（docs 未明記。確実な required-check 経路は GitHub Actions）
- [ ] PR の review-comment / review-submitted が GitHub trigger サブイベントとして対応するか（明記は opened/closed/assigned/labeled/synchronize +「その他更新」）
- [ ] クラウドセッションで committed hook（`.claude/settings.json`）が発火するか（Qiita 二次情報は PreToolUse 例を挙げるが公式 Routines doc は未明記）
- [ ] 二次情報のプラン別実行上限（Pro:5 / Max:15 / Team:25）は公式 doc 非記載・research preview で変動しうる

## 先行アイデア・生きてるスレッドとの接続

- 20260414「制御ループの不在」への回答 = 本構想。ラフループの駆動面を remote に出す。
- channels event-driven 構想（保留中、再開条件「engine ラフループ組込み時」）のマネージド版が Routines の GitHub trigger。今がその地点に見える。
- engine Phase5 配送セマンティクス軸（push/poll 分離）= remote の Trigger 行が push/poll の問いを体現。
- #185 episode lifecycle 機械制御 = フロー原型 1/3 の本命候補。

## セカンドオピニオン投入用プロンプト（Web Claude / ChatGPT 手動用）

以下を新規スレッドにそのまま貼り、客観的批評を求める。回答ログは [discussion-logs/](discussion-logs/) に保存する。

```text
私は「AI ハーネス」（ルール/スキル/フック/サブエージェントで構成された、コーディング
エージェントの動作を制御する層）をローカルの bash + 薄いラッパー + markdown で育てている。
今、これをクラウド側（Claude Code Routines = cron / API / GitHub event をトリガに
クラウドで自律実行するセッション）まで延ばす「remote ハーネス」を構想している。

骨子:
1. ハーネスを Trigger / Driver / Work(判断) / Gate / State の5スロットに分解。remote では
   Trigger=cron/API/GitHub event、Driver=cron/event 再fire、State=repo/PR/commit status
   が新しく使えるようになる。
2. 「強制力」は Routine 自体からは出ない。Routine は react するだけでブロックしないので、
   実際にブロックするのは GitHub の branch protection / required check。PR 自体が同期確認点。
3. 用途は (A) 非機械的フローの強制（必ず SO / 条件レビュー / episode 必須）と
   (B) 持続的な自己改善ラフループ（閉じても走る・event-driven）の2系統。
4. 設計哲学は「薄く大きく」: 重い部分はマネージドクラウドに外出しし、リポジトリは
   markdown のまま reach だけ広げる。

この構想に対して、以下を厳しく評価してほしい:
- 見落としている前提や弱点。特に「強制力は branch protection から出る」という整理の穴。
- 5スロット分解より良いフレーミングはあるか（ゼロベースで別の切り口を1つ以上）。
- (A)(B) 以外に remote で初めて可能になるフロー原型を見落としていないか。
- この方向に進むと将来どこで詰むか（運用事故・コスト・ロックイン・確実性の幻想）。
- 「やらない / 一部だけ」が正解になる条件は何か。

同意ではなく反証を優先してほしい。
```

## 一次情報

- [ルーティンで作業を自動化する（Routines 公式 / 日本語）](https://code.claude.com/docs/ja/routines)
- [GitHub Actions（required check の正攻法）](https://code.claude.com/docs/ja/github-actions)
- [Claude Code on the web（クラウド環境）](https://code.claude.com/docs/ja/claude-code-on-the-web)
- [API 経由でルーティンをトリガーする](https://platform.claude.com/docs/ja/api/claude-code/routines-fire)
- [【実録】Claude Code Routines を3日間運用してみた（Qiita / 二次情報）](https://qiita.com/nogataka/items/3ff7b14684306ef413e0)
