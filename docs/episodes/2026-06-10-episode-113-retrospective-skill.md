---
id: "01KTS0260KD29DP2J7HPKJWRTV"
title: "Issue #113 episode-retrospective skill 新設 — ゼロベース設計と SO ゲートの記録"
date: 2026-06-10
type: episode
status: stable
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/113"
    reason: "本作業の対象 Issue（Episode closure 時の構造化振り返りスキル新設）"
  - type: evidence_for
    ref: "docs/research/2026-06-10-episode-quality-audit.md"
    reason: "設計の主根拠（52 episode 全数監査・法則 L1〜L8・提言 R1）"
  - type: design_context
    ref: "docs/episodes/2026-06-10-episode-149-audit-meta.md"
    reason: "skill 出力の実質プロトタイプ（自己適用 1 例目）。本 episode は 2 例目"
  - type: integration_target
    ref: "canonical/skills/episode-retrospective/SKILL.md"
    reason: "本作業の成果物"
tags: [episode, retrospective, skill, closure, issue-113, zero-base, so-gate]
---

# Issue #113 episode-retrospective skill 新設 — ゼロベース設計と SO ゲートの記録

## Context / なぜ

Episode の closure 品質（消費者明示・routing・status 確定）が全コーパスで最弱という監査結果（#149 → PR #153）を受け、closure 時の構造化振り返りを skill 化する Issue #113 を、フレッシュスレッドがゼロベース原則（先行議論を読む前に一次原理から設計 → 突合）で担当した。

## 次の消費者

- **#62（negative knowledge 注入側）の設計者**: 本 skill の出力型「原則」「蒸留シグナル」が注入フォーマットの入力契約になる。closure 側のフィールドから逆算すること
- **R4 同期ゲート（branch-finish / PR フロー組込み）の実装者**: 本 skill が「助言であり同期ゲートではない」と明記した制約の解消が仕事になる
- **次に episode を closure する全エージェント**: skill 本体が直接の消費物

## 作業の流れ（要約）

1. **ゼロベース設計**: #113 コメント群・PR #153 を読む前に、一次原理（価値=消費される / 負の知 > 正の知 / 「なぜ」はコードから不可視）から設計案を起草し、突合基準線として確定
2. **突合**: #113 本文 + コメント 8 件 + 監査ノート + 149-audit-meta を読み、一致・不一致を記録
3. **オーナーゲート 3 分岐**: ①骨格 = 出力型×消費チャネル + KPT は皮 ②失敗捕捉 = tier 別外部チェック ③監査 R2 を同 PR に含める
4. **プラン SO（Codex + Claude opus/high）**: 両者が独立に同じ 4 欠陥を指摘 → プラン v2 へ反映してオーナー承認
5. **実装**: SKILL.md 新設 / spec-card routing 行 / document-format.md R2 編集 / CATALOG 追加
6. **実装後 SO（Codex + Claude opus/high）**: should-fix 3 件（tier 判定順の論理穴 / document-format との任意・必須衝突 / 本 episode 自身の closure 未完遂）を捕捉 → 全件反映して closure（要点は closure 節に転記）

## 決定と根拠

- **骨格 = closure gate checklist + 出力型×消費チャネルの内容プロンプト + 任意の KPT/YWT 皮**。監査 R1-4 の「KPT+YWT ハイブリッド」は採用せず格下げ。根拠: 監査の主結果（枠組み選択は主要因でない、穴は closure 軸）+ オーナー 2026-06-10 コメント（振り返り枠は感想カテゴリでなく出力型×消費チャネルで定義）。マージ済み提言からの意図的逸脱として記録する
- **内容セクションは必須テンプレにしない**（該当時のみ・空欄穴埋め禁止）。棄却案 = 全セクション必須のフルテンプレ。根拠: 監査 L2/L3（2026-05 のテンプレ化が蒸留を 1.82 → 1.32 に下げた）と design-principles §4（手段指示は構造化セクション限定）
- **opt-out を正当な closure として定型化 + 客観的失格条件**。棄却案 = フル振り返りか無かの二択。根拠: オーナー実運用観察「振り返るほどでもない closure が普通にある。摩擦 = skip = episode ごと消える」
- **heavy tier 判定は印象でなくトリガ列挙**。棄却案 = エージェントの自己判定。根拠: 別リポ実証で自己評価は 3 観点中 2 つで甘い（Problem 自己検出率 0）
- **R1-5（back-propagation）は routing に内包、R1-6（evidence anchor）は条件付き必須**。棄却案 = 独立セクション化（低頻度事象に常設セクションは過剰）

## 事実・失敗

