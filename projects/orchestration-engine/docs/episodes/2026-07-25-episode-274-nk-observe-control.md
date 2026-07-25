---
id: "01KYCGNS8VFW56AM6BBAHHJTJK"
title: "negative knowledge ループ 段5+6 — 観測記録の要素スキーマと制御候補の提示"
date: 2026-07-25
type: episode
status: stable
related:
  - type: derived_from
    ref: "https://github.com/stlwolf/ai-development-hub/pull/282"
    reason: "本実装の PR（plan は作業層 `.oe/` にあり非永続なので、確定内容と SO の要点は PR 本文と本 episode へ転記した）"
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/274"
    reason: "実装対象 issue（段5 観測記録 + 段6 制御）"
  - type: discussion
    ref: "projects/orchestration-engine/docs/discussions/2026-07-21-discussion-negative-knowledge-loop-foundation.md"
    reason: "設計正本（§4 DJ-4 の段5/段6・§6.4/6.10/6.11/6.14/6.16）"
tags: [orchestration-engine, negative-knowledge, "#274"]
---

# negative knowledge ループ 段5+6 の実装記録

## なぜこの作業が始まったか

negative knowledge ループ（収穫 → 保存 → 突合 → 注入 → 観測 → 制御）のうち、#272 で段1+2（型付き store と `validate-knowledge`）、#273 で段3+4（`knowledge-list` と brief の注入 slot）が着地した。本単位（#274）は残る段5（観測記録）と段6（制御）を v0 として実装し、ループを一周閉じる。v0 の観測は意思決定に使わない placeholder であり、段5 は「検証」を名乗らない。

## 経緯（リアルタイム追記）

- 2026-07-25: brief `.oe/brief-274-nk-observe-control.md` を受け、plan-first で `.oe/plan-274-nk-observe-control.md` を作成。gate 1 の探索木（DJ-A〜G）を §3 に外部化した。DJ-F（supersede の後継 id の記録先）は gate 0 の「note に」の解釈が2通りあったため、案B（本文 prose）を推奨として owner へ1点確認に出した。
- 2026-07-25: gate 3（owner HG）通過。plan 承認。DJ-F は案B（item 本文 prose に `superseded by <後継 ULID>`・スキーマ不変）で裁定され、遷移規則に「後継チェーンの機械照会が必要になったら typed フィールド `superseded_by` へ昇格する」という昇格条件を1行添える条件が付いた。他の DJ は recommend どおり採用。
- 2026-07-25: worktree `feat/#274_nk-observe-control` を子が自作し、本 episode の枠を作成。gate 2 設計SO（`so-compare` 弱・3レーン = codex / claude opus-high / cursor）を起動。反証面は owner 指定の DJ-B/C の縁（ref の揮発層拒否・note の1行制約・集計表示形式・`invalid` バケット）で、gate 0 の決定は反証外。ゼロベース拡張を折り込み gate 1 の実 SO と兼ねる。

- 2026-07-25: gate 2 設計SO の結果。**実返却は2レーン**（codex 410秒 / cursor 107秒）で、**claude レーンは 720 秒のリトライ後も空返却**（`timeout_empty`）。弱 SO の終了条件では実返却が1レーン以上あれば disclose して進めるため SO 未実施扱いにはしないが、3レーン想定に対して1レーン欠けた partial である。2レーンが独立に収束し、material な欠陥を6件検出した（`ref` hygiene の対称コピーによる偽陽性 / 制御候補が status を見ない sticky さ / 不正な observation から候補が立ち human で黙殺される / jq `strptime` がカレンダー妥当性を保証しない実測 / JSON 回帰契約の未定義 / 書き戻しの完全性が機械検知不能）。要点と改訂内容は plan §9 に転記した（生出力 `tmp/so-274-design/` は非永続）。
- 2026-07-25: owner 指示（material が出たら差し戻し）に従い、実装に入らず親統括へ差し戻した。owner 判断を仰ぐ点は3つ（`schema_version` の bump / `--strict` の意味論を広げるか / item の top-level `date` にも厳密なカレンダー検査を広げるか）。

