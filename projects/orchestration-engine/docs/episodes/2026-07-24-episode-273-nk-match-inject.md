---
id: "01KY9T6GTNDXEE4JVH8M6MCPT6"
title: "negative knowledge ループ 段3+4 — 全件列挙 verb knowledge-list と brief 注入 slot"
date: 2026-07-24
type: episode
status: stable
related:
  - type: derived_from
    ref: ".oe/plan-273-nk-match-inject.md"
    reason: "本実装の plan（§9 が gate 2 設計SO 後の確定版）"
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/273"
    reason: "実装対象 issue（段3 突合 + 段4 注入）"
  - type: discussion
    ref: "projects/orchestration-engine/docs/discussions/2026-07-21-discussion-negative-knowledge-loop-foundation.md"
    reason: "設計正本（§6.3/6.5/6.6/6.13/6.16）"
tags: [orchestration-engine, negative-knowledge, "#273"]
---

# negative knowledge ループ 段3+4 の実装記録

## なぜこの作業が始まったか

negative knowledge ループ（収穫→保存→突合→注入→観測→制御）のうち、#272 で段1+2（型付き store + `validate-knowledge`）が着地した。本単位（#273）はその次の輪、段3（突合＝統括が brief を組む時に候補を提示）と段4（注入＝採用 knowledge を brief 固定節に焼く）を v0 として実装する。v0 は機械 matcher を作らず「全件列挙 + 統括の採否」で false negative ゼロを狙う。

## 経緯（plan-first → gate 2 SO → owner 裁定）

- plan-first で `.oe/plan-273-nk-match-inject.md` を作成し、gate 1 のゼロベース探索（DJ-A〜F）を §3 に外部化した。
- gate 2 設計SO（`so-compare` 弱・3レーン = codex / claude opus-high / cursor）を実施。3レーンが強く収束し、DJ-B/C/D/F に material な欠陥を検出（生出力 `tmp/so-273-design/`・要点は plan §9 に転記）。owner へ差し戻した。
- owner が子 recommend どおり裁定（2026-07-24）: DJ-F=cursor 統合案 / discovery 整合=軽量 assert テストのみ / DJ-C=HEAD tree snapshot 版で GO。DJ-B/D/E 改訂も承認。plan §9 が確定版。

### gate 2 設計SO で確定した DJ（committed 転記・plan §9 は `.oe/`=gitignored のため要点をここに保全）

- **DJ-A（verb 名）**: `knowledge-list`（noun-verb・gate 0 DJ-4 明記・将来 `knowledge list` namespace へ平坦マップ）。SO 対象外・小さく可逆。
- **DJ-B（出力書式）**: 3レーンが (a) `item_ref` 欠落＝`source.ref` は出典（episode/PR/URL）であって item 本体へのリンクでない (b) `exclusions`（採否の核心）欠落 (c) `summary`＝先頭行という名が「意味要約済み」と誤認させる、を指摘。→ 出力に `item_ref` と `exclusions` を追加、`summary` を `excerpt`（見出し skip・意味要約でない）へ改名、`landing` 主フィールド化、`type` 出力削除、`--json` に `schema_version` と `head`（固定 HEAD SHA）追加。
- **DJ-C（横断発見）**: 案A（find）は 3/3 不採用（本単位の `tests/` fixture を本番 store 誤列挙・prune denylist 負債）。案E も生 `git ls-files` は index（staged 込み）・pathspec が cwd 相対/先頭 `*/` で root 直下木取りこぼし/`*` が items 下位まで再帰（validator と集合ズレ）・git 非在で exit128、を指摘。→ **HEAD tree snapshot 版**に硬化（`git ls-tree -rz HEAD`・repo-root 錨・items 直下 ULID を厳密 regex・決定論順・git 非在/HEAD 不成立 exit2・submodule 非降下）。disk は `--include-uncommitted` 明示時のみ。
- **DJ-D（slot 書式）**: `source.ref` は出典で教訓本文でない → 子が辿ると誤成果物に着地。→ slot に `item`（item path＝全文導線）+ `landing` + 「行動をどう変えるか」の一行 + 空状態の区別（採用なし/列挙不完全）。
- **DJ-E（手順配置）**: guardrail は薄く（slot + 1 行手順）・コマンド詳細（オプション/exit/snapshot）は README（+ toolkit）に単一集約・delegate-task はポインタのみ（guardrail と delegate-task の二重管理を避ける）。
- **DJ-F（malformed exit）**: 当初の WARN(stderr)+skip+exit0 は 3/3 危険（stdout を読むモデル統括に見落としが不可視・段3 の false-negative-zero を破る）。→ stdout の flagged row で surface + 集計、既定 exit0・`--strict` で skipped>0 は exit1・環境エラー exit2、段3 手順は常に `--strict`。

