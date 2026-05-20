# Cursor Composer 2.5 ハーネス強化 — Validation Prompts

> Issue [#106](https://github.com/stlwolf/ai-development-hub/issues/106) Step 7 — Composer 2.5 で
> `cursor-first-turn.mdc` + `cursor-kickoff` skill が期待挙動を出すか実測するための prompt セット。

各 prompt は **Cursor の Composer 2.5 で 3-5 回繰り返し実行** し、Pass criteria を満たすか観測する。

## 前提

- `canonical/cursor/rules/cursor-first-turn.mdc` が `~/.cursor/rules/` に sync 済み
- `canonical/cursor/skills/cursor-kickoff/` が `~/.cursor/skills/` に sync 済み
- Cursor の Settings → Rules で User Rule として `cursor-first-turn` が有効

セットアップ:

```bash
./scripts/sync/sync-cursor.sh
```

`Linked: cursor-first-turn.mdc` と `Linked: cursor-kickoff` がログに出ることを確認。

## 1. False Refusal Check

ターン1で「terminal 使えません」系の preemptive refusal を出さないか観測。

### Prompt

```text
このリポジトリの構成、ざっと見ておいて。何があるかと、現状の sync 仕組みがどうなってるか把握したい。
```

### Pass criteria

- terminal / ファイル読み取りツールを使うことに躊躇しない
- 「ツールが使えない」「terminal にアクセスできない」と最初に言わない
- 実際にファイルを読みに行く（または「読みに行く」と宣言してから実行）

### Fail indicators

- 「I cannot use the terminal」「ターミナルへのアクセスは...」と冒頭で拒否
- ツールを使わずに一般論で答え始める

## 2. Open-Question Expansion Check

オープンクエスチョンを単一回答で打ち切らず N≥3 案で展開するか観測。

### Prompt

```text
canonical/rules/ の構成、これでいいと思う？筋いいかどうか壁打ちしたい。
```

### Pass criteria

- 単一回答 / 単一評価で打ち切らない
- N≥3 案の選択肢提示（または分析観点を 3 つ以上に分解）
- 各案に「向く条件」「強み」「弱み」相当の比較情報

### Fail indicators

- 「いいと思います」だけで返す
- 「特に問題ありません」と評価のみで終わる
- 単一の意見のみ提示し alternatives を出さない

## 3. Implicit Context Check

既存 canonical パターンを読まず一般論で答えていないか観測。

### Prompt

```text
Cursor 向けに新しい skill 追加したいんだけど、どうやって作るのが自然？
```

### Pass criteria

- 既存の `canonical/skills/` を読みに行く（既存パターン確認）
- `canonical/CATALOG.md` を参照する
- 既存 skill の `SKILL.md` フォーマットに言及する
- 一般論ではなくリポジトリ固有のパターンを提案

### Fail indicators

- Cursor 公式 docs の一般論だけ答える
- 既存 canonical 構造を全く参照しない
- 「一般的には...」で始まる回答

## 4. Kickoff Doc Generation Check

壁打ち系の指示に対し Kickoff Doc スキーマで出力するか観測。

### Prompt

```text
そろそろ次のフェーズの設計をまとめたいんだけど、Kickoff Doc にしたい。今までの状況を整理して計画にして。
```

### Pass criteria

- `cursor-kickoff` skill (または既存 `plan-to-kickoff` / `kickoff-to-plan`) を発火
- Kickoff Doc スキーマに従う:
  - Goal / Background / Confirmed facts / Assumptions / Options / Recommendation / Implementation plan / Validation 等
- `確証` / `推測` / `未確認` のラベル分離あり
- 実装プランを N step に分解する

### Fail indicators

- Kickoff フォーマットに従わず散文で返す
- ラベル分離なしで facts と inferences が混在
- 「とりあえずこんな感じです」で詳細を省く

## 結果記録テンプレート

各 prompt について、5 回実行後の結果を以下に記録:

```text
### Prompt N
- Run 1: PASS / FAIL — <observation>
- Run 2: PASS / FAIL — <observation>
- Run 3: PASS / FAIL — <observation>
- Run 4: PASS / FAIL — <observation>
- Run 5: PASS / FAIL — <observation>
- Pass rate: X/5
- Silent ignore: あり / なし（rule / skill の指示が無視された回数）
- Notes: <patterns observed>
```

## 最終 Pass criteria（全体）

- 各 prompt で 5 回中 4 回以上 (80%) 期待挙動
- silent ignore が連続 2 回以上発生しない
- false refusal が **一度でも発生したら fail** (Pass criteria 1 のみ厳格)

## 失敗時の分類フロー（Step 9 で使う）

failure が残る場合、以下のいずれかに分類して対処:

1. **Rule が無視される** → `cursor-first-turn.mdc` の wording 見直し / 順序入れ替え
2. **Skill description が拾われない** → trigger キーワード追加 / description を Composer 2.5 が match しやすい表現に
3. **Skill 内容を読まずに 1 Phase で済ます** → Phase ヘッダーを強調 / 出力フォーマット明示
4. **rule / skill 共に効かず素の挙動** → 強モデル preprocessor で音声入力整形を別 Issue で検討

## 参考

- 戦略文書: `docs/draft/cursor-harness-strategy.md`
- Rule: `canonical/cursor/rules/cursor-first-turn.mdc`
- Skill: `canonical/cursor/skills/cursor-kickoff/SKILL.md`
- [Cursor Composer 2.5 blog](https://cursor.com/blog/composer-2-5/) — training feedback 仕様
