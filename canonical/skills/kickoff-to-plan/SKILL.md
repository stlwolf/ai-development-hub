---
name: kickoff-to-plan
description: Kickoff Documentを実行可能なプランに忠実変換する。省略・要約・gate省きを防止し、全セクション・全チェックボックス・全gateを漏れなくTODO項目に展開する。Cursor Plan Mode変換時、Claude Code Tasks/TodoWrite生成時、キックオフからプラン作成時に使用する。
---

# Kickoff to Plan — 忠実変換スキル

## いつ使うか

- Kickoff Document（`plans/*-kickoff-*.md`）を実行可能なプランに変換するとき
- 既存のプランMD（`plans/*-plan-*.md`）をTODOリストに変換するとき
- 構造化された実装計画をステップバイステップの実行プランに落とし込むとき

**注意: このスキルは「変換」専用。変換中にStep 0の調査コマンドを実行したり、ファイルを探索したりしないこと。まず変換を完了させ、実行は変換後に行う。**

## 対応プラットフォーム

| プラットフォーム | 出力形式 | 特記事項 |
|---|---|---|
| **Cursor Plan Mode** | Plan ModeのTODOリスト | gate/checkpointはTODO項目として実行 |
| **Claude Code（対話モード）** | TaskCreate + プランファイル | タスクは `~/.claude/tasks/` に永続化。Plan Mode中はプランファイル生成 |
| **Claude Code（非対話 / Agent SDK）** | TodoWrite + 構造化テキスト出力 | TodoWriteのid/content/statusにマッピング |
| **その他のエージェント** | Markdown チェックリスト | `- [ ]` 形式で出力 |

出力形式は異なるが、**変換の原則と完全性チェックは全プラットフォーム共通**。

## 変換の原則

### 絶対ルール

1. **省略禁止**: Kickoffの全セクション・全項目がプランのどこかに対応する出力を持つこと（TODO項目またはContext注記）
2. **要約禁止**: 「〜等」「〜など」でまとめない。チェックボックスは1項目1TODO
3. **意訳禁止**: Kickoffの表現をそのまま使用する。項目名、コマンド名、ファイルパス、技術用語を言い換えない。ただし**トランケーション**（情報量が多い場合に先頭部分を残し「…（詳細は [参照パス] を参照）」で省略する）は意訳ではなく許容される。トランケーション時も残す部分はKickoff原文をそのまま使用すること
4. **Gate独立配置**: gate/checkpoint/reviewは実装Stepとは別の独立TODO項目として、対応Stepの直後に配置
5. **順序保持**: Kickoffに記載された実行順序をそのまま維持。Stepの順序を入れ替えない
6. **詳細保持**: 概算時間、コード例、コマンド例、表の内容はTODO項目の説明に含める

### TODO項目とContext注記の区分

Kickoffの要素は2種類に分類して出力する:

| 分類 | 出力先 | 対象 |
|---|---|---|
| **TODO項目** | プラン本体のチェック可能な項目 | 実行・検証・判断を伴う全ての要素 |
| **Context注記** | プラン冒頭の「Context」セクション | 背景情報・参照ファイル一覧・解決済み事項など、実行を伴わない情報 |

**判断基準**: 「完了したかどうか」を判定できるものはTODO。できないもの（背景説明、既に完了した事実）はContext注記。**迷ったらTODOにする。**

**例外: 前提条件となるContext注記。** 解決済み事項が後続Stepの前提条件になる場合（例: 「Phase 3でauto-saveが動作済み」がStep 4のvsix検証の前提）、Context注記に加え、該当Stepの説明にも「前提: [内容]」として再掲する。Context注記のみだと実装時に見落とされるリスクがある。

### Gate変換ルール

Kickoffに含まれるgateの種類と変換方法（全プラットフォーム共通）:

| Kickoff上のgate | TODO での表現 | プレフィックス |
|---|---|---|
| `!! GATE: テスト全パス` | 独立TODO: 「GATE: テスト全パスを確認」（前のStepと次のStepの間） | `GATE:` |
| `!! HG-N: ユーザー作業待ち` | 独立TODO: 「HG-N: [作業内容] — ユーザー完了報告を待つ」 | `HG-N:` |
| `peer-ai-review 実施ポイント` | 独立TODO: 「REVIEW: peer-ai-review — [対象の説明]」 | `REVIEW:` |
| ADR作成チェックリスト項目 | 独立TODO: 「ADR: [判断内容]を記録」（対応Stepの直後） | `ADR:` |
| `← Stage N 完了後、ここで停止` | 独立TODO: 「STOP: Stage N完了 — ユーザーに報告し、Mode切替の指示を待つ」 | `STOP:` |

