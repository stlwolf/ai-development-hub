---
id: "01M7374KYTP4ZZMDWCS7RJZEMA"
title: "#572 資格情報を入れた画面の写しに password の値が残るのを防ぐ節を playwright-browser に足す"
date: 2026-11-11
type: episode
status: draft
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/572"
    reason: "本 episode の作業対象"
tags: [skill, playwright, credentials, harness]
---

# #572 資格情報を入れた画面の写しに password の値が残るのを防ぐ節を playwright-browser に足す

## なぜこの作業が始まったか

別のリポジトリの検証の作業（2026-11-04）で、ログインに失敗した画面の `browser_snapshot` が password の欄の値を文字として出し、会話の記録に残った。2026-11-10 には、ログアウトのあとのサインインの画面で、ブラウザの自動入力が password の欄を埋めていた。この教訓を `playwright-browser` スキルに入れる。統括の小さな直しの委譲（3件のうち2件目）として受けた。出来事は別のリポジトリのものなので、スキルにも PR にも、そのリポジトリや画面の名前を書かず、一般の形で書く。

## この単位の入力

- brief: 統括の委譲の書面（gitignored の作業層）。認識合わせと plan は owner の指示で省いた。
- 注入された knowledge item: 統括の採用は0件。着手時に `knowledge-list --strict`（100件）を見て、ブラウザの写しや資格情報に当たる item は無かった。`01M5F0CNEKA9ED9AMQ3YWGGF8W`（決まりを書いた本人が、スキル自身の文面でその決まりを破る）は近いので採用し、S1-3 で当てた。
- SO モード: 実装SO は弱・Codex 1レーンと Copilot 1ラウンド。

## 作業の記録

### S1-0: 着手（2026-11-11 02:12）

- baseline: `origin/master` `74237b2`。
- ブランチ: `docs/#572_playwright_credential_snapshot`。#481 と同じく、デスクトップアプリが用意した worktree の中でブランチを切った。#481 の PR の Copilot のレビューを待つあいだに始めた。

### S1-1: 足した節の中身と置き場所（2026-11-11 02:12 頃）

`canonical/skills/playwright-browser/SKILL.md` の「注意事項」の前に「資格情報を入れる画面の扱い」の節を足した。brief が挙げる5つ（入力の道具に値を渡さない・snapshot は password の値を含みうる・失敗とログアウトのあとの画面では写しの前に欄を空にするか `about:blank` へ移る・伏せる処理は password の欄も対象にしてログインの入力欄は置き換えない・`.catch` で握りつぶさない）と、issue の教訓の残り2つ（写しを撮らずに成功を確かめてから撮る・値を引数に出さない検査）を入れた。

判断の why:

- 置き場所は「よくあるパターン」の中ではなく、独立した節にした。「フォーム入力」のパターンは `browser_fill_form` に値を渡す例なので、その中に置くと、例と禁止が同じ場所で食い違って読める。独立した節にして、資格情報の場面だけに当てる。
- 成功の見分け方に `input[type=password]` を書いた。issue の「password の欄が画面に無い」を、道具で確かめられる形にするためである。
- 値を引数に出さない検査に、`grep -rcF -f <値のファイル> <置き場> | grep -v ':0$'` を例として載せた。手元で、値の入ったファイルの名前と件数だけが出ること、値のファイルに空の行があると全部の行に当たる（当たり件数が行数と同じになる）ことを確かめた。後者は節に注意として書いた。
- skill の `description` は変えていない。発火の語を変えない決まりで、足した節は既存の場面（ブラウザ操作・画面確認）の中の注意なので、新しい語は要らない。

### S1-2: issue の残りの2つの「決める」（2026-11-11 02:12 頃）

- ログインのスクリプトの直し方を、スキルの例（コード）として書くかは、書かないと決めた。直すことの3つ（伏せる処理を入力欄に当てない・失敗したら password の欄を空にして `about:blank` に戻す・ログインの画面では写しを撮らない）は、節の箇条にそのまま入っている。コードの例を書くには、資格情報をファイルから読むスクリプトをどこで動かすか（`browser_run_code` の中でファイルを読めるか、別の Playwright のスクリプトか）を決める必要があり、手元で確かめていない形を例として配ることになる。
- knowledge store に negative knowledge として入れるかは、入れないと決めた。教訓は、ブラウザを操作するたびに読み込まれるスキルに入ったので、行動を変える場所に既に届いている。knowledge item は、スキルが届かない場面で注入するためのもので、ここでは同じ教訓を2か所に持つことになる。

