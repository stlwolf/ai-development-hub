---
title: "情報収集ストリームの継続資料 — 成果物索引・未処理の在庫・再取得手順"
date: 2026-08-20
status: handoff
tags: [handoff, intake, feedly, backlog, continuation]
related_research:
  - docs/research/2026-07-27-loop-engineering-intake.md（ループ軸・Feedly API の実測を含む）
  - docs/research/2026-07-27-team-harness-intake.md（チーム軸）
  - docs/research/2026-07-27-ai-slop-design-process.md（単独）
  - docs/research/2026-07-27-branchbox-container-worktree-isolation.md（単独・defer）
  - docs/research/2026-08-13-enforcement-placement-intake.md（強制力の階段）
  - docs/research/2026-08-13-supervisor-design-intake.md（統括の設計）
  - docs/research/2026-08-17-opus5-rule-shift-intake.md（Opus 5 の前提変化）
related_issues: [24, 130, 194, 263, 281, 286, 293, 305, 307, 309, 313, 322, 326, 327]
next_step:
  trigger: "情報収集を再開するとき / 未処理の在庫に手を付けるとき / Feedly の取得が止まったとき"
  actions:
    - "Feedly から取り直す場合は §4 の手順をそのまま実行する。トークンの失効日を先に確認する"
    - "未処理の在庫（§3）から着手する場合、Goodpatch の 2 点（ループ 4 分類と AGENTS.md の肥大化対策）は #307 に効くので優先する"
    - "未実行のアクション候補（§5）は、対応する Issue に着手するタイミングで消化する。まとめて出すと質が落ちる"
  referenced_by: "docs/BACKLOG.md（在庫のポインタ）/ #307（棚卸し）/ #130（intake の定期自動化）"
---

# 情報収集ストリームの継続資料

## 1. このドキュメントの役割

2026 年 7 月末から 8 月にかけて、Feedly の Read Later に溜めた記事を読み込んでリポジトリの資産へ接続する作業を続けた。その作業は 1 つの会話スレッドの上で進んでいて、成果物は外部化してあるが、**進行状態（何を読み終え、何が残り、どう取得したか）はスレッドの中にしか無かった。**

アカウントの移行などでスレッドを参照できなくなっても継続できるように、状態をここへ移す。新しいセッションはこのドキュメントから入れる。

## 2. 済んでいること

### リサーチノート（7 本）

| ノート | 軸 | 対象 |
|---|---|---|
| `2026-07-27-loop-engineering-intake.md` | ループを閉じる・育てる | 7 件 |
| `2026-07-27-team-harness-intake.md` | 個人ハーネスのチーム移送 | 8 件 |
| `2026-07-27-ai-slop-design-process.md` | ルール集の限界と評価能力 | 1 件 |
| `2026-07-27-branchbox-container-worktree-isolation.md` | 実行隔離（defer） | 1 件 |
| `2026-08-13-enforcement-placement-intake.md` | 強制力をどこに置くか | 5 件 |
| `2026-08-13-supervisor-design-intake.md` | 統括セッションの設計 | 2 件 |
| `2026-08-17-opus5-rule-shift-intake.md` | Opus 5 の前提変化 | 6 件 + 公式 changelog |

合計 30 件の記事を処理した。各ノートに記事情報・本質的パターン・資産マッピング・アクション判定が入っている。

### 起票した Issue（3 件）

- #307 Opus 5 世代の公式指針に照らしてハーネス（rules / skills）を棚卸しする。前提知識と材料をコメント 2 件で渡してある
- #326 統括セッションの責務を棚卸しし、残す作業と投げる作業を分ける。起票前の探索記録をコメントに置いてある
- #327 cockpit のスレッド情報に現在のモデルを表示する。設計は Issue の中で行う前提

### ノートに入っている実測値

- Feedly の Read Later 100 件（すべて 2026 年保存分）の月別取り込み率。`2026-07-27-loop-engineering-intake.md` の「現状測定」節
- Feedly API のレート上限と有効期限。同じ節
- lean system prompt が v2.1.154 から既定という公式 changelog の確認。`2026-08-17-opus5-rule-shift-intake.md` の 1 節

## 3. 未処理の在庫

### 3.1 束 B（4 件・読了済みでノート未作成）

2026-08-05 に保存し、8/06 に軽く読んだ。要点だけここに残す。正式なノート化はしていない。

**実践ループエンジニアリング（Goodpatch Tech Blog）**
https://goodpatch-tech.hatenablog.com/entry/loop_engineering_proc

