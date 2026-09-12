---
id: "01M2ASD0XT4D694BVHXG1F634T"
title: "統括の計画的な交代を verb にする — 残りの実装（retire と文書）"
date: 2026-09-12
type: plan
status: draft
source: "https://github.com/stlwolf/ai-development-hub/issues/390"
scope: orchestration-engine
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/390"
    reason: "この単位の正本"
  - type: derived_from
    ref: "projects/orchestration-engine/docs/plans/2026-09-11-plan-390-supervisor-planned-succession.md"
    reason: "移設元。ゲート0 から3 までは元の plan で通っており、本 plan は残りの step を**移設**したものである（書き直しではない）"
  - type: design_context
    ref: "projects/orchestration-engine/docs/decisions/2026-07-09-decision-238-239-succession-watchdog-lean-arch.md"
    reason: "新 engine state を作らない・seat は薄い pointer に defer という上位アーキの決定。設計判断はこの制約の下で選んでいる"
  - type: design_context
    ref: "projects/orchestration-engine/docs/decisions/2026-07-10-decision-238-board-schema.md"
    reason: "board の形についての契約と、#390 が足した amendment（legacy を続ける）。Step 4-3 の板の書き換え案が乗る前提"
  - type: design_context
    ref: "projects/orchestration-engine/docs/decisions/2026-09-11-decision-watchdog-outside-session.md"
    reason: "常駐の見張りの置き場。retire が見張りの状態をどう読むかの前提"
  - type: derived_from
    ref: "projects/orchestration-engine/docs/episodes/2026-09-12-episode-390-retire-and-docs.md"
    reason: "この plan の単位の作業記録"
tags: [orchestration-engine, succession, cockpit, retire, handoff]
so:
  design: weak
  impl: weak
  reason: "設計は元の plan でゲート1（ゼロベース代替探索）とゲート2（設計SO・3レーン）を通し、ゲート3 で owner が承認している。本 plan は承認済みの step の移設なので新しい設計SO は要らない。実装は元の plan と同じくシェルスクリプトの追加で、テストが合否を決められるため実装SO は弱でよい"
---

# 統括の計画的な交代を verb にする — 残りの実装（retire と文書）

## この plan は何で、何でないか

**移設である。書き直しではない。** #390 の元の plan（`2026-09-11-plan-390-supervisor-planned-succession.md`）は PR を4本に分けていたが、`document-format.md` は committed 層の plan を「実装の最初の PR と一緒に着地させる」と定めており、**1本の plan を4つの PR にまたがらせた時点でその形が壊れていた**（着地した文書が後続の PR で変わり続ける状態になる）。owner の裁定（2026-09-12）で**残りの作業を1つの PR にまとめる**ことになったので、残りの step をこちらへ移した。

- **step の本文は1文字も変えていない。** 承認済みの母集団をそのまま移している。
- **新しいゲート3 は要らない**（owner 裁定）。ゲート0 から3 までは元の plan で通っている。
- 設計判断（DJ-1 から DJ-12）・棄却した案・ゲート1 と2 の記録・owner に預けた判断とその回答は、**元の plan が正本**である。ここには写さない（同じ説明を2箇所に置くと片方だけ古くなる）。

済んだぶん（PR-1 = `prepare` と状態収集 / PR-2 = `take` と `start` と交代イベント）の記録も元の plan にある。

## この単位の形

**PR は1本である。** 中身は次の4つで、受入だけは PR にしない。

| 中身 | 元の plan での位置 |
| --- | --- |
| `retire` の実装 | Step 3-1 〜 3-6 |
| README の2項目 | Step 4-1・4-2 |
| board の `## succession 手順` を書き換える**案**と owner HG | Step 4-3・HG |
| 受入（**PR にしない**） | Step 4-5・4-6 |

**受入を PR にしないのは、交代が起きるまで実行できない性質のものだから**である（owner 裁定）。次の実際の交代で `prepare` → `start` → `take` → `retire` を1回通し、episode へ追記して単位を閉じる。

## 本文を書き換えた step（前後）

**移設の原則は「本文を変えない」だが、狙いは承認した母集団が黙って縮むのを防ぐことであって、文面の不変ではない**（統括の回答・2026-09-12）。owner が PR を1本と裁定した以上、「PR-3 を出す」「PR-4 を出す」の2つは**その裁定によって内容が決まる**。注記だけ足して本文を放置すると、**plan が自分の単位の形と食い違ったまま残る**。だから書き換え、前後をここに残す。

