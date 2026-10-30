# モデル / effort ルーティングと週次枠の配分 — 調査メモ

- 作成: 2026-10-30
- 更新: 2026-10-30（§11 の静的解析結果を実行して確認し、該当節と §12 に追記）
- 状態: 調査中（追記前提）
- 対象: `stlwolf/ai-development-hub` の orchestration-engine（統括 / 子の起動）と statusLine heartbeat
- 根拠ラベル: `[verified]` 一次情報（公式 doc / リポジトリ実体）で確認 / `[unverified-summary]` 二次情報・第三者記事 / `[speculation]` 根拠なし・推測
  - `[verified-binary]`（§11）: バイナリの静的解析で実装の存在を確認
  - `[verified-local]`（§11 追記・§12）: 実際に実行して確認。実行環境はユーザーのローカル Mac ではなく claude.ai のクラウドコンテナ（§12.1）

## 1. 目的

- 週次枠（7d）と 5h 枠を、リセットまでに超過せず可能な限り使い切る（量）
- 同時に、タスクごとに過不足ない性能（モデル × effort）を割り当てる（配分）
- 「全部低くして数を増やす」「全部高くしてすぐ終わらす」はどちらも量しか満たさない。両方を満たすことが理想

## 2. Claude Code の effort 解決順序と制約

- 優先順位 `[verified]`（model-config doc）
  1. `CLAUDE_CODE_EFFORT_LEVEL` / `--effort` / セッション中の `/effort`
  2. 設定（`modelSettings.<model>.effortLevel`, `effortLevel`）
  3. モデルのデフォルト
- `CLAUDE_CODE_EFFORT_LEVEL` を export すると `--effort` も frontmatter も黙って上書きされる `[unverified-summary]`（wmedia tip #149, DEV 記事）
  - 子ごとに effort を変えるなら export しない。harness-check / hook で検知する価値あり
  - `[verified-local]` コマンド単位で `CLAUDE_CODE_EFFORT_LEVEL=low` を付けると、`--effort medium` とスキル frontmatter の `effort: high` の両方より優先された（§11.3 の B7）
- `effortLevel: "max"` は settings では無視（max はセッション限定）`[unverified-summary]`
- スキル / サブエージェントの `effort:` frontmatter はそのスキル・エージェント実行中のみ有効 `[verified]`
  - 過去に Agent tool 経由で frontmatter `effort:` が無視される issue あり（#64706, 2026-06）`[unverified-summary]`。使用中バージョンで効いているか要確認
    - `[verified-local]` v2.1.314 では再現しない。サブエージェントは frontmatter どおりの `effort: low` / `model: sonnet` で動いた（§11.3 の B5）
  - スキル内で `${CLAUDE_EFFORT}` が使える `[unverified-summary]` → 確認行を入れて実効値を見る
    - `[verified-local]` 展開される。値はそのスキルに適用された effort（§11.3 の B1・B2）
  - `[verified-local]` スキル終了後の次のターンは `--effort` の値に戻った（§11.3 の B6）
- モデルごとの effort 保存（`modelSettings`）は v2.1.251 以降 `[unverified-summary]`
  - `[verified-local]` 対話モードの `/effort high` は `modelSettings.<モデル ID>.effortLevel` に保存され、「新しいセッションの既定」になる（§11.1 のローカル検証 C）
- 上限は `maxEffortLevel` / 組織の上限がすべてに優先 `[verified]`
- モデル（親）は `/effort` `/model` を自分で打てない（組み込み CLI コマンドはスキル扱いされない）`[verified]`（Skill tool 仕様）
- `ultrathink` はそのターンだけ深く考えさせるキーワード `[verified]`

## 3. effort の公式定義（API）

- effort は厳密なトークン予算ではなく行動シグナル。thinking・本文・ツール呼び出しと引数を含む全出力トークンに作用 `[verified]`（platform effort doc）
- 各レベル `[verified]`

| レベル | 公式の説明 | 想定用途 |
|---|---|---|
| `low` | 最も効率的。能力は一部低下 | サブエージェント等の単純タスク |
| `medium` | 速度・コスト・性能のバランス | 一般的なエージェント作業 |
| `high` | 良い結果に必要なだけ使う | 複雑な推論・難しいコーディング |
| `xhigh` | 30分超・数百万トークン規模の長時間タスク向け | 長時間自律コーディング |
| `max` | 消費制約なし。能力の上限 | 最も深い推論 |

- 低いほど: ツール呼び出しをまとめて減らす / 前置きなしで着手 / 完了報告が短い。高いほど: 呼び出し増 / 計画を説明 / 変更を詳しく要約 `[verified]`
- デフォルト: Opus 5.5・Haiku 5.5 は `medium`、Fable 5.1 は `high` `[verified]`
- 公式推奨の要点 `[verified]`
  - Sonnet 5.5: well-specified なエージェント作業は `medium`、難しい長時間タスクは `high`
  - Opus 4.7: 複雑な問題で推論が浅いならプロンプトより effort を上げる
- 会話途中の effort 変更（per-message effort, beta）: ヘッダー `mid-conversation-output-config-2026-07-01`、`role: "system"` の空メッセージに `output_config.effort`。プロンプトキャッシュを維持できる。対応: Fable 5.1 / Mythos 5.1 / Opus 5.5 / Opus 5 / Sonnet 5.5 / Haiku 5.5 `[verified]`
  - Claude Code で使えるかは未確認 `[speculation]`
    - `[verified-local]` Claude Code は内部で使っている。Haiku / Sonnet / Opus 5.5 で `per_turn_effort_active: true`、effort を途中で変えてもキャッシュが読まれた（§11.4 のローカル検証 D）

## 4. effort 別の実測（第三者）

- Opus 5.5 / 長時間 `/goal` 1本 `[unverified-summary]`（openclawdatabase, n=1）
  - low $3.91・16分（動くが粗い）/ medium $12.44 / high $16.31 / xhigh $25.92（最良）/ max $50.38（劣化）
- SlopCodeBench（Opus 5.5）`[unverified-summary]`
  - 厳密合格: medium 28 > xhigh 25。xhigh はコードが約5倍クリーン、コスト 2.1〜4.2倍