- ループを 4 つに分類する。Turn-based（手動トリガー）、Goal-based（定量目標）、Time-based（定期実行）、Proactive（イベント駆動）。この 4 分類でスキルを 12 個作った [unverified-summary]
- 停止条件を先に定義する。対象が 0 件なら処理しない、処理済みは重複実行しない、指摘が 2 ターン直らなければ人間に投げる [unverified-summary]
- ループ自体を振り返って育てる retrospective スキルが最重要だと結論している [unverified-summary]
- **`AGENTS.md` が 16 行から 278 行に肥大化した。新しいモデルで効果を失う可能性があるので、定期的に全削除して 1 行ずつ戻す運用を研究中** [unverified-summary]
- 開発スピード 2 倍、テストカバレッジ 3 倍以上という数値は自己申告 [unverified-summary]
- **#307 に効く。** 4 分類は #130（定期）と保留中のイベント駆動構想（Proactive）を置く座標になる。全削除して 1 行ずつ戻す運用は、ルールが積み上がって効果が見えなくなる問題への実務的な対処である

**「網羅的に書いて」では網羅されない — プロンプト 4 パターン（COMPASS）**
https://zenn.dev/qubena/articles/290096df3e83b3

- 抽象的な指示は「何を根拠にするか」「どこまで含めるか」の暗黙の前提が伝わらないので効かない [unverified-summary]
- 4 パターンは、使ってよい情報源を限定するポジティブ制約、用語集を明示的に渡すユビキタス言語の注入、抽象的な品質指示を判定基準と NG 例に翻訳してプロンプト本体に埋め込むこと、生成後に自身へ検査させるセルフチェックの必須化 [unverified-summary]
- **4 つ目は Opus 5 の公式指針と逆を向く。** 公式は自己検証を促す指示の削除を勧めている。世代差が実務記事にどう現れるかの実例として #307 の材料になる

**AI 生成ドキュメントのレビュー体制と Notion 同期（COMPASS）**
https://zenn.dev/qubena/articles/1dbaea899e0c1a

- 職種ごとに PR を分割してレビュー責任を分ける（仕様書はディレクターとデザイナー、Gherkin はエンジニア、テスト項目書は QA） [unverified-summary]
- PR のマージをトリガーに依存関係マップを参照し、影響を受けるファイルを AI が自動更新する [unverified-summary]
- GitHub を正本としつつ Notion へ一方向で同期し、検索やタグを使いたい人の閲覧手段を別に用意する [unverified-summary]
- canonical を 3 ツールへ一方向配布している構成と同型である

**AI ワークフローを CI/CD 化した罠 2 つ（COMPASS）**
https://zenn.dev/qubena/articles/9f9c672c786452

- Phantom Failure。`env` ブロックの中で `needs` 参照や動的な Matrix JSON を使うと静的検証で未解決と判定され、成功しているのに失敗表示になる。回避は `env` を経由せず `needs` から直接参照し、動的な値は個別の `outputs` に分けること [unverified-summary]
- `GITHUB_TOKEN` は実行リポジトリにしかスコープが効かない。クロスリポジトリや bot 名義の PR 作成では Organization の PAT を使い分ける [unverified-summary]
- ノート化の価値は低い。GitHub Actions で AI を回す実装に入るときに開けば足りる

### 3.2 6 月保存の未読（5 件）

- Datadog と AWS が同じ日に出した Ops エージェントは何を奪い合っているのか（2026-06-13）
- alibaba/open-code-review（2026-06-07）。OSS なので `oss-research-session` の案件として起票する候補
- Claude Code トークン枯渇問題と最適化戦略（2026-06-07）
- Claude Code 更新まとめ 脆弱性の自動検知・スキルの自動ロード（2026-06-03）。最も腐りやすい層
- インフラもアプリも同じ AI に書かせたら境界面のズレが消えた（2026-06-03）

### 3.3 それより古い在庫（約 66 件）

2026 年 1 月から 5 月に保存した未取り込み分。内訳は 5 月 11 件、4 月 22 件、3 月 13 件、2 月 11 件、1 月 9 件。

後回しにする判断をしている。理由は、記事が腐ったというより、当時の関心（ハーネスをどう作るか）に対する実装が既に進んでいて相対価値が落ちたためである。

Read Later 全体では 100 件より古いところに数年前の記事も残っている。3〜4 か月前に一度削ったが、まだ残っている。層で切る基準（ツール選定やデファクトは腐る、設計原則や組織プロセスや人間側の認知は腐りにくい）を決めてから一括で処理するのが安い。

## 4. Feedly から取り直す手順

### 前提

