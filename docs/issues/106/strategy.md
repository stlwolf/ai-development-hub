# Cursor Composer 2.5 向けハーネス強化 戦略文書

> Issue [#106](https://github.com/stlwolf/ai-development-hub/issues/106) — Epic [#37](https://github.com/stlwolf/ai-development-hub/issues/37) G6 (Initializer Agent 完全版) の Cursor 向け簡易版。

## 1. 背景と目的

### 解きたい課題

Cursor Composer 2.5 (Kimi K2.5 base + RL fine-tune, 2026-05-18 リリース) を、これまでの「実装ワーカー」用途だけでなく **「壁打ち → Plan 作成」フェーズでも実用レベル** で使えるようにする。

Composer 2.5 は Opus 4.7 比で約 1/10〜1/30 のコスト。実装フェーズの精度は既に `peer-ai-review` / `so-compare` でカバー済みだが、**入口側（壁打ち〜計画立案）で以下の弱点が顕著**:

- 音声入力の断片的・探索的指示を「事実確認」レベルに矮小化する
- 利用可能なツール（terminal 等）を最初に「使えません」と拒否する
- オープンクエスチョンを N 案に展開せず最短回答で打ち切る
- 暗黙の前提（既存パターン、制約）を読まず毎回明示指示が必要

### なぜ起きるか（仮説）

Cursor ハーネスが Composer 2.5 の自然言語解釈能力（Claude/GPT 系より低い）を前提にしていない。Kimi K2.5 ベースのため Anthropic 系アラインメント特性とは異なる挙動を示す。

### ゴール

Cursor 用ハーネスを構造的に強化し、Composer 2.5 でも壁打ち〜Plan フェーズが安定するようにする。**強モデルとの使い分け（Plan-once-execute-cheap パターン）は維持** しつつ、Cursor 内で完結できるフェーズを拡大する。

## 2. Composer 2.5 の特性（一次情報ベース）

| 項目 | 値 / 状態 | 出典 |
|---|---|---|
| ベース | Moonshot Kimi K2.5 (open-weight) | [Cursor blog](https://cursor.com/blog/composer-2-5/), API id decode から [HN 議論](https://news.ycombinator.com/item?id=47444346)（推測検証） |
| 訓練 | Cursor 側で RL fine-tune (85% of compute) | [Cursor blog](https://cursor.com/blog/composer-2-5/) |
| API id | `kimi-k2p5-rl-0317-s515-fast` | [HN: Cursor backend response decoded](https://news.ycombinator.com/item?id=47444346)（外部観測） |
| 価格 | $0.50/M input, $2.50/M output (Standard) | [Cursor Models & Pricing](https://cursor.com/docs/models-and-pricing) |
| Opus 4.7 比 | 入力 10x / 出力 30x 安い | 上記価格と Opus 4.7 公式価格からの計算（派生値） |
| Context | 物理 256K, 効果は MECW 128K-256K | [Cursor docs Models](https://cursor.com/docs/models) (256K), MECW 範囲は[Composer 2 technical post](https://cursor.com/blog/composer-2-5/) からの推測 |
| Training feedback | 「Reminder: Available tools...」形式の targeted textual feedback を学習に使用 | [Cursor blog](https://cursor.com/blog/composer-2-5/) |

**重要**: training に "Reminder: Available tools..." が使われている事実は、「**ターン1での自己能力宣言が効く直接根拠**」となる。同じ表現プロトコルを runtime で使えば挙動が予測しやすい。

## 3. 一次情報の根拠（確証 / 推測のラベル付き）

### 確証

| 主張 | ソース |
|---|---|
| Cursor 2.4 で Agent Skills が公式機能化、Rules=static / Skills=dynamic の役割分担明示 | [Cursor changelog 2.4](https://cursor.com/changelog/2-4), [Cursor docs Rules](https://cursor.com/docs/rules) |
| `.mdc` 制御軸は `alwaysApply` / `globs` / `description` のみ。モデル別 routing は未実装 | [Cursor docs Rules](https://cursor.com/docs/rules), [forum feature request](https://forum.cursor.com/t/bind-specific-rules-mdc-to-custom-modes-or-agents/121536) |
| alwaysApply は <200 words が公式推奨（token tax 警告） | Cursor 公式 docs |
| Cursor 3.0.16 既知バグ: alwaysApply: true が silently "requestable" に降格 | [forum bug report](https://forum.cursor.com/t/alwaysapply-true-rules-and-cursorrules-both-silently-treated-as-requestable-instead-of-auto-injected-cursor-3-0-16-macos/157431) |
| forum 実測: alwaysApply: true (3/3 compliance) vs false (0/3 compliance) | [forum guide](https://forum.cursor.com/t/cursorrules-isnt-loaded-in-agent-mode-i-tested-it-heres-what-actually-works/152045) |
| Reddit 実測: 50 rules でも実コード 96-98% compliance（silent ignore あり） | [Reddit r/cursor](https://www.reddit.com/r/cursor/comments/1rcwnzr/i_loaded_50_cursor_rules_at_once_to_find_the/) |
| static self-reflection は性能劣化する場合あり → 観測可能 protocol が必要 | [arXiv:2503.00902 Instruct-of-Reflection](https://arxiv.org/abs/2503.00902) |
| NLAH ハーネスの State Semantics / Failure Taxonomy 概念 | [arXiv:2603.25723](https://arxiv.org/abs/2603.25723) |
| Composer 2.5 = Kimi K2.5 base + RL fine-tune | [Hacker News](https://news.ycombinator.com/item?id=47444346) |

### 推測（裏取り不十分だが妥当性あり）

- Composer 2.5 の training reminder 仕様は inference 時の prefix injection にも応用可能（公式 blog は training 文脈で言及、inference 適用は要実測）
- Kimi K2.5 ベース起因で、Anthropic 系プロンプトテクニック（XML タグ、Chain-of-Thought 強制）が効きにくい可能性

### 採用しないもの（Gemini 出力の捏造ライン）

- 数字 (40%, 25%, 8.3%, $18.75 等) — 出典なし
- arXiv:2601.19231 を「prefix で refusal 抑制」の根拠として使うのは誤用（同論文は fine-tuning による refusal unlearning、inference 時 prefix の話ではない）

## 4. アプローチ: 薄い alwaysApply + 重い Agent Skill (wrapper)

```text
Composer 2.5 入力
      ↓
[ canonical/cursor/rules/cursor-first-turn.mdc ]   ← alwaysApply: true, <200 words
   ・ターン1自己能力宣言
   ・即拒否禁止
   ・音声入力解釈プロトコル
   ・Kickoff trigger
      ↓
[ canonical/cursor/skills/cursor-kickoff/SKILL.md ] ← Agent Skill, 重い
   ・タスク分類（FACT_CHECK / WALL_BOUNCE / PLAN / EXECUTE）
   ・お膳立て（前提読み、能力確認）
   ・既存スキルへの orchestration
      ↓
[ 既存スキル群 ]
   ・question-driven-design
   ・plan-to-kickoff
   ・kickoff-to-plan
   ・adversarial-review
```

### なぜこの構成か

1. **公式の役割分担と一致**: Rules=static context (常時注入)、Skills=dynamic capabilities (description match で発火)
2. **forum 実測で alwaysApply 側が信頼できる**: 3/3 compliance vs 0/3
3. **token tax 回避**: alwaysApply は 200 words 未満に絞り、重い手順は Skill 側で on-demand 読み込み
4. **観測可能 protocol**: arXiv:2503.00902 が示す通り、抽象的「反省せよ」は逆効果。「何を、どの形式で出すか」を schema 強制する
5. **既存スキル再利用**: 強モデル側の skill 改善が cursor-kickoff 経由で Cursor にも波及

### 不採用案

| 案 | 不採用理由 |
|---|---|
| 全部 alwaysApply に詰め込む | token tax、200 words 超で公式推奨逸脱、Reddit 実測で silent ignore 確認 |
| Apply Intelligently (description-based 動的読み込み) を多用 | forum 実測で取りこぼしリスク (0/3 compliance)、低スペックモデルでは description match 精度が不安定 |
| 強モデル preprocessor で音声入力を整形してから Cursor に渡す | 運用摩擦増、最初から導入は overkill。Composer 2.5 単体で failure が残った場合の次手として保留 |
| 現状維持 | 壁打ちフェーズで毎回弱点に引っかかる |

## 5. 既存スキルとの関係（wrapper として呼び出し）

cursor-kickoff は新規実装ではなく **wrapper / orchestrator**。Composer 2.5 が拾いきれない暗黙のお膳立てを補い、既存の汎用スキルへ橋渡しする。

| 呼び出し先 | 呼び出すタイミング |
|---|---|
| `question-driven-design` | 暗黙の設計判断が多いタスクで、計画前に質問フェーズが必要なとき |
| `plan-to-kickoff` | Cursor Plan Mode 出力を Kickoff Doc 化するとき |
| `kickoff-to-plan` | Kickoff Doc を実行可能 Plan に展開するとき |
| `adversarial-review` | Plan の品質チェック |

「贅肉」（解釈能力の弱さを補う冗長性）は意図的なコスト。再実装はしない。

### 既存スキルが持っていないもの（cursor-kickoff の新規部分）

- 音声入力解釈プロトコル（`input-style-rule` はあるが Composer 2.5 向けの強い強制はない）
- 能力宣言プロトコル（ターン1で必要）
- 多角展開強制（`question-driven-design` は質問ベース、N 案展開ではない）
- 即拒否禁止プロトコル
- タスク種別の最初の分類（FACT_CHECK / WALL_BOUNCE / PLAN / EXECUTE）

## 6. 配置設計

### 新規ファイル

| パス | 種別 | 言語 | 配布先 |
|---|---|---|---|
| `canonical/cursor/rules/cursor-first-turn.mdc` | Cursor User Rule | 英語 (rules 規約) | `~/.cursor/rules/` |
| `canonical/cursor/skills/cursor-kickoff/SKILL.md` | Cursor Agent Skill | 日本語 (skills 規約) | `~/.cursor/skills/cursor-kickoff/` |

### sync 機構の拡張

現状の `scripts/sync/sync-cursor.sh` は `.mdc` の自動配置を実装していない（`canonical/cursor/README.md` L29 で「手動運用」前提）。

本 Issue で以下を追加:

- `sync_mdc_files()` 関数を新設、または `sync_md_files()` を拡張して `.mdc` 拡張子に対応
- `canonical/cursor/rules/*.mdc` → `~/.cursor/rules/*.mdc` にシンリンク
- `canonical/cursor/skills/cursor-kickoff/` → `~/.cursor/skills/cursor-kickoff/` にシンリンク（既存 `sync_dirs` で対応可能か検証）

### canonical/CATALOG.md / canonical/cursor/README.md

- CATALOG: 新規 rule (cursor-first-turn) と skill (cursor-kickoff) を Skills/Rules テーブルに追加。「ツール固有拡張」セクションの cursor/ 行も更新
- cursor/README.md: rules/ と skills/ サブディレクトリの説明を追加、「User Rules は手動運用」記述を sync 自動化に更新

## 7. 検証計画

### Static

- `shellcheck scripts/sync/sync-cursor.sh` (sync 変更時)
- `canonical/CATALOG.md` の登録とファイル実体の整合確認

### Behavioral (Composer 2.5 で実測)

4 種の validation prompt を **各 3-5 回繰り返し** 実行し、silent ignore / compliance / false refusal を観測:

1. **False refusal check**: 音声入力風の雑な指示で、terminal 使えませんと言い出さないか
2. **Open-question expansion check**: 「筋いい？」系のオープンクエスチョンを最短回答で打ち切らず N 案展開するか
3. **Implicit context check**: 既存 canonical パターン（`CATALOG.md`, 既存 skill）を読みに行くか
4. **Kickoff Doc generation check**: 壁打ち → Kickoff Doc 化が指示通り発火するか

Pass criteria:

- 各 prompt で 5 回中 4 回以上 expected behavior が出る (80% compliance)
- silent ignore が連続 2 回以上発生しない

### Regression

- Claude Code / Codex 側の挙動に変化なし（sync で他ターゲットに余分なファイルが配布されないことを確認）
- `sync-cursor.sh` 変更が `sync-claude.sh` / `sync-codex.sh` に影響しない

## 8. リスクと対処

| リスク | 影響 | 対処 |
|---|---|---|
| Skill description を Composer 2.5 が拾わない | cursor-kickoff が発火しない | trigger キーワード豊富に列挙、validation で観測。発火しなければ rule 側で明示的に skill 名を呼ぶ |
| 既存 skills と機能重複懸念 | メンテ負荷増 | wrapper 設計で既存 skill を呼び出す形に。再実装しない |
| 抽象プロトコルが効かない (arXiv:2503.00902) | rule/skill が実効性を持たない | 全プロトコルを「観測可能な出力 schema」で書く。"reflect" 系の語を使わない |
| Kimi K2.5 ベース起因で Anthropic 系プロンプト技法が効かない | テクニックを書いても無視される | 検証段階で Anthropic 系イディオム (XML タグ強制等) を避ける。training reminder 形式に寄せる |
| Cursor 3.0.16 alwaysApply バグ | rule が機能しない | 現在 3.4.20 で影響範囲外（確認済み） |
| MECW (128K-256K) を超える context bloat | rule/skill が落とされる | alwaysApply を <200 words に厳守、skill は on-demand |

## 9. 議論ログ（Gemini 出力の検証、ChatGPT 出力の差分）

### 経緯

1. 初期壁打ち: Claude Code 上で課題整理、Plan-once-execute-cheap パターンの確認
2. Gemini (通常チャットモード) に投入: 視点は採用可、citation の検証が必要
3. ChatGPT (Deep Research モード相当、repo 情報注入済み) に投入: 質が段違い、forum/Reddit 実測まで grounding

### Gemini 出力から採用したもの

- 「ハーネス強化」の方向性
- Cursor 用 alwaysApply + Agent Skill の構成案
- skill/rule のテンプレ骨格

### Gemini 出力から捨てたもの

- 数字 (40%, 25%, 8.3%, $18.75 等) — 出典なし
- arXiv:2601.19231 を「prefix で refusal 抑制」根拠として引用 — 論文は fine-tuning による refusal unlearning であり、inference 時 prefix の話ではない（誤用）
- 内部 episode への参照 — 捏造（Gemini に repo 情報を渡していなかったため）

### ChatGPT 出力で新たに得たもの

- **Cursor 2.4 で Agent Skills が公式機能化** という事実（私の前回想定では「ad-hoc SKILL.md」だったが、公式 spec があった）
- **forum 実測の compliance データ** (alwaysApply: 3/3 vs 0/3)
- **Reddit 50 rules 実測** (96-98% compliance, silent ignore あり)
- **Composer 2.5 公式 blog の "Reminder: Available tools" 仕様** ← 「自己能力宣言が効く直接根拠」
- **arXiv:2503.00902** — static reflection は逆効果、観測可能 protocol が必要

### 設計への影響

- 当初: 3 つの .mdc に分割（Apply Intelligently 含む）
- 修正後: **1 つの薄い alwaysApply + 1 つの重い Agent Skill** に集約（forum 実測の compliance 差を根拠）

## 10. 参考文献

### 一次情報

- [Cursor Composer 2.5 公式 blog](https://cursor.com/blog/composer-2-5/)
- [Cursor Rules 公式 docs](https://cursor.com/docs/rules)
- [Cursor changelog 2.4 — Agent Skills](https://cursor.com/changelog/2-4)
- [Cursor agent best practices](https://cursor.com/blog/agent-best-practices/)
- [Hacker News: Composer 2 = Kimi K2.5 base](https://news.ycombinator.com/item?id=47444346)

### 実測・実証

- [forum: alwaysApply compliance 実測](https://forum.cursor.com/t/cursorrules-isnt-loaded-in-agent-mode-i-tested-it-heres-what-actually-works/152045)
- [Reddit r/cursor: 50 rules 限界実験](https://www.reddit.com/r/cursor/comments/1rcwnzr/i_loaded_50_cursor_rules_at_once_to_find_the/)
- [forum: alwaysApply 3.0.16 silently downgraded bug](https://forum.cursor.com/t/alwaysapply-true-rules-and-cursorrules-both-silently-treated-as-requestable-instead-of-auto-injected-cursor-3-0-16-macos/157431)

### 学術論文

- [arXiv:2503.00902 — Instruct-of-Reflection](https://arxiv.org/abs/2503.00902)
- [arXiv:2603.25723 — NLAH (Natural-Language Agent Harnesses)](https://arxiv.org/abs/2603.25723)
- [arXiv:2510.18892 — 256 LLMs instruction adherence](https://arxiv.org/abs/2510.18892)

### 概念枠組

- [Martin Fowler — Harness Engineering](https://martinfowler.com/articles/exploring-gen-ai/harness-engineering.html)
- [Martin Fowler — Harness Engineering memo](https://martinfowler.com/articles/exploring-gen-ai/harness-engineering-memo.html)

### 関連内部資料

- `projects/orchestration-research/synthesis/harness-engineering-mapping.md` — 自設計とのマッピング
- Epic [#37](https://github.com/stlwolf/ai-development-hub/issues/37) — Harness Engineering 基盤整備
- Issue [#106](https://github.com/stlwolf/ai-development-hub/issues/106) — 本 Issue