## 確定した設計（plan §9）

- **knowledge-list**（新設・read-only・sync-bin 配布）: 既定は `git ls-tree -rz HEAD` で committed の item を repo-root 起点で蒸留木横断列挙。path は厳密 regex で `knowledge/items/` 直下の ULID `.md` のみ。決定論順。git 非在/HEAD 不成立は exit 2（案A へ暗黙 fallback しない）。submodule は既定で降りない。disk（未 commit 込み）は `--include-uncommitted` 明示時のみ。
- 出力フィールド: id / item_ref / status / landing / date / trigger / prediction / exclusions / excerpt（本文先頭・見出し marker 除去・意味要約ではない・文字数上限で切詰め）/ source.ref。`--json` はメタ付きオブジェクト（`schema_version` / `source` / `head`〔固定 HEAD SHA・git-head 以外は null〕/ `listed` / `skipped` / `items` / `malformed`）。human 末尾は git-head モードで `source: git-head @ <HEAD SHA>`。
- **malformed**: stdout に flagged row（id は ULID ファイル名から復元・`status: MALFORMED`・path）で surface（黙って落とさない）。末尾に listed/skipped 集計。既定 exit 0・`--strict` で skipped>0 は exit 1・環境エラー exit 2。段3 手順は常に `--strict`。
- **discovery 整合**: 「knowledge-list の対象集合 == validate-knowledge directory-mode の対象集合」を assert するテストを置く（共有 primitive refactor は follow-up）。
- **doc**: doc-flow-guardrail 固定節に slot（可変節直前）+ 薄い注入手順、README に列挙節（+ hub dogfood 横断解決・exit code 表）、orchestration-toolkit に 1 行、delegate-task にポインタ。可搬性 = command 名 + 関係ルールで自立、hub 固有は README（非 sync）へ。

## Step 記録

- **Step 1（scaffold）**: worktree 自作（`feat/#273_nk-match-inject`）→ 本 episode 枠を着手時に作成。
- **Step 2（knowledge-list.sh）**: `validate-knowledge.sh` の frontmatter 抽出（awk → yq → jq）を踏襲。既定モードは `git ls-tree -rz --name-only HEAD` で committed item を列挙し、`(^|/)knowledge/items/[^/]+\.md$` + ULID basename で items/ 直下のみに厳密に絞る。本文は `git show HEAD:<path>` の blob から読む（working-tree の dirty を混ぜない）。`--include-uncommitted`（find・prune）と explicit positional（git 不要）も実装。malformed / 非 ULID は stdout の flagged row で surface。JSON はメタ付きオブジェクト。excerpt は見出しを skip し ASCII 空白境界でのみ切詰め（多バイト分割による jq UTF-8 破損を回避）。
  - self-review で 2 箇所直した: `set -e` 下で `.source.ref` が非 object のとき jq が落ちて全体が死ぬ罠 → `source|type=="object"` guard。human 出力の型混在 → `tostring` + `exclusions|map(tostring)`。
