---
id: "01KZ1VQA1979K4S2MMH5YY24ZJ"
title: "#299 配送シグナルの反転を止め、受け手側の受領印へ置き換える — 実行記録（E 系単位）"
date: 2026-08-03
type: episode
status: draft
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

- **nonce**: `[oe:<ULID 26桁>]`。`_oe_send_nonce` が外部コマンドなしで払い出す（1000 回で衝突なし・Crockford 文字集合内であることを実測）。
- **冪等**: 書き込み側では重複を潰さない（append-only の不変条件を崩さないため）。同じ nonce の受領は **read 側で 1 件に畳む。**
- **`report_received` を上書きしない**: 別イベントにした。`prompt_received` は `covers_*` を持たない。`report_received`（読んだ）と `prompt_received`（1 ターンとして取り込んだ）は別物である。
- **`--no-enter`（ステージのみ）には nonce を載せない。** `message_sent` を emit しないので、載せると突き合わせ先の無い受領印を作ってしまう。
- **preview にタグを載せない。** 画面へ流す文字列とログの preview を分けた。nonce は構造化フィールド（`delivery_receipt.nonce`）に入る。

### 版依存であることの書き方（強めない）

hook は Claude Code の契約（イベント名・stdin の `.prompt`・`$TMUX_PANE` の伝播）に依存する。plan が置いた強さをそのまま保ち、**「免疫があるとは言わない。壊れ方がましだと言っている」**と書いた。ましだと言える根拠は1つだけである。失効した画面の目印は**静かに嘘の値を出し続けた**のに対し、hook 契約が壊れた場合は**印が出なくなる**という観測可能な形で現れる。

**そして「観測可能」は自動では観測されない。** だから P3 を同じ単位に入れた。

### transport 凍結の再判定

**P1 が入ると、2026-06-09 に置いた「transport 据え置き」の判断を再判定できるようになる。** 当時の据え置きは「clean 環境で再現不能 → 比較計測が不能 → 賭けない」という三段の理由だった。受領印は実トラフィックでの到達率を出すので、**transport を替えたときの前後比較ができる。** 本単位では替えない（owner 判断で P1 の後）。

### P3 の形（`bin/oe-selfcheck`）

対象は画面 scrape だけではない。**hook 契約・transcript の JSONL 形式・pane↔session の橋・保持期間**も同じ版依存であり、同じ壊れ方をする。

判定を3値にしたのが肝である。`ok` / `broken` / **`indeterminate`（検査自体が成立しなかった。ok ではない）**。採用 NK `01KYMRE1N7N0J8VP3CBZZEZ8Q3` の「0件を不在の証拠にするな」を、**各検査に陽性対照を持たせる**形で実装した。たとえば受領印が 0 件でも、nonce 付きの送信が 0 件なら `indeterminate` にする（検出できる対象が無いのだから異常と読めない）。送信が在って受領印が 0 件のときだけ `broken` と断定する。

画面 scrape の検査は「いま目印が見えるか」では見ない（idle と区別できないため）。**目印は入力欄より上に描かれる**という構造を使い、入力欄が画面下3行に入っているペインでは目印が走査窓に決して入らない、と決定論的に判定する。

現時点の実行結果は `screen-marker=broken`（既知・P2-b は owner 判断で採らない）、`hook-contract=broken`（sync 前なので配線が無い＝正しい報告）、残り3つは `ok`。

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
| 5. 生存絞り | 既定で相手のペインが消えている行を伏せる。伏せた件数は毎回告げる。liveness が判定できない（tmux 不在）行は落とさない |

### 反転表示の解消

`MISS` 列を廃止した。`suspected_miss` を数える列は、実測で逆を指していた値を「miss」として提示していた。判定にも表示にも使わない。

### 実測での効き方

master 時点では 87 行の恒久バックログを吐いていた。変更後は、既定（shadow・生存絞り・起点なし）で **32 行**になる。`--include-gone` を付けると 331 行で、これはメッセージ単位へ移した分だけ増えている。運用は「起点を置いてから見る」で、そうすると新しいぶんだけが出る。

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

（レーンごとの結果と反映は次項）

## E6. PR + Copilot

（着手時に記入する）

## 判断・撤回・棄却のログ

（その場で追記する）

## E7. closure

（マージ前に書く）
