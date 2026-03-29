# メタデータ層を使ったAI向けリポジトリ構造の自動同期 — マルチAIブレスト統合

- 日付: 2026-03-29
- 性質: ブレスト統合（Claude + ChatGPT）。2つの独立した議論を統合・整理。
- derived_from:
  - [discussion-logs/metadata-layer-discussion-claude.md](discussion-logs/metadata-layer-discussion-claude.md) — Claude (Opus 4.6 Extended) との壁打ち（音声入力ベース）
  - [discussion-logs/metadata-layer-mirror-repo-discussion.md](discussion-logs/metadata-layer-mirror-repo-discussion.md) — ChatGPT との議論（所感・分析・正規形比較・意味論層・北極星概念）
- related_ideas:
  - [20260208/hypothesis-intentional-compression-and-promotion-flow.md](../20260208/hypothesis-intentional-compression-and-promotion-flow.md) — 三層構造 + 昇格フロー
  - [20260220/context-persistence-4layer-model.md](../20260220/context-persistence-4layer-model.md) — コンテキスト永続化4層モデル
  - [20260218/discussion-log-inference-ratio-domain-boundaries.md](../20260218/discussion-log-inference-ratio-domain-boundaries.md) — ルーラーエージェント構想
  - [20260121/episodic_memory_data.md](../20260121/episodic_memory_data.md) — エピソード記憶的データ分類

---

## 構想の核心（一文）

> AIの長期記憶基盤を作るというより、Gitイベントを起点に開発判断を軽量な構造化レコードとして自動蓄積し、それを元にAI向け・人間向けの文脈ビューを派生生成する仕組み。

---

## 着想

Oh My Open Codeの「プロジェクト全体に階層的AGENTS.mdを生成する機能」をきっかけに、本筋リポジトリを汚さずAI専用のメタデータ階層を自動生成・同期するシステムを構想。Claude、ChatGPTそれぞれと独立に壁打ちした結果、以下の共通認識に収束した。

---

## 議論の経緯と収束

### Claude との議論で見えたこと

1. **orphan branch + worktree パターン**: 最初の実装候補として提案。同一リポジトリ内でメタ層と本筋が共存しつつ `.gitignore` で完全分離。同期は post-commit hook
2. **保存場所問題**: sui-memory（ローカルSQLite）やgit notes との比較。「ソースデータはgitで同期、インデックスはローカルで再構築」（npm install型パターン）
3. **「全部取っておく必要があるのか」**: ここが転換点。エピソード記憶 vs 意味記憶の議論を経て、**意思決定のスナップショットだけ残せば十分** という結論に到達
4. **5フィールドの決定記録**: when / what / weight / status / scope。ADRの理想をLLM自動抽出で初めて実現できるという構図
5. **2層分離**: 人間が書く層（ADR/README）と自動生成メタ層を明確に分ける
6. **Ralph Loop との接続**: 決定記録は Ralph の progress.txt を構造化・自動化したもの。第三者的に自動生成される点が差異
7. **正規化とビューの分離**: 保存の正規形 / AIへの投影 / 人間への投影を分けて考える。CLAUDE.mdに全部書こうとする発想からの脱却

### ChatGPT との議論で見えたこと

1. **3層整理**: 明示ドキュメント層 / 自動生成の決定記録層 / 一時的な生ログ層。Claude議論の2層に生ログ層を加えた構成
2. **「コミット = 決定」への修正**: コミットは「決定の痕跡候補」であり決定そのものではない。LLMに判定させるフィルタリング層が必要
3. **スキーマ拡張**: 5フィールドでは rationale と evidence が欠けており後から弱い。最終的に10フィールド案（when / scope / kind / status / importance / decision / rationale / evidence / alternatives / actor）
4. **ledger 正規形 vs tree 正規形**: 詳細比較の結果、**ledger を SoT、tree を materialized view** とする結論
5. **仮想的な意味論層**: 物理実装層 / 論理メタ層 / 投影層の3段構造。ledger も実は中間形であり、本質は「意味グラフ + イベントログ」
6. **repo 構造は偶然ではなくアーキテクチャの表明**: path を主キーにしない、ただし primary projection axis として強く採用する。tree-first but not tree-only
7. **北極星としての mirror repo**: 単なる説明層ではなく、理想状態・責務境界・方向性を示す規範層。ただし immutable truth ではなく revisable guidance
8. **人間の理解の起点は物理層**: 抽象モデルから始まらない。repo tree は人間の理解の足場であり、mirror repo はそこに意味を重ねるもの
9. **AI の有限コンテキストと中間層**: mirror は文脈ルーティング層。単なる要約ではなく「意味を保ったまま探索範囲を絞る圧縮」

