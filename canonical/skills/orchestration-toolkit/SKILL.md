---
name: orchestration-toolkit
description: oe-* オーケストレーションツール群（engine 本体 / 親子委譲 / SO ゲート / 選択・観測）と駆動層規律の統合概観。複数エージェント委譲・設計SO/実装SO・read-only 観測・engine 1 サイクルを使うとき、ツール群の全体像をリポジトリ走査でなく一貫した形で把握したいときに使用する。
---

# Orchestration Toolkit (oe-*) — 統合概観

oe-* ツール群を **1 つのパッケージとして一貫理解する**ための概観。個別スクリプトを repo 走査して断片把握すると齟齬が出るため、本スキルで全体像を取り、詳細は各 verb の README / focused スキルへ routing する。実体は engine の `bin/`（`oe` ＋ `oe-*`・**全 23 verb**。hub では `projects/orchestration-engine/bin/`）。この 22 は `bin/` 直下の実行可能エントリの実数なので、verb が増減したら下の役割別リストとこの数も直す。

## ツール群（役割別）

- **engine 本体**: `oe`（自律 1 サイクル: `board_apply`[盤面初期化=#175 layout]→spawn→envelope→send→**monitor loop（内部で capture/classify/KVS 書込）**→（monitor 成功時）verify→cleanup[trap EXIT]。状態 KVS ＋ audit jsonl ＋ circuit breaker[max_turns/max_panes/timeout]。**spawn=生成 / verify=別 reviewer spawn＝生成と反証を物理分離**）/ `oe-capture`（ペイン capture 補助）。
- **親子委譲**: `oe-delegate`（子セッション起動 + 最初のキック）/ `oe-kick`（`#N` or kickoff パスを 1 引数で受け `oe-delegate` のフラグ列へ展開するワンショットラッパー）/ `oe-send`（既存ペインへ 1 行/キックオフ送信・戻しもこれ）/ `oe-list`（宛先候補を source 列付きで列挙）/ `oe-register`（spawn を経ずに手動起動したペインを登記し、自分を root にする・相手を自分の子に link する）/ `oe-ack`（自分宛てに届いた報告へ受領印を打つ。受領は推論せず、受け取った側が明示的に打つ）/ `oe-jump`（通知やラベルから対象 tmux ペインへ focus する。`--record` で直近の target を replay）/ `oe-report`（legacy・戻しは oe-send に一本化）。詳細手順 → `delegate-task` スキル。
- **SO ゲート**: `oe-refute`（**設計SO**・確定前の同期反証・`--rubric exploration|consensus`）/ `oe-review`（**実装SO**・reviewed diff バインドのコード欠陥レビュー・`lens=impl`）。いずれも `so-compare` を wrap。※engine 内の `verify`（単一 reviewer の compliance review）とは**別物**（同名注意）。
- **選択 / 観測**: `oe-select`（`oe-list`+fzf で対話選択→`oe-send` 委譲する UX。preview で `tmux capture-pane` を読む）/ `oe-status`（**read-only 俯瞰**: engine の audit-terminal reducer 由来 state ＋ delegate liveness。**ペイン出力は読まない＝検出しない**）/ `oe-activity`（親子活動ログを read 時に投影するビュー。往復・配送・直近 preview・子の生存・受領を出す）/ `oe-tree`（spawn トポロジを罫線ツリーで描く。`--watch` で live 表示、`--pick` で選んだペインへ jump + 最大化）/ `oe-ident`（ペインの識別子を pane border へ read 時投影する表示ヘルパ）/ `oe-threads`（**生存ペインごとのモデル名とコンテキスト%**。statusLine 拍動 sidecar を**生存ペイン側から**引くので、登記されていない手動ペインも出る＝`oe-tree` とは母集団が違う。鮮度は行を落とすのではなく帰属の解決にだけ使い、候補が複数なら潰さず曖昧と出す）。
- **watchdog（read-only・cron から回せる）**: `oe-undelivered`（子→親の報告が未受領のまま時間窓を越えたものを拾う）/ `oe-vitals`（統括セッションの拍動の鮮度と context% を見て、肥大接近とプロセス死を拾う）/ `oe-selfcheck`（外部の版に固定された前提が今も成り立つかを点検する）/ `oe-hookfire`（止める側のフックが直近の窓で発火したかを記録から読む）。4本に共通するのは **engine の state（イベントログ / registry / session-state）を書き換えない**ことだけである。**「ファイルを一切書かない」という意味ではない** — 二重通知を抑える cache、観測の起点、一時ファイルなど、何をどこへ書くかは verb ごとに違う。完全な read-only を前提にした環境で走らせるなら、**verb ごとに README で書き込み先を確かめること**（この節に書き込みの一覧を持たせない。まとめると必ず古くなるか、どれか1本にだけ当てはまる性質を4本に広げてしまう）。判定の詳細と exit も各 verb の README を正本とする。
- **doc 表示**: `oe-view`（生成した doc を開く入口。md は viewer ペインで `glow`、それ以外は `open` に回す）。
- **negative knowledge store（standalone・`oe-` 無し・sync-bin 配布）**: `knowledge-list`（段3 突合＝store の item を蒸留木横断で read-only 列挙・`--strict`/`--json`/`--include-uncommitted`。**段6 v0 として observations を state ごとに集計し、`status: active` + adverse な観測の item に制御候補フラグを立てる**・書き換えはしない）/ `validate-knowledge`（item スキーマ検証・observations の要素スキーマを含む・advisory）。列挙 → 採否 → 注入の手順は `doc-flow-guardrail`「negative knowledge 注入」節（**列挙のあとに検証を回す二段チェック**）、観測の書き戻しは `episode-retrospective`、コマンド詳細は store の `knowledge/README.md`。

## 駆動層規律（engine 作業の 1 サイクル）

駆動層の1サイクル（層・遷移・ゲートの全体地図）は **`doc-flow-guardrail`** を正本とする（重複を持たない）。本節は各ゲートで使う **oe-* ツール**だけを扱う。設計SO/実装SO のツールは **`so` モード次第**（弱〔既定〕=`oe-refute`/`oe-review`・強=`peer-ai-review`。下記モード行参照）。

- **SO レーンポリシー（運用方針。verb 既定は `--lanes 2`）**: 設計SO=**`oe-refute --lanes 3` を明示**（3社=codex+cursor+claude。Claude/Opus を設計＝選択肢拡張に活かす）／実装SO=既定の **`oe-review`（2社=codex+cursor・実装者 Claude を抜き model 多様性で欠陥検出）**。観点が違うので**両方**実施（設計だけで実装SO を省略しない）。重い対象は都度 3社+3社 もありだが、なるべく分割して重くしない。※レーンの model（cursor=composer / claude=opus 等）は **so-compare 側の指定**で oe-* は固定しない。
- **SO モード（強/弱・レーン軸と直交）**: **強 SO**=`peer-ai-review`（全レーン合意まで iterate・partial=再試行・0=不可）／**弱 SO**=`so-compare`/`oe-refute`/`oe-review`（1 周可・partial=disclose・**0=SO 未実施で再試行/escalate="0 はなし"**）。**設計段階に kickoff/plan の `so` frontmatter で選択**（正本 `canonical/orchestration-spec/document-format.md` の「SO モード」節〔§4.1〕）。レーン数（上記ポリシー）とモードは**直交**（別々に選ぶ）。
- 集約は **conservative**（1 レーンでも material な指摘 → 全体 refuted）。`refuted` は **exit 3（advisory・JSON が正本）**＝oe-* は機械的に PR/マージを止めない（確定保留は harness/運用判断）。
- 蒸留パイプライン doc の型・入口・ライフサイクルは **`doc-flow-guardrail`**（フロー地図）と `document-format.md`〔文書型別テンプレート §8 / ライフサイクル規範 §12〕が正本。closure は `episode-retrospective`（マージ前・後追いは `reconstructed` 明示）。
- **完全移譲**: 自律委譲子は discussion/設計SO から 実装→実装SO→Episode→PR→Copilot→closure まで**一気通貫**（親は巻き取らない）。
- **自律委譲子の権限（運用・opt-in）**: `oe-delegate`/`oe-kick` は既定で permission-mode を付けない。自律子には `--claude-arg --permission-mode --claude-arg auto` を**明示的に渡す**。`bypassPermissions` は委譲子では即死するため `auto` を使う（実機学び・コード強制ではない）。auto/full 権限の自律子はガードレールでユーザー明示承認が要る。
  - **elevated 子 spawn の owner 承認ハンドシェイク（#262）**: 子が elevated（bypass / 本番・機微アクセス）のとき、親は spawn 前に `oe-delegate --print-approval` で整形済み承認パッケージ + ダイジェストを owner へ先出しし、承認後に `--approved-digest` 付きで実 spawn する（承認↔実行を binding・分類器は迂回しない）。**規範はここ・操作手順は `delegate-task`・ゲート位置は `doc-flow-guardrail`**（3軸分離）。通常のローカル auto 委譲は対象外。

## malform hygiene（生 capture の会話混入を断つ）

長寿命・ツール密な統括セッションでは、子ペインの生出力（tool-call タグ列・box-drawing・制御文字）が親の会話コンテキストへ入ると、親が自己回帰で模倣して tool-call malform が連鎖・悪化する。oe-* の**会話到達面**（event-bus preview）は write+read サニタイズ済み（#224 / `projects/orchestration-engine/lib/sanitize.sh`）だが、**統括が生 `wez pane capture` / `tmux capture-pane` を直叩きして会話へ貼る経路はサニタイズを通らない**＝文字列制御では消えない。ここは behavioral な規律で断つ:

- **壊れた/生の子ペイン出力を会話へ貼り返さない**。渡すなら要約するか、path（ファイル/ログの場所）で受け渡す。これは tmux/Wez どちらの capture でも効く load-bearing な規範。
- どうしても中身を確認するなら、生出力を**そのまま会話に載せない**（必要行だけ要約・引用符やコードブロックで囲んで自己回帰の連続を断つ）。現状 sanitize 済みの tmux peek 入口は無い（安全 capture 入口は follow-up）。
- **親をリーンに保つ**: capture は最小限に、重い読み取り・作業は子へオフロードし、セッションは短命化して早めに handoff する（長コンテキスト劣化＝Phase 5 #105/#108 の副因も緩む）。

報告・戻しでも同じ（生 capture を貼らず要約 or path）。委譲/報告の操作手順は `delegate-task`。背景と scoping は #233。

## 重要な不変条件 / gotcha

- **`oe` / `oe-*` は原則 PATH 未登録** → engine の `bin/` ディレクトリのパスで起動する（hub では `projects/orchestration-engine/bin/`）。**ただし bin sync の配布対象に入れた verb は例外で、sync を実行した環境では PATH 上にある**（本稿執筆時点の配布対象は `oe-tree` と `oe-hookfire` の2本。`so-compare` / `wez` / `knowledge-list` / `validate-knowledge` 等の standalone スクリプトも同じ経路）。**配布対象であることと、その環境に配備済みであることは別である。** 一覧も配布対象が増えれば古くなるので、起動方法を決める前に `command -v <verb>` で確かめること（配布対象の正本は bin sync スクリプトの配列）。
- SO の audit は本体 per-session（`audit/{id}.jsonl`）と別系統: **`oe-refute.jsonl`（`event_type=oe_refute`・`rubric`）/ `oe-review.jsonl`（`event_type=oe_review`・`lens=impl`・diff バインド）**。`oe-status` の ENGINE 区画には SO audit は出ない（別 viewer）。
- engine の state KVS は **初回=target 完了（`@@OE_EXIT` 検出）時に作成**・verify は完了後に同 KVS へ追記。**実行中 / CB timeout は KVS 不在**（観測は audit-tail から導く）。

## 詳細への routing

- 各 verb のフラグ/挙動: engine の `bin/README.md`（hub では `projects/orchestration-engine/bin/README.md`）
- 委譲の操作手順: `delegate-task` スキル
- 設計確定前のゼロベース探索: `predecision-exploration` / バグ調査のコードパス網羅: `code-path-exhaustion`
- SO テンプレ（選択肢拡張）: `so-compare` スキル
- closure の振り返り: `episode-retrospective` スキル