**プレフィックスは省略不可。** プラットフォームを問わず、gate系TODOはプレフィックスで視覚的に識別できるようにする。

**STOP は最重要gate。** Stage遷移の停止指示（`← ここで停止してユーザーに報告する`）は、CursorのPlan Mode/Agent Mode切替やClaude Codeのタスク区切りに直結する。省略すると後続Stageが意図せず実行される。

**REVIEWのカウント指針。** Stage内手順にpeer-ai-review（例: 「3. peer-ai-review: プランの3者合意を取得」）が含まれ、かつ「peer-ai-review 実施ポイント」セクション（§7等）にも別のレビューポイントが記載されている場合、**これらは別物として個別にREVIEW TODOを生成する**。Stage内のpeer-ai-reviewはプラン全体の合意、§の実施ポイントは特定タイミングでの検証（前提調査完了後、実装後コードレビュー等）であり、目的が異なる。統合しない。

### ADR・Gateの配置ルール

ADRやGateの対応Stepが明示されている場合（例: 「Step 1完了時」）はその直後に配置する。

**対応Stepが明示されていない場合**: ADR/Gateの内容から最も関連するStepを推論し、そのStepの直後に配置する。推論根拠をTODO説明に「（Step Nに関連: [理由]）」として付記する。

### リスクの配置ルール

**デフォルト: 関連Stepの説明に「リスク: [内容] / 対処: [対処方法]」として埋め込む。** 実際のKickoffではリスクは3-5行程度であり、Stepと紐づけることで実装時に参照しやすくなる。

**独立TODOにするケース**: リスクが複数Stepにまたがる場合、または対処方法自体が独立した作業を伴う場合は「RISK: [リスク内容] — 対処: [対処方法]」形式の独立TODOとして配置する。

## 変換手順

### Step 1: Kickoffの全セクションを列挙する

Kickoff Documentを読み、以下のセクション存在チェックを行う。存在するセクションを全てメモする:

```
- [ ] YAMLフロントマター（related, tags, use_when, participants等）
- [ ] 作業開始前の必読ファイル指示（「作業開始前に必ず以下を読むこと」）
- [ ] 実行フロー（Stage 1/2/3）
  - Stage内の番号付き手順
  - Stage間の停止指示（← ここで停止）
- [ ] 目的 / 成功基準
- [ ] 引き継ぎ
  - 解決済み
  - Phase Nで対応が必要（未解決）
  - 既知の制約
- [ ] Pre-Implementation Checklist（事前チェック）
- [ ] ユーザー事前作業（Human Gate前提）
- [ ] Human Gates 一覧
- [ ] 実施計画（Step 0〜N）
  - 各Stepのサブタスク / チェックリスト
  - 各Step内の GATE
  - 各Step内の ADR TODO
  - 条件付きStep（Step 1b, 1c等のフォールバック）
- [ ] リスクと対処
- [ ] peer-ai-review 実施ポイント
- [ ] ADR 作成チェックリスト
- [ ] Technical Details / 補足情報
- [ ] 変更対象コード一覧（テーブル）
- [ ] 調査結果（事前調査済み）
- [ ] 検証マトリクス対応
- [ ] 完了条件 / 成果物一覧
- [ ] Post-Completion / 将来の拡張
```

**存在しないセクションはスキップして良い。存在するセクションは全て変換する。**

### Step 2: セクションマッピングに従って出力を生成する

以下のマッピング表に従い、各セクションをTODO項目またはContext注記に変換する。

