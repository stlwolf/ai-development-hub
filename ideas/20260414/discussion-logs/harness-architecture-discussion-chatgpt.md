# ハーネスアーキテクチャの層分離と制御ループ設計 — ChatGPTブレスト

- 日付: 2026-04-14
- AI: ChatGPT
- 形式: Claudeとの壁打ち内容を持ち込んでのクロスレビュー + 追加観点の抽出
- 元URL: https://chatgpt.com/c/69de2dae-b034-83e8-baba-13723cd725c9
- Notion: [AI議論倉庫](https://app.notion.com/p/3f1d512817d54e37b560973cbb60c4bb)

---

## 議論の流れ

### 1. 全体評価: 層分離の本質は「決定性の境界設計」

Claudeとの壁打ちで出た `rules → skills → commands → agents + hooks` の4層分離と、最大ギャップ「制御ループの不在」について評価。

**ChatGPTの分析:**
- このアイデアの本質は「CLIを増やす」ではなく、**LLMに任せる判断の粒度を下げ、システム側に寄せられる部分を構造化していくこと**
- 抽象論ではなく、branch命名・hook統合・parallel session・worktree/virtual env・wez/tmuxの物理基盤まで落として考えている点が設計原則としての強さ
- 3本柱（機械的判断のコマンド寄せ / 非決定的探索の隔離 / 最終適用の決定論的直列化）は一貫している

---

### 2. 強い観点: 3つのコア洞察

**観点1: 層分離の軸が「抽象度」ではなく「決定性」**

普通は rules / skills / commands / agents を責務や抽象度で切りがちだが、この議論では:
- commands/hooks 側 = 決定論的・検証可能
- agents 側 = 非決定論的・探索的

という軸で再整理できる。AIハーネスで破綻しやすいのは抽象度の高低ではなく、どこが再現可能か・揺らぐか・テストできるか・監査可能か。

> このアーキテクチャは「レイヤードアーキテクチャ」というより **determinism boundary architecture** に近い。

**観点2: コマンドの設計単位 = transactional workflow segment**

「1 command = 1 action」ではなく、機械的判断が連続する区間（issue番号取得 → 命名規則適用 → branch作成 → 検証 → 後始末）を1単位とする。

- 監査ログ・再試行・失敗回復・テレメトリの単位もこのセグメントに揃えられる
- 将来的にかなり効く設計

**観点3: 並列探索と本番適用の分離**

並列セッションの成果をそのまま production artifact と見なさず **候補提案** として扱う。

- speculative execution / staging / promotion pipeline の発想に近い
- merge順序問題、hidden conflict、side effect contamination、sessionごとの偶然の成否を切り分けられる
- AIエージェントの作業を「自律実行」ではなく **探索器** として扱う

---

### 3. 追加観点: Claude議論では出なかった6つの視点

**観点A: 制御ループ = 閉ループ制御系（5要素モデル）**

「層ではなく閉ループ制御系」として捉え直す提案。

| 要素 | 役割 |
|------|------|
| Policy | 何を良しとするか。rules, constraints, objectives |
| Planner | どの手順で行くか決める。agent / orchestrator |
| Actuator | 実際に変える。commands |
| Sensor | 状態を観測する。hooks, diff, tests, logs, captures |
| Controller | 観測結果を元に次の行動を決める。loop manager |

controller の責務:
- failure時の再試行方針
- partial success の扱い
- parallel exploration の打ち切り条件
- convergence の判定

> 「制御ループの不在」を埋める次の設計ステップは、レイヤの追加ではなく **controller contract の定義**。

**観点B: policyのcommandへの埋没リスク**

コマンド肥大化より危険なのは **policy が command に埋没すること**。

分離すべき3つ:
- **Command**: 手順・状態遷移・トランザクション境界
- **Policy**: 許可/禁止、優先順位、命名規則、適用条件
- **Context Resolver**: project/environmentごとの差分吸収

**観点C: 仮想環境の3種分離**

| 種別 | 手段 | 目的 |
|------|------|------|
| UI隔離 | pane, tmux, wezterm, session labels | 見える化と人間管理 |
| execution隔離 | shell process, env vars, temp dirs, credentials scope | 副作用抑制 |
| workspace隔離 | git worktree, ephemeral branch, containerized FS, sandbox | 差分衝突防止 |

責務の切り分け:
- `wez` = session fabric
- worktree/container = execution sandbox
- orchestrator = promotion manager

**観点D: 「再実行」より「昇格（promotion model）」が核心**

昇格の粒度候補:
- raw diff
- patch set
- AST-level transformation
- intent + acceptance criteria
- command replay log

初期推奨の4点セット: **intent / evidence / diff / replayable command log**

- diffだけだと意味が残らない
- intentだけだと再現が揺らぐ
- command logだけだと適用条件が見えない

**観点E: hooks削減の本質 = semantic observability**

hooks削減の価値は速度ではなく、**観測点を「外部の事後検証」から「内部の文脈付き検証」へ寄せられること**。

外部hookの限界: 意図を知らない、変更前提を知らない、失敗の意味が荒い、部分成功を表現しづらい

command内部の強み: 入力パラメータ・途中状態・実行意図・失敗箇所・rollback可能範囲を全部持てる

**観点F: セッション管理 = 認知補助（orchestration cockpit）**

複数セッション運用のボトルネックはCPU/IOではなく**人間の認知負荷**。

必要な見える化:
- どのセッションが何を担当しているか
- 現在 phase が何か
- 成功/失敗/保留
- 依存関係
- どの差分が競合しそうか

> `wez` 系は terminal control toolkit というより **orchestration cockpit** に寄せて考えた方が価値が出る。

---

### 4. 懸念点と注意

**懸念1: コマンド中心化しすぎるとエージェントの自由度が死ぬ**

モード分離で対処:
- exploration mode
- production mode
- repair mode
- audit mode

同じ command でもモードで拘束度を変えられると強い。

**懸念2: 直列再実行のコスト問題**

中期では「衝突しない差分は昇格」「衝突するものだけ再実行」に寄せる必要がある。将来的に必要:
- independent patch promotion
- conflict class detection
- dependency-aware merge ordering

**懸念3: session tool と orchestration kernel の混同**

4分割を推奨:
- **session fabric**: pane/session/workspace生成
- **orchestration kernel**: phase管理、依存関係、収束制御
- **domain commands**: PR, branch, review, cleanup など
- **policy pack**: project-specific rules

---

### 5. コア原則の言語化（5本柱）

1. **コア原則**: 非決定的な探索と、決定的な適用を分離する
2. **境界原則**: 機械的判断が連続する区間は command に吸収する
3. **安全原則**: 並列環境は探索のために使い、本番適用は promotion / replay を通して行う
4. **観測原則**: 検証は外部hookの事後確認より、内部commandの文脈付き検証を優先する
5. **基盤原則**: セッション管理は単なる端末操作ではなく、人間の認知補助を含む orchestration substrate とみなす

---

### 6. CLI for AI の評価フレーム

**CLI for AI の4分類:**

| 分類 | 例 | 性質 |
|------|------|------|
| Primitive CLI | session create, worktree create, capture logs, diff summarize | 最小操作の部品、再利用性が高い |
| Workflow CLI | branch create with naming policy, PR prep, review collect, parallel run converge | 機械的判断の連続区間をまとめたもの（今回の議論の主役） |
| Policy-aware CLI | `--project`, `--policy-profile`, `--strict`, `--mode=explore\|apply\|repair` | プロジェクト差分吸収 |
| Orchestration CLI | spawn, monitor, converge, replay, promote | 複数セッション/エージェントの制御 |

**CLI に寄せるべきもの vs 他に残すべきもの:**

- CLI: 入出力が明確、成否判定可能、手順固定、フラグに落ちる差分、証跡が必要
- skill/prompt: 文脈判断主役、複数案比較、曖昧な設計判断、暗黙知の補完
- hook/guard: 最低限の強制、bypass検知、外部安全柵
- orchestrator: 並列/直列切替、再試行ポリシー、収束判定、promotion/replay判断

**今後のツール評価ポイント（5軸）:**

1. 「実行」ツールか「制御」ツールか
2. policy が埋め込みか外出し可能か
3. 証跡が残るか
4. 並列実行後の収束設計があるか
5. vendor固有UIの便利さ vs 抽象化可能性のバランス

---

### 7. 核心的認識

> CLI for AI は「AIがCLIを使う」という話に見えて、実際はもっと大きい。
> **AIに任せる判断と、システムに固定する判断の境界をどこに引くか** という設計の話。

今やるべきは「CLI for AI の実装」そのものより、**CLI for AI の評価フレームを自分の中に作ること**。