| step | 変更前（元の plan） | 変更後（この plan） |
| --- | --- | --- |
| Step 3-6 | `PR-3 を出す` | `retire` と README の2項目と board の書き換え案を載せた**1本の PR を出す** |
| Step 4-4 | `PR-4 を出す` | **Step 3-6 と同じ1本の PR で満たす** |

- **行は消していない。** 項目の数は変えない（統合を理由に母集団を縮めない）。元の plan の側には変更前の本文がそのまま残っており、そちらが「前」の記録である。
- **受入の2件（Step 4-5・4-6）は変えていない。** PR の単位ではないので裁定の影響を受けない。

## 移設した step のうち、文面と実態がずれるもの（残すもの）

- **Step 4-5 の流れに `start` が入っていない。** 元の plan を書いた時点では `start` がまだ無く、owner 裁定2(b) であとから足した。受入で通すのは `prepare` → `start` → `take` → `retire` の4つである（`start` の kickoff が届いたことの確認は Step 4-6 が持つ）。**本文は変えない**（受入の step は PR の本数の裁定の影響を受けないため）。

## ステップ

**着手は PR #393 が master へ着地したあと。** 枝は `origin/master` から切り直す（PR-2 は squash で入るため）。**plan だけの PR は立てない。** この plan と episode は、`retire` の実装と同じ枝・同じ PR に載せる。

**進捗（2026-09-13 時点）: Step 3-1 〜 3-6 と 4-1 〜 4-4 と HG は済み。残っているのは受入（4-5 / 4-6）だけで、これは次の実際の交代まで実行できない。**
step の文言と結果がずれたものは各行の下に「結果:」として残し、未了のものはその理由を書く。
**step を削ったり要件を弱めたりはしていない**（項目は 14 のまま）。

### PR: `retire` と文書（1本）

- [x] Step 3-1: `oe-handoff retire` を実装する（機械の検査をやり直し、前任の申告と突き合わせ、食い違いを列挙する）
- [x] Step 3-2: 停止の必須条件を3つ入れる。前任の session_id が引き継ぎ記録に残っていること（`claude --resume` で開き直せる）・生きた委譲子が0体であること・前任の申告の各項目に処分が付いていること
- [x] Step 3-3: 引数なしの `retire` は下見にする（検査して結果を表示するだけ・停止しない）。判定が通らないときは理由を列挙して非0 で終わる
  - 結果: 下見が既定である。テスト [1] が「`kill-pane` を1度も呼ばないこと」と「前任が生きたままであること」の両方を見ている。
- [x] Step 3-4: `--execute` は**検査をやり直してから**停止する（時間差の穴がここで閉じる）。**打つのは後継である**（owner 裁定2(a)）。段階1 で `--execute` が触れてよいのは**前任のペインだけ**で、board・登記・イベントログ・worktree・PR には触れないことを実装と README の両方に書く
  - 結果: 実装と README の両方に書いた。**加えて、閉じる直前に transcript がまだ使えるかと委譲子の数をやり直す**（実装SO 2周目の指摘）。触れていないことはテスト [13] が board・登記・イベントログの mtime で見ている。**mtime は `date -r` で取る**（`stat -f %m` は GNU で誤って成功し、before と after が同じ誤った値になって検査が効かない・Copilot の指摘）。
- [x] Step 3-5: テストを書く（食い違いがあるとき・session_id が無いとき・生きた委譲子が居るときに、いずれも停止しないこと。`--execute` が再検査を先に走らせること。`--execute` が前任のペイン以外を変更しないこと）
  - 結果: 69 件。実装SO 2周（計7件）と Copilot（3件）の指摘で増えた。**「閉じる直前に子が現れたら閉じない」のテストは、最初は主張を証明していなかった**（目印を開始前に置いたので早い方の検査で落ちていた）ので、retire の途中で必ず走る `gh` に目印を作らせる形へ直し、**早い方で落ちていないことも assertion にした**。
- [x] GATE: `shellcheck` が通ること
  - 結果: exit 0（`bin/oe-handoff` と `tests/test_handoff_retire.sh`）。