- 読み取り `[speculation]`: effort を上げても合格率は単調に上がらない。変わるのは網羅性・仕上がり・確認の丁寧さ。`max` は割に合わないことが多い

## 5. 公式の自動切り替え機能（予算連動のものはない）

- `opusplan`: plan mode は Opus、実行は Sonnet。公式唯一のフェーズ単位ルーティング `[verified]`
- フォールバック連鎖（`--fallback-model`, 最大3）: 過負荷・サーバーエラー時のみ。レート制限・課金では切り替わらない。そのターンのみ `[verified]`
- 安全分類器フォールバック（サイバー / 生物）: コスト無関係 `[verified]`
- Adaptive thinking: 5.5 世代・Fable は常時有効。effort の範囲内でステップごとに思考量をモデルが決める（ターン内調整は自作不要）`[verified]`
- Fable の usage credits: プランにより別課金。対話は同意プロンプト、`-p` は確認なしで課金 `[verified]`
- 予算（rate_limits）を見てモデル / effort を変える公式機能は見当たらない `[verified]`（doc 範囲内）
- 公式の方向性: 部品（`rate_limits` 公開, `modelSettings`, `maxEffortLevel`, サブエージェント model 指定）を渡してユーザー側で組ませる形に見える `[speculation]`

## 6. OSS ルーターとの違い

- claude-code-router 等は通信層のプロキシ。リクエスト単位で送り先モデルを差し替え、API 料金削減が主目的。サブスク枠は扱わない `[unverified-summary]`
- 本件はオーケストレーション層。タスク / フェーズ単位で起動時の `--model` / `--effort` を決め、週次枠を配分する。競合せず、組み合わせるなら OSS が下の層

## 7. リポジトリ現状（`[verified]` リポジトリ実体, HEAD f25ebd3）

- `projects/orchestration-engine/lib/spawn.sh`
  - claude 起動: `claude -p '<prompt>' --model <model> --add-dir ... --output-format text --no-session-persistence --max-budget-usd 1.0`
  - `ai_cli` / `ai_model` を引数で受ける。未指定時は `OE_TARGET_AI_CLI` / `OE_TARGET_AI_MODEL`、既定 `cursor-agent` / `composer-2`
  - effort 引数なし
  - `--no-session-persistence` のため `--resume` によるモデル切り替え継続は不可。区切りごとに envelope で文脈を渡しモデルを選び直す形
- `canonical/claude/statusline/statusline-oe-heartbeat.sh`
  - 表示: `rate_limits.seven_day.used_percentage`（常時）、`five_hour`（閾値 80% 以上で残り時間付き）
  - sidecar `<session_id>.json` に書くのは `ts, context_pct, pane, server_pid, model{id,display_name}` のみ。`rate_limits` は保存していない
  - `rate_limits` はサブスク認証かつ初回 API 応答後のみ載る
- `canonical/skills/*/SKILL.md`: `effort:` / `model:` frontmatter を持つスキルなし。settings 側にも `effortLevel` 指定なし
- 統括の計画的引き継ぎ（#390 handoff / retire）が既存
- 過去に「claude の上限を statusLine の `rate_limits` から先行検知」は HG-D で起票見送り（plan-303）

## 8. 設計方針（議論で合意した方向）

### 8.1 配分の考え方

- 各タスクで `効果 − λ × 消費枠` が最大の設定（モデル × effort）を選ぶ。λ（枠1%の値段）だけを予算状況で動かす
  - 余りそう → λ を下げる → 上の設定で効果が伸びるタスクから格上げ
  - 足りなそう → λ を上げる → 上げても効果が伸びないタスクから格下げ
- タスクごとの下限（性能の床）は予算と無関係に維持（下げるとやり直しで高くつく）
- λ は制御ループで調整。超過と余りは損失が非対称なので目標は 95% 前後、リセットに近づくほど 100% に寄せる
- 5h 枠は別制約。Fable は別枠なので λ を別に持つ
- 格上げと「バックログから次タスク投入」を同じ基準で比較（リセット前の使い切りもこの一部）

### 8.2 着地見込み

```text
経過率      t = 1 - (resets_at - now) / 7日
消費ペース  = 直近N時間の 7d% 増分 / N時間
着地見込み  = used% + 消費ペース × 残り時間
```

- 〜80% 未満: 格上げ / 80〜100%: 維持 / 100% 超: 格下げ（境界にヒステリシス）

### 8.3 タスク難易度の尺度（モデル非依存）

- 尺度はタスク側の性質に置き、モデル世代ごとに「どの設定がどこで崩れるか」の線だけ引き直す

| 軸 | 低コストで足りる | 上位との差が出る |
|---|---|---|
| 仕様が閉じているか | 確定している | 曖昧・判断が要る |
| 検証できるか | テスト / 終了コードで自動判定 | 機械判定できない |
| 手順の長さ | 短く独立 | 長く前の判断に依存 |
| 同時に見る範囲 | 1ファイル・1資料 | 複数情報源の整合 |
| 新規性 | 既知パターン | 前例なし・ニッチ |
| 見逃し時の損害 | すぐ戻せる | 後工程に波及 |

- 分類ごとの目安 `[speculation]`

| 分類 | 目安 |
|---|---|
| ゼロベース探索 | 最上位。上げるのは effort よりモデル |
| 設計 | high |
| デバッグ・不具合調査 | high。モデル間差が最も出やすい |
| 調査 | medium〜high（単純収集は low） |
| 実装 | 仕様確定 + テストありなら medium から格上げ / 曖昧なら high |
| 文書作成 | low〜medium（decision / discussion など判断を伴うものは medium〜high） |

- 「検証できるか」が最重要: 検証可能なら低で始めて落ちたら格上げ、不可能なら最初から上に投資
- 失敗原因で上げる軸を選ぶ `[speculation]`
  - 発想不足・方向違い → モデルを上げる
  - 確認漏れ・網羅不足 → effort を上げる
  - 格上げごとに失敗の種類を記録 → 失敗分類表になる

### 8.4 統括（親）

- 統括は Fable で起動する方針
  - 「Fable の方が総消費が増えない」感覚の説明候補: 能力が高くターン数・ツール呼び出し・やり直しが減る `[speculation]`
  - 比較条件の注意: 既定は Fable `high` 対 Opus 5.5 `medium` `[verified]`
