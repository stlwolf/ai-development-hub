---
id: "01M28CQ6J3F3V5EG2J5FNK616R"
title: "統括の計画的な交代を verb にする（#390 plan フェーズ）"
date: 2026-09-11
type: episode
status: draft
related:
  - type: derived_from
    ref: "https://github.com/stlwolf/ai-development-hub/issues/390"
    reason: "この単位の正本。ゲート0 の結論が issue 本文にある"
tags: [orchestration-engine, succession, cockpit, plan]
---

# episode — 統括の計画的な交代を verb にする（#390 plan フェーズ）

## なぜこの作業が始まったか

統括セッションは context が尽きるたびに交代する。いまその交代は、立ち上げプロンプト 36 行と引き継ぎ brief 50 行を毎回人が手で書き、口頭で spawn を指示する形でしか回っていない。owner は 2026-09-11 に「統括自体をシームレスに復活できる仕組み・あまりプロンプトを使わないでできる形」を求め、cockpit の改善順序として「1. 通信経路を手厚く → 2. 交代と復帰」を裁定した。1 は #336 で着地したので、次がこの単位である。本 episode は #390 のうち **plan を作るところまで**を記録する。実装は owner の Human Gate（ゲート3）の後になる。

この単位は**前任が応答できる場合**の交代だけを扱う。前任が応答しない場合（クラッシュ後の復帰）は #355 で、分かれ目は前任が自分の状態を申告できるかどうかの1点である。

## 作業の記録

### 材料を読む（2026-09-11）

読んだもの: issue #390 本文（ゲート0 の結論を含む）/ #355 / #238 / discussion `2026-07-13-discussion-supervisor-succession-recovery-and-observability.md` / 一次材料の2ファイル（`.oe/prompt-succession-14th.md` 35 行・`.oe/brief-cockpit-handoff-14th-generation.md` 50 行）/ board の line 3 と succession 手順節 / engine の `bin/README.md` のうち `oe-delegate` `oe-send` `oe-register` `oe-selfcheck` `oe-vitals` `oe-refute` の節。

board は 350KB あるので全部は読んでいない（line 1-8 と 169-192 のみ）。

### ゲート1 — 初期案と暗黙の前提を並べる（2026-09-11）

SO を回す前に、いま手元にある案と、その案が黙って置いている前提を書き出した。

暗黙の前提（issue 本文の「設計の骨」と手動の引き継ぎの実物から抽出）:

- 前提1: 交代は1回きりの出来事で、渡す瞬間がある。
- 前提2: 渡すものは文書（brief と立ち上げプロンプト）で、誰かが書かなければならない。
- 前提3: 後継は新しい pane で立ち上がる新しいセッションである。
- 前提4: board（350KB の自由記述）が durable な正本で、brief はその要約である。
- 前提5: 席は board の line 3 に書かれた pane ID で見分ける。
- 前提6: 前任は最後に停止される。
- 前提7: 引き継ぎ文書は交代の時点で書く。

前提7 が一番あやしい。交代のきっかけは context の枯渇なので、**一番長い文書を、一番 context が残っていない時点で書かせている。**

昇格の印: 引き継ぎ文書を交代時点で書く前提そのものが設計判断である

初期の案セット（カテゴリ別）:

