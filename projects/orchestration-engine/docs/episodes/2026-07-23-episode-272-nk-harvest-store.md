---
id: "01KY6VTZPHWD0F23GKVCBGWJTT"
title: "#272 negative knowledge ループ 段1+2 — 収穫スキーマと型付き store の実装"
date: 2026-07-23
type: episode
status: stable
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/272"
    reason: "実装対象の issue(段1 収穫 + 段2 保存)"
  - type: derived_from
    ref: "projects/orchestration-engine/docs/discussions/2026-07-21-discussion-negative-knowledge-loop-foundation.md"
    reason: "設計正本(6段骨格・DJ-1〜5・§6 未決論点)"
  - type: design_context
    ref: "https://github.com/stlwolf/ai-development-hub/issues/263"
    reason: "型付き層の両輪・スキーマ語彙の整合"
tags: [negative-knowledge, orchestration-engine, knowledge-store, episode-272]
---

# #272 negative knowledge ループ 段1+2 — 収穫スキーマと型付き store の実装

## Context / なぜこの作業が始まったか

negative knowledge ループ(episode の教訓を次の作業へ機械的に読み戻す自己修正ループ)の6段骨格のうち、段1(収穫)と段2(保存)を土台として実装する。episode の消費側が欠落してループが閉じていない現状(昇格率 13〜19%・読む人のいない義務は守られない)を、committed の型付き knowledge store + closure 時の収穫手順 + 機械検証で塞ぐ第一歩。設計正本は 2026-07-21 の discussion、実装方針は #272 の gate 0 / gate 3 コメントで確定。

## 作業の枠組み

- plan(作業層): `.oe/plan-272-nk-store.md`(gate 3 承認済み・設計SO 後に改訂)。
- 設計SO(gate 2): `.oe/so-272-design-findings.md`(codex + cursor 返却・claude timeout の partial)。F1〜F12 を plan に fold、B1/B2 は owner GO 済み。
- branch: `feat/#272_nk-harvest-store`。

## Step ログ(随時追記)

### Step 0: worktree + episode 枠(2026-07-23)

- worktree を自作(`wt switch --create feat/#272_nk-harvest-store --base master`)。cwd は Claude Code では追従しないため以後は絶対パスで作業。
- 本 episode 枠を作成。以後リアルタイム追記。

### Step 1: 検証スクリプト + テスト(2026-07-23)

- `projects/orchestration-engine/scripts/validate-knowledge.sh` を実装。`validate-board.sh` の idiom(exit 0/1/2・advisory・frontmatter 抽出)を踏襲しつつ、frontmatter がネスト(source.ref)・配列(observations/exclusions)・enum を持つため yq(YAML→JSON)+ jq で検査する。単一ファイル + directory mode(直下 `*.md` 非再帰)対応。
- yq の挙動を事前確認: 無引用 `date: 2026-07-23` は JSON 文字列化・scalar root は非 object として検出可・malformed YAML は yq exit 1(= schema 違反 exit 1 に写す。環境エラー exit 2 と分離)。
- `projects/orchestration-engine/tests/test_validate_knowledge.sh` を実装(61 assertion・正例/負例/directory mode/exit 分離を網羅)。設計SO で挙がった負例契約(malformed=exit1・source.ref 揮発/絶対/不存在・observations 空必須・prose 可視文字・非 .md)を固定。
- source.ref 存在確認は `OE_KNOWLEDGE_REPO_ROOT` で基点を上書きしテストを決定化(validate-board の `OE_BOARD_NOW_EPOCH` と同型)。
- つまずき: テスト[10](source scalar)の fixture 構築で sed の範囲削除 + 先頭 prepend が `source:` を開始 `---` の上に置き frontmatter を壊した。validator は正しく「frontmatter block not found」を検出(= validator は正常・テスト側のバグ)。awk による見出し+次行の 1 行 scalar 置換に修正し 61/61 PASS。
- shellcheck: validator・テストとも PASS。

### Step 2: store + README + 規約追記(2026-07-23)

