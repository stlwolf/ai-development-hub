---
id: "01KPXCAQQ8A85GG4WH5FQ5T2AW"
title: "探索プロセスの構造化 — 早期収束バイアスの抑制と Exhaustion Before Conclusion の実装設計"
date: 2026-04-23
type: discussion
status: draft
related:
  - type: sibling
    ref: docs/specs/2026-04-22-discussion-hypothesis-driven-exploration.md
    reason: "Cursor での議論成果。本 discussion は Notion (Claude + ChatGPT) での継続議論を統合"
  - type: evidence_for
    ref: projects/wezterm-ai-mode/docs/episodes/2026-04-22-episode-wez-notify.md
    reason: "TTY direct write 発見プロセス — option C 発見エピソード"
  - type: sibling
    ref: docs/specs/2026-04-06-discussion-multi-round-control-loop.md
    reason: "多周制御の仕様 — findings 収束管理。本 discussion は findings 拡張の方向"
  - type: design_context
    ref: ideas/20260208/hypothesis-second-opinion-review-flow.md
    reason: "SO レビューフローの仮説 — 反証担当の固定"
  - type: design_context
    ref: "#"
    reason: "別プロジェクトの Sentry 調査中に抽出されたコードパス網羅原則（外部リポジトリのため ref 省略）"
tags: [exhaustion-before-conclusion, exploration, so-compare, arena-compare, cognitive-mode, ruler-layer, compare-evolution]
sources:
  - label: "Claude (Opus) — 探索プロセスの設計"
    url: "https://claude.ai/chat/ad8a9834-d191-46b8-a9e2-5a7fc3347d76"
  - label: "ChatGPT — 探索プロセスの設計"
    url: "https://chatgpt.com/c/69e87805-405c-83e8-a1e0-8ce63022eb7a"
---

# 探索プロセスの構造化 — 早期収束バイアスの抑制と Exhaustion Before Conclusion の実装設計

Notion 上の Claude + ChatGPT 議論を統合。Cursor での先行 discussion（[sibling](docs/specs/2026-04-22-discussion-hypothesis-driven-exploration.md)）で抽出された原則を、Issue 化に向けて具体的な設計方針に展開する。

---

## 1. 背景と課題

### 1.1 出発点: 2つの独立エピソードから同一構造が出現

**エピソード A — wez notify の option C 発見（設計判断ドメイン）**

初期選択肢 A/B で確定しかけたところ、人間の即興判断で SO ゼロベースレビューを実施。未探索だった option C（TTY 直接書き込み）が発見され最適解として採用。発見は「確定したけど、もう一回ゼロベースで聞いてみよう」という人間判断に完全依存。

**エピソード B — Sentry 調査のコードパス網羅（バグ調査ドメイン）**

エラー調査で、入力→出力のコードパスに未読区間が残った状態で外部仮説（インフラ差異）に飛んだ。コードを全て読んでいれば 2 ステップで解決するところを 6 ステップかかった。

### 1.2 共通する上位原則: Exhaustion Before Conclusion

> 網羅性が保証される前に結論に飛ぶな。

| バグ調査（コードパス網羅） | 設計判断（wez notify） |
|---|---|
| コードパスに未読区間がある状態で外部仮説に飛ぶ | 選択肢に未探索の代替案がある状態で確定する |
| 「全て読んでから外部仮説に進め」 | 「ゼロベースで代替案を探索してから確定しろ」 |
| 仮説ファイルの外部化でループ検出 | 選択肢の外部化で探索網羅性を可視化 |

### 1.3 LLM の早期収束バイアス

LLM は以下の傾向を持ち、ルール（テキスト指示）だけでは抑制しきれない:

- **もっともらしい局所解への飛びつき**: 1回目からそれなりに筋の通った回答を出すが、最頻出パターン・無難な設計・中庸案に寄っている
- **外部要因への帰着**: 「要件次第です」「ユースケースによります」で判断を外部化し、手元で検証可能な範囲すら試さずに探索を打ち切る
- **表面的多様性**: 「3案出しました」と言いつつ実質同じカテゴリの変奏。独立性がない

canonical/ の設計原則「確定的レイヤーと確率的レイヤーの分離」の境界線上の問題。探索の「質」は確率的（モデル依存）だが、**探索の「構造」は確定的に強制できる**。

---

## 2. 核心の問い

今50%の探索品質で飛びついているものを80%まで引き上げるために、確定的レイヤーで何を強制できるか。

残り20%はエッジケースであり、人間でも「出てきてから対応する」レベル。100%は目指さない。

---

## 3. 確定的に強制可能な構造（設計方針）

### 3.1 出力差分検証ゲート

「3案出せ」ではなく「3案出した上で、各案の差分を構造的に宣言させる」。出力フォーマットとして「この案は案Aと何が違うのか」「どの前提を変えたのか」を明示。hook や post-processing で「差分が実質ゼロの案」を機械的に検出して reject。diff 的発想。