- 引き継ぎ文書を誰が書くか: A-1 前任が手書き（現状）/ A-2 verb が観測できる事実から骨格を生成し人は会話にしか無かった分だけ書く / A-3 board 自体を引き継ぎ文書にして別 brief を作らない / A-4 前任が生きている間ずっと少しずつ書き足す / A-5 文書を作らず resume で会話ごと引き継ぐ
- 後継が席を取る工程: B-1 手順を手で踏む（現状）/ B-2 後継が自ペインで1コマンド（登記・board 張替・検算・見張り確認・記録）/ B-3 前任が spawn 時に board へ「後継待ち」の行を作り後継が埋める（issue の中間案）/ B-4 board が pane でなく session_id を宣言する（#247・スコープ外）/ B-5 機械が読む席の宣言を board 本文から外し、機械可読の別ファイルへ置いて board はそれを指す
- 前任の自己申告: C-1 会話で自由文（現状）/ C-2 verb が機械で確かめられる分（open PR・未 push・worktree・生きた子・未達の送信・board の書き残し）を自動で集め、人は機械で確かめられない分だけ申告する / C-3 後継が同じ機械の検査を独立にやり直して突合する / C-4 申告を作らず owner が見て決める
- 前任を閉じる経路: D-1 生の `tmux kill-pane` を owner が叩く（現状）/ D-2 後継が verb で閉じる（申告の記録と後継自身の検査が揃っていることを条件にする）/ D-3 前任が自分で閉じる / D-4 閉じずに席から降ろすだけにする / D-5 verb は閉じるコマンドを表示するだけで実行は owner がやる
- 交代の形そのもの: E-1 context 枯渇時点の1回きりの出来事（現状）/ E-2 重なり期間を置いて、後継が動くと確かめてから席を移す / E-3 席を file にして、読んだセッションが誰でも統括になる（identity を無くす）/ E-4 統括を短命にして頻繁に回す
- 交代のきっかけ: F-1 owner か前任が気づく（現状）/ F-2 `oe-vitals` の context 検知（既定 85%）の ping が交代の入口を兼ねる / F-3 閾値で自動 spawn

### 実測1 — 引き継ぎ文書のどこまでが機械で出せるか（2026-09-11）

立ち上げプロンプト 36 行と brief 50 行を節ごとに分け、「観測できる事実か」「会話にしか無かったものか」で仕分けた。仕分けの根拠として、実際にコマンドを叩いて値が取れるかを確かめた。

取れたもの（すべて既存のコマンドで、追加の機構なしに取れる）:

- open PR の一覧と draft かどうか（`gh pr list --json number,title,isDraft`）
- worktree の一覧（`git worktree list`）
- 生きている委譲子の一覧と、その model・context%（`oe-tree`）
- 常駐の見張りの登録状態（`launchctl list | grep oe-`。`com.stlwolf.oe-vitals` と `com.stlwolf.oe-confirm` の2本が登録済みと確認）
- 前任の session_id と context%（拍動 sidecar を pane で逆引きする。`~/.claude/state/oe-heartbeat/<session_id>.json` の中身が `{"ts":...,"context_pct":...,"pane":"%N",...}` なので、pane から session_id を引ける）

最後の1点は設計にとって非自明である。issue 本文は「前任は後継の session_id を知る手段を持たない」と書いているが、これは**前任から後継への向き**の話で、逆向き（後継が前任の session_id を引く）は sidecar の逆引きで成立する。いま brief には前任の session_id が手で書き写してあるが、これは機械で出せる。

会話にしか無かったもの（機械では出せない）:

- owner に預けている判断とその前提
- owner が決めた次のテーマの順序
- 「渡らないもの」節（owner の関心の順・前任が踏んだ誤りの型）
- in-flight の表の「次に起きること」列（状態は機械で出せるが、次に何が起きるかは判断である）

**節ごとに見ると、立ち上げプロンプト 36 行のうち約 24 行（「起動時にやること」6工程と冒頭の identity 宣言）は機械で出せる。** 残り 12 行は brief の要点の再掲で、brief を読ませれば不要になる。

昇格の印: 立ち上げプロンプトは「統括になる」verb が無いから存在している

もう1つ分かったのは、brief の「この期間に確立した運用（守ること）」節（17 項目）が、世代をまたいで書き写され続けていることである。durable な規律なので、世代ごとの brief ではなく知識の層（memory / rules / knowledge item）に置くべきもので、毎回 brief へ写すのは損失である。

### 実測2 — 交代のきっかけに使えるはずの検知が、いま動いていない（2026-09-11）