- 2026-07-25: owner が material 6件の改訂をすべて採用し、判断3点を裁定（#274 コメントが正本）。schema_version は据え置き（additive・回帰テストで既存キー不変を機械固定）/ `--strict` は広げず meta の `integrity_issues` と二段チェックの明文化で可視化 / top-level `date` も同じ純 jq ヘッダで暦厳密化（同一ファイルの同一バグの片割れを残さない）。gate 3 GO を受けて実装に着手した。
- 2026-07-25: 実装。`validate-knowledge` の observations 検査を要素スキーマへ差し替え（jq 1 パスで違反1行・here-string で受けて warn に積む）、暦検査を純 jq の `cal_ok` にして observations.date と top-level date の両方へ適用、`knowledge-list` に集計・制御候補フラグ・`integrity_issues` を additive で追加。spec の knowledge 節に要素スキーマと status 遷移規則、`episode-retrospective` に観測書き戻しの Step、`doc-flow-guardrail` に往復の締めと二段チェックを追加した。
- 2026-07-25: 実測での確認。テストは `test_validate_knowledge` 138 assertion / `test_knowledge_list` 117 assertion がすべて green。`shellcheck` は 4 ファイルとも clean（jq プログラムの単一引用は SC2016 を意図的に disable）。本番 store に対する human 出力は master 版と **byte 一致**（`diff` で確認）、`--json` も追加5フィールドを除けば master と一致した。本番 store の実 item 3件には観測を書き込んでいない。
- 2026-07-25: 途中で踏んだ非自明な失敗を2件記録する。(1) テスト内で `"exit 1（暦不正 $bad_date）"` のように**変数名の直後に全角括弧**を置くと `set -u` 下で「未割り当ての変数」として落ちた（`${bad_date}` で回避）。(2) 最初に書いた smoke fixture が閉じ `---` と本文を欠いており、validator の「frontmatter block not found」を実装バグと誤読しかけた（fixture 側の不備だった）。

- 2026-07-25: gate 4 実装SO（`oe-review` 弱・2レーン・diff バインド・reviewed_sha `3b34810`）。**verdict は refuted**（codex が material 検出・cursor は survived。conservative 集約で全体 refuted）。codex の指摘は正しく、実測で再現した: `ref_bad` が URL と issue/PR 形式の免除を絶対パス・揮発層・`..` の検査より**先**に見ていたため、末尾に `#N` を付けるだけで hygiene を迂回できた（`../../repo#274` / `/tmp/evidence.md#274` / `/tmp/evidence.md://x`）。その ref を持つ harmful レコードが「valid な adverse 観測」として集計され、**誤った制御候補**を生成できていた。gate 2 設計SO で C1（対称コピーの偽陽性）を直した結果、逆側に穴が空いていたことになる。
- 2026-07-25: 修正。判定順を入れ替え、scheme 始まりの URL だけを hygiene 対象外にして、残りは絶対パス・先頭一致の揮発層・`..` セグメントで拒否する形にした。issue/PR 参照は hygiene のどの条件にも触れないので**免除分岐そのものが不要**で、持たせること自体が迂回路だった。迂回入力5件を validator（exit 1）と lister（invalid 集計・候補を立てない）の両方に回帰として固定し、148 + 121 assertion green。修正後の diff で実装SO を再実行した。

- 2026-07-25: 実装SO 2周目（reviewed_sha `28a18d3`）も **refuted**。codex が「`note: null` が要素スキーマをすり抜け、不正な harmful/contradicted レコードから制御候補を生成できる」と指摘（cursor は survived）。実測で確かめると、**両コマンドの判定は一致していた**（validator も lister も valid 扱い）ので、指摘にあった「契約の分裂」ではなかった。ただし spec の文言は「任意・存在時は string」であり present-but-null はそれに反するので、**厳しくする側に倒した**（書き手が note を書いたつもりで空になった記録が黙って通る余地を消す）。両方を同時に直し、contract テストの fixture に `note: null` を足して判定集合の一致で縛った。
- 2026-07-25: 実装SO 3周目を修正後の diff（`note` 修正込み）で実行。**iterate はここで止める**方針を先に決めた（弱 SO の終了条件は1周で足り、レーンが毎周新しい nit を出す構造に引きずられない）。3周目でさらに material が出た場合は自分で直さず親へ上げる。