- 降格は #390 の計画的引き継ぎに「Fable 消費ペースが目標線超過」の条件を足して Opus 統括へ引き継ぐ
- 軽い対処: 重い作業を Opus の子へ出して Fable 消費を抑える
- フェーズ固定の effort はスキル frontmatter で表現できるが、frontmatter は `--effort` / ルーターより優先されるため、予算に関係なく落とせない実装系スキルだけに固定値を書く

### 8.5 子

- `spawn.sh` に `ai_effort` を追加し、claude は `--effort` を付与（cursor-agent / codex は `case` 内で吸収）
- 前段に「タスク種別 → `(ai_cli, ai_model, ai_effort)`」を返す関数。最初はルールベース
- 明示引数は最優先のまま
- 子を Fable で `-p` 起動する場合は usage credits の無確認課金に備えて明示許可フラグを設ける

### 8.6 記録

- sidecar に `rate_limits` の 7d / 5h の `used_percentage` / `resets_at` を追加
- 同時に JSONL 時系列へ追記（`ts, session_id, model.id, context_pct, d7, d5, r7`）。リセット時刻ごとにファイル分割
- 7d% はアカウント全体の値。並行セッションがあると増分をセッション / モデルに帰属できない → セッション単位のトークン / コスト値が必要
- タスク単位の記録: タスク種別・選んだ設定・消費・検証結果・格上げ有無・失敗の種類・人の評価（「下で足りた / 上が必要だった」の二択）
- 較正: 分類ごとに 2〜3 本の代表タスクを固定し、新モデル登場時のみ `arena-compare` / `so-compare` でモデル × effort を一巡

## 9. 進め方（案）

1. statusLine の生 JSON を 1 回書き出してフィールドを確認

    ```bash
    printf '%s' "$input" > ~/.claude/state/statusline-raw.json
    ```

2. sidecar に rate_limits 追加 + JSONL 時系列（`test_oe_heartbeat_producer.sh` にテスト追加）
3. statusLine に着地見込みと推奨 effort を表示（人間判断の補助）
4. `spawn.sh` に `ai_effort` とルーター関数
5. 統括の Fable 降格条件を #390 引き継ぎに追加
6. リセット前の使い切りタスク

## 10. 未確認事項（調査で埋める）

- [x] statusLine 入力 JSON の `rate_limits` に Fable 別枠のフィールドがあるか → **ない**。Fable は `get_usage` の `model_scoped` にある（§11.1）
  - `[verified-local]` 実データでも `five_hour` / `seven_day` の 2 つだけ（§11.1 のローカル検証 C）
- [x] statusLine 入力にセッション単位のトークン数 / コストのフィールドがあるか → `cost.total_cost_usd` 等はある。トークン内訳は要実データ確認（§11.1）
  - `[verified-local]` トークン内訳もある。`context_window.total_input_tokens` / `total_output_tokens` と、cache 内訳付きの `context_window.current_usage`（§11.1 のローカル検証 C）
- [ ] Fable の枠の仕組み（別枠の週次上限か usage credits か）が自分のプランでどうなっているか → `get_usage` をローカルで叩けば `model_scoped` / `extra_usage` で判明（§11.2）
  - `[verified-local]` このコンテナでは判明せず。OAuth トークンに profile スコープがなく、`get_usage` の `rate_limits` が null。通常ログインしたマシンでの実行待ち（§12.3・§12.4）
- [x] `claude -p`（非対話）実行時に `rate_limits` を取得する手段があるか → stream-json の control request `get_usage` で取れる見込み（§11.2）。実動はローカル確認
  - `[verified-local]` 2 経路ある。`get_usage` は profile スコープ付きのトークンが必要。stream-json 出力の `rate_limit_event` なら profile スコープなしでも 5h / 7d が取れる（§11.2 のローカル検証 A）
- [x] 使用中バージョンでスキル / サブエージェント frontmatter の `effort:` が実際に効くか（`${CLAUDE_EFFORT}` で確認）→ キーはスキーマに存在（§11.3）、実効はローカル確認
  - `[verified-local]` 効く。スラッシュ起動・Skill ツール・Agent ツールの 3 経路すべて（§11.3 のローカル検証 B）
- [x] スキル frontmatter で `model:` が指定できるか → **できる**（§11.3）
  - `[verified-local]` 指定したモデルで実際に応答した（§11.3 の B3）
- [ ] `--resume` と `--model` の併用で別モデル継続できるか（現状 `--no-session-persistence` のため優先度低）
- [x] effort 変更でプロンプトキャッシュが無効化されるか → per-turn effort が有効なモデルでは**維持**、無効時は再構築（§11.4）
  - `[verified-local]` 実測でも維持。Haiku で effort を low → high に変えたターンの cache_creation は 73 トークン（§11.4 のローカル検証 D）
- [x] per-message effort（beta）が Claude Code から使えるか → Claude Code 自身が per-turn effort として内部で使用（§11.4）
  - `[verified-local]` Haiku / Sonnet / Opus 5.5 で `per_turn_effort_active: true`
- [ ] Fable の `per_turn_effort_active` → Fable の `-p` 実行は事前確認が必要なため未実施（§12.3）
- [ ] モデル切り替え時のキャッシュ無効化コストの実測
- [ ] effort 別・モデル別の性能差の追加データ（第三者 n=1 以外）
- [ ] Fable high 対 Opus medium / high の総消費比較（自データで検証）
- [ ] リセット前の使い切りタスクで、停止条件をどこから読むか
- [ ] `--max-budget-usd` がサブスク利用時にどう扱われるか（API 金額上限のみか）

## 11. 追記: Claude Code バイナリの静的解析（2026-10-30）

- 方法: クラウド作業環境に npm で `@anthropic-ai/claude-code@2.1.314` を入れ、未ログインのまま埋め込み JS の文字列（zod スキーマと describe 文）を grep。実データ（自分の使用率）は取れない
- ラベル `[verified-binary]`: v2.1.314 の実装にスキーマ / 処理が存在することを確認。`@internal` 記載のものは仕様変更があり得る。実動はローカル確認が必要
- 各節末尾の「ローカル検証」は、同じ v2.1.314 を実行して確かめた結果（実行環境と注意点は §12.1）

