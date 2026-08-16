---
id: "01M02WHH47W10QT7YBVYN2TYNG"
title: "#322 HOME 未設定で oe-* が引数解析の前に落ちる — 実装プラン（HOME 部分のみ）"
date: 2026-08-15
type: plan
status: draft
source: "https://github.com/stlwolf/ai-development-hub/issues/322"
scope: orchestration-engine
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/322"
    reason: "本プランの起点（2件のうち HOME 部分のみ・cc-lint はスコープ外）"
  - type: design_context
    ref: "projects/orchestration-engine/docs/episodes/2026-08-15-episode-322-home-unset.md"
    reason: "baseline 実測・gate 2 の反証・棄却した案の正本"
tags: [engine, home, set-u, help, robustness]
so:
  design: weak
  impl: weak
  reason: "先例が同一リポジトリにあり判断の幅は狭い。ただし先例の premise が移らない箇所が複数あり、帯の設計は判断を含む"
---

# #322 HOME 未設定で oe-* が引数解析の前に落ちる — 実装プラン

## この単位が引き受けるもの

`set -u` の下で未定義の `${HOME}` を展開するため、`oe-*` が**引数解析へ到達する前にシェルごと終了する**問題を止める。**#322 のうち `HOME` 部分だけ**を扱い、`cc-lint` の素通り（issue の「1.」）は**スコープ外**である。**#322 は close しない。**

## この plan は gate 2 で当初案が3点覆っている（読む前に）

経緯は episode が正本。結論だけ置く。

1. **スコープが6箇所では足りない。** lib を直すと `bin/oe-jump:31` と `bin/oe-view:30` が次の落下点として露出する（**実測で確定**）。最小は**9箇所**。
2. **「読み取りは空なら state 無しとして振る舞う」は誤り。** #322 の症状（環境の失敗が別の帯を汚す）を修正側で再生産する。
3. **「書き込みは一律で明示失敗」は誤り。** `event-bus` の「常に return 0」という文書化された不変条件と衝突する。

## 確認済みの事実（一次読解 + 実測）

| # | 事実 | 状態 | 根拠 |
|---|------|------|------|
| F1 | 21 verb 中 **13 本**が `HOME` 未設定で `--help` を返せない（rc 0→1） | verified | 21本を `env -u HOME` で実測 |
| F2 | 死ぬ場所は3種。`lib/delegate-registry.sh:14`（8本）/ `lib/oe-viewer.sh:24`（`oe-view`）/ `bin/oe-activity:50`（`oe-activity`） | verified | 各 verb の stderr を採取 |
| F3 | `oe-send` / `oe-ack` / `oe-report` は**出力ゼロで rc=1**。`lib/delegate-send.sh:22` の `source ... 2>/dev/null || true` が診断だけ消し、`set -u` の終了は止められないため | verified | `bash -x` で trace |
| F4 | **lib を直すと `bin/oe-jump:31` と `bin/oe-view:30` が露出する** | verified | 4変数を外から与えて「lib 修正済み」と等価な状態を作り実測（`rc=1` / `行 31` / `行 30`） |
| F5 | `--help` は **stderr** に出る verb がある（`oe-send` で 1492 B・rc=0） | verified | 実測 |
| F6 | 先例（`cc-lint.sh`）は「3分岐の代入」＋「使用側の非空ガード」（`:75` / `:102`）の**対**で成立している | verified | 同ファイル |
| F7 | `${VAR:-default}` は**未設定と空文字を畳む**ので、空文字を入れても後段の `:-` 再評価で既定値へ戻る | verified | 実測（実 registry を1件汚す事故つき・episode に記録） |
| F8 | `lib/event-bus.sh:41-42` は `delegate-registry.sh:14-15` と**同じ変数を再宣言**する | verified | 両ファイル |
| F9 | **6箇所を同時に同じ形へ変え `HOME` 不在が保たれるなら、空文字は塗り直されない**（F7 の観測は「registry 側だけ + 実 HOME 在り」という過渡状態） | verified | codex レーンの指摘を条件で確認 |
| F10 | `lib/event-bus.sh:12-13` が「emit 失敗は本体を壊さない・全 public 関数は常に return 0」を不変条件として明記 | verified | 同ファイル |
| F11 | `bin/oe-ack:154` は `set -e` 下で `oe_event_report_received` を裸呼び出しする | verified | 同ファイル |
| F12 | `oe_reg_record` を明示失敗させても `bin/oe-delegate:373` の `\|\| true` に飲まれる（`bin/oe-register:127` は拾う） | verified | 両ファイル |
| F13 | `tests/test_event_bus.sh:195-205` が「registry が source されない経路でも event-bus 自身が既定を入れる」を assert している | verified | 同ファイル |
| F14 | `HOME=/` は `-n` を通り root 直下を掴む。相対 `HOME` は cwd 配下に state を散らす | unverified-summary | claude レーンの指摘（`-n` の意味からの演繹・未実測） |
| F15 | 同型の未ガードが `bin/oe-undelivered:128`（裸）と `bin/oe-vitals:136/145` / `bin/oe-hookfire:39-40` / `bin/oe-selfcheck:30-35`（`${HOME:-}` 形）に残る | verified | grep + 実測（これらは help が先に短絡するので現状は落ちない） |

