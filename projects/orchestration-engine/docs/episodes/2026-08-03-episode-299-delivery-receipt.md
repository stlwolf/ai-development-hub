---
id: "01KZ1VQA1979K4S2MMH5YY24ZJ"
title: "#299 配送シグナルの反転を止め、受け手側の受領印へ置き換える — 実行記録（E 系単位）"
date: 2026-08-03
type: episode
status: stable
related:
  - type: refs
    ref: "https://github.com/stlwolf/ai-development-hub/issues/299"
    reason: "本 issue。owner の gate 3 判断 = P0 + P1 + P3 を1本・P2-b は採らない・transport は P1 の後・oe-ack は含めるが report_received の意味は上書きしない"
  - type: derived_from
    ref: ".oe/plan-delivery-confirm.md"
    reason: "前単位（D 系）の plan。本単位はその §4 P0 / P1 / P3 / P4 を実装する。作業層（gitignored）"
  - type: refs
    ref: "projects/orchestration-engine/docs/plans/2026-06-09-plan-oe-send-ingestion-rootfix.md"
    reason: "#144 の設計判断。marker の実在が当時 verified で記録されており、本単位が失効を確認した相手"
tags: [orchestration, delivery-signal, receipt, hook, oe-send, episode]
---

# #299 配送シグナルの反転を止め、受け手側の受領印へ置き換える — 実行記録（E 系単位）

**この記録はリアルタイム追記である。** 着手時に枠を作り、判断・撤回・棄却をその場で書いている。closure は E7（マージ前）。

## Context（なぜこの作業が始まったか）

前単位（D 系）で、`oe-events.jsonl` の `delivery_signal` が**配送の失敗と逆を指している**ことが分かった。最も厳しい突合（`typed` 限定 + 宛先ペイン束縛 + 1対1排他割当）で `suspected_miss` は 244/250 = 97.6% が到達確認、`none` は 162/217 = 74.7% だった。真の未着候補は `none` 側に 55 件、`miss` 側に 6 件である。

原因は3つ重なっている。`finalize` が Enter を撃った**後**から観測を始めること、画面の目印（`esc to interrupt`）が現行の claude で出ないこと、折り返した payload が `❯` 行1本と全文一致しないことである。

owner の gate 3 判断は「P0 + P1 + P3 を1本で・P2-b は採らない・transport は P1 の後・`oe-ack` は含めるが `report_received` の意味は上書きしない」だった。

## E1. worktree と episode 枠

- branch: `fix/#299_delivery_receipt`（`branch-naming`・`fix` は「機能修正・不具合修正」）
- worktree は子（本セッション）が自作した。統括は hands-off。
- **基準値は統括の申告をそのまま採らず、自分で実測した。** 結果は下の「基準値」節に書く。理由は採用 NK `01KYMRE1N7N0J8VP3CBZZEZ8Q3`（計測器が何を測っているか確かめてから数字を使う）を、他人が測った基準値にも当てるためである。

### 基準値（master・変更前・2026-08-03 実測）

統括が申告した2本は一致した。**本単位が触る領域の基準値も併せて取った**（統括の申告は2本だけで、触る先を覆っていなかったため）。

| テスト | 結果 | 出どころ |
|---|---|---|
| `test_oe_refute.sh` | pass=63 fail=0 | 統括の申告値と一致 [verified] |
| `test_oe_review.sh` | pass=64 fail=0 | 統括の申告値と一致 [verified] |
| `test_delegate_send.sh` | pass=39 fail=0 | 本単位が追加で取った（P0 の変更先） [verified] |
| `test_event_bus.sh` | pass=71 fail=0 | 同上（schema と emit の変更先） [verified] |
| `test_oe_undelivered.sh` | pass=54 fail=0 | 同上（P4 の変更先） [verified] |
| `test_oe_ack.sh` | pass=41 fail=0 | 同上（`oe-ack` の位置づけ見直し先） [verified] |
| `test_oe_activity.sh` | pass=70 fail=0 | 同上（`delivery_signal` の表示先） [verified] |

## E2. P0 — 反転した記録を止める

### 止めたもの（1点だけ）

`lib/delegate-send.sh` で、finalize が rc=3 を返したときに `delivery_signal="suspected_miss"` を焼いていた1行だけを変えた。いまは `unknown` を書く。

### 止めなかったもの（意図して据え置いた2点）

plan §4 P0 が「同じ `fin_rc==3` が3つのものを駆動している」と書いたうちの、残り2つには触っていない。