### 11.1 statusLine 入力 JSON

- `rate_limits` に入るのは `five_hour` / `seven_day`（各 `used_percentage`, `resets_at`）のみ。gateway 認証時だけ `spend_limit` が加わる `[verified-binary]`
  - Fable 別枠・`seven_day_opus` / `seven_day_sonnet` は statusLine には**出ない**
- 他に statusLine 入力にあるもの `[verified-binary]`
  - `cost.total_cost_usd` / `total_duration_ms` / `total_api_duration_ms` / `total_lines_added` / `total_lines_removed`
  - `effort.level`（effort 対応モデル時）、`thinking.enabled`
  - `context_window`、`exceeds_200k_tokens`、`fast_mode`、`agent.name`、`worktree`
  - `prompt_cache.warm` / `expires_at`（refresh のタイミング計算に使われている）
- statusLine の再描画トリガーに `rate_limits.*.resets_at` とキャッシュ期限が使われている `[verified-binary]`

#### ローカル検証 C `[verified-local]`

- 日時・版: 2026-10-30 16:20〜16:22 UTC、v2.1.314
- 方法: 対話モードを tmux 上で起動し、`--settings` で statusLine だけを「入力 JSON をそのまま書き出すスクリプト」に差し替えた。初回起動の画面（テーマ選択・フォルダー信頼）と `/effort` の保存先がコンテナの設定に書き込まれないよう、`CLAUDE_CONFIG_DIR` を使い捨てディレクトリに向けた（どちらもコマンド単位の指定）
- プロンプト「Reply with exactly: OK」を 1 回送り、その前後の入力 JSON を比べた

```bash
env -u CLAUDE_EFFORT CLAUDE_CONFIG_DIR="$TMP/config" \
  claude --model haiku --effort low --strict-mcp-config --settings "$TMP/settings.json"
# settings.json: {"statusLine":{"type":"command","command":"<dump.sh> <出力先>"}}
```

- 起動直後（API 呼び出し前）のキー: `session_id`, `cwd`, `workspace{current_dir, project_dir, added_dirs}`, `transcript_path`, `scratchpad_dir`, `model{id, display_name}`, `version`, `output_style{name}`, `effort{level}`, `thinking{enabled}`, `fast_mode`, `cost`, `context_window`, `exceeds_200k_tokens`
- 初回 API 応答の後に増えたキー: `rate_limits`, `prompt_cache`, `prompt_id`
- `rate_limits`: `five_hour` / `seven_day` の 2 つだけ。`used_percentage` は整数の %、`resets_at` は epoch 秒。Fable・Opus・Sonnet 別の行はない
- `cost`: `total_cost_usd`（list 価格換算）, `total_duration_ms`, `total_api_duration_ms`, `total_lines_added`, `total_lines_removed`
- `effort`: `{"level": "low"}`。対話中に `/effort high` を打つと、API を呼ばないまま次の描画で `"high"` に変わった
  - 注意: `/effort high` は「saved as your default for new sessions」と表示し、ユーザー設定の `modelSettings.claude-haiku-5-5.effortLevel` に書き込んだ（今回は使い捨ての `CLAUDE_CONFIG_DIR` 側）。statusLine を確かめるセッションで `/effort` や `/model` を打つと `~/.claude/settings.json` が変わる
- `context_window`: `total_input_tokens`, `total_output_tokens`, `context_window_size`, `current_usage{input_tokens, output_tokens, cache_creation_input_tokens, cache_read_input_tokens}`, `used_percentage`, `remaining_percentage`
- `prompt_cache`: `warm`, `caching_observed`, `ttl`（`"1h"`）, `expires_at`, `requests`, `misses`, `expected_rebuilds`, `hit_ratio`, `cache_write_tokens`, `miss_recache_tokens`, `last_miss_at`, `last_miss_cause`, `miss_causes`, `recache_tokens_if_cold`（静的解析で挙げた 2 つより多い）
- 出なかったもの: `agent`, `worktree`, `spend_limit`（それぞれ `--agent`・worktree・gateway 認証の時だけと見られる。今回はどれも該当しない）
- 初回 API 応答の後の入力（抜粋。パスと ID は省略）

```json
{
  "effort": { "level": "low" },
  "model": { "id": "claude-haiku-5-5", "display_name": "Haiku 5.5" },
  "cost": {
    "total_cost_usd": 0.008413,
    "total_duration_ms": 45295,
    "total_api_duration_ms": 1495,
    "total_lines_added": 0,
    "total_lines_removed": 0
  },
  "context_window": {
    "total_input_tokens": 42056,
    "total_output_tokens": 4,
    "context_window_size": 1000000,
    "current_usage": {
      "input_tokens": 2,
      "output_tokens": 4,
      "cache_creation_input_tokens": 42054,
      "cache_read_input_tokens": 0
    },
    "used_percentage": 4,
    "remaining_percentage": 96
  },
  "rate_limits": {
    "five_hour": { "used_percentage": 10, "resets_at": 1793388000 },
    "seven_day": { "used_percentage": 15, "resets_at": 1793761200 }
  }
}
```

- `resets_at` の換算: 5h は 2026-10-30T19:20:00Z、7d は 2026-11-04T03:00:00Z
- profile スコープのないトークン（§12.1）でも `rate_limits` は出た。値は API 応答のヘッダーから作られるため（§11.2 のローカル検証 A）

### 11.2 `get_usage` control request（Fable 別枠の取得経路）

- stream-json の control request `subtype: "get_usage"`（`skip_behaviors: true` で transcript 走査を省略。「使用量メーター用途向け」と記載）`[verified-binary]`
- 応答の `rate_limits` に含まれるもの `[verified-binary]`
  - `five_hour` / `seven_day` / `seven_day_opus` / `seven_day_sonnet` / `seven_day_oauth_apps`
  - `model_scoped[]`: `{display_name（例 'Fable'）, utilization, resets_at}` — **モデル別の週次枠**
  - `extra_usage`: `{is_enabled, monthly_limit, used_credits, utilization, currency}` — usage credits
  - `subscription_type`、`rate_limits_available`
  - `session.total_cost_usd` / `session.model_usage`（モデル別のセッション消費）