- **Step 3（test）**: `test_validate_knowledge.sh` の subprocess + `${BASH}` 起動を踏襲。18 グループ 50 assert。git repo fixture を temp に作り HEAD snapshot・横断・空・malformed・非 ULID・nested 非再帰・dirty 非表示・`--strict`・`--include-uncommitted` prune・explicit・discovery 整合（surface 集合 == validate-knowledge 対象集合）を固定。全 PASS。validate-knowledge test も 74 PASS で回帰なし。
- **Step 4（配布 + doc）**: sync-bin に `knowledge-list` 追加。doc-flow-guardrail に「negative knowledge」slot（可変節直前）+ 薄い「negative knowledge 注入」手順。store README に「列挙（段3 突合）」節（dogfood 横断解決 + exit code 整合表）。orchestration-toolkit に 1 行、delegate-task にポインタ 1 行（3軸分離・手順の実体は guardrail 側のみ）。
- **Step 5（gate 4・実装SO）**: `oe-review --lanes 2 --base master`（弱・codex+cursor）が **refuted**（2/2 material）。指摘は妥当で、同ラウンドで修正した:
  1. **失敗の握り潰し**: `git show HEAD:$path || true` が blob 読み出し失敗（object 欠損・partial clone・権限）を空内容へ変換し、環境エラーを MALFORMED（データエラー）に誤分類していた（`--strict` で exit1・本来 exit2）。→ `|| true` を外し、read 失敗は exit 2（`git fetch` を促す）。空でも valid な blob（git show exit0 + 空）とは区別。`ls-tree`/`find` も process substitution から temp file 経由に変え producer の exit code を検査（exit 2）。`cat` の失敗も exit 2。
  2. **HEAD 未固定**: 列挙と各 blob 読み出しで symbolic `HEAD` を再解決していた（実行中の HEAD 移動で snapshot 不整合）。→ 開始時に `rev-parse` で具体 SHA へ固定し、`ls-tree`/`show` 双方で同一 SHA を使う。SHA を出力メタ（`head` フィールド・human 末尾）に出す。
  3. **テスト（codex 指摘）**: discovery 整合テストが oracle を別実装（`git ls-tree|grep`）していた。→ `validate-knowledge --verbose` の "checking" ログで validator の**実対象**を観測する形に変更。blob 欠損 → exit 2 のテスト（loose object 削除）と head==実 SHA（pinning）のアサートを追加。
  - 修正後: knowledge-list 55 assert 全 PASS・validate-knowledge 74 PASS 回帰なし・shellcheck clean。修正の副作用として suite が `set -e`+pipefail で落ちた罠（validator exit1 を command substitution が伝播）も検出し `|| true` で中和。
- **Step 5b（実装SO 2 周目）**: 修正後の再 review で cursor は **survived**、codex が新規 material 2 件を検出（実機再現つき）。両方妥当なので修正:
  1. **閉じ `---` 欠落の偽成功**: 開き `---` のみで以降が valid YAML だと valid item 扱いされていた（validator は拒否する）。→ frontmatter 抽出を delimiter 検査込みの 1 パス awk にし、閉じ欠落は MALFORMED。
  2. **無制限 excerpt の argv DoS**: 空白の無い巨大 1 行（約 1.1MB）を切り詰めず `jq --arg` に渡し `Argument list too long`（exit 126）で exit code 契約を破っていた。→ 空白の有無に依らず文字数上限で必ず切り詰め（UTF-8 ロケール前提で文字境界）。
  - 修正中に **SIGPIPE × pipefail の罠**を自己検出: delimiter 検査/excerpt 抽出で早期 exit する consumer（`grep -q`・awk `exit`）が巨大 body の producer に SIGPIPE を送り、pipefail が pipeline を誤って非 0 にして valid item を MALFORMED 誤判定していた。→ 両者を「入力を最後まで読み切り END で返す」awk に統一（早期 exit しない）。
  - 修正後: 61 assert 全 PASS（[20] 閉じ欠落・[21] 巨大 excerpt を追加）・shellcheck clean・validate-knowledge 74 PASS 回帰なし。