### S1-3: スキル自身の文面が新しい節と食い違わないかを見た結果（2026-11-11 02:13 頃）

採用した item `01M5F0CNEKA9ED9AMQ3YWGGF8W` に従い、`browser_type`・`browser_fill_form` が出てくる行をスキル全体で探した（`grep -n`）。「よくあるパターン」の「フォーム入力」は、`browser_fill_form` に「ユーザー名」の欄の値を渡す例で、ログインの form にもそのまま当てはめて読める。新しい節は資格情報の値を入力の道具に渡さないと書くので、同じスキルの中で例と決まりが食い違う。例そのものは資格情報でない form には正しいので消さず、例のすぐ下に「ログインの form のように資格情報を入れるときは、この手順ではなく『資格情報を入れる画面の扱い』の節に従う」の1行を足した。表の行（ツールの説明）と「注意事項」の `browser_type` の行は、道具の働きを書いているだけなので変えていない。

### S2-1: 実装SO の結果と採否（2026-11-11 02:14〜02:18 頃）

Codex 1レーン（`gpt-6.1-sol`・161秒・exit 0・`tool_status` は `not_observed`）は「修正推奨」で、指摘を4つ返した。結果は `tmp/so-572/codex-stdout.txt`（gitignored）にある。Codex は upstream の実装を根拠にしたので、主な2つを自分で `gh api` で upstream（`microsoft/playwright` の `main`・`microsoft/playwright-mcp` の README）から読んで確かめた。この環境で動いている Playwright MCP の版と同じかは確かめていない。

1. 採る（高）。snapshot は `browser_snapshot` だけで撮られるのではない。upstream の `packages/playwright-core/src/tools/backend/` で、`browser_navigate`・`browser_navigate_back`（`navigate.ts`）、`browser_click`・`browser_drag`・`browser_hover`・`browser_select_option`（`snapshot.ts`）、`browser_type`・`browser_press_key`（`keyboard.ts`）、`browser_wait_for`（`wait.ts`）が `response.setIncludeSnapshot()` を呼ぶことを確かめた。最初の版は「写しを撮らない」と書いていたが、ログインの画面を開く `browser_navigate` の応答だけで、自動入力された値が記録に入りうる。節の最初の項目を、これらの道具を成功の確認か後始末まで呼ばない、に書き直し、ログインとログアウトの操作をひとつのスクリプトの中で済ませる項目を足した。基本フローと注意事項の「操作のたびに snapshot を取る」の2か所に、このあいだは当てないと書いた。
   - accessibility の木が password の値を含むことも、`packages/injected/src/ariaSnapshot.ts` で、`input` の `type` が checkbox・radio・file でなければ `element.value` を子に入れることで確かめた（password を除いていない）。
2. 採る（中）。URL の変化と password の欄の不在だけを成功とすると、多要素認証やエラーの画面へ移った場合と区別できない。成功の確認（ログインのあとにだけ出る要素や URL）と、写しを撮ってよいかの確認（password の欄が無い）を分けた。`type=text` に切り替えた欄・ワンタイムのコード・API キー・iframe の中の欄がセレクタで見つからないことも書いた。
3. 採る（中）。値を出さない検査の限界（画像・escape や encode で形が変わった値は見つからない・値のファイルを検査する場所の中に置くと自身が当たる・読めないファイルのエラーを「当たり無し」と読まない）を箇条にした。件数が「出現の数」でなく「当たった行の数」であることも直した。
4. 採る（低）。`.catch(() => {})` の害を「後始末が走らない」と断定していたのを、「失敗を成功として先へ進み、失敗のときの後始末に届かない」に直した（`finally` に置いた後始末は走るので）。

ほかに Codex が挙げた、Playwright MCP の `--secrets` も1項目として足した。README の設定の説明（`secrets` は道具の応答の中の一致する文字を置き換える・便宜の機能で守りの機能ではない）を読んで確かめ、そのとおりに書いた。S1-2 の2つの判断（スクリプトの例を書かない・knowledge store に入れない）には反論が無かった。

昇格の印: Playwright MCP の道具の多くが応答に snapshot を付けることは、資格情報に限らず「写しに残したくないものがある画面」全般に当たる。スキルの別の節（基本フロー）に一般の注意として書くかは、この単位の範囲の外である。