- `/usage` 画面の「Current week (Fable)」はこの `model_scoped` から描画されている `[verified-binary]`
- 呼べない文脈では `get_usage is not supported in this context` が返る → `-p` + stream-json で使えるかはローカル確認
- ローカル確認用（未検証の手順）

    ```bash
    printf '%s\n' '{"type":"control_request","request_id":"u1","request":{"subtype":"get_usage","skip_behaviors":true}}' \
      | claude -p --input-format stream-json --output-format stream-json --verbose \
      | jq -c 'select(.type=="control_response")'
    ```

#### ローカル検証 A `[verified-local]`

- 日時・版: 2026-10-30 16:12:53 UTC、v2.1.314
- 上のコマンドはそのまま動いた（`--verbose` あり、initialize の先行送信は不要）。出力は `active_goal` / `autocompact_state` / `control_response`（`subtype: "success"`）の 3 行
- 応答（`behaviors` を除く）

```json
{
  "session": {
    "total_cost_usd": 0,
    "total_api_duration_ms": 0,
    "total_duration_ms": 1302,
    "total_lines_added": 0,
    "total_lines_removed": 0,
    "model_usage": {}
  },
  "subscription_type": null,
  "rate_limits_available": false,
  "rate_limits": null
}
```

- 原因: このコンテナの OAuth トークンに profile スコープがない。debug log に `[Bootstrap] Skipped: 403 for OAuth token without profile scope`。スキーマの説明文にも「API key / Bedrock / Vertex / profile スコープなしでは false。その場合 rate_limits は null」とある `[verified-binary]`
- 枠の消費: メッセージ API の呼び出しはなかった（`total_cost_usd: 0`、`model_usage` が空、`total_api_duration_ms: 0`）。プロンプトを送らない形で呼べる。使用率そのものは `/api/oauth/usage` への GET で取る実装 `[verified-binary]`
- `model_scoped` / `extra_usage` / `seven_day_opus` / `seven_day_sonnet` / `subscription_type` の実値は取れていない（§12.4 の手順でローカル実行待ち）
- 代わりに取れたもの: `-p` の stream-json 出力には、API 応答のたびに `rate_limit_event` が流れる。profile スコープがなくても出た
  - 中身は `anthropic-ratelimit-unified-*` ヘッダー由来。`unifiedWindows` に `five_hour` / `seven_day`（アカウントによっては `seven_day_overage_included`）の `utilization`（0〜1）と `resetsAt` が入る `[verified-binary]`
  - 実際の値（D の Haiku 実行時）

```json
{"status":"allowed","resetsAt":1793388000,"rateLimitType":"five_hour","overageStatus":"rejected","overageDisabledReason":"org_level_disabled","isUsingOverage":false,"unifiedWindows":{"five_hour":{"utilization":0.07,"resetsAt":1793388000,"status":"allowed"},"seven_day":{"utilization":0.15,"resetsAt":1793761200,"status":"allowed"}}}
```

- Fable の枠は週次の別枠か usage credits か: **結論は保留**
  - 分かったこと: `overageStatus: "rejected"` と `overageDisabledReason: "org_level_disabled"` から、このアカウントでは extra usage（usage credits）が組織単位で無効。CLI の debug log にも `Org fast mode: disabled (extra_usage_disabled)`
  - 推測 `[speculation]`: この状態で Fable が使えるなら、usage credits ではなくモデル別の週次枠（`model_scoped`）から引かれていると考えるのが自然
  - 決め手になる `model_scoped` の Fable 行と `extra_usage` は、profile スコープ付きのトークンで `get_usage` を呼ばないと見えない

### 11.3 frontmatter

- スキル（コマンド）frontmatter の既知キーに `model` と `effort` がある `[verified-binary]`
  - `model`: コマンドのデフォルトモデル
  - `effort`: `low` / `medium` / `high` / `max` または整数（describe 文。xhigh の記載なし）
- サブエージェント定義の `model`: エイリアス / モデル ID / `inherit`。省略時は既定サブエージェントモデル、なければ親のモデル `[verified-binary]`
- `CLAUDE_EFFORT` 文字列は存在（スキル内変数の実装）`[verified-binary]`
- 実際に効くか（過去 issue #64706）は未確認のまま

#### ローカル検証 B `[verified-local]`

- 日時・版: 2026-10-30 16:17〜16:19 UTC、v2.1.314
- 事前確認: `CLAUDE_CODE_EFFORT_LEVEL` は未設定。親のハーネスが `CLAUDE_EFFORT=xhigh` を export しており子に継承されるため、全実行に `env -u CLAUDE_EFFORT` を付けた（§12.1）
- 使い捨てディレクトリに次を置いた
  - `.claude/skills/effort-low/SKILL.md`（`effort: low`）、`.claude/skills/effort-high/SKILL.md`（`effort: high`）
  - `.claude/skills/model-sonnet/SKILL.md`（`model: sonnet`）
  - `.claude/agents/effort-probe.md`（`model: sonnet`, `effort: low`, `tools: Bash`）
- スキル本文の例（`effort-high` も同じ形）

```markdown
---
name: effort-low
description: Verification probe for the effort frontmatter (low). Use only when explicitly asked to run effort-low.
effort: low
---

Run this exact Bash command once: printenv CLAUDE_EFFORT

Then reply with exactly one line in this format and nothing else:

SKILL=effort-low TEMPLATE=${CLAUDE_EFFORT} RUNTIME=<output of the command>
```

- 判定に使った 3 点
  - TEMPLATE: 本文の `${CLAUDE_EFFORT}` が展開された値
  - RUNTIME: そのターンで `printenv CLAUDE_EFFORT` を実行した値（ハーネスが Bash に渡すターンの effort）
  - transcript の assistant 行の `effort` / `perTurnEffort` / `message.model`（`--session-id` を指定して保存先を特定）
- 実行例（B1。B2〜B7 はプロンプト・モデル・ツールを変えただけ。B6 は stream-json 入力で 2 ターン送った）

```bash
env -u CLAUDE_EFFORT claude -p "/effort-low" --model haiku --effort medium \
  --output-format stream-json --verbose --session-id "$(uuidgen)" \
  --strict-mcp-config --tools Bash --allowedTools "Bash(printenv CLAUDE_EFFORT)"
```