- store: `docs/knowledge/items/`(ULID item のみ)+ `.gitkeep`(cold-start・空 store は validator で OK)。README は親 `docs/knowledge/README.md`(スキーマ例 fenced・B1)に置き、items/ には live sample を置かない(段3 汚染回避)。既存の自由記述ノート(`docs/knowledge/*.md`)とは items/ サブディレクトリで隔離。
- `canonical/orchestration-spec/document-format.md`: §2 intro + 一枚絵に「committed 状態 store 層」を追加、§2.5 で位置づけ(文書でなく状態 store)、§3.4 で `knowledge` を独立 store item 型として定義(必須9項・独自 status enum・ULID ファイル名の §9 逸脱と理由・§4〜§9/§15 の carve-out・採用先向け置き場規則)、§13.3 + §13.6 に第3昇格経路を追記。**#3.1 の閉じた5型 enum・#19 ゲート・§2.4 番号は不変**(回帰なし)。
- `canonical/skills/episode-retrospective/SKILL.md`: Step 3 の原則/蒸留シグナル行を store へ接続、Step 5(収穫)を追加(基準=非自明・再発しうる・行動を変える+未着地確認、手順、保存 HG=owner マージ、poisoning、Step 4 と独立)、関係節に #272 を追記。
- `canonical/skills/spec-card/SKILL.md`: 5型表に1行足さず、独立 knowledge item 節を追加(共通規約非適用・必須9項・ULID ファイル名)。
- 検証: 61/61 PASS・shellcheck PASS・hazard clean(制御バイト/pane ID/絶対パスなし)。

### Step 3: gate 4 実装SO(2026-07-23)