`oe-vitals` は board の `現統括:` から pane を取り、その拍動 sidecar の `context_pct` が 85% を超えたら交代を促す。これが交代のきっかけの候補（案 F-2）だった。実際に叩いて確かめた。

```
統括 %84 の拍動: 7567 秒前（oe-vitals の既定窓 W=1800 秒）
oe-vitals: 現統括 %84（beat stale/2h6m · ctx=17% · pane=alive · W=1800s · T=85%）
  → 検知なし（beat stale だが pane が gone でない＝death は確定 gone でのみ判定・alive/?×stale は no-op）
```

拍動は statusLine が書くので、セッションが描画しないあいだ更新されない。**統括の拍動が窓より古くなると、context 検知は沈黙する。** いま現に沈黙している。これは「検知しなかった」と「健全だった」が読み手から区別できない形で、この単位が採用した negative knowledge の1つ目（停止を報告する主体を当人に置くな）と同じ型である。統括の拍動を書くのは統括自身のセッションだからである。

この単位のスコープ外（拍動の鮮度そのものは復帰側の軸）だが、**案 F-2 を交代の入口として当てにはできない**という設計上の結論はここで確定する。surface して親へ上げる。

### ゲート1 — ゼロベース代替探索の実行と結果（2026-09-11）

`SO_TIMEOUT=600 SO_CLAUDE_TIMEOUT=1200 oe-refute --claim .oe/claim-390-gate1.md --lanes 3 --rubric exploration` を実行した。claim は 13,474 バイトで、材料をレーンに読みに行かせない自己完結の形にした（採用した negative knowledge `01M141TB5YHB6VN62RA5TP0S3Q` の指示どおり上限も上げた）。結果は3レーンとも実返却で、空返しは1本も出ていない（cursor 87 秒 / codex 175 秒 / claude は 1200 秒の枠内で完走）。

- verdict: `refuted`（3/3 レーンが material に反証）
- audit_id: `20260911141134S4MRTPKRDR34`
- output_dir: `tmp/oe-refute-20260911141134S4MRTPKRDR34`（永続しないので内容は plan と本 episode へ転記した）

**「これ以外の技術カテゴリの代替は残っていない」という主張は成立しなかった。** 出てきた代替は plan の「棄却した案」節に理由つきで載せた。ここには、設計そのものを変えた指摘だけを書く。

#### 覆った点1 — owner の設計の骨1の理由が、実測と合わない

issue 本文の設計の骨1は「席を見分ける材料は pane と session_id の2つで、どちらも後継のプロセスの中にしか存在しない。前任は後継の session_id を知る手段を持たない」と書いている。claude レーンがこれを3経路で崩し、私が自分で全部確かめて、3つとも成立した。

- 拍動 sidecar は `~/.claude/state/oe-heartbeat/<session_id>.json` で、ファイル名が session_id、本文に pane が入る。ディレクトリを1回読めば pane から session_id を引ける。後継のプロセスに入る必要はない。[verified]
- `lib/spawn.sh` は新しい pane の ID を `OE_SPAWN_PANE_ID` に受ける。委譲で後継を spawn するなら、前任は後継が起動する前に後継の pane を持つ。[verified]
- `lib/delegate-registry.sh` の `oe_reg_record <child_pane> <label> <workspace> <parent_pane>` は、親が子の登記を書く関数である。「他人の席は書けない」という制約は engine の中に存在しない。[verified]

つまり「後継が自分で取りに行くしかない」は**技術的な制約ではなく、運用として選んだ方針**である。結論（後継が取りに行く）を変える必要は無いが、**理由は置き換えないと使えない。** 置き換えた理由は plan の DJ-4 に書いた。骨を勝手に覆さず、owner に預ける判断として残した。

昇格の印: 設計の骨の理由が実測で崩れたが結論は残る、という形の扱い方

#### 覆った点2 — 生きた子がいる交代では、前任を閉じると子の報告先が死ぬ

