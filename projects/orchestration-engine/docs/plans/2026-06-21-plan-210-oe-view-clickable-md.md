---
id: "01KVMXY9NKS11MSMHCN5F6QSKP"
title: "oe-view 実装計画 — 生成doc のクリッカブル md ビューア（hyperlink_rules + open-uri）"
date: 2026-06-21
type: plan
status: draft
related:
  - type: target_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/210"
    reason: "本計画の対象 Issue"
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/169"
    reason: "CLI cockpit リッチ UI ツール群（親）"
  - type: reference
    ref: "projects/orchestration-engine/docs/discussions/2026-06-21-discussion-179-notify-pane-jump.md"
    reason: "#179 はトーストclick=url-onlyでスキームハンドラを避けた。#210 は出力hyperlink=open-uri横取り可で前提が異なる"
tags: [cockpit, oe-view, markdown, viewer, wezterm, hyperlink]
---

# oe-view 実装計画 — 生成doc のクリッカブル md ビューア

> 駆動層: 痛点ヒアリング → レンダラ/起動 DJ 確定 → open-uri 機構 一次確認(verified) → 計画 draft → **設計SO(cc+codex+cursor) reconcile（§10）** → 本改訂 → 承認 → 実装 → 実装SO(oe-review) → episode → PR。
> 実装はユーザーのプラン承認後。Issue 起点なのでブランチ/worktree は承認後に自律作成。

## 1. 痛点 / 成果物

plan/kickoff/episode 等の md を生成するとパスは表示されるが、見るたびに Finder/手動ペイン操作が要る。これを「パスから Finder/手動操作なしで即ビュー（md=端末内 glow / 非md=open）」にする。ターミナル完結が理想。成果物は2層・PR は2本（§8）:

- `oe-view <path>`（hub・新規 CLI）: `.md` → viewer ペインで `glow` 描画 / 非 md → `open`。クリック層に非依存で単体動作（`--here`/手動）。
- WezTerm 連携（dotfiles・wezterm.lua）: 出力中の doc パスをクリッカブル化し、クリック（Cmd+Click）を横取りして `oe-view` を argv 起動。

## 2. 機構（一次確認済み・verified）

WezTerm 公式 doc で確認:

- `hyperlink_rules`: 正規表現で出力テキストをカスタムスキーム URI 化可（`$0`/`$1`）。https://wezterm.org/config/lua/config/hyperlink_rules.html
- `open-uri` イベント: ハイパーリンククリックで `(window, pane, uri)` を受け、`false` 返却でブラウザ起動を抑止し任意アクション実行可。カスタムスキーム対応。https://wezterm.org/config/lua/window-events/open-uri.html

→ 経路: 出力パス →(hyperlink_rules)→ `oeview://<path>` →(Cmd+Click)→ `open-uri` 横取り → `oe-view <path>` argv 起動 → md=viewer pane+glow / 非md=open。**macOS LaunchServices スキーム登録(.app)は不要**。#179 は対象が「トースト通知click=url-only」で escape hatch が無く CLI replay に逃げたが、#210 は「出力 viewport hyperlink」で open-uri が使える（設計SO 3者で確認）。

## 3. コマンド仕様（oe-view）

```
oe-view [--here] [--from-link] [--json] [--] <path>
oe-view --help
```

- 既定: 対象が `*.md`（拡張子・大小無視）→ viewer ペインを解決して `glow` で表示（送信は注入安全化・§5）。非 md → `open -- <path>`。
- `--here`: 分割せず現ペインのページャ（`glow -p`、無ければ `bat`）。tmux 非 wez / Cursor 統合ターミナル / dotfiles 未反映時の degrade 本線。
- `--from-link`: クリック経由フラグ。**allowlist 強制・非 md 拒否（md のみ）**を有効化（直叩きより厳格)。
- `--json`: `{status, kind:"md"|"other", action:"glow"|"open", pane_id?}`。
- exit code（DJ-5 reconcile・矛盾解消）: `0`=成功 / `1`=対象不在・allowlist 外・glow/open 失敗 / `2`=usage・環境エラー（wez 不在・glow 未導入を含む。依存不足を独立コードにせず環境エラーに統一し案内文を出す）。

## 4. 設計判断（DJ・設計SO reconcile 反映済 / §10）

確定（ユーザー選択・代替提示 = predecision-exploration トレース）:

- **DJ-A レンダラ = `glow`**。代替 bat/qlmanage 提示の上で不採用。
- **DJ-B 起動 = クリッカブルリンク**。設計SO がゼロベースで QuickSelect / record-replay / fzf picker を「リスク束を構造的に回避する対抗」として提示したが、**マウスクリックの体験を保ち緩和策フル適用で確定**（再計量済の確定前トレース）。

