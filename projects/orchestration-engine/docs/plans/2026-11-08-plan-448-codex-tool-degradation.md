---
id: "01M6XJGTFG2MW9MS5FSHEW7XZ3"
title: "#448 Codexの道具の障害を通常SOの成功に数えない"
date: 2026-11-08
type: plan
status: in-development
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/448"
    reason: "対象issue"
  - type: design_context
    ref: "https://github.com/stlwolf/ai-development-hub/issues/448#issuecomment-6721165630"
    reason: "ownerが了承した認識合わせ"
tags: [so-compare, codex, verification]
so:
  design: weak
  impl: weak
  reason: "記録の追加と集計の変更は可逆で、CLIスタブによる回帰テストで検証できる。別モデルの実返却は未取得で、レビューゲートは未完了"
---

# #448 Codexの道具の障害を通常SOの成功に数えない

## Context

#442ではcode-mode hostのタイムアウト中も回答が返り、プロセス終了だけを見たmetaが成功だった。認識合わせと計画案にownerが了承した。この文書は承認済み計画と、実装中に確認した診断経路を記録する。CLI自体の修理と#516の一般的なmeta読取の改修は含めない。

## 進め方とゲート

- [x] 認識合わせの確定版を#448に投稿する。
- [x] 計画案を提示し、ownerの明示承認を受ける。
- [x] Codex 0.163.0のソースで診断と保存記録の形式を確認する。
- [x] 道具の障害を独立したmetaに残し、表示と集計に届ける。
- [x] CLIスタブで実際のso-compareを起動する回帰テストを追加する。
- [x] 回帰テスト・既存のSO関連テスト・ShellCheck・構文検査を通す（398項目成功）。
- [ ] 実装SOを完了する。別モデルへの問い合わせは認証失効で実返却0件のため未完了。
- [ ] PRレビューを通し、ownerの判断でマージする。

検証コマンドは `bash projects/orchestration-engine/tests/test_so_compare_tool_status.sh`、同じtests配下の `test_so_compare_read_only.sh`・`test_so_compare_input_rejection.sh`・`test_so_compare_version.sh`・`test_oe_refute.sh`・`test_oe_review.sh`・`test_oe_lane_explain.sh`。変更したシェルスクリプトには `shellcheck -x -P SCRIPTDIR` と `bash -n` を実行する。

## 比較した案と採否

- stderr全文のキーワード検索は採らない。依頼文や回答の引用を障害と誤判定しうる。
- 公開JSONLだけの診断は採らない。code-modeの `FunctionCallError::RespondToModel` はモデルへの道具の返答に入り、公開イベントへ写らない経路がある。
- 公開JSONLと、そのthread IDに一致する保存記録を併用する。プロセスの終了結果は変えず、`tool_status` を追加する。保存記録を確認できなければ `unknown` として通常成功には数えない。
- Codex本体を修理する案はissueの範囲外。

保存記録の探索は既存のtimeoutで5秒に制限し、一意に特定できたファイルだけを権限600でコピーする。診断・exec/waitに対応する直接のエラー返答だけを見る。障害後に成功イベントがあっても障害を消さない。通常のコマンドが同じ文言を印字した場合は除外する。

## 完了条件と限界

障害を含む回答の `VERDICT: survived` が集計を通らず、正常回答・引用・別の呼び出しの返答を誤判定しないこと。記録不在、壊れたJSON、再試行、出力先の再利用も確認する。実際のcode-mode障害はこの環境では再現できていない。fixtureは構成したもので、実物のログとは呼ばない。Bash 3.2と別モデルのレビューの実施状況はepisodeに記録する。
