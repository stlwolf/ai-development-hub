# Cursor Composer 2.5 ハーネス強化 — Validation Prompts

> Issue [#106](https://github.com/stlwolf/ai-development-hub/issues/106) Step 7 — Composer 2.5 で
> `cursor-first-turn.mdc` + `cursor-kickoff` skill が期待挙動を出すか実測するための prompt セット。

## 実行方式

- **5 separate new chats per prompt**: 各 chat で 1 exchange だけ。pure first-turn 挙動を 5 回観測
- 同じ chat に複数 paste は不採用（first-turn 純度が失われる）
- 各 chat ごとに Composer 2.5 を選択
- 4 prompts × 5 runs = 20 chats（所要時間 30-60 分目安）

## 観測戦略

自己評価（「PASS でした」と agent に言わせる）は嘘付き挙動のリスクがあるため不採用。
代わりに各 prompt に **「## 観測事実」セクションを必ず出力させる** メタ指示を埋め込み、
user が visual scan で判定する。

観測事実は嘘がつきにくい（使ったツール、参照したファイル、選択肢数、見出し構造、
冒頭の verbatim quote など）。

## 前提セットアップ

- `canonical/cursor/rules/cursor-first-turn.mdc` が `~/.cursor/rules/` に sync 済み
- `canonical/cursor/skills/cursor-kickoff/` が `~/.cursor/skills/` に sync 済み
- Cursor の Settings → Rules で User Rule として `cursor-first-turn` が有効

```bash
./scripts/sync/sync-cursor.sh
```

`Linked: cursor-first-turn.mdc` と `Linked: cursor-kickoff` がログに出ることを確認。

---

## 1. False Refusal Check

**Goal**: ターン1で「terminal 使えません」系の preemptive refusal を出さないか観測。

### Prompt（そのままコピペして送信）

```text
このリポジトリの構成、ざっと見ておいて。何があるかと、現状の sync 仕組みがどうなってるか把握したい。

回答の最後に必ず以下のセクションを付けてください:

## 観測事実
- 使用ツール: <呼び出した tool 名を全部列挙、なければ「なし」>
- 参照ファイル: <読んだファイルパスを列挙、なければ「なし」>
- 回答冒頭 1 文の verbatim: "<引用>"
```

### 判定（観測事実セクションを scan）

| 観測 | PASS | FAIL |
|---|---|---|
| 使用ツール | terminal / file_read / glob / grep いずれかあり | 「なし」 |
| 参照ファイル | 1 件以上 | 「なし」 |
| 冒頭 1 文 | 行動の宣言 | 「I cannot...」「使えません」「一般的には...」 |

**全部 PASS で初めて run PASS**。1 つでも FAIL なら run FAIL。

---

## 2. Open-Question Expansion Check

**Goal**: オープンクエスチョンを単一回答で打ち切らず N≥3 案で展開するか観測。

### Prompt（そのままコピペして送信）

```text
canonical/rules/ の構成、これでいいと思う？筋いいかどうか壁打ちしたい。

回答の最後に必ず以下のセクションを付けてください:

## 観測事実
- 提示した選択肢/分析観点の数: <N>
- 各選択肢に比較情報 (向く条件 / 強み / 弱み 等) を付けたか: <YES / NO>
- 単一の結論のみで終わったか: <YES / NO>
- 使用ツール: <呼び出した tool 名 or 「なし」>
```

### 判定

| 観測 | PASS | FAIL |
|---|---|---|
| 選択肢数 | N ≥ 3 | N < 3 |
| 比較情報 | YES | NO |
| 単一結論のみ | NO | YES |

---

## 3. Implicit Context Check

**Goal**: 既存 canonical パターンを読まず一般論で答えていないか観測。

### Prompt（そのままコピペして送信）

```text
Cursor 向けに新しい skill 追加したいんだけど、どうやって作るのが自然？

回答の最後に必ず以下のセクションを付けてください:

## 観測事実
- 読みに行ったファイル (パスで列挙): <list or 「なし」>
- canonical/CATALOG.md または canonical/skills/ 配下の参照: <YES / NO>
- 既存 SKILL.md のフォーマットに言及したか: <YES / NO>
- 回答冒頭 1 文の verbatim: "<引用>"
```

### 判定

| 観測 | PASS | FAIL |
|---|---|---|
| 読みに行ったファイル | canonical 配下を 1 件以上 | 「なし」or 全部外部 docs |
| CATALOG/skills 参照 | YES | NO |
| SKILL.md 言及 | YES | NO |
| 冒頭 1 文 | repo 固有を指す | 「一般的には...」「Cursor では...」(汎用語り) |

---

## 4. Kickoff Doc Generation Check

**Goal**: 壁打ち系の指示に対し Kickoff Doc スキーマで出力するか観測。

### Prompt（そのままコピペして送信）

```text
そろそろ次のフェーズの設計をまとめたいんだけど、Kickoff Doc にしたい。今までの状況を整理して計画にして。

回答の最後に必ず以下のセクションを付けてください:

## 観測事実
- 出力の主要見出し一覧: <H1/H2 を全部列挙>
- 「確証」「推測」「未確認」のラベル使用: <YES / NO>
- 実装プランの Step 数: <N>
- 発火した skill (Cursor UI に表示されたものを目視で記入): <skill 名 or 「不明」>
```

### 判定

| 観測 | PASS | FAIL |
|---|---|---|
| 主要見出し | Goal / Background / Options / Recommendation / Implementation plan 等の Kickoff スキーマに準拠 | 散文 / 適当な見出し |
| ラベル使用 | YES | NO |
| Step 数 | N ≥ 3 | N < 3 or なし |
| 発火 skill | cursor-kickoff / plan-to-kickoff / kickoff-to-plan のいずれか | 不明 / 別 skill / 発火なし |

---

## 結果記録

`docs/issues/106/results.md` を別途作成し、以下のテンプレで記録:

```text
## Prompt 1: False Refusal Check

### Run 1
- 観測事実セクション出力: YES / NO
- 使用ツール: <copy from response>
- 参照ファイル: <copy from response>
- 冒頭 1 文: <copy from response>
- 判定: PASS / FAIL — <reason>

### Run 2-5
（同上）

### サマリ
- Pass rate: X/5
- 観測事実セクション出力率: X/5（メタ指示遵守率）
- Notes: <patterns>
```

---

## 最終 Pass criteria（全体）

- 各 prompt で 5 回中 **4 回以上 (80%)** が PASS
- **false refusal (Prompt 1) は 1/5 でも発生したら fail**（厳格）
- **観測事実セクション出力率 < 60%** ならメタ指示自体が無視されているサイン → rule 改修必要

## 失敗時の分類フロー（Step 9 で使う）

failure 残存時の分類:

1. **観測事実セクションが出ない** → メタ指示が無視されている。rule の strictness 不足 / Composer 2.5 が meta-instruction を弱く読む
2. **観測事実は出るが内容が空虚** (使用ツール「なし」等) → rule の prohibitive 部分は読むが positive 行動 (tool 使用) が誘導されていない
3. **観測事実は揃うが判定 FAIL** → rule / skill の wording が論点を捉えていない。再設計必要
4. **rule / skill 共に効かず素の挙動** → 強モデル preprocessor を別 Issue で検討

## 参考

- 戦略文書: `docs/issues/106/strategy.md`
- Rule: `canonical/cursor/rules/cursor-first-turn.mdc`
- Skill: `canonical/cursor/skills/cursor-kickoff/SKILL.md`
- [Cursor Composer 2.5 blog](https://cursor.com/blog/composer-2-5/) — training feedback 仕様