| Kickoffセクション | 出力先 | 変換ルール |
|---|---|---|
| **YAMLフロントマター** | Context注記 | `related`の参照ファイルはStep 0の読み込み対象としてTODOにも反映。`tags`/`use_when`等はContext注記のみ |
| **必読ファイル指示** | Pre-Implementation TODO | 「作業開始前に読むこと」の各ファイルを個別のTODO「READ: [ファイルパス] — [目的]」に展開 |
| **実行フロー** | プラン冒頭の構造説明 + STOP TODO | Stage区切りをプランの大構造として使用。Stage間の停止指示は `STOP:` TODOに変換 |
| **目的（散文）** | Context注記 | 問題の背景・現状の課題をContext注記に記載。要約せずKickoff原文の表現を保持する |
| **成功基準（チェックボックス）** | 最終検証TODO群 | 各チェックボックスを個別の検証TODOに展開。プラン末尾に配置 |
| **引き継ぎ（解決済み）** | Context注記（+ Step再掲） | 「前提: [内容]」としてContext注記に記載。後続Stepの前提条件になる場合は該当Step説明にも「前提:」として再掲 |
| **引き継ぎ（対応が必要）** | Step一覧との照合 | Step一覧に含まれていれば重複として省略可。含まれていなければ独立TODOに追加 |
| **引き継ぎ（既知の制約）** | 各Step内の注意事項 | 関連するStepの説明に「制約:」として含める |
| **Pre-Implementation Checklist** | プラン冒頭のTODO群 | Step 0の前に配置。1項目1TODO |
| **ユーザー事前作業** | Human Gate TODOの説明に含める | HG-N TODOの前提条件として記載。具体的な手順を全て含める |
| **Human Gates** | 独立TODO（`HG-N:`プレフィックス） | Gate一覧の各行を独立TODOに。タイミング列の位置に配置 |
| **Step 0〜N** | 番号付きTODO群（プラン本体） | 下記「Step変換の詳細ルール」参照 |
| **条件付きStep（Step Nb等）** | 独立TODO（条件付き） | 「条件: [発動条件]」を付記した独立TODOとして配置 |
| **Step内のGATE** | 独立TODO（`GATE:`プレフィックス） | 該当Stepの直後、次Stepの直前に配置 |
| **リスクと対処** | Step内埋め込み（デフォルト）or 独立TODO | 上記「リスクの配置ルール」参照 |
| **peer-ai-review** | 独立TODO（`REVIEW:`プレフィックス） | 実施ポイントの記載位置に配置 |
| **ADR チェックリスト** | 独立TODO（`ADR:`プレフィックス） | 対応Stepの直後に配置。未指定の場合は内容から推論（配置ルール参照） |
| **Technical Details** | 関連Step内の参照情報 | 補足として関連Stepに含めるか、Context注記に記載 |
| **変更対象コード一覧** | 関連Step内の参照情報 | 変更対象ファイルを関連Stepの説明に含める |
| **調査結果（事前調査済み）** | Context注記 or Step 0 | 調査が完了済みならContext注記。追加調査が必要ならStep 0のTODOに |
| **検証マトリクス対応** | 最終検証TODO群 | 各検証IDを対応する検証TODOに含める |
| **完了条件** | 最終検証TODO群 | 成功基準と統合してプラン末尾に配置 |
| **Post-Completion** | プラン対象外として明記 | 「本プランのスコープ外」として末尾に注記のみ |

### Step 3: Step変換の詳細ルール

各Stepの変換で守るべきルール:

1. **Step番号と名前を保持**: 「Step 0: 前提調査」→ TODO「Step 0: 前提調査（概算: 30分）」
2. **概算時間を含める**: Kickoffに概算時間があれば必ずTODO名に含める
3. **サブタスク展開**: Step内にチェックボックスや箇条書きがある場合、各項目を子TODOとして展開
4. **コード例の保持**: Step内にコード例がある場合、TODO説明にコードブロックとして含める
5. **Gate挿入**: Step内に`!! GATE:`がある場合、Stepの子TODOの最後ではなく、Stepの外に独立gateとして配置
6. **ADR挿入**: ADRチェックリストで対応Stepが指定されている場合、そのStepの直後に独立ADR TODOを配置
7. **条件付きStep**: Step 1b, 1c等のフォールバックStepは、「条件: [発動条件]」を付記して独立TODOとして配置。省略しない

**変換例1: 基本的なStep**

Kickoff:
```markdown
### Step 1: esbuild バンドリング（概算: 1時間）

- `esbuild` を devDependencies に追加
- 拡張用ビルド: `src/extension.ts` → `out/extension.js`（better-sqlite3 は external）
- CLI 用ビルド: `src/cli.ts` → `out/cli.js`（better-sqlite3 は external）
- `package.json` の `scripts` に `build` / `watch` を追加
- `tsconfig.json` は型チェック用に残す（`tsc --noEmit`）
```

Plan:
```
Step 1: esbuild バンドリング（概算: 1時間）
  - esbuild を devDependencies に追加
  - 拡張用ビルド: src/extension.ts → out/extension.js（better-sqlite3 は external）
  - CLI 用ビルド: src/cli.ts → out/cli.js（better-sqlite3 は external）
  - package.json の scripts に build / watch を追加
  - tsconfig.json は型チェック用に残す（tsc --noEmit）
GATE: Step 1 ビルドパス確認
ADR: esbuild の設定方針（external 指定、バンドル対象）を記録
```