## 設計判断

### DJ-1 判定を「非空か」から「宣言済みか」へ変える（`${VAR+x}`）

**採用: 6+3 箇所すべてで次の形にする。**

```sh
if   [ -n "${OE_DELEGATE_STATE_DIR+x}" ]; then :          # 既に決まっている（空文字＝state 無しも含む）
elif [ -n "${HOME:-}" ] && _oe_home_usable; then OE_DELEGATE_STATE_DIR="${HOME}/.claude/state/oe-delegate"
else                                            OE_DELEGATE_STATE_DIR=""
fi
```

- **`+x` にすると宣言済み（空文字を含む）を尊重する**ので、`delegate-registry.sh:14` と `event-bus.sh:41` のどちらが先に走っても塗り替えが起きない（F7 / F8 / F9）。番兵値（相対パスに化ける）とフラグ変数（真実の源が2つ）は両レーンとも退けた。
- **これは `OE_*_DIR=""` の意味を「既定へ落ちる」から「state 無し」へ変える挙動変更である。** PR 本文に明記する。副次的に #270 の F20（`mktemp` 失敗で空になった変数が実環境へ解決される）と同じ危険も塞ぐ。
- **`event-bus.sh:41-42` の再宣言は消さない**（F13 の既存テストが直接 assert している）。

**「先例と同じ3分岐に揃える」という言い方はしない。** 先例の第1分岐は `HOOK_FIRING_DIR` という**別の変数**の検査で、engine 側は**代入対象と同じ変数の「もう決まっているか」検査**になる。見た目は3分岐でも別の構文であり、その違いが F7 の畳み込みを生む。**「先例の形を engine の再宣言構造へ翻訳した」が正確な言い方である。**

### DJ-2 `HOME` の使用可否は「非空」でなく「絶対パスかつ `/` でない」で見る

`-n` だけだと `HOME=/` が通って root 直下（`//.claude/state/...`）を掴み、相対 `HOME` は cwd 配下に state を散らす（F14）。

**先例が `-n` で済むのは、あれが tally を1バイト追記するだけの best-effort だからである。engine は state を作るので同じ基準では足りない。** 採用した negative knowledge `01KZVHE0KQ5VCX0SXH0F4SM14D`（先例の規律を移すときは前提が移植先に在るか確かめよ）が、**代入の形だけでなく判定式の側にも当たった。**

```sh
_oe_home_usable() { case "${HOME:-}" in /) return 1 ;; /*) return 0 ;; *) return 1 ;; esac; }
```

**未実測なので、実装時に `HOME=/` / 相対 / 空文字の3通りを測ってから確定する**（F14 の status を上げる）。

### DJ-3 読み取りは「黙って諦める」を採らない — 帯を分けて名乗る

**当初案（空なら state 無しとして振る舞う）は棄却する。** #322 は「仕組みが動いていないこと自体が観測できない」を直す issue なので、沈黙は要件違反である。

**「置き場が決まっていて中身が無い」（正当な0件）と「置き場が決まらない」（backend unavailable）を区別する。**