- **Step 5c（実装SO 3 周目）**: cursor 再び survived。codex がさらに深い edge を 4 件。3 件を修正・1 件を v0 限界として明示 defer:
  1. **巨大 frontmatter の argv DoS**: 出力組立の `jq --argjson items "$items_arr"` が巨大 item を含む配列を argv で渡し exit 126（round-2 の excerpt と同クラスの別経路）。→ items/malformed 配列を `printf`（builtin）+ `jq -s` の stdin で渡す。per-item 組立も `--argjson` を stdin `<<<` に変更済み。
  2. **repo-root 末尾スラッシュ**: prefix 除去が失敗し item_ref が絶対パス漏れ。→ `REPO_ROOT="${REPO_ROOT%/}"` で正規化。
  3. **discovery 整合の主張過大**: HEAD snapshot(lister) と作業ツリー(validator) は未 commit 差分でズレる。→ README を「committed 状態では一致・未 commit 中のズレは設計どおり」に精緻化（コード/テストは committed+clean 前提で正しい）。
  4. **【defer・v0 限界】C locale の excerpt 切詰め**: 非 UTF-8 ロケールで末尾 1 文字が U+FFFD に置換されうる。crash も exit 契約違反も無く（jq が置換・実機で C locale exit 0 を確認）、excerpt は preview で正本は item 本体。薄い列挙 verb の v0 には過剰なので script コメントに限界を明示し defer。owner fact-check 対象。
  - 追加テスト [22]（巨大 frontmatter → exit0/listed1）[23]（末尾スラッシュ → 相対 item_ref）。64 assert 全 PASS・shellcheck clean・validate-knowledge 74 PASS。
  - **SO 反復の停止判断**: 3 周実施（弱 SO の上限）。cursor は 2 周連続 survived、codex の指摘は crash 級（argv/SIGPIPE）から cosmetic（C locale U+FFFD）へ収束。material は全て修正済みなので、敵対レーンの際限ない深掘りを追わず gate 4 実装SO を閉じる。停止判断と defer 1 件は完了報告で親 fact-check に出す。
- **Step 6（gate 4・Copilot）**: PR #278 で `@copilot` にレビュー依頼。8/8 ファイルをレビューし **コメント無し（generated no comments）**。未返信スレッド無しなので返信対象ゼロ（`copilot-review-response` の評価対象なし）。

## closure（gate 5・マージ前）

tier = **heavy**（実行中の失敗/修正あり・意図起動の SO レーン複数・非自明な設計判断）。

### closure gate checklist

- **Context / なぜ**: 冒頭「なぜこの作業が始まったか」節に自己完結記述あり（#272 の次の輪＝消費側 v0）。
- **次の消費者**: (1) 統括セッション（brief 組立時に `knowledge-list` で列挙し slot へ注入する運用者）(2) #274（段5/6 = observations 書き戻し・制御。本 PR の注入実績を前提にする）(3) owner（マージ HG + 本報告の fact-check）。
- **follow-up routing**（各項に durable な行き先。「owner に surface」は人への申し送りで durable 行き先にならないため、Issue / doc §参照 / 追わない理由確定 のいずれかに落とす）:
  - **observations 書き戻し・段5・段6（制御）** → **#274**（README §2.5 / 設計正本 §6 で #274 と明示された範囲）。
  - **matcher（機械照合）・効果帰属/成功基準** → 設計正本 discussion `2026-07-21-...-negative-knowledge-loop-foundation.md` §6.3 / §6.10（未決論点・defer 宣言）。**durable 決定ログ**は matcher 実装時の follow-up（同 §6.3）。
  - **注入予算・競合の機械規則** → 同 discussion §6.13。**push 型注入（配送セマンティクス）** → §6.6。**event-bus 計装（識別子・イベント契約）** → §6.14 + DJ-4 横断計装。**guard コンパイル着地先** → §6.9 / §7（相補経路）。いずれも本単位でスコープ外の defer（#274 に束ねない）。
  - **C locale の excerpt 末尾 U+FFFD** → **追わない**（v0 既知限界・cosmetic・非 UTF-8 ロケール限定・crash/exit 契約違反なし・script コメント + README §列挙「既知の限界」に記載）。owner が UTF-8 安全な切詰めを望む場合のみ follow-up。
  - **negative knowledge 収穫（下記 Step 5 の 3 候補）** → **本 PR に in-PR 収穫済み**（owner フロー決定 2026-07-24: 収穫は in-PR 相乗りが既定・#278 が最初の実例）。3 item を `knowledge/items/` にコミット・保存 HG は owner マージ。
  - **discovery の共有 primitive refactor**（列挙と検証で発見ロジックを 1 本化）→ follow-up（未 Issue）。v0 は「対象集合一致を assert するテスト」で代替済み（owner 裁定・軽量案）。
  - **`knowledge <subcommand>` 統合** → follow-up（未 Issue・gate 0 DJ-4 が defer 明記・`validate-knowledge` を churn させない）。