**変換例2: Stage遷移の停止指示**

Kickoff:
```markdown
### Stage 1: プラン策定（Agent mode）

1. **コンテキスト読み込み**: 本キックオフ + `CONVENTIONS.md` + 既存コード
2. **プラン作成**: Agent mode で `docs/plans/YYYY-MM-DD-plan-xxx.md` に直接作成
3. **peer-ai-review**: `/peer-ai-review` でプランの3者合意を取得
4. **CP 確定**: 合意内容をプラン MD に反映し、ユーザーに報告

**← Stage 1 完了後、ここで停止してユーザーに報告する。**
```

Plan:
```
[Stage 1: プラン策定]
  1. コンテキスト読み込み — 本キックオフ + CONVENTIONS.md + 既存コード
  2. プラン作成 — Agent mode で docs/plans/YYYY-MM-DD-plan-xxx.md に直接作成
  REVIEW: peer-ai-review — プランの3者合意を取得
  4. CP 確定 — 合意内容をプラン MD に反映し、ユーザーに報告
STOP: Stage 1 完了 — ユーザーに報告し、Plan mode への切替指示を待つ
```

**注意**: Stage内の番号はKickoff原文の番号体系をそのまま使用する（1, 2, 3, 4）。「Stage 1-1」のような独自番号体系を作らない（意訳禁止ルール）。peer-ai-reviewは原文で「3.」だが、REVIEW: TODOに変換されるため番号を付けない。

**変換例3: 条件付きStep**

Kickoff:
```markdown
### Step 1b: SQLite ライブラリ代替調査（Step 0/1 で解明不十分な場合）

- better-sqlite3 以外の選択肢を調査
- sql.js（WASM版）の制約を確認
```

Plan:
```
Step 1b: SQLite ライブラリ代替調査（条件: Step 0/1 で解明不十分な場合）
  - better-sqlite3 以外の選択肢を調査
  - sql.js（WASM版）の制約を確認
```

### Step 4: 完全性チェック

変換後、以下のチェックリストを実行する。**必須チェック（5項目）は全て合格するまでプランを確定しない。** 推奨チェックは合格が望ましいが、合理的な理由があればスキップ可。

**不合格時の手順**: 不合格項目を特定 → 該当箇所を修正 → 再度チェックを実行。修正→再チェックのループは最大3回。3回で解消しない場合は不合格項目と理由をユーザーに報告する。

**数値出力の義務**: 各突合項目は「Kickoff: N件 → プラン: N件」の数値ペアで結果を明示すること。「確認済み」のみの報告は不可。

```
## 完全性チェック

### 必須（全合格必須）
- [ ] Kickoffの成功基準チェックボックス数（N件）= プランの最終検証TODO数（N件）
- [ ] Kickoffの各Stepサブタスク数（N件）= プランの各Step子TODO数（N件）
- [ ] KickoffのSTOP指示数（N件）= プランのSTOP TODO数（N件）
- [ ] 全てのGATEが独立TODO項目である（Stepの子TODOに埋没していない）
- [ ] 「〜等」「〜など」で省略された項目がない

### 推奨: 項目数の突合
- [ ] Kickoffの完了条件チェックボックス数（N件）= プランの成果物検証TODO数（N件）
- [ ] KickoffのHuman Gate数（N件）= プランのHG-N TODO数（N件）
- [ ] KickoffのADRチェックリスト項目数（N件）= プランのADR TODO数（N件）
- [ ] Kickoffのpeer-ai-review実施ポイント数（N件）= プランのREVIEW TODO数（N件）
- [ ] KickoffのPre-Implementation項目数（N件）= プランのPre-Implementation TODO数（N件）
- [ ] Kickoffの必読ファイル数（N件）= プランのREAD TODO数（N件）
- [ ] Kickoffのリスク表行数（N件）= プランのリスク反映箇所数（N件）

### 推奨: 構造の検証
- [ ] 全てのSTOPがStage境界の正しい位置に配置されている
- [ ] 全てのHuman GateがKickoff記載のタイミング位置に配置されている
- [ ] 全てのADR TODOが対応Stepの直後に配置されている
- [ ] Step 0（前提調査）がプランに含まれている（Kickoffに存在する場合）
- [ ] 条件付きStep（Step Nb等）がプランに含まれている（Kickoffに存在する場合）
- [ ] 概算時間がStep名に含まれている（Kickoffに存在する場合）

### 推奨: 内容の検証
- [ ] Kickoffの表現がそのまま使われている（意訳・言い換えがない）
- [ ] コード例・コマンド例がそのまま保持されている
- [ ] リスク表の全行がプランのどこかに反映されている
- [ ] 既知の制約が関連Stepの説明に含まれている
- [ ] 必読ファイルの参照がREAD TODOに含まれている
- [ ] frontmatterのrelated参照がContext注記またはStep 0に含まれている
- [ ] 引き継ぎの「解決済み」がContext注記に含まれている（前提になる場合はStep側にも再掲）
- [ ] 引き継ぎの「対応が必要」がStep一覧に反映されている（Kickoffに存在する場合）
```

