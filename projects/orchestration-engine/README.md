# orchestration-engine

自前オーケストレーションツール MVP の実装プロジェクト（[Epic #19](https://github.com/stlwolf/ai-development-hub/issues/19) Phase 4）。

## 目的

構造化ドキュメントのルーティングエンジンを Bash + jq で薄く実装し、AI コーディングエージェント間のタスク・コンテキスト受け渡しを自動化する。

3層モデルにおける**上半身（エージェント層）**に相当する。下半身（[wez CLI](../wezterm-ai-mode/) Phase 1 完了）と中間層（通信プロトコル、設計中）の上に構築される。

## 研究フェーズとの関係

本プロジェクトは [`projects/orchestration-research/`](../orchestration-research/) の Phase 1〜3（OSS リサーチ・概念抽出・設計統合）成果を起点とする。研究プロジェクトは **frozen**（Phase 1〜3 完了でクローズ）。本プロジェクトでは:

- 研究成果は**参照のみ**（直接編集しない）
- 研究起点以降の追加設計入力は**本プロジェクト側の `docs/` に記述**

### 主要参照

- `projects/orchestration-research/synthesis/architecture-sketch.md` — 全体アーキテクチャ素描（研究フェーズ正本、frozen）
- `projects/orchestration-research/synthesis/harness-engineering-mapping.md` — ハーネス概念マッピング
- `projects/orchestration-research/synthesis/context-foundation.md` — コンテキスト基盤

### 起点以降の追加設計入力

- [#37](https://github.com/stlwolf/ai-development-hub/issues/37) Harness Engineering 基盤整備 — G1〜G7 ギャップ
- [#20 issuecomment-4298073225](https://github.com/stlwolf/ai-development-hub/issues/20#issuecomment-4298073225) — 3層モデルと Epic ゴール不鮮明問題
- `docs/specs/2026-04-27-discussion-cli-wrapper-layers-and-token-discipline.md` — CLIラッパー4層モデル
- [#22](https://github.com/stlwolf/ai-development-hub/issues/22) / [#36](https://github.com/stlwolf/ai-development-hub/issues/36) CLOSE — 制御ループ入力層整備済み

## 構成

```
projects/orchestration-engine/
├── README.md                  # このファイル
├── bin/                       # 実行可能エントリ（各スクリプトの簡易説明は bin/README.md）
│   ├── oe                     # 本体エンジン: 1 サイクル自律オーケストレーション（envelope→spawn→capture→verify→monitor）
│   ├── oe-capture             # 既存ペインに attach して終端マーカーを capture→分類→KVS/audit
│   ├── oe-delegate            # 子 Claude セッションを起動しタスクをキック（親子委譲: spawn + kick）
│   ├── oe-kick                # #N / kickoff パスを 1 引数で受ける oe-delegate の薄いワンショットラッパー（#178）
│   ├── oe-send                # 既存ペインへ 1 行を汎用送信（%N/ラベル・--kickoff・--no-enter・送信信頼化 finalize）
│   ├── oe-list                # 委譲の宛先候補を一覧（spawn registry + pane-issue）
│   ├── oe-report              # 親へ申し送り/レビュー依頼（legacy・戻しは oe-send に一本化）
│   └── oe-status              # cockpit 観測UI: read-only 俯瞰（ENGINE=audit-terminal state / DELEGATE=liveness）+ 監査ログ閲覧（#177）
├── lib/                       # Bash 関数ライブラリ（source 専用）
│   ├── constants.sh           # OE_POLL_INTERVAL, OE_CB_*, OE_DATA_DIR, OE_TARGET_AI_*, OE_VERIFY_AI_* 等
│   ├── envelope.sh            # JSON エンベロープ生成
│   ├── spawn.sh               # wez pane split + send + CLI ディスパッチャ（cursor-agent / claude / codex）
│   ├── capture.sh             # マーカー検出・6 値分類・KVS 書き込み（target pane 監視）
│   ├── verify.sh              # 検証ゲート v1（reviewer spawn + file redirect 経路 scan + KVS 書き込み）
│   ├── monitor.sh             # ポーリングループ + サーキットブレーカー
│   ├── audit.sh               # JSONL 監査ログ追記
│   ├── cleanup.sh             # trap EXIT 用ペイン kill + tmp 削除 + wez notify
│   ├── attach.sh              # 既存ペインに attach して capture→分類→audit/KVS（oe-capture が使用）
│   ├── session.sh             # セッション ID 生成
│   ├── delegate-registry.sh   # 親子委譲の宛先アドレッシング（spawn registry + pane-issue の union 解決）
│   └── delegate-send.sh       # 1 行 safe-send（改行 fail-fast）+ 観測ベース finalize（Enter 吸収の回復・#144）
├── schemas/                   # JSON Schema 5 件（envelope / audit-log / session-state / exit-code-mapping / failure-taxonomy）
├── tests/                     # mock テスト suite（delegate registry / send 等の単体を含む）
│   └── e2e_real_agent/        # 実 agent (cursor-agent + claude) で 1 サイクル E2E 検証（Step 4-4 で新設）
├── scripts/
│   ├── validate-envelope.sh   # エンベロープ JSON 検証
│   └── validate-session-state.sh  # KVS 状態 JSON 検証（verification map 含む）
├── audit/                     # 監査ログ JSONL 出力先（runtime）
├── state/                     # セッション状態 KVS 出力先（runtime。委譲レジストリは ~/.claude/state/ 配下）
└── docs/
    ├── discussions/           # 探索・ブレスト・調査メモ
    ├── plans/                 # KickOff / Plan（実行可能粒度）
    ├── episodes/              # 実行記録・作業ログ
    └── decisions/             # ADR / 意思決定の蒸留
```

docs 配置は [`projects/wezterm-ai-mode/docs/`](../wezterm-ai-mode/docs/) の構造を踏襲し、`spec-card` スキルの蒸留パイプライン（Discussion → KickOff → Plan → Episode → Decision/ADR）に準拠する。

## 2 系統: 本体エンジン と 親子委譲 CLI

本プロジェクトには目的の異なる 2 系統がある。

| 系統 | 入口 | 性質 |
|------|------|------|
| **本体エンジン** | `bin/oe` | 非対話・wez + `claude -p` の自律オーケストレーションループ（Phase 4 MVP）。envelope→spawn→capture→verify→monitor を1サイクル回す |
| **親子委譲 CLI（delegate-task 系）** | `bin/oe-delegate` / `bin/oe-send` / `bin/oe-list` | 対話セッション間の軽量な委譲プリミティブ。tmux `send-keys` の1行注入で、統括スレッド（親）→ 子 Claude N 個のスター型委譲を行う |

### 親子委譲 CLI（delegate-task 系）

統括スレッドから子セッションへタスク・事前情報を渡す痛点（コピペ・誤送信）を解消する単機能コマンド群。自然言語層の `delegate-task` スキルから駆動する。

- `oe-delegate` — 子を `tmux split-window` で起動し、タスク（または `--kickoff <doc>`）をキック（spawn + send の合成）
- `oe-kick` — `oe-delegate` の薄いワンショットラッパー。`#N` or kickoff パスを 1 引数で受け妥当なフラグ列へ展開（`--label` 自動付与・workspace 既定化）（[#178](https://github.com/stlwolf/ai-development-hub/issues/178)）
- `oe-send` — 既存ペインへ 1 行を汎用送信。親→子の追送、子→親の戻し（`oe-send "$PARENT_TMUX_PANE" ...`）、関連の薄い側道会話を一手に担う。`%N`/ラベル解決・`--kickoff`・`--no-enter`（投入のみ＝ステージ）
- `oe-list` — 宛先候補を source 列付きで一覧
- `oe-report` — legacy（戻しは `oe-send` に一本化済み）

設計上のポイント:

- **疎結合**: `oe-delegate` は spawn + kick に純化し report を内包しない（戻しは汎用 `oe-send`）。「ワンラリーに焼き付けると Claude 組み込み subagent の劣化版になる」ため
- **アドレッシング**: 親所有 spawn レジストリ（`~/.claude/state/oe-delegate/`）と `wt switch` 由来の pane-issue（`~/.claude/state/pane-issue/`）を **union 解決**。`#N` はトークン境界の完全一致（`#14`≠`#142`）、spawn は親スコープで誤着弾を防止
- **1 行保証**: `lib/delegate-send.sh` が改行（LF/CR）を含む payload を fail-fast で拒否（プロンプト途中送信の根本封じ）
- **送信信頼化**: 自動 Enter が間欠的に「吸収」され submit されない問題に対し、送信後に観測ベースの finalize（入力欄に staged のまま残る吸収を settle 窓終端まで観測し Enter を1回だけ再送）。受け手依存ゆえ best-effort・保守的で、transport の rc は変えない。`OE_SEND_FINALIZE=0` で無効化可（[#144](https://github.com/stlwolf/ai-development-hub/issues/144)）

経緯: [PR #143](https://github.com/stlwolf/ai-development-hub/pull/143)（再設計）/ `docs/episodes/2026-06-08-episode-oe-delegate-redesign.md`、送信信頼化は [#144](https://github.com/stlwolf/ai-development-hub/issues/144) / `docs/episodes/2026-06-09-episode-oe-send-finalize-ingestion.md`。各スクリプトの引数は `bin/README.md` 参照。

## cockpit 本線（WezTerm + tmux を第一級の作業面とする）

オーケストレーション・委譲・一覧・通知・人間介入の主戦場は **WezTerm 画面 + tmux**（CLI cockpit）に置く。Cursor は閲覧・軽い編集・補助であり、必須の司令塔ではない（[#169](https://github.com/stlwolf/ai-development-hub/issues/169) で方針確定）。

| レイヤ | 配置 | 役割 |
|--------|------|------|
| 閲覧・軽編集 | Cursor（任意・補助） | コード閲覧・局所編集 |
| 認知 cockpit | WezTerm 画面 + tmux | 盤面の俯瞰・TTY 直接介入・人間の追送 |
| 機械オーケストレ | `bin/oe` + `wez` + `claude -p` / `cursor-agent -p` | 非対話の自律 1 サイクル |
| 正本・ルール | `canonical/` + sync | ハーネス配備 |

cockpit 本線を構成する運用コマンド:

- `oe-delegate` / `oe-send` / `oe-list` — 対話セッション間の人間介入・追送・宛先解決（tmux `send-keys` 経路）
- `oe-capture` — 既存ペインの終端マーカー回収（観測）
- `wez`（`pane` / `notify` / `discover`）— 物理ペイン操作・通知・ソケット検出

理由: エージェント作業を IDE の内側に閉じない可搬な「橋」はターミナル層（[#21](https://github.com/stlwolf/ai-development-hub/issues/21)）。Cursor のリッチ表示（一覧・ナビ・履歴）は合成 UI であり、fzf / peco / 自作 list として tmux 側へ移管できる。

> 注: 「Cursor から `wez` を叩く」前提の旧文言が残る箇所は、本方針（primary cockpit = WezTerm + tmux、Cursor は補助）で上書きされる。

## 観測層と駆動層の分離

本プロジェクトは **観測層** と **駆動層** を明示的に分離した運用を行う。これは MVP 完成前のドッグフード検証でもある（orchestration-engine が解決したい問題そのもの = 「スレッド/セッション間のコンテキスト引き継ぎを構造化ドキュメントで実現」）。

| 層 | 配置 | 役割 |
|----|------|------|
| **観測層** | GitHub Issue / コメント / PR | MVP **外** からのプロジェクト進捗の俯瞰、人間のスプリント管理、外部ステークホルダーへの可視化 |
| **駆動層** | `docs/{discussions,plans,episodes,decisions}/` | エージェントが読み書きするコンテキスト引き継ぎ装置。開発サイクル自体はここで完結 |

### 運用ルール

- **開発サイクルは駆動層で完結**: KickOff → Plan → Episode → ADR の蒸留パイプラインで進める
- **Issue / コメントは観測用ハイライト**: スプリント運用に必要な情報を残すが、エージェントが Issue を読まないと進められない状態にはしない
- **エージェントの初期入力は driving layer のみで完結すべき**: 「`#19` の本文 + 本 README + 該当 KickOff / Plan」だけで Step を進められる状態を維持
- **観測層→駆動層への翻訳が必要なら ADR / Episode 化**: Issue コメントで重要な意思決定が発生したら ADR に蒸留して駆動層に持ち込む

### Dogfood 視点

orchestration-engine の MVP は「閉セッション間のリアルタイム双方向通信」を扱う（[Discussion §4](./docs/discussions/2026-05-13-discussion-engine-scope-and-goals.md)）。スレッド / Cursor チャットセッションも閉セッションの一種であり、driving layer のドキュメントだけで次セッションへ引き継ぎできるかが、本 MVP の有効性検証になる。

検証成功条件: 新規スレッドが本 README + 該当 Discussion / KickOff / Plan を読むだけで、人間が前スレッドの会話履歴を伝えなくても Step を進められること。

## 状態

**Phase 4 MVP 完了 (2026-05)**。target = cursor-agent (composer-2) + reviewer = claude (sonnet-4-6) で実機 1 サイクル E2E 完走実証済み (Step 4-4)、architecture-sketch.md frozen 化済み (Step 4-5)、Epic [#19](https://github.com/stlwolf/ai-development-hub/issues/19) close。

| Step | 内容 | 状態 |
|------|------|------|
| 4-0 | PJ 立ち上げ + Discussion 作成（スコープ・ゴール・docs 配置確定） | ✅ 完了（[#81](https://github.com/stlwolf/ai-development-hub/issues/81)） |
| 4-1 | エンベロープ + ディスパッチャの骨格 | ✅ 完了（[#84](https://github.com/stlwolf/ai-development-hub/issues/84) / [PR #85](https://github.com/stlwolf/ai-development-hub/pull/85) / [PR #86](https://github.com/stlwolf/ai-development-hub/pull/86)） |
| 4-2 | 成果物パース + 状態管理 | ✅ 完了（[#87](https://github.com/stlwolf/ai-development-hub/issues/87) / [PR #88](https://github.com/stlwolf/ai-development-hub/pull/88)） |
| 4-3 | 検証ゲート v1（adversarial review 相当） | ✅ 完了（[#89](https://github.com/stlwolf/ai-development-hub/issues/89) / [PR #94](https://github.com/stlwolf/ai-development-hub/pull/94)） |
| 4-4 | E2E 検証（実 agent で 1 サイクル完走） | ✅ 完了（[#95](https://github.com/stlwolf/ai-development-hub/issues/95) / [PR #97](https://github.com/stlwolf/ai-development-hub/pull/97)） |
| 4-5 | フィードバック → architecture-sketch.md 更新 + frozen 化 | ✅ 完了（[#103](https://github.com/stlwolf/ai-development-hub/issues/103) / [PR #104](https://github.com/stlwolf/ai-development-hub/pull/104)） |

### Phase 4 後の追加（post-MVP）

MVP（`bin/oe` 本体）完了後、運用ドッグフードから派生した拡張（上記「親子委譲 CLI」系統）:

- `oe-capture` — 既存ペインの終端マーカー capture（[#109](https://github.com/stlwolf/ai-development-hub/issues/109)）
- 親子委譲 CLI（`oe-delegate` / `oe-send` / `oe-list`）— [#138](https://github.com/stlwolf/ai-development-hub/issues/138) 設計 → [PR #143](https://github.com/stlwolf/ai-development-hub/pull/143) 再設計（疎結合化・アドレッシング）→ [#144](https://github.com/stlwolf/ai-development-hub/issues/144) 送信信頼化（観測ベース finalize）

### Phase 4 完了報告と Phase 5 方向感

- **Phase 4 完了報告**: [`projects/orchestration-research/synthesis/architecture-sketch.md`](../orchestration-research/synthesis/architecture-sketch.md) §11 (Step 4-5 で追記、frozen)
- **Phase 5 方向感メモ** (Phase 5 着手時の入力資料): [`docs/plans/2026-05-18-kickoff-phase-5-direction.md`](./docs/plans/2026-05-18-kickoff-phase-5-direction.md) (`status: draft`)
- **設計判断の正本**: [`docs/decisions/`](./docs/decisions/) 配下の ADR 5 件
- **Step 別経緯**: [`docs/episodes/`](./docs/episodes/) 配下の Episode 17 件

## 関連

- Parent Epic: [#19](https://github.com/stlwolf/ai-development-hub/issues/19) 自前オーケストレーションツール MVP (Phase 4 完了で close)
- 並列トラック: [#20](https://github.com/stlwolf/ai-development-hub/issues/20) wez CLI / [#37](https://github.com/stlwolf/ai-development-hub/issues/37) Harness / [#24](https://github.com/stlwolf/ai-development-hub/issues/24) フック拡充 / [#62](https://github.com/stlwolf/ai-development-hub/issues/62) Negative Knowledge
- サブ論点: [#77](https://github.com/stlwolf/ai-development-hub/issues/77) ゼロベース探索 / [#78](https://github.com/stlwolf/ai-development-hub/issues/78) コードパス網羅

### 派生 Issue (MVP 後拡張候補、Phase 5 で本質性仕分け)

| Issue | 内容 |
|---|---|
| [#92](https://github.com/stlwolf/ai-development-hub/issues/92) | 検証ゲート v2 検討候補: 変更ファイル検出 per-pane 化 + 完了報告内容の充実 |
| [#93](https://github.com/stlwolf/ai-development-hub/issues/93) | reviewer 一時ファイル掃除 (前半完了) + nonce marker (後半 = MVP 後拡張) |
| [#98](https://github.com/stlwolf/ai-development-hub/issues/98) | target ペイン出力を file redirect 経路に統一 |
| [#99](https://github.com/stlwolf/ai-development-hub/issues/99) | bin/oe --task-file の異常系 (空 / 不在 / 不正パス) の仕様明示 |
| [#100](https://github.com/stlwolf/ai-development-hub/issues/100) | _oe_verify_scan_log_file の単体テスト追加 |
| [#101](https://github.com/stlwolf/ai-development-hub/issues/101) | reviewer marker の false-positive 抑制 |
| [#102](https://github.com/stlwolf/ai-development-hub/issues/102) | _oe_strip_ansi 共通関数化 |