- 弱 SO・実装2レーン(codex + cursor)。cursor 返却・codex timeout(1/2 partial・disclose・"0はなし"満たす)。証跡 `tmp/so-272-impl/`。
- cursor 結論: **material な欠陥なし**。exit 分離(malformed=1)・bash 3.2 互換・doc↔validator 整合・回帰なし(閉じた5型 enum/#19/§11 番号不変)・hazard clean・70(当時 61)/61 PASS を確認。
- 非 material の cheap fix を採用: (1) README のスキーマ例 ULID が `O`/`I` を含み Crockford 非準拠 → 有効な ULID に差し替え(コピペ摩擦の除去)。(2) doc↔validator drift(exclusions 要素の string 型が未検証)→ validator に要素 string チェックを追加。
- coverage 追加: null 必須キー / tmp/ 揮発 ref / source 空 map(ref 欠落) / exclusions 非文字列要素 / directory 非再帰(nested 無視)。→ 70/70 PASS・shellcheck PASS。

### Step 4: PR + Copilot(2026-07-23)

- PR #275 作成(Refs #272・title 正規化・本文テンプレ)。Copilot をレビュアーに依頼。
- Copilot レビュー(1 summary + 3 inline)。3件とも妥当につき1ラウンドで対応(review-loop autonomy):
  1. `validate-knowledge.sh`: `source.ref` の相対パスに `..` が通りパストラバーサル(`../../etc/passwd`)が成立 → `..` セグメントを明示拒否。負例テスト[36]追加。
  2. `test_validate_knowledge.sh`[19]: exclusions scalar 化 fixture のデッドコード(sed + head|grep が後続 write_valid_item に上書きされる)を削除して簡略化。
  3. `docs/knowledge/README.md`: スキーマ例コメントの `.oe//tmp/` が区切りに見えない → 「`.oe/` と `tmp/`」に明確化 + `..` 不可も追記。
- 72/72 PASS・shellcheck PASS。各スレッドへ対応内容 + コミット SHA で返信。

### Step 5: closure(2026-07-23・リアルタイム追記・reconstructed ではない)

**tier = heavy**（非自明な設計判断 = DJ-A/B/E の型体系・置き場・ULID 逸脱、意図的に起動した外部レビュー = 設計SO gate 2 + 実装SO gate 4）。

#### closure gate checklist

- **Context / なぜ**: 冒頭「Context」節に自己完結で記載済み（ループの消費側欠落を塞ぐ段1+2 の土台）。
- **次の消費者**: #273（突合・注入）実装者 = この store から候補を列挙し brief に焼き込む / #274（observations 中身・段6 制御）実装者 = `observations` スロットと status 遷移を設計 / owner = PR #275 マージ判断。
- **follow-up routing**: 下記「残課題」で各項目に行き先を付与。
- **status 確定**: draft → stable（達成。段1+2 の v0 スキーマ + store + 検証 + 収穫手順が landing）。
- **evidence anchor**: 検証結果（72/72 PASS・shellcheck PASS）と SO 判定（設計SO の F1〜F12 + B1/B2、実装SO の material なし、Copilot 3件対応）は本 episode 本文に転記済み。SO 生出力は `tmp/so-272-design/` `tmp/so-272-impl/`（gitignored・揮発）、differential は `.oe/so-272-design-findings.md`（gitignored）= breadcrumb。
- **SO 証跡リンク**: 上記 tmp/ パス（揮発）。判定は本文に転記済み。

#### 内容セクション

- **事実・失敗**: (1) 検証テスト fixture のバグ（test[10] の sed 範囲削除 + prepend が frontmatter を破壊）を validator が正しく検出（validator は正常・テスト側の欠陥）→ awk 置換に修正。(2) so-compare のレーンが両ゲートで 1 本ずつ timeout（設計=claude、実装=codex）。弱 SO の partial（≥1 実返却で disclose・"0はなし"満たす）で前進。(3) Copilot が path traversal（`source.ref` の `..`）を指摘 = 実質的なセキュリティ欠陥を検出。
- **決定と根拠**: DJ-B は独立サブ節（B2）で閉じた5型 enum に触れず #19 回帰を回避。B1 は本番 store に live `active` sample を置かず README スキーマ例 + fixture へ（段3 の全件列挙による store 汚染回避）。`observations` は v0 で空必須（前方互換より「予約の明示」を優先・設計SO F3）。ULID regex は §5 準拠で charset+length に留め、先頭 `[0-7]` 厳密化は将来拡張へ（既存規約踏襲）。
- **わかったこと**: yq は無引用 `date` を `!!timestamp` 経由で JSON 文字列化する（grep でなく yq→JSON 変換してから jq 検査するのが型付き frontmatter 検証の素直な形）。malformed YAML は yq exit 1 で捕捉でき、schema 違反（exit 1）と環境エラー（exit 2）を分離できる。
- **原則（Pattern）**: 「committed 状態 store」= 文書ではなく状態の永続化場所を蒸留5段と分けて型付ける、という層の切り分け。format 機構（§4〜§9）の carve-out を明示しないと spec-card の共通規約が誤適用される（設計SO F1 の穴）。
- **行動変更**: episode closure に Step 5 収穫を追加（トリガ = closure・機構 = `validate-knowledge.sh` + 収穫基準・着地先 = `docs/knowledge/items/`）。
- **蒸留シグナル**: 設計級は committed（document-format §2.5/§3.4）に landing 済み。独立の decision 昇格候補は **なし**（discussion 正本 + spec で足りる）。skill/rule 昇格候補 **なし**。
- **残課題（routing）**:
  - 突合・注入の oe helper → #273。
  - `observations` の中身スキーマ・段6 制御・効果測定計装 → #274。
  - ULID 先頭 `[0-7]` の厳密化 → document-format §5「将来拡張」（追わない宣言はしない・低優先）。
  - `test_validate_knowledge.sh` の CI 配線 → 本スコープ外（他 OE テストと同様 standalone・別 issue 化は owner 判断）。
  - so-compare レーンの timeout 頻発 → 観測のみ（本 issue の範囲外・SO 機構側）。

#### Step 4（heavy 外部チェック）: 条件付き辞退

Step4 辞退: 理由 = 本タスクで意図的 SO を 2 回（設計 gate 2 + 実装 gate 4）実施し substance に外部の目が入っており、closure 品質の4観点も客観的に確認できるため / 既存チェックで覆った観点: 失敗の選択的省略（事実・失敗節に test fixture バグ・SO timeout・Copilot 指摘を記載）/ routing 網羅（残課題に全行き先付与）/ evidence anchor（72/72・SO 判定を本文転記）/ back-propagation（doc 整合の指摘 F1/F2/B2 は本 PR 内で反映済み・外部 doc に残債なし）/ 未実施観点と判断: なし。

#### Step 5 収穫: なし

この episode から knowledge store への収穫は **なし**。理由: 得られた知見（yq→JSON 検証・carve-out・状態 store 層）は committed の document-format §2.5/§3.4 とテストに既に landing 済み（未着地の確認で除外）。汎用 negative knowledge として切り出せる形式例は B1 の決定どおり README + fixture で示し、本番 store に live item は置かない（cold-start のまま = 段3 汚染回避）。「なし」も正当な収穫結果（過剰収穫を避ける）。

#### 達成度

達成（段1+2 v0）。段3 以降は #273/#274 へ。

### Step 6: owner レビュー差し戻し対応 — 可搬性(2026-07-23)

owner レビューで、sync 配布される canonical 3ファイルに hub 固有パス `projects/orchestration-engine/scripts/validate-knowledge.sh` が operational 参照として混入し、sync 先の別リポジトリで解決不能になる欠陥を指摘。修正:

- (1) `scripts/sync/sync-bin.sh` の配布対象に `validate-knowledge` を追加(oe-tree と同型・`~/bin` へ symlink)。これで採用先でも bare コマンド名で呼べる。
- (2) canonical 3ファイル(document-format §3.4 / episode-retrospective の実行例含む / spec-card)の operational 参照をコマンド名 `validate-knowledge` に置換。hub の engine `scripts/` は「正本」provenance 注記として残す。document-format:96 の設計正本 discussion パスは「(hub リポジトリ内)」限定子を付与。
- (3) store パスは置き場規則(蒸留木ルート直下 `knowledge/items/`)を主にし、`docs/knowledge/items/` は ai-hub の実体例示へ降格。
- **追加で発見した派生欠陥**: validator の `REPO_ROOT` を**スクリプト位置**から逆算していた(`../../..`)。これは `~/bin/validate-knowledge` symlink として別リポジトリで実行すると誤る(可搬性の同族問題)。**item の git toplevel から引く**方式に変更(in-repo でも symlink 配布でも item の repo を正しく取る・git 外は存在確認をスキップ)。simulated `~/bin` symlink で source.ref 存在確認が正しく効くことを実機確認。
- 検証: 72/72 PASS・shellcheck PASS(validator/sync-bin/tests)・canonical の残 hub パスは provenance 注記のみ。

status は stable のまま(段1+2 の landing は不変・本 round は可搬性の精緻化)。

### Step 7: owner レビュー訂正 — store 実体を engine 木へ移設(2026-07-23)

owner 訂正: ai-hub には蒸留木が複数ある(トップレベル `docs/` と engine `projects/orchestration-engine/docs/`)。store の実体はループの持ち主である engine 木に置くのが筋。移設:

- (1) store を `docs/knowledge/items/` から **`projects/orchestration-engine/docs/knowledge/`** へ移設。`items/` サブディレクトリは作らず item(ULID 名)を直下に置く。README も同ディレクトリへ。トップレベル `docs/knowledge/` の自由記述ノート2本は不変(不干渉)。旧 `docs/knowledge/items/.gitkeep` と旧 README は削除。
- (2) document-format の置き場規則に「**蒸留木が複数あるリポジトリでは store も木ごと**(実体例 = engine 木)・段3 の列挙は各木の store を横断」を明記。§2 一枚絵 / §2.5 実体 / §3.4 規則 / §13.3 / §13.6 / episode-retrospective / spec-card の実体例パスを engine 木へ追随(規則主・例示従は維持)。
- (3) #273 への申し送り(列挙は各蒸留木の store を横断して見る＝複数木なら複数 store)を episode-retrospective のスコープ外注記に1行 surface + PR 本文にも記載。
- **validator の必要変更**: store dir に README が item と同居するため、directory mode を「ULID 名の item のみ検証・非 item(README 等)は skip」に変更(owner の「パス非依存＝不要なら触らない」に対し、同居により変更が必要になった旨を surface)。実 engine store dir(README のみ・item ゼロ)で README skip + exit 0 を実機確認。
- 検証: 72/72 PASS(README skip の負例含む)・shellcheck PASS・canonical の docs/knowledge/items 参照ゼロ・hazard clean。

達成度: 達成(段1+2 v0・store 実体は engine 木)。段3=#273/段5-6=#274 はスコープ外。

### Step 8: 親 fact-check 差し戻し — items/ 隔離へ回帰(F6 すり抜け検知の復元)(2026-07-23)

親 fact-check の指摘: Step 7 の flat 化 + 非 ULID silent skip は、gate 3 承認済み・設計SO F6 の「誤名 item のすり抜け検知」を巻き戻していた(誤名 item が黙って検証対象から外れる)。加えて §3.4 の「自由記述ノートの無い木を選ぶ」条項は未決定の採用先制約で削除すべき。**私(実装子)の設計ミスを親が捕捉**。修正:

- store を `<engine 木>/docs/knowledge/items/`(ULID item のみ)へ回帰。README は `<engine 木>/docs/knowledge/README.md`(items/ の外)。engine 木の位置は Step 7 のとおり維持。cold-start は `items/.gitkeep`。
- validator の directory mode を「items/ 内の全 `*.md` を検証・誤名(非 ULID)は skip でなく WARN + exit 1」へ回帰(F6 どおり)。実機で誤名 item が WARN + exit1、空 items/(.gitkeep のみ)が exit0 を確認。
- テストを追随: skip 正当化テスト → **誤名 item の WARN テスト**([37])へ差し替え。README 同居テストは撤去(README は items/ の外)。
- §3.4 は前版の「自由記述ノートがあれば `knowledge/` 直下・`items/` に混ぜない」形へ回帰 + 「木ごと store・段3 列挙は各木横断」の追記を維持。「無い木を選ぶ」条項は削除。§2 一枚絵/§2.5/§13.3/§13.6/episode-retrospective/spec-card の実体例を `items/` 付きへ追随。
- 検証: 74/74 PASS(誤名 WARN テスト含む)・shellcheck PASS・canonical の bare `knowledge/<ULID>` 参照ゼロ・hazard clean。

教訓（この round 自体の negative knowledge・ただし store には収穫しない=下記）: owner の「不要なら触らない」を額面で受け、items/ 撤去に伴う validator の silent-skip 化が F6(既承認の設計判断)を巻き戻した。**既承認の設計ゲート成果を後続変更が黙って緩める**のは典型的な回帰。親 fact-check が捕捉。この教訓は本 episode に記録するが、汎用 knowledge item 化は B1(本番 store に live sample を置かない)と過剰収穫回避により見送る。

### Step 9: owner レビュー訂正3件目 — 置き場の関係ルール化 + 可搬性の物差し全掃(2026-07-24)

owner 訂正: canonical(sync 配布)は hub 固有情報を剥がしても指示が立つべき。#272 で 3 回目の同種指摘（memory `feedback_canonical_skill_format_self_complete` に正本化）。修正:

- (1) **置き場を関係ルール化**: 「item は**収穫元 episode が属する木**の `knowledge/items/` に置く(＝ `source.ref` と同じ木)」。複数木の曖昧さを repo 固有パスなしで解く。§3.4 / §2.5 / §13.3 / §2 一枚絵 / episode-retrospective(Step5・関連節) / spec-card を関係形へ書き換え。
- (2) **hub 具体パス + 「正本は hub の engine scripts/」を synced 指示から除去**し、任意の dogfood / provenance へ降格。ai-hub 具体パスと validator 正本の所在は store README(hub 固有・非 sync)へ移設。木解決が要れば store README を見る、と規則側に明記。
- (3) 検証はコマンド名 `validate-knowledge` のまま(既に達成)。sync-bin 配布パスの明記も synced 指示から除去(README に残す)。
- (4) **物差し全掃**: #272 diff の canonical 追記全体を「hub 情報を剥がして指示が立つか」で再点検。store/検証/置き場/昇格経路すべて関係+コマンド名で自立。残る hub 参照は §2.5 の設計正本 discussion citation のみ(provenance・`(hub リポジトリ内)` 明示・operational でない)。sync-bin を参照する他ファイル(hooks/README・verification コマンド)は #272 diff 外につき不干渉。エンジン本体所在参照はスコープ外。
- 検証: 74/74 PASS・shellcheck PASS・synced canonical に hub store-path / hub provenance ゼロ・hazard clean。

達成度: 達成(段1+2 v0・置き場は関係ルール・canonical は self-complete)。