- **status 確定**: draft → **stable**（達成: 受け入れ基準 1〜8 を満たす。ただし C locale の excerpt は「追わない」で確定した既知限界であって「解決」ではない）。
- **evidence anchor**: SO 生出力は揮発層（`.oe/`・`tmp/` は gitignored＝本 PR に含まれない）。**設計SO の DJ-A〜F の指摘・解決は上記「gate 2 設計SO で確定した DJ」節に committed 転記済み**（plan §9 / `tmp/so-273-design/` に依存せず復元可能）。実装SO 3 周の要点は Step 5/5b/5c に転記済み。
- **SO 証跡（揮発・参考）**: 設計SO=`tmp/so-273-design/`、実装SO 3 周=`tmp/oe-review-2026072410{3224,4346,5530}*`、closure check=`tmp/so-273-closure2/`（内容は本文転記済み・パスは非永続）。

### 内容セクション（出力型 × 消費チャネル）

- **事実・失敗**（選択的省略をしない・全件）:
  - round1: `git show`/`ls-tree`/`cat` の失敗握り潰し（`|| true` で env エラーをデータ扱い）+ symbolic `HEAD` 未固定 + discovery 整合テストが oracle を別実装（`git ls-tree|grep` 再実装）→ すべて修正（producer を temp file + exit 検査・`HEAD` を SHA 固定・oracle を `validate-knowledge --verbose` の実対象観測に変更）。
  - round2: 閉じ `---` 欠落の偽成功 + excerpt の無制限 argv DoS → 修正。**その修正過程で自分が誘発した SIGPIPE×pipefail の罠**（早期 exit consumer が巨大 body の producer に SIGPIPE→pipefail が正常データを誤 MALFORMED）を検出→ 読み切り awk に統一。
  - round3: 出力組立の argv DoS（`--argjson items`）+ repo-root 末尾スラッシュの絶対パス漏れ + discovery 整合の主張過大（README）→ 修正。
  - テスト強化中に **test suite 自体の `set -e`+pipefail 落ち**（directory mode の validator が exit1 を command substitution へ伝播）を自分のテスト実行で検出→ `|| true` で中和。
  - **未解決（意図的 defer）**: C locale の excerpt 末尾 U+FFFD（上記 routing で「追わない」確定）。したがって「material を全て解決」ではない — crash 級は全て修正、cosmetic な C locale 1 件のみ既知限界として残す。
- **決定と根拠**: DJ-C は find（案A）でなく **HEAD tree snapshot 版の git（案E 硬化）**を採用（committed 状態 store の意味 + prune denylist 負債回避 + 未 HG item を注入しない信頼境界）。棄却: 案A（fixture を本番 store 誤列挙・denylist 負債）、生 `git ls-files`（index 込み・pathspec の罠）、materialized catalog / content 検索（v0 過剰）。
- **原則（Pattern/Anti-pattern）**: 下記 Step 5 の収穫候補。
- **蒸留シグナル**: negative knowledge 3 件を **in-PR 収穫済み**（Step 5）。Decision/skill/rule 昇格は無し（設計は既存 discussion §6 が正本）。
- **残課題**: 上記 follow-up routing 参照（すべて行き先付与済み）。

### Step 4（heavy 外部チェック・実施済み）