### 交差点と相違点

**収束した点:**
- Decision Ledger を SoT とし、tree/AGENTS.md は派生ビューとする
- 全会話ログの保存より決定記録の方が費用対効果が高い
- 人間が書く明示文書と自動生成メタは分離すべき
- MVP は post-commit hook + 軽量LLM の非常駐構成で十分
- 保存の正規形と読み出しのインターフェースは分離すべき

**Claude 側の強み:**
- 実装イメージの具体性（orphan branch, worktree, hook スクリプト）
- Ralph Loop / 司書エージェントとの接続
- 「ゼロが10になるだけで劇的に違う」の洞察

**ChatGPT 側の強み:**
- 正規形比較の網羅性（ledger vs tree の詳細分析）
- 仮想意味論層の概念導入（物理 / 論理 / 投影の3段）
- 北極星・規範層としての発展的概念
- 「保存すべきは情報か、判断か、再構築可能性か」の問いの深掘り

**相違点:**
- Claude: 5フィールド + 2追加（rationale, evidence）= 7フィールドで十分 → ChatGPT: 10フィールドが実用的な最小線
- Claude: orphan branch + tree 構造を前提 → ChatGPT: 最初は flat ledger で十分、tree は後
- Claude: 「エピソード記憶の方が意味記憶より残りやすい」の指摘 → ChatGPT: この視点は出ていない
- ChatGPT: mirror repo は「プロジェクトの意味論的OS」にもなりうる → Claude: そこまでは言っていない

---

## 収束した設計判断

### 1. SoT は Decision Ledger

判断をレコードとして時系列に蓄積する append-only log が正規形。理由:
- 失いたくないのは「決定の事実」
- 履歴の追跡に強い
- 衝突しにくい（append-only）
- 後から任意のビューを生成できる

### 2. Tree は派生ビュー

repo 階層に対応した AGENTS.md / summary は ledger からの派生物。SoT ではない。
- ただし「単なるビュー」以上に重要: 人間の理解の足場として機能
- repo tree を primary projection axis として強く採用しつつ、乖離した部分だけ論理メタで補正

### 3. 最小スキーマ（MVP + 実用線）

**MVP（7フィールド）:**

| field | 意味 |
|---|---|
| `when` | タイムスタンプ |
| `scope` | 影響範囲（path / domain） |
| `status` | decided / tentative / reverted / superseded |
| `importance` | high / medium / low |
| `decision` | 決定内容（1〜2行） |
| `rationale` | 理由の短文 |
| `evidence` | commit hash / PR / issue / doc link |

**実用拡張（+3フィールド）:**

| field | 意味 |
|---|---|
| `kind` | architecture / implementation / convention / ops |
| `alternatives` | 却下候補があれば短く |
| `actor` | 人間 / agent / mixed |

### 4. 実装の起点は post-commit hook

- 入力: `git diff`, commit message, branch名, PR title/body
- 処理: LLM に「これは決定か雑修正か」を判定させ、決定なら7フィールドを抽出
- 出力: `meta/decisions.jsonl`
- 常駐プロセス不要、作業エージェントの会話履歴へのアクセスも不要

### 5. Ralph Loop との位置関係

- Ralph = 進捗メモ（実行ループ・状態復元・次の一手の継続）
- 今回の決定記録 = 判断メモ（判断の永続化・検索可能化・文脈復元）
- 別責務だが情報の流れとしてはつながる: worker がコミット → 決定記録が自動生成 → 次の worker セッション起動時に司書エージェントが関連する決定を選んでキックオフに含める

### 6. 保存と読み出しの分離

| レイヤー | 役割 | 最適形式 |
|---|---|---|
| 保存の正規形 | 追記しやすさ・スキーマ安定性 | JSONL ledger |
| AI への投影 | トークン効率・段階的ロード | tree / compact summary |
| 人間への投影 | path対応・可読性 | AGENTS.md / ADR候補 |

同じ元データから用途ごとに違う形に投影する。DBの正規化とビューの関係そのもの。

---

## 新たに浮上した概念

### 仮想的な意味論層（ChatGPT議論発）

メタの正体は物理配置されたファイル群ではなく、仮想的な知識空間:

1. **物理実装層**: repo / directory / file / commit / PR
2. **論理メタ層**: 意味的なノードと関係（concern, decision, constraint, domain）
3. **投影層**: 利用時に実装都合に合わせて展開（path別、domain別、AI kickoff用、人間向け）

正規形は ledger ですらなく、突き詰めると **意味グラフ + イベントログ** に近い。ただし MVP ではこの抽象度まで持ち込まない。