1. **`OE_SEND_SIGNAL_MISS=1` のときの rc=4。** 呼び出し側のフォールバック用。opt-in であり既定では発火しない。
2. **finalize の回復状態機械そのもの**（staged_idle の Enter 撃ち直し）。これを止めるのは P2-b の領分で、owner が採らないと判断した範囲に隣接する。

**「失うものはほぼ無い」と言えるのは1の範囲に限る。** 母集団で rc=3 が拾えていた真の stage miss 6 件は `unknown` の中に残るが、`unknown` は未着を意味しない。判別には受領印（P1）が要る。

### `none` を上書きしなかった理由

`none` の定義は「未着シグナル無し（`delivered` の確証ではない）」である。ここへ「観測を止めた」の意味を載せると、**過去レコードの意味まで遡って変わってしまう。** schema は additive 拡張を明記しているので、`unknown` を足すほうを採った。rc=0 は従来どおり `none` を書く。

### `suspected_miss` を enum から消さなかった理由

過去レコードに 342 件残っており、enum から消すと既存ログが schema 違反になる。値は残し、**description に「書き込み停止・実測で逆を指していた・未着の根拠に使ってはならない」と書いた。**

`lib/event-bus.sh` の正規化でも `suspected_miss` を受理値として残した。呼び出し側が渡してきた値を黙って `none` へ潰すと、渡された事実が消えるためである。**書き込みを止めたのは `delegate-send.sh` 側であって、正規化側ではない。**

### テスト

`test_event_bus.sh` に [20]〜[24] を追加した（pass 71 → 95・fail=0）。既存テストはこの書き込みパスを覆っていなかった。

### この段で踏んだ失敗

追加したテスト [22] が role 解決で2件落ちた。**テストを緩める前に原因を見に行った**ところ、同ファイルの [16] が registry GC を模擬して `rm -f "$OE_DELEGATE_STATE_DIR"/*.json` しており、その後に走る自分のブロックには fixture が無かった。期待値を下げるのでなく、自分のブロックで fixture を張り直して解消した。

## E3. P1 + P3 — 受け手側の受領印と、前提の健全性検査

### P1 の形

送信側（`lib/delegate-send.sh`）が payload の末尾へ相関 ID を載せる。受け手側（`canonical/hooks/scripts/oe-prompt-receipt.sh`・`UserPromptSubmit` hook）が、それを自分のターンとして取り込んだ瞬間に `prompt_received` を追記する。

- **nonce**: `[oe:<26 桁>]`。`_oe_send_nonce` が外部コマンドなしで払い出す（1000 回で衝突なし・Crockford base32 の文字集合内であることを実測）。**厳密な ULID 仕様互換ではない**（`$RANDOM` 由来なので「一意な 26 桁」までを主張する）。
- **冪等**: 書き込み側では重複を潰さない（append-only の不変条件を崩さないため）。同じ nonce の受領は **read 側で 1 件に畳む。**
- **`report_received` を上書きしない**: 別イベントにした。`prompt_received` は `covers_*` を持たない。`report_received`（読んだ）と `prompt_received`（1 ターンとして取り込んだ）は別物である。
- **`--no-enter`（ステージのみ）には nonce を載せない。** `message_sent` を emit しないので、載せると突き合わせ先の無い受領印を作ってしまう。
- **preview にタグを載せない。** 画面へ流す文字列とログの preview を分けた。nonce は構造化フィールド（`delivery_receipt.nonce`）に入る。

### 版依存であることの書き方（強めない）

hook は Claude Code の契約（イベント名・stdin の `.prompt`・`$TMUX_PANE` の伝播）に依存する。plan が置いた強さをそのまま保ち、**「免疫があるとは言わない。壊れ方がましだと言っている」**と書いた。ましだと言える根拠は1つだけである。失効した画面の目印は**静かに嘘の値を出し続けた**のに対し、hook 契約が壊れた場合は**印が出なくなる**という観測可能な形で現れる。

**そして「観測可能」は自動では観測されない。** だから P3 を同じ単位に入れた。

### transport 凍結の再判定

**P1 が入ると、2026-06-09 に置いた「transport 据え置き」の判断を再判定できるようになる。** 当時の据え置きは「clean 環境で再現不能 → 比較計測が不能 → 賭けない」という三段の理由だった。受領印は実トラフィックでの到達率を出すので、**transport を替えたときの前後比較ができる。** 本単位では替えない（owner 判断で P1 の後）。

> **この節の書き方は E5 で撤回した。** 実装SO が「前後比較ができる」を過大と判定した（ベースライン不在・欠測の交絡・計測自体が payload を伸ばす）。確定形は `本文: E5. gate 4 — 実装SO + テスト` の「反証で直したもの（言い切り）」を見ること。

