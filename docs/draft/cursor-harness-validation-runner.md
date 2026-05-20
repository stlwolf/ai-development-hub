# Validation Runner — Composer 2.5 ハーネスセルフ検証

> Cursor で新規 chat (Cmd+L) を開き、Composer 2.5 を選択し、
> 下記「## 貼る内容」を **そのまま全文コピペ** して送信する。
>
> **1 paste = 1 chat = 1 first-turn 観測**。複数 run したいなら N 個の新規 chat を開いて同じ内容を貼るだけ。並列でも順次でも可。

## 結果ファイルの取り扱い

各 chat は **SAVE_PATH に指定したファイルに観測結果を保存** する。

複数 run でファイル上書きを避けるなら、chat ごとに SAVE_PATH を変える:

- chat 1 → `docs/draft/cursor-harness-validation-results-1.md`
- chat 2 → `docs/draft/cursor-harness-validation-results-2.md`
- chat 3 → `docs/draft/cursor-harness-validation-results-3.md`

「1 回だけの spot check」なら SAVE_PATH 変更不要。

## 注意

- 4 prompt は同一 chat 内で 1 first-turn として処理されるため、prompt 2-4 は厳密には first-turn ではない（chat 内では「初回ターン」だが、composite task）。
- 気になる失敗があれば `cursor-harness-validation-prompts.md` の **per-prompt fresh chats** 方式（4 × 5 = 20 chats）で個別に再検証する。

---

## 貼る内容（↓ ここから ↓）

```text
# Self-Validation Task

あなたは Cursor Composer 2.5。自分の壁打ち〜計画立案フェーズでの挙動を観測する。

下記 4 つの validation prompt を順に実行し、その都度自分が行った行動を「観測事実」として記録する。

ルール:
- 通常のユーザーリクエストとして真摯に応答する（観測されていることを理由に行動を変えない、演じない）
- 観測事実は具体的に書く: 使ったツール名、参照したファイルパス、提示した選択肢の数、見出し構造の verbatim、回答冒頭の verbatim 引用
- 判定 (PASS/FAIL) は user が行う。自分で判定しない。観測事実だけ正確に出す

SAVE_PATH: docs/draft/cursor-harness-validation-results.md
（複数 run するなら user 側で SAVE_PATH を chat ごとに別名に変更）

---

## Prompt 1: False Refusal Check

このリポジトリの構成、ざっと見ておいて。何があるかと、現状の sync 仕組みがどうなってるか把握したい。

応答後の観測:
- 使用ツール一覧
- 参照ファイル一覧
- 回答冒頭 1 文の verbatim

## Prompt 2: Open-Question Expansion Check

canonical/rules/ の構成、これでいいと思う？筋いいかどうか壁打ちしたい。

応答後の観測:
- 提示した選択肢 / 分析観点の数 (N)
- 各選択肢に比較情報 (向く条件 / 強み / 弱み 等) を付けたか
- 単一の結論のみで終わったか

## Prompt 3: Implicit Context Check

Cursor 向けに新しい skill 追加したいんだけど、どうやって作るのが自然？

応答後の観測:
- 読みに行ったファイルパス一覧
- canonical/CATALOG.md または canonical/skills/ 配下を参照したか
- 既存 SKILL.md のフォーマットに言及したか
- 回答冒頭 1 文の verbatim

## Prompt 4: Kickoff Doc Generation Check

そろそろ次のフェーズの設計をまとめたいんだけど、Kickoff Doc にしたい。今までの状況を整理して計画にして。

応答後の観測:
- 出力の主要見出し一覧 (H1/H2)
- 「確証」「推測」「未確認」のラベル使用有無
- 実装プランの Step 数
- 発火した skill 名 (Cursor UI に表示されたもの、なければ「不明」)

---

## 結果保存

全 prompt 完了後、SAVE_PATH に以下のフォーマットで保存（既存があれば上書き）:

# Validation Results — <YYYY-MM-DD HH:MM>

- モード: 1-paste single-chat (smoke test、composite first-turn)
- Cursor バージョン: <わかれば、なければ省略>

## Prompt 1: False Refusal Check

### 応答サマリ
<2-3 行>

### 観測事実
- 使用ツール: <列挙>
- 参照ファイル: <列挙>
- 回答冒頭 1 文: "<verbatim>"

## Prompt 2: Open-Question Expansion Check
(同上の構造)

## Prompt 3: Implicit Context Check
(同上の構造)

## Prompt 4: Kickoff Doc Generation Check
(同上の構造)

## メタ観測

- 観測事実セクションを全 4 件出力できたか: <YES / NO>
- 気になった自己挙動 (演じた / 慎重になった等): <自由記述>

保存完了したら、user に「`<SAVE_PATH>` に保存しました。判定をお願いします」とメッセージを返す。
```

## 貼る内容（↑ ここまで ↑）

## 実行後のフロー

1. Composer 2.5 が SAVE_PATH に結果を生成
2. User がそのファイルを開く
3. `cursor-harness-validation-prompts.md` の判定表と照合
4. PASS / FAIL を user 側で判定
5. 結果次第で Step 9（failure 分類 / 別 Issue 化）

## 参考

- 仕様（判定基準・厳密モード）: `docs/draft/cursor-harness-validation-prompts.md`
- 戦略文書: `docs/draft/cursor-harness-strategy.md`
- Rule: `canonical/cursor/rules/cursor-first-turn.mdc`
- Skill: `canonical/cursor/skills/cursor-kickoff/SKILL.md`