| 経路 | 現状の空のときの見え方 | 採る形 |
|---|---|---|
| `oe_reg_resolve`（`:71-121`） | 0件 → **rc=1 `no live target matches`** ＝「宛先が無い」に化ける | **rc=2（環境エラー）** へ倒す。`tmux list-panes` 失敗（`:82-88`）が既に使っている帯に揃える。`%N` 素通し（`:74-77`）は state 不要なので**成功のまま** |
| `oe_reg_list`（`:124-165`） | 全て `pane-title` へ degrade ＝ 登記が無いように見える | 一覧の前に **stderr で1行名乗る**（登記を読んでいない） |
| `bin/oe-tree:414` | `/*.json` を glob → **空ツリーを exit 0** ＝「子は居ない」という誤った成功 | 走査前に**明示**し、root を走査しない |
| `bin/oe-ack:101-105` | `nothing to ack (... /oe-events.jsonl)` で **exit 0** | 環境エラーとして名乗る |
| `bin/oe-ident` / `_oe_event_ident` | 空投影 | **現状のままでよい**（border 表示・label enrichment は best-effort が既存契約） |

### DJ-4 書き込みは経路ごとの既存契約に合わせる（一律にしない）

**issue の受け入れ条件「書き先が無いことを明示して落ちる」は、`event-bus` の不変条件（F10）と正面から衝突する。** 実装者が黙ってどちらかを選ぶべきではないので **owner の gate 3 に上げる**（下記）。plan の既定案は次のとおり。

| 経路 | 既存契約 | 採る形 |
|---|---|---|
| `oe_reg_record`（registry） | 失敗を rc=1 + メッセージで返す | **明示失敗を維持**し、メッセージを「書き先が無い（HOME 未設定）」に整える（今は空パスが出るだけ） |
| `_oe_viewer_write_state`（viewer） | rc=1 + メッセージ | **`oe_viewer_resolve` の先頭へ preflight を移す。** 現状は kill → spawn → write の順なので、write でだけ失敗すると**未追跡のペインが残る** |
| `oe_event_emit`（event log） | **常に return 0**（F10） | **rc は 0 のまま**。`mkdir -p ""` が失敗して root へ触らないことは既に成立しているので、**「なぜ emit しなかったか」を1回だけ stderr に名乗る**に留める |

**`bin/oe-delegate:373` の `|| true`（F12）は本単位では触らない。** 触ると「登記できなかったのに spawn が成功扱い」を変える話になり、#270 のスコープ外節に載せた案E と同じ単位になる。**PR 本文で申し送る。**

### DJ-5 使用側ガードは root を走査する箇所に絞る

空文字は多くの箇所で自然に安全側へ倒れる（`mkdir -p ""` は失敗・`[[ -d "" ]]` は偽・`[[ -f "/x" ]]` は偽）。**追加のガードが要るのは root を走査する glob である。**

- `lib/event-bus.sh:75` … `grep -lF ... "/${pid}"_*.json`（`:38-40` のコメントが避けたいと明言している当のもの）
- `bin/oe-ident:67` … 同型
- `bin/oe-tree:414` … `/*.json`
- `lib/delegate-registry.sh:204` … `:172` の `[[ -d "" ]]` で到達しないが、**#270 で入れた `[[ -n "$pid" ]]` と同じ理由で明示的に非空を確かめる**

`OE_PANE_ISSUE_DIR` は engine が書かず、使用箇所は全て `-f` + `jq` の読みなので**ガードは要らない**（両レーン一致）。

### DJ-6 スコープ — 9箇所を本単位、残りは owner 判断

**本単位（受け入れ条件を満たすのに必要）**: lib 6箇所（`event-bus.sh:41/42/46`・`delegate-registry.sh:14/15`・`oe-viewer.sh:24`）+ `bin/oe-activity:50` + `bin/oe-jump:31` + `bin/oe-view:30`。

**owner の判断に載せる**（下記「gate 3 で決めてほしいこと」）:

- `bin/oe-undelivered:128`（裸の `${HOME}`・help は短絡するが実経路で落ちる。1行）
- `bin/oe-vitals:136/145`・`bin/oe-hookfire:39-40`（`${HOME:-}` 形。`set -u` では落ちないが `/.claude/...` を組み立てる ＝ **受け入れ条件「`/.claude/...` へ書きに行かない」に抵触する**）
- `bin/oe-selfcheck:30-35/165`（同型だが表示ロジックに絡むので別単位を推奨）
- `lib/delegate-send.sh:22` / `lib/event-bus.sh:25` / `:31` の `2>/dev/null`（F3 の「0 B で rc=1」を作った当のもの。6箇所を直せば症状は消えるが**診断を消す仕掛けは残る**）