- **Feedly Pro が必要である。** 無料プランでは developer token を発行できない（発行ページが Pro へのアップグレードを要求する）
- トークンは `~/.config/feedly/token`、更新用は `~/.config/feedly/refresh_token` に置いてある（パーミッション 600）
- **有効期限は 2026-08-27。** 発行から 30 日。切れたら https://feedly.com/v3/auth/dev で再発行する
- refresh token による更新が回るかは未検証。定期実行に組む場合の唯一の手作業リスクである
- レート上限は 1 日 50 リクエスト。1 リクエストで 100 件取れるので、記事ごとに投げる設計にしないこと

### 一覧を取る

```bash
T=$(tr -d '[:space:]' < ~/.config/feedly/token)
UID_=$(curl -sS -H "Authorization: OAuth $T" https://cloud.feedly.com/v3/profile | jq -r .id)

curl -sS -H "Authorization: OAuth $T" --get \
  https://cloud.feedly.com/v3/streams/contents \
  --data-urlencode "streamId=user/$UID_/tag/global.saved" \
  --data-urlencode 'count=100' -o /tmp/saved.json

jq -r '.items[] | [((.actionTimestamp // .crawled // .published)/1000 | strftime("%Y-%m-%d")),
  (.canonicalUrl // .alternate[0].href), .title] | @tsv' /tmp/saved.json
```

100 件より古いものは応答の `continuation` を `--data-urlencode "continuation=..."` で渡して続きを取る。

### 取り込み済みかを判定する

保存記事の URL が既存のノートや Issue の本文に出典として現れるかで判定できる。文字列一致なので取りこぼしはあるが、月別の傾向は掴める。

```bash
key=$(printf '%s' "$url" | sed -E 's#https?://##; s#/$##')
grep -rl -F "$key" docs/ ideas/
```

## 5. 未実行のアクション候補

ノートで判定済みだが実行していないもの。対応する Issue に着手するタイミングで消化する。まとめて出すと質が落ちる。

### 既存 Issue へのコメント候補（6 件）

| 先 | 渡すもの | 出典ノート |
|---|---|---|
| #305 | 段階的強化の失敗履歴と、機械判定できるものは hook という基準 | enforcement-placement |
| #322 | 宣言的マッチャの誤発火と、境界判定・二重検証 | enforcement-placement |
| #309 | スキップ理由を区別した記録、やらなかったことの記録 | enforcement-placement |
| #293 | 再委譲ループの実害と、AL401 という検査手段 | supervisor-design |
| #194 | probe の spec と findings という返却契約の形 | supervisor-design |
| #281 | 副産物（委譲の発行数）で規律の遵守を数える測定軸 | supervisor-design |

### 保留（defer）3 件

- `careful-operations-rule` に安全装置と信頼境界の区別を書くか（enforcement-placement）
- 静的検査の取り込み方。agentlint をそのまま導入するか、パターンを回収して自前に作るか、見送るか（enforcement-placement に判断軸あり）
- 統括のモデル配置。#326 の責務棚卸しが上流にある（supervisor-design）

### 実験候補 1 件

自リポジトリのレビュー痕跡（Copilot コメントと episode）から `diff-audit` の観点を蒸留できるか、小規模に試す（team-harness）。

### #307 着手時に最初に確かめること

`~/.claude/settings.json` の `env` に `CLAUDE_CODE_SIMPLE_SYSTEM_PROMPT` を `"0"` で置くと長版のシステムプロンプトへ戻る、という記述がある。効くならルールを書き換えずに済む選択肢が増える。公式 changelog に記載がなく一次未確認なので、実機で確かめる。

## 6. 期限のあるもの

- **Feedly の developer token が 2026-08-27 に失効する。** 残り 7 日。切れると取得が止まる。refresh が回るかの検証も未実施

## 7. このスレッドで決めたこと

記録を残さないと同じ議論を繰り返すもの。

- **X（旧 Twitter）からの情報収集は見送る。** 課金が必要で、かつ有象無象から漉す手間が、公式の changelog を直接引く手間を上回る。実際に今回、二次記事で事例を発見し公式で裏を取る流れで一次確認が済んだ
- **PRONI のワンタイム実行基盤の記事は、AI ハーネスの材料としては取り込まない。** インフラ作業側の関心で拾ったもので、参照する価値は 2 点だけ（GitHub 内の承認機構は侵害時に無効になる、#262 に対する論拠になる）。enforcement-placement ノートの「取り込み対象外」節に記録済み
- **リサーチノート 4 本の日付は正しい。** 一時「ファイル名の日付が 1 週間ずれている」と報告したが、ファイルの更新時刻を確認したところファイル名と一致していた。誤報だった。リネームは不要である
- **Read Later の全件棚卸しは、1 件ずつ AI に精査させない。** 3〜4 か月前にその方法で数十件削ったがコストが高く、まだ残っている。タイトルと保存日で層に切ってから判断する