確定（設計SO reconcile）:

- **DJ-1 配置 = engine `projects/orchestration-engine/bin/oe-view`**。ただし根拠を訂正: oe-jump の engine 配置理由（`oe_reg_resolve`=tmux↔registry glue）は oe-view に転用しない（oe-view は registry/tmux 不使用）。配置理由は「**cockpit UX glue**（wez pane + open + 種別ディスパッチ）であり、`wez` は下層プリミティブのまま（ADR-001/004 の wez=下層方針を守る・上方依存を作らない）」。viewer 解決ロジックは `lib/oe-viewer.sh` に切り出してテスト mock 容易化。
- **DJ-2 クリッカブル化 = `hyperlink_rules` 自動マッチ**。必須: `config.hyperlink_rules` 代入はデフォルト規則を全消しするため `wezterm.default_hyperlink_rules()` に `table.insert`。regex は doc ルート＋サブdir＋拡張子で厳格に絞る（例: `…/ai-development-hub/projects/[^/]+/docs/(plans|episodes|kickoffs|discussions|decisions)/[^[:space:]]+\.md`）。空白なしパスのみ対象（本リポは kebab パス規約）。OSC 8 明示出力は tmux で落ちやすい（hyperlink_rules は描画グリッド層で tmux 下も効く）ため v1 では採らない（将来 precision 層候補）。
- **DJ-3 click→command = wezterm.lua `open-uri` ハンドラ**。条件: ハンドラは `oeview:` 以外を無視・URI を厳格 parse（`oeview:///<abs-path>` 三スラッシュ）・**argv 配列**で `oe-view --from-link <path>` を起動（`wezterm.background_child_process`/`run_child_process`、shell 非経由）。GUI プロセスは PATH が痩せるため `oe-view`/`glow` は**絶対パス**指定。UX は Cmd+Click（`CompleteSelectionOrOpenLinkAtMouseCursor`）と明記。
- **DJ-4 viewer ペイン = state file 追跡で再利用**。`~/.claude/state/oe-view/viewer-pane-id`（oe-jump の last-target 同型）に pane_id 保存 → `_wez_pane_exists` 相当で生存確認 → 生存なら send / 無効なら split+state 更新。**glow の TUI ページャと send の衝突**を避けるため、再利用は「前回プロセス終了＝プロンプト復帰」を保証できる起動形に限定（非ページャ or 表示後復帰）。できない場合は「毎回 split + 古い viewer kill」に倒す。**新規作成時は `wez pane activate <source>`** でフォーカス奪取（#111）を回避（既定 focus=作業ペイン維持）。
- **DJ-5 fallback**: `--here` で `glow -p` / `bat`（導入済）。glow 不在・wez 不在は exit 2 + 導入案内。素 install 検証 → 採用なら dotfiles codify。

## 5. セキュリティ / 堅牢性（実装必須・設計SO で格上げ）

- **送信層のシェル注入（P0・最重要）**: viewer 表示が `wez pane send <id> "glow -- <path>"` の場合、`send-text`（`projects/wezterm-ai-mode/lib/pane.sh:465`）は受信シェルに**行入力としてタイプ→再トークナイズ**される。実在ファイル名 `a$(whoami).md` でも `$(whoami)` がペインのシェルで評価される（`\n` 拒否はメタ文字を防がない）。
  - v1 修正: 送信文字列を組む直前に `printf %q` でシェルクォート（`glow -- <quoted>`）。
  - 本筋（follow-up 候補）: `wez` に argv spawn verb（`wezterm cli spawn -- glow <path>`）を足し、shell を経由しない。実装時に v1（%q）か本筋（spawn 追加）かを再評価。
- **allowlist 実装必須（P0）**: `oe-view`（特に `--from-link`）は `realpath` 正規化後に doc ルート配下 prefix を判定（`..`/symlink トラバーサル対策）。範囲外は exit 1。
- **入力サニタイズ**: URI decode 後の改行・NUL・制御文字を拒否。実体存在＋通常ファイル確認。
- **クリック経由は md 限定**: `--from-link` では非 md `open`（任意アプリ/スクリプト起動）を禁止。CLI 直叩きの非 md `open` とは分ける。
- **Lua 側は parse のみ**: 実行判断（種別/allowlist/存在）は全て `oe-view` に集約。
- **フォーカス**: viewer 作成時のみ source へ activate（#111）。

## 6. テスト

`oe-view`（hub・shell・mock shim で wez/glow/open を差し替え）:

- [ ] md 判定 → viewer 解決 + glow 表示の引数列 / 非 md → `open -- <path>`
- [ ] **注入**: `a$(whoami).md` 等メタ文字ファイル名で送信文字列が `%q` 済（or argv 起動で shell 非経由）であること
- [ ] **allowlist**: doc ルート外パス・symlink 経由の範囲外・`..` → exit 1
- [ ] 入力サニタイズ: 改行/NUL/制御文字を拒否
- [ ] `--from-link` で非 md `open` が拒否される
- [ ] viewer 再利用: state の pane 生存→send / stale→split+state 更新 / 新規作成時 source へ activate
- [ ] 不在パス→exit 1 / usage 不正→exit 2 / wez・glow 不在→exit 2 + 案内
- [ ] `--here`（`glow -p`/`bat`）/ `--json` スキーマ（`jq -e`）/ `shellcheck`

wezterm.lua 連携（手動・実機ゲート）:

- [ ] doc パスがクリッカブル化（`default_hyperlink_rules()`+追加規則・既存 https 等が消えない）
- [ ] Cmd+Click → ブラウザに飛ばず `oe-view` 発火（open-uri `false`）
- [ ] **tmux 下**: `terminal-features hyperlinks` 有効 + Shift/Cmd+Click で wez 直下 shell と wez→tmux 子の両方でクリック→発火
- [ ] GUI プロセス起動でも絶対パスで `oe-view`/`glow` 解決
- [ ] 細工リンク（範囲外/メタ文字/非oeview）が無害化

## 7. 触るファイル

- 追加（hub）: `bin/oe-view`、`lib/oe-viewer.sh`、`tests/test_oe_view.sh`（すべて `projects/orchestration-engine/`）
- 変更（hub）: `bin/README.md`（oe-view 節 + 3段 degrade 表）。必要なら `wez` に argv spawn verb（本筋採用時・`projects/wezterm-ai-mode`）
- 追加/変更（dotfiles・別リポ）: `wezterm.lua` の `hyperlink_rules`（default ベース）+ `open-uri` ハンドラ。hub には設定スニペット/手順を doc 化（hub に lua 本体は置かない）
- 流用（read）: `bin/oe-jump`（state/解決の作法）、`projects/wezterm-ai-mode/lib/pane.sh`（split/activate/send/`_wez_pane_exists`）

## 8. スコープガード / PR 単位

- md=glow / 非md=open のみ。通知起点ジャンプ（#179）とは別レンズ＝出力テキスト起点。
- **issue は #210 の1本、PR は2本**（dotfiles が別リポ・検証モードが別=機械ゲート vs 実機手動のため）:
  - PR1（hub）: `oe-view` + tests + 手順 doc。`--here`/手動で即有用・機械ゲートで land。
  - PR2（dotfiles）: `hyperlink_rules` + `open-uri` ハンドラ。実機手動ゲート。PR1 を前提にリンク。
- wezterm.lua 正本は dotfiles（hub は手順 doc のみ）。glow 常設は dotfiles provisioning（素 install は検証フェーズ限定）。

## 9. ゲート

- 設計SO（§10）reconcile 済 → 本改訂で DJ 確定 → **ユーザー承認**で実装着手。
- 実装後: 実装SO（`oe-review`・コード欠陥/到達可能性レンズ・設計SO とは別レンズ）。verdict=refuted なら PR 保留。
- closure: `episode-retrospective`（消費者明示・routing・status・Decision 昇格判断）。

## 10. 設計SO reconcile（cc + codex + cursor・2026-06-21）

3者の verdict（出力は `tmp/so-20260621-201231/`・gitignore）:

- **機構（open-uri・scheme不要）**: 3者「妥当」。確定。
- **送信層のシェル注入**: Codex/Claude「重大・要修正」、Cursor は「`\n` 拒否で安全」と**誤判定**。実体（`pane.sh:465` send-text＝シェルへタイプ→再トークナイズ）照合により Codex/Claude を採用（vote でなく証拠で判定・evidence-verification-rule）。→ §5 P0。
- **DJ-1 配置**: Codex/Cursor「engine 妥当」、Claude「oe-jump 根拠は転用不可→`wez view`」。reconcile=engine 維持＋根拠訂正（cockpit UX glue・wez は下層維持）。
- **DJ-2/DJ-4/security**: 3者一致で要修正（default_hyperlink_rules・regex 厳格化 / state追跡+pager衝突+#111 activate / allowlist realpath 必須化）。反映済。
- **DJ-5 exit code 矛盾**: Codex 指摘。環境エラーを `2` に統一で解消。
- **トリガ再計量**: 3者がキーボードトリガ（QuickSelect/fzf/record-replay）をリスク低減案として提示。ユーザー判断で**クリック維持＋全緩和**に確定。QuickSelect は将来の追加トリガ候補として記録（v1 範囲外）。
- **1 issue 一括 vs 分割**: issue 1 / PR 2 で合意（§8）。