**`bin/oe-view:30` の `OE_VIEW_ROOTS` は挙動の決定が要る。** `--from-link` の allowlist なので、`HOME` も明示 roots も無いときは**空＝全拒否（fail-closed）**にする。allowlist が決まらないときに通すのは境界の意味が逆である。`tests/test_oe_view.sh:383-393` が既定を検証しているので、テストの追加が要る。

## 手順

### Step 1 — `_oe_home_usable` と3分岐を入れる（9箇所）

`lib/delegate-registry.sh` に判定ヘルパを1つ置き、`event-bus.sh` / `oe-viewer.sh` からも使えるようにする（source されない経路があるので `declare -F` で存在確認してから使い、無ければ各ファイルに同じ判定を持たせる）。9箇所を DJ-1 の形へ書き換える。

### Step 2 — 読み取り側の帯を直す（DJ-3）

`oe_reg_resolve` の rc=2 化、`oe_reg_list` / `oe-tree` / `oe-ack` の告知。

### Step 3 — 書き込み側を経路ごとに整える（DJ-4）

`oe_reg_record` のメッセージ、`oe_viewer_resolve` 先頭への preflight 移動、`oe_event_emit` の1回名乗り（rc は 0 のまま）。

### Step 4 — root 走査のガード（DJ-5・4箇所）

### Step 5 — テスト（新規1本 + 既存の確認）

**`tests/test_home_unset.sh` を新設する**（既存ファイルへの追記は並列 issue の衝突源になるため）。

- **verb 単位**: `bin/oe-*` を **glob で列挙**して表駆動で回す（**今回 `oe-jump` / `oe-view` を落としたのは列挙が手作業だったからである**）。`env -u HOME <verb> --help` が rc=0 かつ出力非空。`--help` は stderr に出る verb があるので `2>&1` で見る。**`oe-ident` は `--help` を持たない**（不正 pane として空・rc=0）ので例外として明記する。
- **帯**: `env -u HOME oe-send <target> <text>` が rc=1（宛先が無い）**ではない**こと。
- **lib 単位**: `env -u HOME` で (i) registry → event-bus (ii) event-bus → registry の**両順序**で source し、4変数が空のままであることを assert する。
- **root を触らない**: `env -u HOME` で `oe_reg_record` が非0で返り、`/` 直下に何も作られないこと。
- **`HOME=/` / 相対 / 空文字**の3通り（DJ-2 の確定と対）。

**実験の規律**: `HOME` を差し替える形（`env -u HOME` / `HOME=<tmp>`）だけを使い、**state dir の変数を直接空にする実験はしない**（episode に記録した事故の再発防止）。

### Step 6 — 検証

```bash
cd /Users/eddy/work/repos/github.com/stlwolf/ai-development-hub.fix-#322_home_unset_guard/projects/orchestration-engine
shellcheck lib/*.sh bin/oe-* tests/test_home_unset.sh
bash tests/test_home_unset.sh
for t in tests/test_*.sh; do bash "$t" >/dev/null 2>&1 || echo "FAIL $t"; done
/bin/bash tests/test_home_unset.sh   # bash 3.2.57（ADR-005）
```

### Step 7 — gate 4（実装SO 2レーン + テスト実行 + Copilot）→ PR

## 受け入れ条件

- [ ] `HOME` 未設定でも `oe-*` が引数解析まで到達し、`--help` が 0 を返す（**`oe-ident` の例外を明記**）→ Step 1 / Step 5
- [ ] `HOME` 未設定で state を書く必要がある経路は、書き先が無いことを明示して落ちる（`/.claude/...` へ書きに行かない）→ Step 3。**ただし `event_emit` は既存不変条件により rc=0 のまま「名乗る」だけ**（gate 3 の裁定に従う）
- [ ] 9箇所が同じ形に揃っている。**`${HOME:-}` を足すだけの直し方は採らない** → Step 1
- [ ] **環境の失敗が「宛先が無い」の帯を汚さない**（`oe_reg_resolve` が rc=2）→ Step 2
- [ ] **`HOME` 未設定のとき、読み取り経路が「空」を成功として黙って返さない** → Step 2
- [ ] root（`/` 直下）を走査・書き込みしない → Step 4 / Step 5
- [ ] `shellcheck` が通り、engine の既存テストが回帰しない（**`test_event_bus.sh:195-205` と `test_oe_view.sh:383-393` を名指しで確認**）→ Step 6
- [ ] bash 3.2.57 と 5.2 の両方で green（ADR-005）
- [ ] PR 本文に「**`cc-lint` 部分は本 PR のスコープ外であり #322 に残る**」と明記する
- [ ] PR 本文に「`OE_*_DIR=""` の意味が変わる」ことと、owner 判断に載せた項目の結論を明記する