### 3.2 反証フェーズの物理的分離

生成と反証を同一ターンでやらせると、生成した案を自分で擁護する方向にバイアスがかかる。オーケストレーションスクリプトで物理的にターンを分ける — 生成と批判を別 invocation にする。deterministic orchestrator / non-deterministic worker パターンの直接適用。

### 3.3 一次コード検証の義務化

設計レベルの探索でも、検証可能な部分は「実際にコード書いて動かせ」を機械的に要求する。hook で exit code を見る世界。wez notify の option C 発見が成功したのは、提案を「良さそう」で終わらせず即座に検証コマンドを実行したから。

### 3.4 収束条件の明示的定義

「いつ終わるか」を事前に定義する。時間ベース、カウントベース（「N回の探索で新しいカテゴリの案が出なくなったら収束」）など。**収束の判断をモデルに委ねない**。モデルは常に「もう十分探索しました」と言いたがるので、収束判断はスクリプト層がカウントベースで行う。

---

## 4. 既存ツール群のギャップ

| 必要な機能 | 既存ツールの対応状況 | ギャップ |
|---|---|---|
| 確定前にゼロベース再探索 | なし | persistent-exploration は「不可能」判定時のみ発動 |
| 選択肢の拡張（A,B → A,B,C） | arena-compare（発散） | 「知らない選択肢を生成させる」プロンプト構造がない |
| 即時実機検証 | なし | SO/Arena の出力は読むだけ。検証は手動 |
| 検証結果の再注入 | so-compare --prev | 手動チェーン。ループが構造化されていない |
| 多周制御の findings 拡張 | discussion-multi-round-control-loop | findings の縮小は定義済みだが拡張は未定義 |

最大のギャップ: 「A で確定、先に進む」が通常フローで、「確定前にまだ探索する」トリガーがない。

---

## 5. ChatGPT 会話からの知見: compare 系スキルの進化方向

### 5.1 認知モードベースの分類

so-compare / arena-compare の現在の区分は「出力形式ベース」（第二意見 vs 複数案比較）。本質的には「認知操作ベース」で再定義すべき:

- 収束的比較 vs 発散的比較
- 探索（可能性発見） vs 監査（欠陥検出）
- ゼロベース vs 前提依存
- 客観意見抽出 vs 観点指定レビュー

### 5.2 思考制御パラメータ

compare 系スキルの入力を「対象A/B」だけでなく思考制御パラメータまで拡張:

- **ゼロベース度**: 既存前提を尊重 / 部分的に疑う / 白紙化
- **批判強度**: 軽い壁打ち / 論理レビュー / 本気で崩しにいく
- **認識空間**: 局所/全体、短期/長期、実装/設計/運用
- **検証強度**: 壁打ち / 論理レビュー / 一次情報確認 / PoC前提

### 5.3 レビュー依頼パターンの分類

過去のレビュー依頼を認知操作で再分類すると、以下のクラスタが見える:

| パターン名 | 典型依頼 | 求めているもの | 必要機能 |
|---|---|---|---|
| A/B優劣比較 | どっちがいい？ | 比較と推奨 | 観点比較、条件付き結論 |
| 観点追加レビュー | 見落としある？ | 指定外の観点 | 汎用的客観レビュー |
| 批判的レビュー | 穴を潰したい | 欠陥抽出 | Critic ロール、反証 |
| ゼロベース再考 | そもそもこの方向でいい？ | 白紙再設計 | 白紙化、再探索 |
| 採用判断 | 最終的に何を採る？ | 意思決定支援 | 採用/非採用理由 |
| 根拠精査 | 論拠足りる？ | 妥当性評価 | 根拠監査、検証要件 |
| 実務適合レビュー | 現場で回る？ | 現実性評価 | 認識空間指定、運用観点 |
| 長期設計レビュー | 将来壊れない？ | 長期保守性 | 時間軸拡張、拡張性観点 |

### 5.4 強制思考操作のプリセット群

compare 系の次段階として、以下の思考操作をプリセット化:

- **白紙化**: 既存案をいったん忘れて再探索
- **逆前提化**: 今の前提を反転させる
- **批判優先化**: まず欠陥から探す
- **候補飽和化**: 最低N系統出すまで収束禁止
- **却下理由先行**: 採用理由より先に落選理由を詰める
- **条件逆転探索**: どの条件で結論が反転するかを探す
- **比較前提監査**: そもそも比較してよい対象かを見る

### 5.5 ルーラー層の萌芽

「この依頼はどの認知モードに振り分けるべきか」を決める上位層の必要性が見えてきた。ルーティング条件として機能する主要軸:

1. **収束 vs 発散**: 既存候補から選ぶか、候補集合を増やすか
2. **探索 vs 監査**: 可能性発見か、欠陥検出か
3. **ゼロベース vs 前提依存**: 白紙化の強度
4. **設計 vs 実装 vs 運用**: 対象の抽象度
5. **客観抽出 vs 観点指定**: レビュースコープ
6. **検証強度**: 壁打ち〜PoC前提

ただし現時点ではワーカー側の実装が不十分で、ルーラーを独立設計するのは時期尚早。Ralph Loop の運用を通じてルーティング判断のログを蓄積し、将来のルーラー仕様根拠にする。

---

## 6. Claude による客観的分析メモ

### Exhaustion Before Conclusion の実装上の注意

この原則は2つの異なる問題を1つの名前でまとめている。探索空間の未踏領域（wez notify 型 → 選択肢の拡張）と、既知検証パスの飛ばし（Sentry 型 → 検証の網羅）。上位原則は1つ、実装 issue は2系統に分離すべき。

### discussion ドキュメント vs ChatGPT 会話の質の差

Cursor での discussion ドキュメント（sibling の `hypothesis-driven-exploration.md`）の方が質が高い。具体的エピソードから帰納的に原則を抽出しており、2つの独立プロジェクトから同じ構造が出ている。ChatGPT 会話は正しいが一般論からの演繹で空中戦になりやすい。統合にあたっては Cursor 側の具体的知見を軸に、ChatGPT の分類フレームを補助的に使う構成が適切。

### ルーラー層の時期尚早性

現在の compare 系スキルは2つ+αの規模。人間が判断できる規模でルーラーを作るのは過剰設計。先にワーカー側を固め、Ralph Loop の運用を通じてルーティング判断のログを蓄積してから再評価。

---

## 7. Issue 化の方針

作成済み（1–4）: [#75](https://github.com/stlwolf/ai-development-hub/issues/75)・[#76](https://github.com/stlwolf/ai-development-hub/issues/76)（親 [Epic #35](https://github.com/stlwolf/ai-development-hub/issues/35)）・[#77](https://github.com/stlwolf/ai-development-hub/issues/77)・[#78](https://github.com/stlwolf/ai-development-hub/issues/78)（親 [Epic #19](https://github.com/stlwolf/ai-development-hub/issues/19)）。Issue 5（認知モード再定義）は未作成。

### Issue 1: Exhaustion Before Conclusion — 原則の定義と canonical/ への追加

- 上位原則として canonical/ に追加
- 2つのエビデンス（wez notify + Sentry）を根拠として明記
- ドキュメント issue

### Issue 2: so-compare 選択肢拡張テンプレート

- so-compare のプロンプト設計原則に「選択肢拡張セクション」を追加
- 「上記の選択肢以外に技術的に可能な代替アプローチを提案」「検証可能な条件を付与」「なぜ元の選択肢群に含まれていなかったか」
- 次の設計判断で実践して効果を記録
- 最小で即着手可能

### Issue 3: 設計判断における確定前ゼロベース探索の構造化（#19 サブ issue）

- 「設計判断の確定直前にゼロベースSOを最低1回強制」を Ralph Loop の具体的ユースケースとして定義
- persistent-exploration のトリガー拡張（「不可能判定時」→「設計確定前」を追加）
- BeeAI RequirementAgent の min_invocations パターン参照

### Issue 4: コードパス網羅原則の仮説外部化メカニズム（#19 サブ issue）

- Sentry 型の問題に対する実装。Issue 3 とは別系統
- `tmp/hypothesis-NNN.md` の外部化プロトコル
- N個蓄積での hook 介入条件の定義

### Issue 5（将来）: compare 系スキルの認知モード再定義

- 出力形式ベース → 認知操作ベースへの再定義
- 思考制御パラメータの設計
- Issue 2-4 の実践結果を踏まえて着手

---

## 8. 優先順位

1. **Issue 2**（so-compare テンプレート追加） — 最小・即効
2. **Issue 1**（Exhaustion Before Conclusion 原則定義） — Issue 2 の実践と並行
3. **Issue 3**（確定前ゼロベース探索） — #19 Ralph Loop の設計進行と同期
4. **Issue 4**（仮説外部化） — #19 Ralph Loop の設計進行と同期
5. **Issue 5**（認知モード再定義） — Issue 2-4 の運用蓄積後

---

## 9. 関連リソース

- [sibling discussion](docs/specs/2026-04-22-discussion-hypothesis-driven-exploration.md) — Cursor での先行議論
- [wez notify episode](projects/wezterm-ai-mode/docs/episodes/2026-04-22-episode-wez-notify.md) — option C 発見エピソード
- [多周制御 discussion](docs/specs/2026-04-06-discussion-multi-round-control-loop.md) — findings 収束管理
- [Epic #19](https://github.com/stlwolf/ai-development-hub/issues/19) — Ralph Loop / control loop implementation