### Mirror Repo の北極星的性格（ChatGPT議論発）

mirror が持つ情報の内部階層:
- **A. 観測された事実**: この決定があった、この path が変わった
- **B. 解釈された意味**: この変更は auth concern に属する
- **C. 規範・北極星**: auth はここまでを責務とするべき

C まで含めると mirror は「プロジェクトの意味論的OS」になる。ただし immutable truth ではなく **revisable guidance** として扱う。

### エピソード記憶と再構築可能性（Claude議論発）

- 意味記憶（原則）よりエピソード記憶（具体的判断の瞬間）の方が残りやすい
- エピソードが残っていれば意味記憶は再抽出可能
- 蒸留の精度が低ければ元データを失った時点で回復不能 → **印象的なエピソードを選択的に残し、原則はオンデマンドで再抽出する** 方が安全
- LLMの応答は再現不可能（確率的）→ 会話ログそのものが一次資料としての価値を持つ

---

## Phase 計画

### Phase 1: Decision Ledger（MVP）

flat ledger としての決定記録。JSONL で7フィールド。post-commit hook で LLM に判定・抽出させ、決定のみ追記。保存先は `meta/decisions.jsonl` か orphan branch の単一ファイル。tree 構造はまだ作らない。

### Phase 2: Path / Domain 別ビュー

ledger に対する path 別・domain 別のフィルタリングビュー生成。ここで初めて「階層っぽさ」が出る。ただし元データは一元管理のまま。

### Phase 3: Directory Summary / AGENTS.md 自動生成

ledger の内容を蒸留して、ルート概要・ディレクトリ概要・関連設計判断を自動生成。最初の構想にあった「階層的 AGENTS.md」「AI 向け summary tree」「司書エージェント向け入口」が効いてくる段階。

---

## 未解決の課題と次の論点

1. **「決定」の判定精度**: コミットが決定なのか雑修正なのかの自動判定。LLM に任せる前提だが精度は未検証
2. **メタ生成コスト**: 毎コミットか PR 単位か。差分ベースで影響範囲のメタだけ更新する仕組みの設計
3. **複数人同時更新のロック戦略**: orphan branch の場合、マージコンフリクトは基本起きないが設計上の考慮は必要
4. **記憶のアクセス抽象化**: MCP経由の統一インターフェースでモデル非依存にアクセスする設計
5. **北極星層の安全性**: 規範的メタが間違った場合の修正フロー、revisable guidance としての運用設計
6. **保存すべきは情報か、判断か、再構築可能性か**: 保存の優先順位は「判断 > 理由 > 証跡 > スコープ > 生の過程」の仮説。検証が必要
7. **mirror repo の各ディレクトリノードが持つべき最小情報セット**: Phase 2/3に進む際に必要な、ディレクトリ単位のメタデータのスキーマ設計

---

## 既存 ideas との接続

### 三層構造 + 昇格フローとの関係

[20260208/hypothesis-intentional-compression-and-promotion-flow.md](../20260208/hypothesis-intentional-compression-and-promotion-flow.md) の Context / Decision / Episode の三層と、今回の 明示ドキュメント層 / 決定記録層 / 生ログ層 はほぼ同型。違いは今回の方が Decision 層の自動化（post-commit hook + LLM）に踏み込んでいる点。昇格フローの「Episode → Decision → Context」は今回の Phase 計画（ledger → view → AGENTS.md）と対応する。

### コンテキスト永続化4層モデルとの関係

[20260220/context-persistence-4layer-model.md](../20260220/context-persistence-4layer-model.md) の層2（構造化ナレッジ）が今回の Decision Ledger に、層3（生ログ）が一時的な作業記憶に対応。4層モデルで「層3の抽出パイプラインが未実装」とされていたボトルネックに対して、今回の post-commit hook + LLM が具体的な実装候補を提示。

### ルーラーエージェントとの関係

[20260218/discussion-log-inference-ratio-domain-boundaries.md](../20260218/discussion-log-inference-ratio-domain-boundaries.md) のルーラーエージェント（過去の判断に基づくガイド）が読むデータの永続化層が、今回の Decision Ledger に対応。ルーラーは新規判断はせず決定記録をナビゲートするだけなので、ledger の検索可能性が直接ルーラーの精度を決める。

### エピソード記憶データとの関係

[20260121/episodic_memory_data.md](../20260121/episodic_memory_data.md) の意味記憶(What) vs エピソード記憶(Why/When/How) の分類が、今回の「エピソード記憶の方が残りやすく、そこから意味記憶は再抽出可能」という洞察と接続。Decision Ledger は構造化されたエピソード記憶として機能する。