### P3 の形（`bin/oe-selfcheck`）

対象は画面 scrape だけではない。**hook 契約・transcript の JSONL 形式・pane↔session の橋・保持期間**も同じ版依存であり、同じ壊れ方をする。

判定を3値にしたのが肝である。`ok` / `broken` / **`indeterminate`（検査自体が成立しなかった。ok ではない）**。採用 NK `01KYMRE1N7N0J8VP3CBZZEZ8Q3` の「0件を不在の証拠にするな」を、**各検査に陽性対照を持たせる**形で実装した。たとえば受領印が 0 件でも、nonce 付きの送信が 0 件なら `indeterminate` にする（検出できる対象が無いのだから異常と読めない）。送信が在って受領印が 0 件のときだけ `broken` と断定する。

画面 scrape の検査は「いま目印が見えるか」では見ない（idle と区別できないため）。**目印は入力欄より上に描かれる**という構造を使い、入力欄が画面下3行に入っているペインでは目印が走査窓に決して入らない、と決定論的に判定する。

この時点の実行結果は `screen-marker=broken`（既知・P2-b は owner 判断で採らない）、`hook-contract=broken`（sync 前なので配線が無い＝正しい報告）、残り3つは `ok`。

> **判定の作りは E5 で3か所直した**（`hook-contract` を直近窓へ・`transcript-format` を JSON 解析へ・`retention-horizon` を `info` へ）。確定形は `本文: E5. gate 4 — 実装SO + テスト`。

### この段で踏んだ失敗（3件）

**1. 持ち越し NK がそのまま出た。** `oe-selfcheck` の初版が transcript を「無い」と誤判定した。原因は `set -o pipefail` の下で `find | xargs ls -t | head -1` を使い、`head` の早期終了で上流が SIGPIPE → パイプライン非0 → `|| newest=""` が**正しく取れていた値を消していた**こと。持ち越し item `01KYA7C9M4EN1EZM3HBEN5WDRP`（pipefail + 早期終了 consumer の SIGPIPE）そのものである。`xargs` の分割で「先頭バッチの最新」しか採れない問題（`01KYA7C9MWDKQK79FGDWRC8W6H` と同根）も同時に避けるため、`date -r` による 1 パス走査へ書き換えた。

**2. 自分のテストが別の理由で通っていた。** `oe-selfcheck` の「送信あり・受領印 0 件 → broken」を検証するテストで、fixture の hook を `$HOME/hooks/` に置いていた（正しくは `$HOME/.claude/hooks/`）。そのため実際には「配線はあるが実行可能でない」で broken になっており、**期待した verdict が別の理由で出ていた。** verdict だけでなく理由（detail）まで検証するアサーションを足して塞いだ。

**3. Write が制御バイトを生のまま埋めた。** `oe-selfcheck` の jq に US（`\x1f`）が生バイトで入った。動作は正しかったが、ソースに生の制御文字が残るのは読めない・壊れやすいので `\u001f` 表記へ直した（既知の罠）。

## E4. P4（1〜5・shadow mode）と `oe-ack` の位置づけ

### P4 の 1〜5 をどう入れたか

| 項目 | 入れ方 |
|---|---|
| 1. 起点（watermark） | `--start-after` / `--set-start-after`。**過去のイベントは消さない。** 起点だけを別ファイルに置き、`--start-after 0` でいつでも全期間へ戻せる |
| 2. shadow mode | **既定を shadow にした。** stdout には出すが owner へは通知しない。`--notify` を明示したときだけ ping |
| 3. 受領印基準の表示 | 「未ack」から「受領印が無い」へ。nonce の無い送信は `判定不可` と出し、**未着とは呼ばない** |
| 4. メッセージ単位 | 抑止キーを `<child>\|<parent>\|<ts>\|<idx>` にした。関係単位だと ack が来ない限り最古未ack の ts が動かず、**同じ関係の新しい未達が永久に抑止されていた** |
| 5. 生存絞り | 既定で相手のペインが消えている行を伏せる。伏せた件数は毎回告げる。liveness が判定できない（tmux 不在）行は落とさない ／ **→ E5 で既定を反転した**（`本文: E5. gate 4 — 実装SO + テスト`） |

### 反転表示の解消

`MISS` 列を廃止した。`suspected_miss` を数える列は、実測で逆を指していた値を「miss」として提示していた。判定にも表示にも使わない。

### 実測での効き方

master 時点では 87 行の恒久バックログを吐いていた。この時点の実装では、既定（shadow・生存絞り・起点なし）で **32 行**、`--alive-only` を外すと 331 行だった（メッセージ単位へ移した分だけ増える）。