| # | セッションの指定 | 呼び方 | 結果 |
|---|---|---|---|
| B1 | haiku, `--effort medium` | `/effort-low` | TEMPLATE=low, RUNTIME=low, transcript `effort: low` |
| B2 | haiku, `--effort medium` | `/effort-high` | 3 点とも high |
| B3 | haiku, `--effort low` | `/model-sonnet` | 応答は `claude-sonnet-5-5`。そのターンの `system/init` の `model` も sonnet。effort は low のまま |
| B4 | haiku, `--effort medium` | モデル自身が Skill ツールで `effort-high` を呼ぶ | Skill を呼ぶまでのターンは medium、スキル読み込み後のターンは high |
| B5 | haiku, `--effort medium` | Agent ツールで `effort-probe` を呼ぶ | サブエージェントは `claude-sonnet-5-5` / low（RUNTIME=low、サブエージェント transcript も `effort: low`）。親は haiku / medium のまま |
| B6 | haiku, `--effort medium` | `/effort-high` の次に普通のターン | 次のターンは medium に戻った（RUNTIME=medium） |
| B7 | B1 と同じ + コマンド単位で `CLAUDE_CODE_EFFORT_LEVEL=low` | `/effort-high` | 3 点とも low |

- 結論
  - frontmatter の `effort:` / `model:` は、スラッシュ起動・Skill ツール・Agent ツールのいずれでも効く
  - 実測した優先順位: `CLAUDE_CODE_EFFORT_LEVEL` > スキル / サブエージェント frontmatter > `--effort`
  - issue #64706（Agent ツールが frontmatter の effort を無視）は v2.1.314 では再現しない
- 未検証: frontmatter に `effort: xhigh` を書いた場合（describe 文に xhigh がない）、スキルの `model:` が次のターンで元に戻るか（effort は戻ることを B6 で確認）

### 11.4 effort 変更とキャッシュ（per-turn effort）

- Claude Code は effort を会話内のターン単位で送る「per-turn effort」を実装（API の per-message effort beta に対応）`[verified-binary]`
  - 有効時（`system/init` の `per_turn_effort_active: true`）: effort 変更は**プロンプトキャッシュを維持**
  - 無効時: effort は top-level パラメータとして送られ、変更でキャッシュ済み prefix を書き直す
  - サーバーが拒否すると `system/per_turn_effort_changed`（false）を `-p` / SDK の出力に流し、以後 effort 変更はキャッシュ再構築（`/clear` や compaction で解除）
- 含意: 統括セッション内で effort を上下させるコストは、対応モデルなら小さい。モデル切り替えはキャッシュ別なので別扱い

#### ローカル検証 D `[verified-local]`

- 日時・版: 2026-10-30 16:15〜16:17 UTC、v2.1.314
- 各モデル 1 回ずつ、最小構成（ツールなし・MCP なし・`--effort low`）で実行し `system/init` を見た

```bash
env -u CLAUDE_EFFORT claude -p "Reply with exactly: OK" --model haiku --effort low \
  --output-format stream-json --verbose --no-session-persistence --strict-mcp-config --tools "" \
  | jq -c 'select(.type=="system" and .subtype=="init") | {model, per_turn_effort_active}'
```

| `--model` | init の `model` | `per_turn_effort_active` |
|---|---|---|
| `haiku` | `claude-haiku-5-5` | `true` |
| `sonnet` | `claude-sonnet-5-5` | `true` |
| `opus` | `claude-opus-5-5` | `true` |
| `fable` | 未実施 | 未確認（Fable の `-p` 実行は事前確認が必要なため。§12.3） |

- `system/per_turn_effort_changed` はどの実行でも出なかった（サーバーの拒否なし）
- キャッシュが本当に維持されるかの実測: Haiku で 1 セッション 3 ターン。`--settings '{"effortLevel":"low"}'` で始め、2 ターン目の後に stream-json の control request `apply_flag_settings`（`{"effortLevel":"high"}`）を送ってから 3 ターン目を送った

| ターン | effort（transcript） | cache_creation | cache_read |
|---|---|---|---|
| 1 | low | 1,407 | 2,276 |
| 2 | low（変更なし） | 979 | 2,752 |
| 3 | high（直前に変更） | 73 | 3,706 |

- effort を変えた 3 ターン目でも、前のターンまでの prefix はすべてキャッシュから読まれた。per-turn effort が有効なら effort 変更でキャッシュは壊れない
- あわせて分かったこと: settings の `effortLevel` も、`apply_flag_settings` による途中変更も効く。transcript の assistant 行には `effort` / `perTurnEffort` / `requestedModel` が残る
- Fable 5.1 について API を呼ばずに分かったこと: control request `initialize` の `models` では `supportsEffort: true`、`supportedEffortLevels` は `low` / `medium` / `high` / `xhigh` / `max`（Haiku / Sonnet / Opus 5.5 も同じ）。ただし per-turn effort が有効かは、サーバーから配信されるモデル情報の別の capability で決まる実装で、ここからは判定できない `[verified-binary]`

### 11.5 実行中セッションのモデル / effort を外から変える

- stream-json の control request に `set_model`（`model` 省略・`default` で既定に戻す）、`apply_flag_settings`（flag 設定層に任意設定をマージ）、`update_settings`（`userSettings` は `effortLevel` のみ受け付ける旨の記載）がある `[verified-binary]`
- 含意 `[speculation]`: 統括を対話 TUI ではなく stream-json で駆動すれば、オーケストレーター側からターンの合間に統括のモデル / effort を変更できる（自己降格の別解）。対話 TUI では従来どおり人間の `/model` `/effort`
  - `[verified-local]` `apply_flag_settings` で effort を変えられることは確認（§11.4 のローカル検証 D）。`set_model` は未実行

### 11.6 その他