- 2026-07-25: 実装SO 3周目（reviewed_sha `564b91c`）は **2/2 レーンが独立に同じ欠陥へ収束**した。`ref_bad` が生の文字列に先頭一致をかけていたため、先頭に空白を入れるか `./` を付けるだけで揮発層の検査を外せた。実測で ` .oe/plan.md` / `  tmp/scratch.md` / `./tmp/scratch.md` はいずれも validator が exit 0 になり、その harmful レコードが制御候補として立っていた。判定前に `ref_norm`（前後の空白除去・`\` を `/` へ・先頭 `./` 除去）を通す形にし、正規化は判定にだけ使って記録値は原文のままにした。偽陽性が増えていないことも実測で再確認した。codex レーンは同じラウンドで Windows 形式（ドライブレター `C:/…`・UNC・backslash traversal）にも触れていた。UNC（`//server/…`）は `^/` の既存条件で拒否済みだったが、**ドライブレター絶対パスは通っていた**ので `^[A-Za-z]:/` を拒否条件に足して family を閉じた（この記録は closure 外部チェックの指摘を受けて後から補ったもので、最初の記載は指摘の範囲を空白と `./` に狭めていた）。
- 2026-07-25: 宣言どおり4周目は回さず、gate 4 を閉じた。テストは 164 + 124 assertion green、shellcheck clean。PR #282 を作成し Copilot にレビュー依頼を出した。

- 2026-07-25: Copilot レビュー（PR #282）で2件の指摘。(1) episode の `derived_from` が作業層 `.oe/` の plan を指していて dead pointer になる → PR URL へ張り替えた。(2) spec の `ref` hygiene が「揮発層のパスは不可」としか書いておらず、URL や自由文まで禁止に読める → 適用範囲（path 形状にだけ当たる・正規化後の先頭一致だけ・途中一致では弾かない）を3項目の規則として明記した。どちらも妥当な指摘で、コミット `e8dd147` で対応し両スレッドへ返信した。

## closure

### tier 判定

**heavy**（heavy トリガに複数該当: 実行中に失敗・撤回・方針転回があった / 意図的に外部レビューレーンを起動した（設計SO 1回・実装SO 3回・closure 外部チェック 2回）/ 非自明な設計判断を比較して棄却した（DJ-A〜G）/ 昇格候補があった（knowledge item 2件を収穫））。したがって Step 2 + Step 3 + Step 4 を実施する。

### gate 2 設計SO の material 6件（committed 転記・plan §9 は `.oe/`＝gitignored なので要点をここに保全）

「すべて採用」だけでは何がどこに着地したか復元できないので、指摘・裁定・着地先/残債を1行ずつ残す。

- **C1 `ref` hygiene の対称コピーは偽陽性**（`source.ref` の `*/tmp/*` 部分一致を写すと自由文や URL 断片を誤爆する）→ 採用。判定を「URL / 非 path / path 形状」の分類順に組み替えて着地（実装 + spec の適用範囲 3項目 + テストの偽陽性/真陽性）。**この面はその後 gate 4 で2度追加の迂回が出た**（判定順・正規化）ので、deny-list 方式そのものの是非は owner 判断へ surface（下記 follow-up）。
- **C2 制御候補が status を見ず sticky**（制御済み item が毎回候補になる・誤観測を消す語彙が enum に無い）→ 採用。候補を `status: active` に限定して着地。「一度立った候補は消えない」ことは v0 の既知の制約として spec に明記（追加機構は追わない）。
- **C3 壊れたレコードから候補が立ち、非配列は human で黙殺される** → 採用。集計と候補判定を要素スキーマを満たすレコードだけに限定し、壊れた台帳は件数に関係なく1行出す形で着地。`--strict` は広げず meta の `integrity_issues` + 二段チェックの明文化で可視化（owner 裁定2）。
- **C4 jq `strptime` は暦不正を通す**（`2026-02-29` / `2026-04-31` を受理する実測）→ 採用。純 jq の `cal_ok` に置き換え、observations.date と top-level date の両方へ適用（owner 裁定3）。knowledge item として収穫済み。
- **C5 JSON の回帰契約が未定義** → 採用。「human 回帰ゼロ」と「JSON は additive・既存キー不変」を分けてテストで固定し、`schema_version` は据え置き（owner 裁定1）。
- **C6 書き戻し完全性は機械検知できず「安売り防止」は過大主張** → **部分採用**。文言を「レビューが唯一の歯」に弱め、注入 item の期待集合を durable に残す手順までを v0 で着地させた。**機械照合（期待集合 == 観測を足した集合）は #24 系へ defer＝残債**。「6件すべて採用」は正確には「6件すべての指摘を受けて plan を改訂し、うち C6 の機械化部分だけを残債として defer」である。

### Step 4（closure の外部チェック）