> **既定はこのあと E5 で反転した。** 生存絞りを既定にすると `oe-undelivered` の主目的が隠れるためである。運用は「起点（watermark）を置いてから見る」で、そうすると新しいぶんだけが出る。

### `oe-ack` の位置づけ

**`report_received` の意味は薄めなかった。** 2つの層を明示的に分けて `bin/oe-ack` の冒頭へ書いた。

- `prompt_received`（#299）: 受け手のセッションが 1 ターンとして**取り込んだ**。機構が自動で撃つ。人の意思を含まない。
- `report_received`（#206A）: 受け取った人 / AI が**読んだ**。手で打つ。機構では代替できない。

**`prompt_received` を `report_received` の代わりに数えてはならない**と明記した。あわせて、`report_received` が6週間で1件しか打たれていない事実と、**その原因が「人が手で打つ verb にした」という設計自体にありうること、そして #299 はそれを解決していないこと**を開示した。到達の可視化だけを機構へ移し、「読んだ」の層は手動のまま残してある。

### この段で踏んだ失敗

**自分が変えたテストが別の理由で通っていた。** `test_delegate_send.sh` の finalize 系テストが4件落ちた。原因は nonce タグで、mock が返す画面（元 payload のみ）と実際に送る文字列（タグ込み）が食い違って `staged` が一致しなくなったことである。実運用では画面にタグ込みが出るので production は正しい。**問題は、落ちた4件の隣にある「Enter は1回」を主張するテストが、同じ理由で通ってしまっていたこと**である（回復が発火しないので結果的に1回になる）。テストの主張が別の理由で成立する状態だったので、finalize 系ブロックでは `OE_SEND_NONCE=0` にして意味を戻し、タグ経路は別テスト（[25][26]）で検証する形にした。

### 副作用の開示

nonce タグで **payload が約 32 文字伸びる。** 長文は入力欄で折り返すと finalize の照合が外れる（#299 で判明した機構）ので、境界付近の送信がわずかに折返し側へ寄る。P2-b（折返し対応）は owner 判断で採っていないため、この分は残る。

## E5. gate 4 — 実装SO + テスト

### 実機確認

隔離した `OE_EVENT_DIR` と使い捨ての claude ペイン2枚で end-to-end を通した。hook は canonical から `~/.claude/hooks/` へ symlink し、`settings.json` へ配線して確認したあと、**両方とも元へ戻した**（worktree を指す symlink を残すと、worktree 削除時に無言で壊れるため。既知の footgun）。

- 受領印が両ペインで出て、`from.pane` がそれぞれ `%279` / `%280` と**別のペインに束縛**された。nonce は送信と1対1で一致した。
- `oe-selfcheck` の `hook-contract` が、配線前 `broken` → 配線後（送信なし）`indeterminate` → 送信と受領印あり `ok` と、設計どおり3値で動いた。
- `oe-undelivered` は受領印のある送信を出さなくなった。

**「自分の pane」では確認していない。** brief は「自分の pane と別の pane の両方」と書いているが、自分のセッションへプロンプトを注入すると作業中の会話へ割り込む。**ペイン束縛が効くかという検証意図は、異なる2枚で満たせると判断した。** 判断として開示する（親が literal な確認を求めるなら別途）。

### 実機で見つけた設計の誤り

**受領印は `message_sent` より必ず先に書かれる。** 送信側は finalize の観測窓（3秒）が閉じてから `message_sent` を書くのに対し、hook は submit の瞬間に走るためである。初版の hook はここで nonce をログから引いて送信元を焼こうとしていたが、**実機 2 件とも解決できず空になった。** 成功しない lookup は「黙って空へ縮退する」経路なので削除し、送信元は read 側が nonce で解決する形にした。

### 実装SO（gate 4・3レーン）

`SO_TIMEOUT=480 SO_CLAUDE_TIMEOUT=1200 so-compare --with codex,claude,cursor`。反証の観点として「効果の言い切り」「版依存の前提が他にも無いか」を明示的に投げた。生出力はパスで渡し、貼っていない。

出力は `tmp/so-e5-impl/`（作業層・gitignored）。

| レーン | 所要 | 分量 | 判定 |
|---|---|---|---|
| cursor | 136 秒 | 11.4KB | `partially-refuted` |
| codex | 425 秒 | 19.5KB | **`refuted`** |
| claude | 1200 秒 ×2（初回＋リトライ） | 0 | **`timeout_empty`（両方とも空）** |