- [x] Step 3-6: `retire` と README の2項目と board の書き換え案を載せた**1本の PR を出す**（owner 裁定 2026-09-12 で PR を1本にまとめたので、元の「PR-3 を出す」から書き換えた。前後は「本文を書き換えた step」節にある）
  - 結果: PR [#394](https://github.com/stlwolf/ai-development-hub/pull/394)（ready）。ゲート4 は実装SO 2周（計7件反映）+ Copilot 3件（全件反映・未返信0）+ テスト5スイート 415 件すべて PASS + `shellcheck` exit 0。
- [x] Step 4-1: `projects/orchestration-engine/bin/README.md` に `oe-handoff` の節を足す（既存の verb と同じ体裁で、契約・引数・制約・関連 lib を書く）
  - 結果: subcommand ごとに**走るセッションが違う**ことを表で先に出し、**確かめられないこと**（`start` の readiness / `oe-vitals` の最終走査 / 拍動を書く前の pane 再利用）を節として書いた。あわせて**索引の本数が実態とずれていた**ので直した（22 と書いて実際は 25・`oe-lane-explain` と `oe-threads` が漏れていた）。スコープ外なので報告で明示した。
- [x] Step 4-2: 残っている歪みを README に明記する。`oe-register root` は前任の root の登記を失効させないので、交代のあと `oe-tree` に cockpit の root が2本並ぶ。lean の決定が「topology の歪みは段階1 の外」としている範囲で、この単位では直さない
  - 結果: README の `oe-handoff` の節に「残っている歪み」として書いた。
- [x] Step 4-3: board の `## succession 手順（後任がやること）` 節を新しい verb を使う形に書き換える案を作る（**書き換えは owner の承認を得てから**。board は稼働中の実ファイルである）
  - 結果: **案を作るところまで済み。** 案は新しい episode の「board の `## succession 手順` の書き換え案」節にある（置き換える節の全文と、owner への問い3つ）。**実 board は1バイトも触っていない。**
- [x] HG: owner に board の書き換えを承認してもらう
  - 結果: owner が承認し、**適用したのは統括である**（2026-09-12）。**この単位（子）は board を1バイトも触っていない。** 案の全文（21 行）がそのまま入った。
  - 検算（子が独立に確かめた分）: 案と適用後の節を突き合わせて差分ゼロ / 宣言行（line 3）は無変更で「現統括」は依然1回だけ / `oe_seat_resolve` は現統括を解決する / 旧見出し0件・新見出し1件 / 置き換えた節の本体に古い pane 番号は残っていない（board の他の場所に残るものは系譜の散文で、触っていない）。
- [x] Step 4-4: **Step 3-6 と同じ1本の PR で満たす**（owner 裁定 2026-09-12。元の「PR-4 を出す」から書き換えた。**行は消さない** — 統合を理由に項目の数を減らさないため。前後は「本文を書き換えた step」節にある）
  - 結果: Step 3-6 と同じ PR [#394](https://github.com/stlwolf/ai-development-hub/pull/394) で満たした。

### 受入（PR にしない）

次の実際の交代で通す。**交代が起きるまで実行できない**ので、PR の単位にしない。通したら episode へ追記して単位を閉じる。

- [ ] Step 4-5: 受入。次の実際の交代で `prepare` → `take` → `retire` を1回通し、結果を episode へ追記する
  - 注記: 通すのは `prepare` → `start` → `take` → `retire` の4つである（`start` は owner 裁定2(b) であとから足したので、この step の本文には出てこない）。
  - **未了（交代が起きるまで実行できない）。** 待っているのは次の実際の交代である。
- [ ] Step 4-6: 受入のとき、**`start` が送った kickoff が後継へ届いたことを受領印で確かめる**（DJ-10 の条件4）。`oe-confirm` の照合で、その送信の相関 ID に対する `prompt_received` が後継のペインから出ていることを見る。出ていなければ受入としない。**起動側で「入力を受け付けられる状態か」を機械で確かめられない以上、届いたことは後始末の側で見るしかない**（統括の申し送り・2026-09-12）
  - **未了（Step 4-5 と同じ。交代が起きるまで実行できない）。**

## リスク・未確認事項

元の plan の「リスク・未確認事項」が引き続き有効である（そちらが正本）。この plan の単位に固有のものだけ書く。

- **board の実ファイルは書き換えない。** Step 4-3 で作るのは案で、書き換えは owner の承認のあとである。稼働中の見張りが 15 分ごとに読んでいる。
- **`retire --execute` を打つのは後継である**（owner 裁定2(a)）。段階1 で触れてよいのは前任のペインだけで、後始末（登記の掃除・worktree の掃除・issue の close）は人のゲートのまま残す。
- **受入が済むまで、この単位は「残余の完全性は保証しない試験運用」である**（元の plan の DJ-10 条件3）。
