---
name: orchestration-toolkit
description: oe-* オーケストレーションツール群（engine 本体 / 親子委譲 / SO ゲート / 選択・観測）と駆動層規律の統合概観。複数エージェント委譲・設計SO/実装SO・read-only 観測・engine 1 サイクルを使うとき、ツール群の全体像をリポジトリ走査でなく一貫した形で把握したいときに使用する。
---

# Orchestration Toolkit (oe-*) — 統合概観

oe-* ツール群を **1 つのパッケージとして一貫理解する**ための概観。個別スクリプトを repo 走査して断片把握すると齟齬が出るため、本スキルで全体像を取り、詳細は各 verb の README / focused スキルへ routing する。実体は `projects/orchestration-engine/bin/`（`oe` ＋ `oe-*`・全 11 verb）。

## ツール群（役割別）

- **engine 本体**: `oe`（自律 1 サイクル: `board_apply`[盤面初期化=#175 layout]→spawn→envelope→send→**monitor loop（内部で capture/classify/KVS 書込）**→（monitor 成功時）verify→cleanup[trap EXIT]。状態 KVS ＋ audit jsonl ＋ circuit breaker[max_turns/max_panes/timeout]。**spawn=生成 / verify=別 reviewer spawn＝生成と反証を物理分離**）/ `oe-capture`（ペイン capture 補助）。
- **親子委譲**: `oe-delegate`（子セッション起動 + 最初のキック）/ `oe-kick`（`#N` or kickoff パスを 1 引数で受け `oe-delegate` のフラグ列へ展開するワンショットラッパー）/ `oe-send`（既存ペインへ 1 行/キックオフ送信・戻しもこれ）/ `oe-list`（宛先候補を source 列付きで列挙）/ `oe-report`（legacy・戻しは oe-send に一本化）。詳細手順 → `delegate-task` スキル。
- **SO ゲート**: `oe-refute`（**設計SO**・確定前の同期反証・`--rubric exploration|consensus`）/ `oe-review`（**実装SO**・reviewed diff バインドのコード欠陥レビュー・`lens=impl`）。いずれも `so-compare` を wrap。※engine 内の `verify`（単一 reviewer の compliance review）とは**別物**（同名注意）。
- **選択 / 観測**: `oe-select`（`oe-list`+fzf で対話選択→`oe-send` 委譲する UX。preview で `tmux capture-pane` を読む）/ `oe-status`（**read-only 俯瞰**: engine の audit-terminal reducer 由来 state ＋ delegate liveness。**ペイン出力は読まない＝検出しない**）。

## 駆動層規律（engine 作業の 1 サイクル）

discussion/DJ → **設計SO** → 実装 → **実装SO** → Episode → PR →（Copilot）→ closure。設計SO/実装SO のツールは **`so` モード次第**（弱〔既定〕=`oe-refute`/`oe-review`・強=`peer-ai-review`。下記モード行参照）。

- **SO レーンポリシー（運用方針。verb 既定は `--lanes 2`）**: 設計SO=**`oe-refute --lanes 3` を明示**（3社=codex+cursor+claude。Claude/Opus を設計＝選択肢拡張に活かす）／実装SO=既定の **`oe-review`（2社=codex+cursor・実装者 Claude を抜き model 多様性で欠陥検出）**。観点が違うので**両方**実施（設計だけで実装SO を省略しない）。重い対象は都度 3社+3社 もありだが、なるべく分割して重くしない。※レーンの model（cursor=composer / claude=opus 等）は **so-compare 側の指定**で oe-* は固定しない。
- **SO モード（強/弱・レーン軸と直交）**: **強 SO**=`peer-ai-review`（全レーン合意まで iterate・partial=再試行・0=不可）／**弱 SO**=`so-compare`/`oe-refute`/`oe-review`（1 周可・partial=disclose・**0=SO 未実施で再試行/escalate="0 はなし"**）。**設計段階に kickoff/plan の `so` frontmatter で選択**（正本 `docs/specs/document-format.md` の「SO モード」節〔§4.1〕）。レーン数（上記ポリシー）とモードは**直交**（別々に選ぶ）。
- 集約は **conservative**（1 レーンでも material な指摘 → 全体 refuted）。`refuted` は **exit 3（advisory・JSON が正本）**＝oe-* は機械的に PR/マージを止めない（確定保留は harness/運用判断）。
- 蒸留パイプライン doc: discussion / kickoff / **episode（締めで必須・本文は随時追記・後追い再構成は `reconstructed` 明示）** / decision-ADR（任意・content 次第）。closure は `episode-retrospective`。
- **完全移譲**: 自律委譲子は discussion/設計SO から 実装→実装SO→Episode→PR→Copilot→closure まで**一気通貫**（親は巻き取らない）。
- **自律委譲子の権限（運用・opt-in）**: `oe-delegate`/`oe-kick` は既定で permission-mode を付けない。自律子には `--claude-arg --permission-mode --claude-arg auto` を**明示的に渡す**。`bypassPermissions` は委譲子では即死するため `auto` を使う（実機学び・コード強制ではない）。auto/full 権限の自律子はガードレールでユーザー明示承認が要る。

## malform hygiene（生 capture の会話混入を断つ）

長寿命・ツール密な統括セッションでは、子ペインの生出力（tool-call タグ列・box-drawing・制御文字）が親の会話コンテキストへ入ると、親が自己回帰で模倣して tool-call malform が連鎖・悪化する。oe-* の**会話到達面**（event-bus preview）は write+read サニタイズ済み（#224 / `projects/orchestration-engine/lib/sanitize.sh`）だが、**統括が生 `wez pane capture` / `tmux capture-pane` を直叩きして会話へ貼る経路はサニタイズを通らない**＝文字列制御では消えない。ここは behavioral な規律で断つ:

- **壊れた/生の子ペイン出力を会話へ貼り返さない**。渡すなら要約するか、path（ファイル/ログの場所）で受け渡す。これは tmux/Wez どちらの capture でも効く load-bearing な規範。
- どうしても中身を確認するなら、生出力を**そのまま会話に載せない**（必要行だけ要約・引用符やコードブロックで囲んで自己回帰の連続を断つ）。現状 sanitize 済みの tmux peek 入口は無い（安全 capture 入口は follow-up）。
- **親をリーンに保つ**: capture は最小限に、重い読み取り・作業は子へオフロードし、セッションは短命化して早めに handoff する（長コンテキスト劣化＝Phase 5 #105/#108 の副因も緩む）。

報告・戻しでも同じ（生 capture を貼らず要約 or path）。委譲/報告の操作手順は `delegate-task`。背景と scoping は #233。

## 重要な不変条件 / gotcha

- `oe` / `oe-*` は **PATH 未登録** → `projects/orchestration-engine/bin/` のパスで起動（`so-compare`/`wez` 等は `~/bin` に sync 済で PATH 上）。
- SO の audit は本体 per-session（`audit/{id}.jsonl`）と別系統: **`oe-refute.jsonl`（`event_type=oe_refute`・`rubric`）/ `oe-review.jsonl`（`event_type=oe_review`・`lens=impl`・diff バインド）**。`oe-status` の ENGINE 区画には SO audit は出ない（別 viewer）。
- engine の state KVS は **初回=target 完了（`@@OE_EXIT` 検出）時に作成**・verify は完了後に同 KVS へ追記。**実行中 / CB timeout は KVS 不在**（観測は audit-tail から導く）。

## 詳細への routing

- 各 verb のフラグ/挙動: `projects/orchestration-engine/bin/README.md`
- 委譲の操作手順: `delegate-task` スキル
- 設計確定前のゼロベース探索: `predecision-exploration` / バグ調査のコードパス網羅: `code-path-exhaustion`
- SO テンプレ（選択肢拡張）: `so-compare` スキル
- closure の振り返り: `episode-retrospective` スキル