**2レーンが実返却したので 0 レーンではない。** claude は既定 1200 秒（brief の「720 秒以上」を満たす）で空返しになり、**リトライ（同じ 1200 秒）でも空だった。**so-compare スキルは「既定の 1200 秒で `timeout_empty` が一度でも観測されたら既定値を測り直すこと」と書いており、**これはその1件目である。** `scripts/so-compare.sh` は本単位のスコープ外（#298 が控えている）なので触らず、事実だけ surface する。

### 反証で直したもの（コード）

**2レーンとも同じ2点を最重要として指した。** どちらも実在の欠陥だったので直した。

1. **`oe-undelivered` が受領印を nonce だけで照合していた。** 別のペインが同じタグを submit しただけで未達が消える ＝ marker と同型の「届いていないのに届いた扱い」。**宛先ペインまで一致を要求する**よう修正し、テストを足した。
2. **`oe-selfcheck` の `hook-contract` が「生涯累計で1件でもあれば ok」だった。** 一度成功すればその後 hook が死んでも永久に緑。**marker が踏んだ罠を、marker を検知するための検査器で再生産していた。** 直近 N 件 + 猶予の窓で見る形へ修正した。

codex がさらに挙げ、直したもの。

3. **相手が gone の行を既定で伏せていた。** これは `oe-undelivered` の**主目的（統括死亡で報告が消える経路）を既定で隠す**。plan の P4-5 は「生存している相手だけに絞る」と書いていたが、**実装時に判断を変えた**。既定で gone も出し、絞りたいときだけ `--alive-only` を打つ。ノイズ制御は起点（watermark）が担う。**plan の記述から意図的に外れた唯一の点であり、理由とともに開示する。**
4. **`.prompt` からタグを取り出せない場合が「タグ無し」と区別できなかった。** 契約変更の疑いとして診断へ記録する。
5. **全検査が `indeterminate` でも exit 0 だった。** 機械監視から見て成功に見えるなら「indeterminate は ok ではない」は画面上の言葉でしかない。exit 2 へ分けた。
6. **`transcript-format` が文字列 grep だった。** 本文に同じ文字列があるだけで ok になる。JSON として user ターンを読む形へ。最新1本だけを見る作りが**プロンプト 0 件の新規セッションで誤爆する**のも実測したので、新しい数本を見る形にした。
7. **`retention-horizon` が常に ok を返していた。** 良し悪しの基準が無いのに ok を出すと他の ok と並んで誤読される。`info` へ分けた。
8. **`判定不可` を owner ping に載せていた。** 未着と呼ばないと決めた対象を鳴らすと、また判別力の無い警報になる。stdout には出し、通知からは外した。

### 反証で直したもの（言い切り）

採用 NK `01KYW0BPJNHP94TNX0VG4G11TX` は「自分が名指しして検出した失敗の型を、こんどは自分が書き手として犯す」ことを警告していた。**警告どおりに犯していた。** 2レーンが名指しした4件に成立条件を併記した。

| 言い切っていた内容 | 直した形 |
|---|---|
| 送信と受領が **1対1に突き合う** | 「read 側が nonce と宛先ペインの両方を見る場合に限る」を併記 |
| ペイン束縛なので**取り違えが起きない** | 「read 側がその束縛を実際に照合する場合だけ」を併記 |
| **壊れ方がまし**だ | 成立条件3つ（selfcheck が実行されること・宛先まで照合すること・契約変更が診断に残ること）を併記し、**(a) は未配線だと明記** |
| transport の**前後比較ができる** | 「材料が揃う」へ弱め、成立条件3つ（ベースライン不在・欠測の交絡・計測自体が payload を伸ばす）を併記 |
| lookup は**構造的に必ず失敗する** | 「実機 2 件で確認。`OE_SEND_FINALIZE=0` 等では順序が入れ替わりうるので『常に』とは言わない」へ |

### 反証のうち採らなかったもの

- **`oe-selfcheck` の定期実行を入れる**（codex / cursor）。cron / launchd への登録は owner 環境依存であり、brief のスコープにも無い。**未配線であることを README と hook のコメントに明記して surface した。** 「壊れ方がまし」の成立条件 (a) がここに掛かっているので、埋まっていないことを隠さない。
- **`oe-activity` の `MISS` 列の是正**（cursor）。brief が名指ししたのは `oe-undelivered` だけである。README に「過去の反転信号を数え続ける・根拠に使うな」と注意書きを置いて surface した。
- **rotation 時の抑止キー不安定・並行実行の排他**（codex）。実在の限界だが本単位の範囲外。README へ開示した。

## E6. PR + Copilot

PR = https://github.com/stlwolf/ai-development-hub/pull/300（`Refs #299`・close しない）。owner 判断で落とした範囲（P2-b / transport）と、P0 の範囲を1点に限ったことを本文へ明記した。