`bin/oe-delegate` は子の起動コマンドに `PARENT_TMUX_PANE=<親 pane> claude` を焼き込む。[verified] 環境変数は起動後に書き換えられないので、前任の pane を閉じると生きている子の戻し先が死ぬ。これは lean の決定が mode3（チャネル脆弱）として挙げている故障そのもので、対策の `@seat` mailbox は「報告の stranding が再発したら導入する」という再開条件つきで defer されている。

今日の交代は委譲子 0 体だったので踏まなかっただけである。`bin/oe-report` は親を「環境変数が先、無ければ `/tmp/oe-parent-<自 pane>` ファイル」の順で解決するので間接参照の口は既にあるが、環境変数が優先されるうえ、README が推す `oe-send "$PARENT_TMUX_PANE"` の直書き経路はこの解決を通らない。[verified]

私の初期案は前任を閉じることだけ考えていて、この依存を見落としていた。plan に DJ-11 として足した。

#### 覆った点3 — 自己申告の分業は、context の圧縮で壊れる側と人に任せる側が一致する

claude レーンの指摘。交代のきっかけは context の枯渇で、その帯では自動の圧縮が動き、圧縮前の往復は要約に畳まれる。**畳まれる側にあるのは、まさに「会話にしか無かったもの」である。** C-2（機械が集める分と人が書く分を分ける）は、壊れる部分をそのまま人に任せている。C-3（後継が機械の検査をやり直す）も機械の分をもう一度やるだけなので、この残余には届かない。

機械で救える範囲はある。`oe-confirm` と `oe-undelivered` が送信単位の到達を照合しているので、未達の送信は前任の記憶に依存しない。ただしこれは「教訓が当たらない」ことの証明ではなく、「当たる範囲が狭まった」ことの確認である。

手当ての方向として2つ出た。圧縮の直前に機械が書き出す（ハーネスの `PreCompact` イベント）か、transcript から第三者が拾うか。**`PreCompact` / `SessionStart` / `SessionEnd` は claude 2.1.268 に実在する**（実行ファイルを検索して確認）が、hub が配線しているのは `PreToolUse` / `PostToolUse` / `Stop` / `Notification` / `UserPromptSubmit` / `TaskCompleted` の6つで、この3つは未使用である。[verified] 配線はハーネス層の変更なので、この単位では owner に預ける判断として出した。

#### 覆った点4 — 交代イベントの追加は、verb 1本より広い変更になる

`schemas/oe-events.schema.json` の type の語彙は `child_spawned` / `message_sent` / `prompt_received` / `report_received` の4つで、交代に当たる型は無い。[verified] 交代イベントを足すなら schema を触る。「席を取る工程を1コマンドに畳むだけ」という見立てより広い。plan のステップに明示した。

#### 覆った点5 — pane から session_id を引く逆引きには、pane の再利用の罠がある

sidecar は掃除されない（`oe-vitals` が read-only を保つため）。実測で**異なる pane 番号が 171 個**貯まっていた。[verified] tmux server を再起動すると pane 番号は振り直されるので、過去世代と同じ番号が後継に割り当たりうる。逆引きするなら pane だけで引かず、現在の tmux server の pid と拍動の新しさで絞る必要がある。sidecar には `server_pid` が入っているので材料はある。

#### 持ちこたえた点

- 引き継ぎ文書を「機械が書く節」と「人が書く節」に分ける方向そのもの（cursor が「現状制約下の有力デフォルト」と明示）。
- 席の取得を後継の1コマンドに畳む方向（同上）。
- 段階を踏んで停止へ進む形（同上・`careful-operations-rule` と整合）。
- 重なり期間を置く形（同上・実運用と整合）。
- 前提7（引き継ぎ文書は交代の時点で書く）が怪しいという読み。ただし3レーンとも「前提3・前提5 も外すとカテゴリが変わる」と追加で指摘した。

