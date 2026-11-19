---
id: "01M7SDBPCPFJY9TS6ZC3SWKRP9"
title: "oe-view は、記録した WezTerm の GUI のプロセスに同じソケットで問い合わせられると確かめたときだけ、前の viewer を閉じる"
date: 2026-11-19
type: decision
status: stable
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/509"
    reason: "本 decision が記録する判断の issue"
  - type: derived_from
    ref: "projects/orchestration-engine/docs/plans/2026-11-18-plan-509-oe-view-viewer-identity.md"
    reason: "判断の材料。設計判断 DJ-1・手当てしない経路・探索の記録"
  - type: reference
    ref: "projects/orchestration-engine/docs/episodes/2026-11-18-episode-509-oe-view-viewer-identity.md"
    reason: "作業の記録。テストで不具合を再現したことと、実物の確認"
  - type: design_context
    ref: "projects/orchestration-engine/docs/plans/2026-06-21-plan-210-oe-view-clickable-md.md"
    reason: "viewer を毎回閉じて開き直す方式（DJ-4）を決めた元の plan。本 decision はその方式を保ったまま、閉じる条件を足す"
tags: [oe-view, wezterm, viewer, pane-identity, decision]
---

# oe-view は、記録した WezTerm の GUI のプロセスに同じソケットで問い合わせられると確かめたときだけ、前の viewer を閉じる

## コンテキスト

`oe-view` は md を開くたびに前の viewer（glow のペイン）を閉じて新しく開き直す（#210 の DJ-4）。前の viewer は、記録したペイン番号で指していた。閉じる前に確かめていたのは、その番号のペインが今あるかだけである。WezTerm を起動し直すとペイン番号は0から振り直されるので、記録の番号が作業中の別のペインに当たると、そのペインを閉じてしまう（#509）。

## 決定

記録には、ペイン番号と一緒に、viewer を開いた GUI のソケットの実体のパスと、その GUI のプロセスの開始時刻を書く。閉じるのは、今回の接続先のソケットが記録と同じで、そのソケットの GUI のプロセスの開始時刻が記録と同じで、記録の番号のペインがあり、それが呼び出し元のペインではないときだけにする。確かめられないときは閉じずに、新しい viewer を開く。1回の実行の中の `wez pane` の呼び出しは、すべて同じソケットに固定する。

## 根拠

- **前提**: WezTerm のペイン番号は、GUI のプロセスの中の1つのカウンタを0から増やすだけで、同じプロセスの中では使い回さない（wezterm の `mux/src/pane.rs` の `PANE_ID`・2026-11-18 に確かめた）。GUI はソケットを `gui-sock-<自分のプロセス番号>` と名付ける（`wezterm-gui/src/main.rs`）。この2つが成り立つかぎり、同じプロセスに問い合わせて記録の番号のペインがあれば、それは oe-view が開いた viewer である。
- **開始時刻を組にする理由**: プロセス番号は、OS を起動し直したあとなどに使い回されうる。ログインのときに起動する WezTerm は、前回と同じ番号になることがある。番号と開始時刻の組なら、同じプロセスと言える。
- **棄却した案**（設計 SO の3レーンで出た案を含む。詳細は plan の探索の記録）:
  - ペインの `tty_name` を照らす。tty の名前も使い回されるので、一致しても同じペインと言えない。
  - ペインの title が glow かを見る。title は誰でも変えられる。
  - 閉じない。viewer が増え続け、#210 の置き換えの方式をやめることになる。
  - ペインではなく viewer のプロセスを目印つきで止め、ペインは正常終了で閉じさせる。ペイン番号に頼らない点で強いが、glow を包む層と、止めたあとにペインが閉じることを実物で確かめる必要があり、変更が大きい。
  - viewer を閉じずに中身を差し替える常駐の viewer。focus と配置の問題も消えるが、別の改善の大きさである。
  - title に乱数の目印を書く、viewer 専用のタブや WezTerm を使う、照合と閉じるを WezTerm の側で1つにする、状態を `wezterm.lua` に持つ。それぞれ、確かめていない前提に頼る・画面の構成が変わる・WezTerm 本体の変更が要る・クリックの経路に頼らず単体で動く要件に反する、で外した。
- **手当てしない経路**: 確かめてから閉じるまでの数ミリ秒に GUI が入れ替わる、同じ番号の GUI が同じ秒に起動している、などの組み合わせは、ゼロではないが現実にはまず起きない。手当てすると、コードとテストが増えるわりに、実際に起きる場面での安全は変わらない。owner がそう判断した（2026-11-18）。

## 結果

- 前の viewer を閉じ損ねる場面が増える。別の GUI から呼んだとき、記録の形を変えたあとの最初の1回、名前にプロセス番号の無いソケット（mux サーバ）につないだとき、開始時刻が取れないときである。閉じ損ねた viewer は人が手で閉じる。
- **覆す条件**: WezTerm がペイン番号を同じプロセスの中で使い回すようになった、または GUI のソケットの名前の付け方が変わった場合は、この判断の前提が崩れる。その場合は、棄却した案のうち、viewer のプロセスを止める案が第一の代わりになる。
- `wez` は、接続先のソケットが消えると `wezterm cli` がそのパスで mux サーバを自動で起動する。起動したばかりの mux サーバには利用者の作業ペインが無いので、本 decision の安全は変わらない。