- ゼロベース案は「どのセクション集合が最適か」に注力したが、監査が示す本丸（closure gate）から見れば重心がずれていた。突合で修正
- プラン v1 は監査 R1 の優先順 5・6（back-propagation / evidence anchor）を取りこぼした。SO（Codex・Claude 両方）が独立に指摘
- プラン v1 の Step 1 精読範囲（design-principles §2/§3/§5）から、テンプレ化リスクの中核を握る **§4 を漏らした**。Claude SO が捕捉。「参照すべき節を自分で選ぶと、設計に都合の悪い節が落ちる」の実例
- ゼロベース基準線にあった「決定と根拠」「蒸留シグナル」を、チャネル骨格への変換時に自分で落とした（オーナーコメントの表にも軸2 相当が無く、一般化の過程で揃って脱落）。SO が基準線との突合で検出 — **基準線を文書として固定していたから検出できた**
- SKILL.md 初版の tier 判定に論理穴: heavy トリガ該当かつ失格条件ゼロの episode が opt-out 可能に読めた（判定順が未定義）。プラン SO・自己適用でも見逃し、**実装後 SO（Claude レーン）が捕捉** → 「heavy → opt-out → standard」の評価順を明文化して修正
- 本 episode 自身が初版で「実装後 SO は後で追記」というプレースホルダを含み、両 SO レーンに**自スキルの L4 禁則（後で追記は 100% 不履行）そのもの**と指摘された。プロセス上は SO 反映後に closure する設計だったが、書き方が dangling だった → 本反映で解消

## わかったこと

- ゼロベース → 突合は、先行議論と独立に収束した点（消費者ゲート = 監査 L1）に corroboration 価値を与える。一方で先行議論の方が成熟している領域では「自分の案の何が劣るか」の検出器として機能する。どちらに転んでも収穫がある
- SO 2 レーンが独立に同じ欠陥群を突いたとき、その指摘は採用してよい確度が高い（プラン SO では 4 欠陥すべてが両レーン一致）
- `gh issue view` がコメント非表示デフォルトであることが、封印付きゼロベースの実装を容易にする（149-audit-meta の知見を本作業でも再確認）

## 蒸留シグナル

- **skill 候補**: 「封印付きゼロベース手順」（基準線を文書固定 → 読む → 突合記録）は #149 と本作業で 2 例目。3 例目が出たら手順スキル化を検討 → 行き先: 追わない（次の該当タスクで再評価）
- Decision / rule 昇格候補: なし（本作業の決定は SKILL.md 本文に正本化済み）

## 残課題（routing 済み）

- rubric before/after 測定（軸5・軸3）の実施 → 行き先: 別doc（skill 本文「効果測定」節が経路の正本。実施トリガ = 導入後 episode の蓄積）
- R4 同期ゲート（branch-finish / PR フローへの closure チェック組込み）→ 行き先: Issue #156（本作業で起票）
- 実行ログマーカー × 失敗セクションの機械突合 → 行き先: 追わない宣言（監査 R3 の defer をオーナー受諾済み。再判断トリガ = #149 B 検証 + 対照群の追記型移行データ）
- `.oe/` の手元ノート（ゼロベース基準線・SO 出力）は gitignore 対象の揮発パスのため、要点を本 episode に転記済み（evidence anchor 自己適用）

## 形式メモ（skill 効果測定用）

- チャネル骨格で拾えたもの: 決定と根拠（5 件）・失敗（4 件）・蒸留シグナル（明示「なし」含む）が自然に埋まった。「次の消費者」が routing の書き方を具体化した
- 拾えなかったもの: 特になし。ただし「わかったこと」と「原則」の境界は曖昧（本 episode では原則セクションを立てず、わかったことに寄せた）
- 皮（KPT/YWT）: 使わず。骨格のみで人間可読性は維持できている感触
- 摩擦: tier 判定と失格条件チェックは数十秒で済む。形式メモ自体が最も「書かされている」感がある（3 例目以降で要否再評価）

## closure（gate checklist 自己適用）

- tier: **heavy**（外部レビューレーン使用・非自明な設計判断・失敗あり）
- 次の消費者: 明示済み（上記）
- follow-up routing: 全件行き先付与済み（上記。行き先 = #156 / 別doc / 追わない宣言）
- status: **stable** で確定（達成度: 達成）
- SO 証跡（出力は gitignore 対象の `tmp/` のため要点を転記 — evidence anchor 自己適用）:
  - プラン SO = `tmp/so-20260610-232846/`（Codex 102s / Claude opus-high 354s、両者成功）。両レーン一致の 4 欠陥: R1-5/6 脱落・出力型 2 欠落（決定と根拠 / 蒸留シグナル）・opt-out 無防備・heavy チェック形骸化リスク → プラン v2 に全件反映
  - 実装後 SO = `tmp/so-20260610-235008/`（Codex 201s / Claude opus-high 238s、両者成功）。should-fix 3 件: ①tier 判定順の論理穴（heavy 優先を明文化）②document-format FB「任意」と skill gate「必須」の衝突（必須 2 項目の注記を追加）③本 episode の closure 未完遂（status 確定・routing 修正・本転記で解消）。Codex の「新規ファイル未追跡」指摘はコミット順序の問題として PR 作成時に解消