## アンチパターン

以下は変換時にやりがちだが、やってはいけないこと:

| NG パターン | なぜNG | 正しい変換 |
|---|---|---|
| 成功基準の複数項目を「成功基準を検証する」1つのTODOにまとめる | 個別項目の検証漏れが発生する | 1チェックボックス = 1 TODO |
| GATEをStepの最後の子タスクにする | 実行時にStepの一部として扱われ、gateとして機能しない | Stepの外に独立TODOとして配置 |
| Stage遷移の停止指示を無視してプランを一気通貫にする | ユーザーがMode切替を行えず、後続Stageが意図せず実行される | 各Stage境界にSTOP TODOを配置 |
| ADR作成を「完了後にまとめて作成」にする | 判断が記憶から薄れ、作成されない | 対応Stepの直後に個別TODO |
| 条件付きStep（Step 1b等）を省略する | フォールバック手段が失われ、メインパス失敗時に手詰まりになる | 条件付きStepも独立TODOとして「条件:」付きで配置 |
| Kickoff文言を意訳・言い換える | ニュアンスが変わり、実装時に原文の意図から逸脱する | Kickoffの表現をそのまま使用 |
| Stage内手順に独自番号体系（Stage 1-1, Stage 1-2等）を付与する | 原文の番号体系と異なり、意訳禁止ルールに違反する | 原文の番号（1. 2. 3. 4.）をそのまま使用。REVIEW: TODOに変換される手順は番号を付けない |
| リスク表を「リスクを確認する」1行で済ませる | 個別リスクの対処が実行されない | 各リスクを独立TODO（デフォルト）またはStep説明に組み込む |
| 概算時間を省略する | 実績との乖離が追跡できない | Step名に`（概算: Xh）`を含める |
| Step 0（前提調査）を省略する | 前提が崩れたまま実装が進む | 必ずプラン先頭に配置 |
| Human GateのユーザーアクションをTODO説明から省略する | 何をすべきか不明になる | ユーザー作業の具体的手順を全て含める |
| 「Technical Details」を全て省略する | 実装時に参照情報が不足する | 関連Stepの説明に含めるかContext注記に記載 |
| 変換中にStep 0の調査コマンドを実行し始める | 変換が中断され、プランが不完全なまま実行フェーズに入る | 変換を完了させてから実行に移る |
| 表形式の情報を文章に変換して列情報を失う | リスクの「影響」「対処」等の構造が失われる | 表形式をそのまま保持するか、各列を明示的にラベル付けする |

## プラットフォーム別の出力方法

### Cursor Plan Mode

Plan Modeで直接プランを構築する。各TODO項目がPlan ModeのUI上のチェック可能な項目になる。

- **TODO粒度: サブタスク単位に展開する。** Task単位（「Task 1: ... 8項目」）ではなく、各サブタスクを個別のTODO項目として登録する。これによりPlan Modeのチェックオフ機能と直接対応し、中間進捗が追跡可能になる
- Context注記: プランの冒頭に「## Context」として記載。Plan本文は最小限に留め、詳細はTODO項目の説明に含める
- Gate/Checkpoint: 独立したTODO項目として配置。実行時にAgent Modeに切り替わって検証される
- コード例: TODO項目の説明に「Kickoff L[行番号] を参照」として原文参照を含める（Plan Modeでは参照のみ、実行はAgent Mode）

### Claude Code（Tasks）

Claude Code の対話モードでは `TaskCreate` / `TaskUpdate` でタスクリストを構築する。タスクは `~/.claude/tasks/` にファイルベースで永続化され、セッション再起動後も保持される。