- 1回目は `so-compare --claude-only` で回したが、**claude レーンは 301 秒で `timeout_empty`（実返却ゼロ）**。gate 2 でも同じレーンが 720 秒リトライ後に空返却しており、この環境の claude レーン固有の症状に見える。実返却ゼロは弱 SO の「0」に当たり SO 未実施なので、**返却実績のあるレーンで回し直した**（`--with codex,cursor`・2レーンとも実返却）。
- 指摘は closure 品質の4観点すべてに及んだ。**採用して直したもの**: frontmatter が `draft` のまま宣言と不一致だった（→ `stable` に確定）/ 設計SO 6件の内容が `.oe/plan §9` 依存で committed 転記が無かった（→ 上記の節を追加）/ Step 4 の失敗と結果が記録されず「転記した」が過大主張だった（→ 本節）/ tier 宣言が無かった（→ 上記）/ 3周目の指摘範囲を空白と `./` に狭めていた（→ Windows 形式の扱いを追記し、ドライブレター絶対パスを拒否条件に追加）/ follow-up の非 durable な行き先（→ 下記 routing を durable 化し、#273 の dead pointer は本 PR で back-propagation）。
- **限界（正直に）**: この closure 外部チェックは1ラウンドで、上記の修正後に再チェックはしていない。また **gate 4 実装SO は3周目の修正後の diff（Copilot 対応・収穫・本節の追記・ドライブレター拒否を含む）に対しては通していない**（4周目を回さない方針を先に宣言した）。最終 diff の保証はテスト（168 + 124 assertion）・shellcheck・Copilot レビューまでで、実装SO は `564b91c` 時点までである。

### closure gate checklist

- **Context / なぜ**: 冒頭「なぜこの作業が始まったか」に自己完結で書いた（#272 と #273 の着地を受けてループを一周閉じる単位）。
- **次の消費者**: (1) この engine の knowledge store を使う統括セッション（`knowledge-list` の集計と制御候補フラグを読み、二段チェックで検証まで回す運用者）(2) 観測を書き戻す委譲子（`episode-retrospective` の書き戻し Step が新しい消費対象）(3) `ref` hygiene の設計をどちらへ倒すか判断する owner（下記 follow-up）(4) 将来 matcher / hard 化（#24 系）を実装する人（observations が教師データと計装の実体になる）。
- **follow-up routing**（すべて行き先つき）:
  - **`ref` hygiene を deny-list から allow-list へ倒すか** → **owner 判断へ surface**（PR #282 の「残る論点」に記載・この PR では実装しない）。3ラウンドのうち2ラウンドが同じ family の迂回を出したという観測が判断材料。
  - **#273 の episode に残る dead pointer**（`related.derived_from.ref` が `.oe/plan-273-nk-match-inject.md`）→ **本 PR で back-propagation 済み**（#273 の `derived_from` を PR #278 の URL へ張り替えた）。「親 / owner へ surface」は #273 自身の closure が「durable な行き先にならない」と定義している形なので、surface で止めず反映した。#272 の episode は `derived_from` が committed な discussion を指しており同種の欠陥はない（確認済み）。
  - **書き戻し完全性の機械ゲート**（注入 item の期待集合 == 観測を足した集合の照合）→ **#24 系の hard 化へ defer**（C6 の残債。v0 は期待集合を durable に残すところまで）。再開条件は matcher 実装または #24 の hook 軸着手時。
  - **append-only の機械検査** → **v0 では追わない**（理由を確定）。設計SO の代替案B は「file 単体の validator ではなく PR の base/head 差分で履歴不変条件（末尾追加のみ・過去要素の編集/削除/並べ替えを reject）を検査する別ゲートに責務を分ける」形。committed 台帳が小さい v0 では PR レビューで足り、別ゲートの新設は費用が上回る。再検討は台帳が育って人手のレビューで追えなくなったときで、行き先は #24 系。
  - **観測の実データがまだ 0 件** → **follow-up として追わない**。次に negative knowledge の注入を受けたタスクで自然発生し、その episode と PR が記録する（人工的な観測を本番 store に書かない方針を守った）。
  - **制御候補が消えない v0 の制約**（誤観測の訂正語彙が enum に無い）→ **spec に既知の制約として明記済み**（追加の機構は追わない）。
  - **`superseded_by` の typed フィールド化** → **追わない**（spec の「status 遷移規則」に昇格条件を明記済み。後継チェーンの機械照会が必要になった時点で再検討）。
  - **設計正本から継承している defer**（効果の帰属・反事実・baseline / trigger の機械 matcher / durable な採否決定ログ / event-bus 計装 / push 型注入 / 自動 status 遷移 / 並行追記の atomicity）→ **設計正本 discussion §6 と PR #282 の「残る論点」に列挙済み**。本 episode で新規に発見した項目はない。