Copilot の指摘は**1件**で、妥当だったので対応した。

- **診断行の JSON エスケープ不足。** `note_env_error` は jq が無いときも通る経路なので手作りの JSON を書いているが、`detail` の `"` を消すだけでバックスラッシュ・改行・タブを escape していなかった。`detail` にパスが入るので、パスに `\` や改行が含まれると `oe-receipt-diag.jsonl` が壊れた JSONL になり、**後段の集計ができなくなる**（診断ファイルの存在意義が消える）。`_json_escape` を足して修正し、危険な文字を含むパスで診断行が JSON として読めることを確かめるテスト [14] を追加した。

**1ラウンドで止める。** 再レビューの再リクエストはしない（brief の指示どおり）。

## E6b. 追加 scope — 測定器を PR に含める（統括の指示・理由つき）

E7 で一度締めたあと、統括から義務を足す scope 追加が来た。**終端（E7）も step 構成も変えない**指示だったので、矛盾の指摘は要らないと判断してそのまま実施した。

**理由（統括の言）**: plan と episode が「P1 が入ると transport 据え置きを再判定できる／替えたときの前後比較ができる」と書いている。**前後比較は同一の測定器でなければ成立しない。** 別々に書き直すと方法が変わって比較不能になる。ところが測定器 `.oe/measure-delivery-confirm.py` は gitignored の作業層にあり、消える。episode は条件（`typed` 限定 + 宛先ペイン束縛 + 1対1排他割当）と結果を残しているが、**コードは残らない。**

これは正しい指摘である。本単位は「前後比較ができる（→ 材料が揃う）」と書きながら、**その比較を可能にする当の道具を成果物から落としていた。**

### やったこと

- `projects/orchestration-engine/scripts/measure-delivery-arrival.py` として PR に含めた。置き場は engine の `scripts/`（既存は `.sh` のみだが、検証でなく測定なので `measure-` の名で新しい family として置いた）。
- **アルゴリズムは一字も変えていない。** `import` 以降を作業層の原本と `diff` して完全一致であることを確認した。変えると過去の測定値と比較できなくなるためである。
- docstring に1節ずつ書いた: 何を測る道具か / 受領印との使い分け（受領印は #299 以降の送信にしか付かないので、**transport 変更の「前」を取れるのは本測定器だけ**）/ 方法の4条件 / 再実行の仕方と `OE_MEASURE_CUT` の意味 / **結果は環境依存である**（保持期間・橋・再送・JSONL 形式）/ **秘匿の境界**（全プロジェクトの transcript を走査するので出力は件数に留める）/ 読み方の注意。
- `projects/orchestration-engine/README.md` のツリーと `bin/README.md` の「到達の確認」節から辿れるようにした。
- `python3 -m py_compile` を通した（python なので `shellcheck` の対象外）。実行して同じ方法で動くことも確認した（`suspected_miss` 245/251=97.6% / `none` 166/222=74.8%。件数が増えているのは調査後に送信が積まれたためで、率は変わっていない）。

### この追加で分かったこと

**「材料が揃う」と書いたときに、材料そのものが成果物に入っているかを確かめていなかった。** 効果の言い切りには成立条件を併記するようになったが、**その条件を満たす物が実際に残るか**は別の確認である。E5 で言い切りを4件撤回した直後に、同じ抜けを別の面で作っていた。

## E7. closure（マージ前）

**tier = heavy。** heavy トリガに複数該当する。実行中に失敗と撤回があった（本文の各段「この段で踏んだ失敗」）。品質ゲート目的で外部レビューを明示起動した（`本文: E5. gate 4 — 実装SO + テスト`）。非自明な設計判断があり棄却した案がある。昇格候補がある。

### closure gate

- **Context / なぜ**: 冒頭の Context 節に自己完結で書いた（`本文: Context（なぜこの作業が始まったか）`）。
- **次の消費者**: (1) この PR をレビューする owner。(2) transport の入れ替えを判断する単位（受領印と `scripts/measure-delivery-arrival.py` がその材料になる）。(3) `oe-selfcheck` の定期実行を配線する単位。(4) `oe-activity` の反転表示を是正する単位。
- **status**: `stable`（達成）。scope の P0 / P1 / P3 / P4 / `oe-ack` はすべて入り、テストと実機で確認した。
- **最終のテスト**: engine 全体で **945 pass / 0 fail**（測定器は python なので `shellcheck` の対象外・`py_compile` で構文を確認）（Copilot 対応の回帰テスト2件を含む）。基準値 `test_oe_refute.sh` pass=63 / `test_oe_review.sh` pass=64 は master と同値。
- **evidence anchor**: SO 出力は `tmp/so-e5-impl/`（gitignored・揮発）なので、**判定・所要・分量・指摘の要点を本文へ転記済み**（`本文: E5. gate 4 — 実装SO + テスト`）。実機確認の結果も数値ごと本文にある。

### follow-up の routing

| 残課題 | 行き先 |
|---|---|
| `oe-selfcheck` に定期実行の配線が無い | **起票を統括へ提案**（owner 環境依存の登録を含むため子は起票しない）。README と hook コメントに未配線と明記済み |
| `oe-activity` の `MISS` 列が過去の反転信号を数え続ける | **同上**。README に注意書きで surface 済み |
| 親→子の kick が `oe-undelivered` の対象外 | **追わない（本単位では）。** plan が明示的にスコープ外としており、判定方向の拡張は別設計 |
| ログ rotation で抑止キーが不安定・並行実行の排他が無い | **同上**。README へ開示済み |
| so-compare の claude レーンが既定 1200 秒で `timeout_empty`（1件目の観測） | **#298 へ申し送り**（`scripts/so-compare.sh` は本単位で触らない指示） |
| `report_received` の採用率がほぼゼロという設計問題 | **追わない（本単位では）。** `bin/oe-ack` の冒頭に原因の見立てとともに開示し、判断は別単位へ |

### 事実・失敗

- **「前後比較ができる」と書きながら、比較に要る測定器を成果物へ入れていなかった**（統括の追加 scope で是正・`本文: E6b. 追加 scope — 測定器を PR に含める（統括の指示・理由つき）`）。

- 追加したテストが registry GC の fixture 不在で落ち、**期待値を下げずに前提を戻して解消した**（`本文: E2. P0 — 反転した記録を止める`）。
- 持ち越し NK の `pipefail` + `head` の SIGPIPE を実際に踏み、検査器が transcript を「無い」と誤判定した（`本文: E3. P1 + P3 — 受け手側の受領印と、前提の健全性検査`）。
- **自分のテストが別の理由で通っていた**のを2回作った。1回目は fixture の hook 配置ミス、2回目は nonce タグで mock と実送信が食い違い「Enter 1回」が別の理由で成立していた（`本文: E3. P1 + P3 — 受け手側の受領印と、前提の健全性検査` / `本文: E4. P4（1〜5・shadow mode）と oe-ack の位置づけ`）。
- **実機で初めて分かった設計の誤り**: 受領印は `message_sent` より先に書かれるので、hook 側の送信元 lookup は成功しない（`本文: E5. gate 4 — 実装SO + テスト`）。
- **言い切りを4件、外部レビューに名指しされて撤回した**（`本文: E5. gate 4 — 実装SO + テスト`）。
- **Copilot が実質的な指摘を1件出し、対応した**（診断行の JSON エスケープ不足・`本文: E6. PR + Copilot`）。**手作りの JSON を書く経路を作ったのに escape を忘れていた** — 診断ファイルは後段の集計対象なので、壊れた行を1つ書くと存在意義が消える。
- **`Write` が制御バイトを生のまま埋める罠を2回踏んだ**（`本文: E3. P1 + P3 — 受け手側の受領印と、前提の健全性検査`。episode 本文でも1回）。

### 決定と根拠（棄却した案を含む）

- **`none` を上書きせず `unknown` を additive に足した。** 棄却した案は「rc=3 も rc=0 も一律 `unknown` にする」。実測で rc=3 が拾えていた真の stage miss 6 件を判別できなくなり、それを P1 の受領印が代替しないため（`本文: E2. P0 — 反転した記録を止める`）。
- **`suspected_miss` を enum から消さなかった。** 過去 342 件が schema 違反になる（同上）。
- **`prompt_received` を `report_received` と別イベントにした。** 「取り込んだ」と「読んだ」は別で、後者を前者で埋めると意味が薄まる（`本文: E4. P4（1〜5・shadow mode）と oe-ack の位置づけ`）。
- **hook を自己完結にし、engine の lib を source しない。** 既存の配備物（notify.sh / statusline）と同じ作法で、配備先からリポジトリが見えないため（`本文: E3. P1 + P3 — 受け手側の受領印と、前提の健全性検査`）。
- **gone を既定で伏せない（plan の P4-5 から意図的に外れた）。** 伏せると `oe-undelivered` の主目的が既定で見えなくなる（`本文: E5. gate 4 — 実装SO + テスト`）。

### わかったこと

- **失効した版依存は「静かに嘘を出し続ける」形で壊れる。** marker は 2026-06-09 に `verified` と記録され、約2か月そのまま信じられていた。壊れたことに気づく仕掛けが無ければ、記録の `verified` は時間とともに嘘になる（`本文: Context（なぜこの作業が始まったか）`）。
- **バグが安全装置の死を隠すことがある。** 折返しのバグが staged_idle の発火を塞いでいたおかげで、marker 死による busy ガードの無効化が事故として表面化していなかった（同上）。
- **検査器は検査対象と同じ罠を踏む。** `hook-contract` の初版が「一度成功すれば永久に緑」で、marker とまったく同じ壊れ方をしていた（`本文: E5. gate 4 — 実装SO + テスト`）。

### 原則（Pattern / Anti-pattern）

- **NG**: 検査の陽性判定を「累計で1件でもあれば ok」にする。**OK**: 直近の窓で見る。累計だと、対象が死んだ後も過去の成功で緑を出し続ける。
- **NG**: 「0 件だったから異常なし」。**OK**: 陽性対照が取れないなら `indeterminate` を返し、`ok` を名乗らない。さらに **`indeterminate` を exit 0 にしない**（機械監視から見て成功に見えるなら、区別は画面上の言葉でしかない）。
- **NG**: ノイズを減らすために、その仕掛けの主目的に当たる対象を既定で伏せる。**OK**: ノイズは別の軸（観測の起点）で減らす。

### 蒸留シグナル

- **knowledge store への収穫**: 下の Step 5 で 2 件収穫した。
- **Decision / ADR への昇格**: **不要と判定した。** 理由を書く。durable なのは「信号が反転していた」「marker が死んで安全装置が置物になっていた」という**観測**であって、設計判断ではない。観測は #299 の issue 本文と本 episode に残っており、設計判断（受け手側で撃つ・別イベントにする・P2-b を採らない）は plan と本 episode から復元できる。**新しい規範を積む段階ではない**（#290 で「規範は積まない」と判断した線に合わせる）。ただし**「版に固定された前提には気づく仕掛けを付ける」は規範化の候補**であり、`oe-selfcheck` の定期実行が入って実効が出てから判断するのが順序として正しい。
- **skill / rule への昇格**: なし。

### Step 5: negative knowledge の収穫（2 件）

`projects/orchestration-engine/docs/knowledge/items/` へ in-PR 相乗りでコミットした。

- `01KZ21M0N0FZ4YMR2R6DPHTWQ4` — 検査器の陽性判定を累計で持つと、対象が死んだ後も緑を出し続ける。
- `01KZ21M0N19WCXAY9G7FQ1SBEK` — ノイズ低減のために、その仕掛けの主目的に当たる対象を既定で伏せない。

収穫しなかった候補: 「Write が制御バイトを埋める」は既存 reference に着地済み。「テストが別の理由で通る」は既存 item と同旨。

### Step 6: 注入された knowledge への観測の書き戻し

brief の slot に載っていた **6 件すべて**に1レコードずつ書き戻した（`ref: "#299"`）。

| item | state |
|---|---|
| `01KYA7C9NN4VDM7H2NYXZB2PSX` | `followed` |
| `01KYMRE1N7N0J8VP3CBZZEZ8Q3` | `followed` |
| `01KYW0BPJNHP94TNX0VG4G11TX` | `externally_verified` |
| `01KYA7C9MWDKQK79FGDWRC8W6H` | `followed` |
| `01KYCQV7SD6BVBWVCRFYJH9TYG` | `no_opportunity` |
| `01KYA7C9M4EN1EZM3HBEN5WDRP` | `externally_verified` |

`externally_verified` にした 2 件は、どちらも**予測どおりの失敗が外部（実装SO / 実測）で確認された**もので、単なるビルド成功ではない。

### Step 4: heavy tier の外部チェック

**辞退する。** 定型で書く。

Step4 辞退: 本単位の実装SO（3レーン起動・2レーン実返却）が closure 品質の4観点のうち3つを実質的に覆っており、残る1つは本 closure 内で機械的に確認できた / 既存チェックで覆った観点: 省略チェック（実行ログの失敗・撤回・指摘は SO が名指しした4件を含めすべて「事実・失敗」節に項目がある）・back-propagation（SO 指摘は README・hook コメント・schema・plan からの逸脱として本文へ反映済み）・evidence anchor（揮発する `tmp/so-e5-impl/` の要点を本文へ転記済み） / 未実施観点と判断: routing 網羅は追加 SO を回さず自己確認した（残課題6件すべてに行き先を付与済みで、行き先なしの箇条書きが無いことは本 closure の表で機械的に見える）