`so-compare` で closure 品質の focused check を実施（claude レーンは `timeout_empty` × 2 で実返却ゼロ → codex レーンに切替。出力 `tmp/so-273-closure2/`）。codex が closure 品質の欠陥を 4 点検出し、**本 closure で全て修正した**:

1. **事実・失敗の選択的省略**: round1 の oracle 別実装・test suite の pipefail 落ち・C locale defer が「事実・失敗」から欠落し「すべて修正」が不正確 → 「事実・失敗」を全件・正確に書き直し（C locale は未解決 defer と明記）。
2. **routing が非 durable**: 「owner に surface」が人への申し送りで durable 行き先でない・`#274` に過剰に束ねていた → 各項を #274（observations+段5/6 のみ）/ 設計正本 discussion §6 の該当節 / 「追わない理由確定」に落とし直し。共有 primitive refactor を routing に追加。
3. **設計SO の evidence が非永続依存**: DJ-B/C/D/F の指摘・解決が gitignored の plan §9 / `tmp/` にしかなく committed 復元不能 → 「gate 2 設計SO で確定した DJ」節に DJ-A〜F を committed 転記。
4. **back-propagation 漏れ**: round1 で足した `head` フィールドと C locale 限界が README 未反映 → README §列挙の JSON フィールド一覧・summary 例・「既知の限界」に転記。

なお discovery 整合の committed/working-tree 差は README §列挙で back-prop 済みと確認された。

### Step 5（negative knowledge 収穫）— in-PR 収穫済み

owner フロー決定（2026-07-24）: negative knowledge の収穫は **in-PR 相乗りが既定**（#278 が最初の実例）。本 episode は収穫基準（非自明・再発しうる・行動を変える・未着地）を満たす 3 件を型付き item として `<engine 蒸留木>/knowledge/items/` にコミットした（source.ref = 本 episode・保存 HG = owner マージ）:

1. **早期 exit consumer × pipefail の SIGPIPE 誤判定**（`01KYA7C9M4EN1EZM3HBEN5WDRP`・landing: nl）: `grep -q` / awk `exit` 等が巨大入力の producer に SIGPIPE を送り、`set -o pipefail` が pipeline を非 0 にして正常データを異常扱いする。→ 大入力経路は「最後まで読み切る」awk にするか pipefail 影響を中和する。
2. **大データを jq/コマンドの argv で渡す ARG_MAX 落ち**（`01KYA7C9MWDKQK79FGDWRC8W6H`・landing: guard-candidate）: `jq --arg/--argjson` に巨大値を argv で渡すと `Argument list too long`（exit 126）で exit 契約を破る。→ `printf`（builtin）+ stdin / here-string で渡す。
3. **環境エラーとデータエラーの分離**（`01KYA7C9NN4VDM7H2NYXZB2PSX`・landing: nl）: `cmd || true` で IO/環境失敗（git object 欠損等）を空データに変換すると「壊れたデータ」に誤分類され exit 契約を破る。→ 失敗は環境エラー（exit 2）として区別する。

全 3 item は `validate-knowledge` の directory mode で pass（exit 0）。信頼境界 = PR レビュー/owner マージ HG（本文は自作の技術知見のみ・secret / 外部由来内容なし）。

## フィードバック

- 想定外だった点: 実装SO の敵対レーン（codex）が round を追うごとに新しい edge を出し続け、修正のたびに別クラスの同種欠陥（argv DoS が excerpt→frontmatter→出力組立と 3 経路）を露呈した。SIGPIPE×pipefail は自分の修正が誘発した罠で、SO でなく自分のテスト実行で検出した。
- 規約遵守状況: plan-first → gate 2 設計SO → owner HG → 実装 → gate 4（実装SO 3 周 + テスト + Copilot）→ closure の順を遵守。マージ/掃除/close/sync は親 / owner に残す。
- ADR 昇格候補: なし（設計正本は既存 discussion §6）。negative knowledge 3 件は Step 5 で in-PR 収穫済み（owner フロー決定＝収穫は in-PR 既定・#278 が最初の実例）。