**注意**: `TodoWrite` は非対話モード（`-p` フラグ）と Agent SDK でのみ利用可能。対話モードでは `TaskCreate` / `TaskUpdate` を使用すること。Plan Mode（`EnterPlanMode` 中）ではプランファイル（`~/.claude/plans/*.md`）が生成されるため、Task登録はPlan Mode終了後に行う。

**IDスキーム（TaskCreate の subject に使用）:**

| Kickoff要素 | subject パターン | description に含める内容 |
|---|---|---|
| 必読ファイル | `read-N: [ファイル名]` | ファイルパス + 読む目的 |
| Pre-Implementation各項目 | `pre-N: [項目名]` | チェック項目の全文 |
| Step番号 + 名前 | `step-N: [Step名]` | 概算時間 + サブタスク全項目を箇条書きで列挙 |
| 条件付きStep | `step-Nb: [Step名]` | 発動条件 + タスク詳細 |
| GATE | `gate-after-step-N` | ゲート条件の全文 |
| STOP | `stop-after-stage-N` | ユーザーへの報告内容 + 次の指示待ち |
| RISK | `risk-N: [リスク名]` | リスク内容 + 影響 + 対処方法 |
| HG-N | `hg-N: [作業名]` | ユーザー作業内容 + 完了条件 |
| REVIEW | `review-after-step-N` | レビュー対象と判定基準 |
| ADR | `adr-after-step-N` | 判断内容と記録先 |
| 成功基準の各項目 | `verify-N` | 検証項目の全文 |
| 完了条件の各項目 | `deliverable-N` | 成果物と確認方法 |

**status の初期値:** 全て `open`。TaskUpdate で完了時に `completed` に変更。

**運用ルール:**
- サブタスクは description 内に箇条書きテキストとして含める（フラットに別Task化しない。ノイズ防止）
- コード例は description 内にインラインで記載。10行を超える場合はトランケーション（先頭3行 + `…（詳細は [ファイルパス] L[行番号] を参照）`）。意訳・言い換えはしない
- Context注記はタスク登録せず、テキスト出力またはプランファイル内に記載する

**非対話モード（`-p` / Agent SDK）の場合:** `TodoWrite` を使用。IDスキームは上記と同一。`merge: false` で初回一括登録、`merge: true` で状態更新。`minItems: 2` 制約に注意（1項目のみの場合はContext注記をテキスト出力し、TODO項目をTodoWriteで登録）

### Markdown チェックリスト（汎用）

上記以外のエージェントや、プランをファイルとして保存する場合:

```markdown
## Context
- 前提: [解決済み事項]
- 参照: [frontmatterのrelated]

## Pre-Implementation
- [ ] READ: [ファイルパス] — [目的]
- [ ] [事前チェック項目]

## Stage 1: プラン策定
- [ ] Stage 1-1: [手順]
- [ ] REVIEW: peer-ai-review — [対象]
- [ ] STOP: Stage 1 完了 — ユーザーに報告

## Step 0: 前提調査（概算: 30分）
- [ ] [サブタスク]

## GATE: Step 0 前提確認
- [ ] [ゲート条件]

## Step 1: [名前]（概算: 1時間）
- [ ] [サブタスク]
## ADR: [判断内容]を記録
## RISK: [リスク内容] — 対処: [対処方法]

## Step 1b: [名前]（条件: [発動条件]）
- [ ] [サブタスク]

...

## 最終検証
- [ ] [成功基準1]
- [ ] [完了条件1]
```

## 変換の開始方法

ユーザーがKickoff Documentを指定したら:

1. 指定されたKickoff Documentを全文読み込む
2. 本スキルの「Step 1: 全セクション列挙」を実行
3. 「Step 2〜3」に従ってTODO項目とContext注記を生成
4. 「Step 4: 完全性チェック」を実行し、不合格項目があれば修正
5. 完全性チェック全合格後、プラットフォームに応じた形式で出力
6. **変換上の判断メモ**を出力する（推奨）

**プラン出力後に、完全性チェックの結果（全項目の合否と具体的な数値）と判断メモをユーザーに報告する。**

### 変換上の判断メモ（推奨）

変換中に解釈が必要だった箇所を記録する。変換の透明性を確保し、ユーザーが判断の妥当性を検証できるようにする目的。

記録すべき判断の例:
- Kickoffに存在しないセクション（Step 0〜N等）をどう解釈したか
- Stage内手順とpeer-ai-review実施ポイントの重複/非重複の判断
- ADR/Gateの対応Stepを推論した根拠
- リスクの配置先の判断（Step内埋め込み vs 独立TODO）
- Context注記にした要素が後続Stepの前提条件になるかの判断