- **status 確定**: `draft` → `stable`（達成）。
- **evidence anchor**: 揮発パスの要点を本文へ転記した — 設計SO（`tmp/so-274-design/`）は上の「material 6件」節、実装SO（`tmp/oe-review-*`）は verdict・reviewed_sha・迂回した ref の具体値、closure 外部チェック（`tmp/so-274-closure/` と `tmp/so-274-closure2/`）は Step 4 節。jq の暦穴はバージョンと受理された日付を本文と knowledge item に残した。`.oe/plan-274-nk-observe-control.md`（作業層・非永続）に依存していた設計SO の確定内容は、この closure で committed 側へ移した。
- **観測の書き戻し**: 本タスクの brief に negative knowledge の slot は無く（注入ゼロ）、書き戻しの対象も無い。自分の Step 6 を自分に適用した結果として、ここに「注入なし」を1行だけ残す。

### 決定と根拠（コードや diff から復元できない「なぜ」）

- **`--strict` を広げなかった**理由は、#273 が確定した「skipped>0 = 列挙できなかった」という契約を後続単位で動かすと、guardrail の段3 手順の意味まで変わるためである。代わりに `integrity_issues` と二段チェックで可視化した。設計SO の codex レーンは `--strict` の拡張を推していたが、owner 裁定で verb 責務の分離（列挙 vs 検証）を保つ側を採った。
- **`schema_version` を上げなかった**理由は、追加が additive で既存キーが不変であり、消費者が現時点で統括（人間）だけだからである。codex レーンは「version フィールドの意味が消える」として bump を material と判定したが、既存キー不変を回帰テストで機械固定することで同じ保証を得た（bump は消費者に無用な分岐を強いる）。
- **観測ゼロなら human 行を出さない**条件付き出力にしたのは、既存 3 item の出力を1バイトも変えずに機能を足せるからである。「観測ゼロが見えない」害は小さい一方、壊れた台帳は件数に関係なく必ず1行出す（黙殺しない）ことで、隠れる方向の失敗だけを塞いだ。
- **`note: null` を弾く側に倒した**のは、両コマンドの判定が一致していた（＝契約の分裂ではなかった）と実測で確認したうえで、spec の「任意・存在時は string」という文言に合わせる判断である。SO の note には「不正なレコードから候補を生成できる」とあったが、この部分は過大な主張だったので、指摘の結論だけを採って理由は自分で置き換えた。

### わかったこと（技術的知見）

- jq の `strptime` はカレンダー妥当性を保証しない（`2026-02-29` / `2026-04-31` を翌月へ正規化して受理する。jq 1.7.1 / 1.8.0 で実測）。月13 だけを負例にしたテストでは緑になる。→ knowledge item として収穫した。
- deny-list の hygiene は判定順と正規化の両方で迂回路を作る。免除の分岐（`#N` 形式の許可）そのものが迂回路になっていた。→ knowledge item として収穫した。
- `warn` のような副作用を持つ関数へパイプで値を渡すと subshell に閉じて件数が失われる（here-string なら閉じない）。これは #273 の収穫済み item（pipefail / SIGPIPE）と同じ「パイプの制御フロー」族だが、失敗の形が違う（件数の喪失 vs 誤分類）ので、既存 item の射程内として新規収穫はしない。
- `set -u` 下で変数名の直後に全角括弧を置くと「未割り当ての変数」で落ちる。日本語ラベルを多用するこのリポジトリでは踏みやすいが、`${var}` で回避でき影響が局所なので、収穫基準の「行動を変える」度合いが弱いと判断して本文記録に留める。

### 蒸留シグナル

- **knowledge store へ収穫**: 2 件（deny-list hygiene の迂回 family / jq strptime の暦穴）。どちらも `landing: guard-candidate`（lint / テストの型に落とせる述語を含む）。
- **Decision / ADR 昇格**: なし。設計判断は既存の discussion（設計正本）と spec の knowledge 節に着地しており、独立した decision doc を切る必要はない。
- **skill / rule**: なし（`episode-retrospective` と `doc-flow-guardrail` の更新が本単位の成果物そのもの）。