- `--max-budget-usd` は「API 呼び出しの金額上限（`--print` 時のみ）」`[verified-binary]`（`--help`）。サブスク枠の歯止めとしての扱いは未確認のまま
- `get_session_cost`: `/usage` が非対話で出す整形テキストを返す `[verified-binary]`
- 設計への影響
  - 記録（§8.6）は statusLine sidecar（5h / 7d 全体・セッションコスト・effort）と `get_usage`（Fable 等モデル別枠・usage credits）の 2 系統にする
  - Fable 用 λ の入力は `model_scoped` の Fable 行
  - 並行セッションの帰属問題は `session.model_usage` / `cost.total_cost_usd` で緩和できる見込み

## 12. ローカル検証結果（2026-10-30）

### 12.1 実行環境と前提

- 実行場所: claude.ai のクラウドセッション（Claude Code on the web のコンテナ）。ユーザーのローカル Mac ではない
  - Remote Control でユーザーのコンピューターにつなげるか確認したが、使えるフォルダーが登録されていなかった
- CLI: `/opt/claude-code/bin/claude`、`claude --version` は `2.1.314 (Claude Code)`。§11 の静的解析と同じ版なので、版の違いによる差はない
- 認証: `claude auth status` は `loggedIn: true`, `authMethod: "oauth_token"`, `apiProvider: "firstParty"`
  - トークンはホストが置いたファイルから読まれ、推論専用（debug log: `OAuth token without profile scope`、`inference token lacks user:mcp_servers scope`）
  - そのため CLI はサブスクを認識しない。control request `initialize` の `account.subscriptionType` は `"Claude API"`、対話画面の表示も「Claude API」
  - 一方で API 応答の `anthropic-ratelimit-unified-*` ヘッダーは載る。`rate_limit_event` と statusLine の `rate_limits` に出た 5h / 7d はアカウント（サブスク）の実際の使用率
- 親から子への環境変数の継承（このセッションのハーネスが Bash に export しているもの）
  - `CLAUDE_EFFORT=xhigh`: 子が effort を決めない場合に誤読しないよう、全実行で `env -u CLAUDE_EFFORT` を付けた
  - `CLAUDE_CODE_SESSION_ID`: `--session-id` を付けない子は、出力の `session_id` も statusLine 入力の `session_id` も親と同じ値になった
  - `CLAUDE_AUTO_BACKGROUND_TASKS=true`: B5 のサブエージェントがバックグラウンドで走り、`result` が 2 回出たのはこの継承によると見られる `[speculation]`
  - `CLAUDE_CODE_EFFORT_LEVEL` は未設定
- 枠の消費
  - 全実行の合計は list 価格換算で約 $0.07（Haiku 中心。Sonnet 3 回、Opus 1 回。Fable は 0 回）
  - 5h 枠は 7%（16:15）→ 10%（16:20）、7d 枠は 15% のまま。同時に動いていたこのセッション自身（親）の消費と区別できない。§8.6 の「増分をセッションに帰属できない」問題がそのまま起きた

### 12.2 予想と違った点・新しく分かった点

- `get_usage` は `-p` で動くが、profile スコープのないトークンでは `rate_limits: null`（§11.2 のローカル検証 A）
  - 予想（§11.2）は「ローカルで叩けば取れる」。実際は「どのマシンか」ではなく「トークンのスコープ」で決まる
  - 推論専用のトークンで子を動かす構成では、`get_usage` に頼れない。`claude setup-token` で作るトークンも推論専用だとすれば同じことが起きる `[speculation]`
- 5h / 7d は `get_usage` がなくても取れる
  - `-p` の stream-json 出力の `rate_limit_event`（API 応答ごと）と、statusLine 入力の `rate_limits`。どちらも profile スコープは不要
  - `get_usage` でしか取れないのは、モデル別の週次枠（`model_scoped`、Fable）と `extra_usage`、`seven_day_opus` / `seven_day_sonnet`
- issue #64706 は v2.1.314 で再現しない。サブエージェント frontmatter の `effort:` / `model:` は効く（§11.3 の B5）
- 優先順位を実測できた: `CLAUDE_CODE_EFFORT_LEVEL` > スキル / サブエージェント frontmatter > `--effort`。frontmatter の effort はそのスキルのターンだけで、次のターンは戻る（§11.3）
- `system/init` は `-p` でもユーザーターンごとに出る（D の 3 ターン実行で 3 回）。`model` はそのターンの実効値で、スキルの `model:` で切り替わったターンでは切り替え後のモデルが入る（§11.3 の B3）
- 対話モードの `/effort` は `modelSettings.<モデル ID>.effortLevel` に保存され、新しいセッションの既定になる（§11.1 のローカル検証 C）。検証用のセッションで打つとユーザー設定が変わる
- 固定で送られるプロンプトの量が構成で大きく違う
  - `-p` + `--tools ""`（MCP なし）: 1 回目の入力は約 3.7k トークン（Haiku）
  - 対話モード（MCP なし、このコンテナの既定ツール・スキル・プラグイン込み）: 約 42k トークン
  - `-p` で既定のツールを全部載せた場合は測っていない
- statusLine の `prompt_cache` は静的解析で挙げた `warm` / `expires_at` 以外に、ミス回数・原因・再キャッシュ時のトークン数（`recache_tokens_if_cold`）まで持つ（§11.1 のローカル検証 C）

### 12.3 確かめられなかったこと

- Fable の枠の仕組み（`model_scoped` の Fable 行、`extra_usage`、`seven_day_opus` / `seven_day_sonnet`、`subscription_type`）
  - 理由: このコンテナのトークンに profile スコープがなく、`get_usage` が `rate_limits: null` を返す
  - 次の手: 通常ログイン（`/login`）したマシンで §12.4 の A を実行する。プロンプトを送らないので、メッセージ API の消費はない見込み（このコンテナでは `model_usage` が空だった）
- Fable の `per_turn_effort_active`
  - 理由: Fable を `-p` で動かすと usage credits が確認なしで課金される可能性があり、事前確認が必要なため未実施
  - 次の手: 許可が出たら §12.4 の D-Fable を 1 回だけ実行する。ただし §11.2 のとおり、このアカウントでは extra usage が無効なので、usage credits への課金は起きない可能性が高い `[speculation]`