## gate 3 の裁定（2026-08-16・owner）

**4件とも裁定が出た。スコープは最終的に「9箇所 + tier 2 の4本 + `2>/dev/null` の3箇所」になる。**

1. **`event_emit` は不変条件を優先する。** rc=0 のまま「書けなかった」を1回名乗る（plan の既定どおり）。**issue の受け入れ条件「明示して落ちる」より `event-bus` の「常に return 0」を上に置く** — 受領印が取れない環境事情で `oe-ack` 本体が `set -e` で死ぬのは本末転倒だから。**受け入れ条件の側がずれているので、統括が issue にコメントを入れる。**
2. **tier 2 は4本とも本単位に入れる**（`oe-undelivered:128` / `oe-vitals:136,145` / `oe-hookfire:39-40` / `oe-selfcheck:30-35`）。自分の推奨は `oe-selfcheck` を別単位だったが、**owner が全部入れると裁定した。** これで受け入れ条件「`/.claude/...` へ書きに行かない」を本単位で完全に満たす。
3. **`2>/dev/null` の3箇所は同じ PR の別コミット**（推奨どおり）。
4. **`OE_VIEW_ROOTS` が空のときの `--from-link` は fail-closed で全拒否**（推奨どおり）。

**PR が大きくなるので、コミットは論理変更ごとに必ず分ける。**

## gate 3 で決めてほしかったこと（裁定済み・記録）

1. **`event_emit` の扱い。** issue の受け入れ条件「書き先が無いことを明示して落ちる」と、`event-bus` の「常に return 0」（F10・`oe-ack:154` は `set -e` 下の裸呼び出し）が衝突する。**plan の既定は「rc=0 のまま1回名乗る」。**
2. **tier 2 をどこまで本単位に入れるか**（`oe-undelivered:128` / `oe-vitals` / `oe-hookfire` / `oe-selfcheck`）。**plan の推奨は `oe-undelivered` + `oe-vitals` + `oe-hookfire` を本単位、`oe-selfcheck` を別単位。**
3. **`2>/dev/null` 3箇所を本単位に含めるか**（`delegate-send.sh:22` / `event-bus.sh:25` / `:31`）。**plan の推奨は同じ PR の別コミット。**
4. **`OE_VIEW_ROOTS` が空のときの `--from-link` の扱い**（推奨: fail-closed = 全拒否）。

## リスク・未確認事項

- **DJ-2 の判定式は未実測**（F14）。実装時に `HOME=/` / 相対 / 空文字を測ってから確定する。
- **「engine 全体で HOME 無しが安全になった」とは主張しない。** 本単位が言えるのは「**未定義 `HOME` で引数解析前に abort するのを止めた**」までである。`HOME=""` / `/` / 相対 / 不存在、および tier 2 の未対応分は残る。
- **両レーンとも verb の実行ができていない**（サンドボックス制限）。F4 の第2落下点は自分の実測で確定させたが、**レーンの判定は静的読解である。**

## gate

- gate 1（ゼロベース代替探索）: 本単位では brief が要求していない（先例が同一リポジトリにあり幅が狭い）。ただし DJ-1 で番兵値・フラグ変数・共通 lib の3案を比較し棄却した記録を残した
- gate 2（設計SO・weak・2レーン）: **通過。両レーンとも実返却。blocker を受けて当初案を3点で改めた**（証跡は `tmp/so-gate2-322/`・episode の gate 2 節）
- gate 3（owner HG）: **本プラン報告後に停止する**
- gate 4（実装SO・weak・2レーン + テスト実行 + Copilot）: 実装後
- gate 5（episode closure・マージ前）+ gate 6（マージ・issue close・worktree 掃除）: 親 / owner。**#322 は close しない**