- `get_usage` がローカルで `/api/oauth/usage` を呼ぶか、その呼び出しが枠を消費しないか（このコンテナの debug log には呼び出しの記録がなく、呼んだかどうか判断できない）
- 子を `spawn.sh` 経由（`wez pane` の新しいペイン）で起動した場合に、親の `CLAUDE_CODE_SESSION_ID` / `CLAUDE_EFFORT` が継承されるか。今回見たのは Bash から直接起動した場合だけ
- frontmatter の `effort: xhigh`、スキルの `model:` が次のターンで戻るか

### 12.4 ローカルで実行する手順

- A: Fable 枠と usage credits（プロンプトを送らない）

```bash
printf '%s\n' '{"type":"control_request","request_id":"u1","request":{"subtype":"get_usage","skip_behaviors":true}}' \
  | claude -p --input-format stream-json --output-format stream-json --verbose --no-session-persistence \
  | jq 'select(.type=="control_response") | .response.response | del(.behaviors)'
```

- 見るところ: `rate_limits_available` が `true` か、`rate_limits.model_scoped` に Fable の行があるか、`rate_limits.extra_usage.is_enabled`、`subscription_type`、`session.model_usage` が空のままか（空ならメッセージ API は呼ばれていない）
- C: statusLine の実フィールド（任意。このコンテナで取れたため、通常ログインで差が出るかを見る場合だけ）
  - 既存の `~/.claude/settings.json` は書き換えず、`--settings` でそのセッションだけ statusLine を差し替える
  - セッション中に `/effort` や `/model` は打たない（ユーザー設定に保存される）

```bash
mkdir -p "$HOME/tmp/statusline-probe"
cat > "$HOME/tmp/statusline-probe/dump.sh" <<'EOF'
#!/usr/bin/env bash
# statusLine の入力 JSON を加工せずに書き出す（検証用）
dir="$HOME/tmp/statusline-probe"
input=$(cat)
printf '%s' "$input" > "$dir/raw-$(date +%s).json"
printf '%s' "$input" > "$dir/latest.json"
printf 'statusline-probe'
EOF
chmod +x "$HOME/tmp/statusline-probe/dump.sh"
```

```bash
claude --model haiku --effort low --settings "$(jq -cn --arg c "$HOME/tmp/statusline-probe/dump.sh" '{statusLine:{type:"command",command:$c}}')"
```

- 起動したら「Reply with exactly: OK」を 1 回送り、statusLine の表示が更新されたら `/exit`
- 確認用

```bash
jq '{rate_limits, cost, effort, context_window, prompt_cache_keys: (.prompt_cache // {} | keys)}' "$HOME/tmp/statusline-probe/latest.json"
```

- D-Fable: Fable の `per_turn_effort_active`（Fable で 1 回 API を呼ぶ。実行前に要判断）

```bash
claude -p "Reply with exactly: OK" --model fable --effort low \
  --output-format stream-json --verbose --no-session-persistence --strict-mcp-config --tools "" \
  | jq -c 'select(.type=="system" and (.subtype=="init" or .subtype=="per_turn_effort_changed")) | {subtype, model, per_turn_effort_active}'
```

### 12.5 設計への影響

- 子の消費を測る: `spawn.sh` の claude を `--output-format stream-json --verbose` にすれば、追加の呼び出しなしで `rate_limit_event`（5h / 7d）と `result.modelUsage`（モデル別トークン・`costUSD`）が取れる。今の `--output-format text` では取れない
  - `result.total_cost_usd` と `result.modelUsage` はセッション内の累計（D の 3 ターン実行で 0.00031 → 0.00053 → 0.00059）。ターン単位の値は `result.usage` か累計の差分で取る
- Fable 用の λ（§8.1）の入力は `get_usage` の `model_scoped` しかない。profile スコープ付きのトークンが前提になるので、統括を動かすマシンのログイン方法を合わせて決める
- §8.4 の「frontmatter は `--effort` より優先されるので、固定値は落とせない実装系スキルだけに書く」は実測でも成り立つ
- `CLAUDE_CODE_EFFORT_LEVEL` が環境に残っているとルーターの `--effort` も frontmatter も効かなくなる。`spawn.sh` で `env -u CLAUDE_CODE_EFFORT_LEVEL` を付けるか、harness-check で検知する
- 統括の effort の上下はキャッシュを壊さない（§11.4 のローカル検証 D）。§11.5 の「stream-json で統括を動かし `apply_flag_settings` で effort を変える」案は、effort については使える
- タスク単位の記録（§8.6）は transcript からも作れる。assistant 行に `effort` / `perTurnEffort` / `requestedModel` / `message.model` が残る（`--no-session-persistence` を外す場合）
- Bash から直接 `claude` を起動する経路（so-compare など）では、子が親の `session_id` を名乗る。statusLine の sidecar は `<session_id>.json` なので、対話モードの子を同じ方法で起動すると親の sidecar を上書きする。`--session-id` を明示するか `env -u CLAUDE_CODE_SESSION_ID` を付ける

## 参考

- [Claude Code Docs: Model configuration](https://code.claude.com/docs/en/model-config)
- [Claude Platform Docs: Effort](https://platform.claude.com/docs/en/build-with-claude/effort)
- [wmedia: Claude Code effort: not the level you think you have](https://wmedia.es/en/tips/claude-code-effort-not-the-level-you-think)
- [wmedia: Claude Code effort per model](https://wmedia.es/en/tips/claude-code-effort-per-model)
- [DEV: 10 Claude Code env vars worth exporting](https://dev.to/gabrielanhaia/10-claude-code-env-vars-worth-exporting-and-why-disabletelemetry0-still-disables-it-32e1)
- [claudeissues #64706: Agent tool ignores effort frontmatter](https://claudeissues.com/issue/64706-agent-tool-ignores-effort-frontmatter-in-subagent-md-files-inherits-global-effor)
- [Opus 5.5 at every effort level on one /goal build](https://openclawdatabase.com/news/videos/2026-09-24-opus-55-every-effort-level-cost-comparison/index.md)
- [Opus 5.5 scores worse on high effort than medium, SlopCodeBench](https://zeli.app/story/50108717)
- [Claude Code Router (2026 Guide)](https://www.morphllm.com/claude-code-router)
- [Feature Request: Automatic Model Switching Between Plan and Execution Modes](https://claudeissues.com/issue/27274-feature-request-automatic-model-switching-between-plan-and-execution-modes)
