---
id: "01KTJS4CG7T3HGVA3A9G4J9458"
title: "親子委譲CLI(oe-delegate)の再設計 — 送信のリッチ化とアドレッシング"
date: 2026-06-08
type: plan
status: ready
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/142"
    reason: "本再設計の傘 Issue"
  - type: source_material
    ref: "https://github.com/stlwolf/ai-development-hub/issues/138"
    reason: "親子スレッド協調プロトコル設計（現行 oe-delegate/oe-report の出自）"
  - type: source_material
    ref: "https://github.com/stlwolf/ai-development-hub/issues/137"
    reason: "wez pane send → Claude Code 注入 PoC（tmux send-keys 一択の根拠）"
  - type: source_material
    ref: "projects/orchestration-engine/lib/spawn.sh"
    reason: "パスポインタ送信の実証パターン（envelope を子に読ませる）"
tags: [orchestration, delegate, oe-delegate, oe-send, addressing, cli-redesign, plan]
---

# 親子委譲CLI(oe-delegate)の再設計 — 送信のリッチ化とアドレッシング

> question-driven-design で実フローを掘り下げ、so ゲート（Codex/Claude）で計画を反証検証した上で確定した v2 プラン。
> 単一 Issue #142 / 単一 PR / 論理単位コミットで実装する。

## Context

`oe-delegate` / `oe-report`（#137 PoC → #138 設計 → #139 実装 / #141 修正）は、tmux `send-keys` でセッション間プロンプトに1行注入する薄いラッパー。「人間目視前提・ポーリングなし・1行注入・親1⇄子1」という PoC 由来のプロトコルをそのままスクリプト化したもので、`delegate-task` スキルから駆動している。

実フローと照合した結果の不適合:

- トポロジは **統括スレッド（親・作業しない）→ 子 N 個（2-3 並列）のスター型**。孫委譲は無い。割り込みは非問題
- 痛点は **親 → 子の送信（キックオフ／事前情報の受け渡し）**。重いケースは4層ドキュメント方式のキックオフ doc を渡すだけで足りるが、軽いケースは親 AI に委譲用のまとめプロンプトを生成させ手でコピペしており、ここに ad-hoc 要望も上乗せする。**コピペ痛点と誤送信の本体はここ**
- 既存ペイン（手で分割済み）へ投げたい用途（関連は薄いが本質的な側道会話）がある
- 子 → 親の戻し（`oe-report`）は最悪不要。今回スコープ外（論点 E）

## 設計判断（論点 A-E）

- **A（組立コンテキストの永続性）**: 既定=揮発ファイルだが `/tmp` ではなく **workspace 配下**（`<workspace>/.oe/kickoff-*.md`、gitignore）に置く。対話型 claude は `--add-dir` 無しで `/tmp` を読めず権限プロンプトで止まるため。必要時 `spec-card` で4層docに昇格。送信口は「揮発でもdocでもパスを受ける」一本化
- **B（side会話ペイン）**: `#N` を持たないペインは生の `%N` を直接 target に取れる escape hatch。`oe-list` は source 列（spawn-registry / pane-issue / pane-title）を出す
- **C（拡張 vs 新編）**: 新規 `oe-send` / `oe-list` 追加 + `oe-delegate` を spawn+send に refactor し **report 結合を除去（疎結合化）**。`oe-report` のコード自体は不触で legacy 化（整理は論点E）。共有ロジックは責務分離:
  - `lib/delegate-send.sh` — 改行拒否の1行 safe-send（transport）。oe-report が将来無改修で乗れるよう先出し
  - `lib/delegate-registry.sh` — record/resolve/list/gc（addressing）
  - 既存 `lib/spawn.sh` の `oe_spawn_send`（wez・`claude -p`・非対話）とは別系統。統合しない旨を docs/skill に明記
- **D（レジストリ）**: `~/.claude/state/oe-delegate/` に per-child `${server}_${pane}.json`（`{pane, label, workspace, parent_pane, role}`）。resolve/list は `parent_pane == $TMUX_PANE` で親スコープ絞り。GC は `pane 不在 or key の pid ≠ 現 server pid` で削除（server 再起動の pane 番号再利用による誤着弾・リーク防止）
- **E（戻し / oe-report 統合）**: 戻しは `oe-send "$PARENT_TMUX_PANE"` に一本化。oe-report のコード整理（薄い alias 化／廃止）は今回スコープ外・別 Issue 候補

## アドレッシング解決の確定仕様

- **順引き**で解決する（filename からの逆算はしない）:
  ```
  pid = 現 tmux server pid
  for p in $(tmux list-panes -a -F '#{pane_id}'):   # 生存ペインのみ起点
    key="${pid}_${p}"; key="${key//[^A-Za-z0-9]/_}" # 書き手(wt-pane-issue.sh)と同一のキー生成
    name = jq .name "$state_dir/$key"               # pane-issue 由来の #N
  ```
  生存確認・現server scope・名前解決が一手に揃い、孤児/別serverの stale を踏まない
- `#N` は **トークン境界の完全一致**（`^#<n>($| )`）。前方一致は使わない（`#1`→`#10`/`#142` 誤マッチ防止）
- 任意名は exact 一致のみ（誤送信防止のため prefix 一致は使わない）
- union（spawn registry + pane-issue）は **pane_id で dedup してから件数判定**。0件→エラー+`oe-list`誘導、複数件→曖昧エラー
- 同一 pane に両ソースのラベルがある場合は **pane-issue（現在の #N）を優先**（子が issue 乗換しても古い spawn ラベルが勝たない）
- `%N` 直指定は registry を介さず素通し（escape hatch、parent scope 対象外）

## 実装ステップ（incremental rollout 順 / 論理単位コミット）

| # | コミット | 内容 |
|---|---------|------|
| 1 | `docs(engine)` | 本プラン doc（駆動層の記録） |
| 2 | `feat(engine)` | `lib/delegate-send.sh` — 改行拒否の1行 safe-send |
| 3 | `feat(engine)` | `bin/oe-send` — %N 直指定 + path pointer + ad-hoc |
| 4 | `refactor(engine)` | `oe-delegate` を spawn+send 化 → report から疎結合化（suffix/tmp 除去・`--no-enter` 内包） |
| 5 | `feat(engine)` | `lib/delegate-registry.sh` — parent-scoped addressing |
| 6 | `feat(engine)` | registry 接続 + `bin/oe-list` |
| 7 | `docs(skill)` | `delegate-task` を新CLI体系に追従 |

### 疎結合化（レビュー中の設計変更）

delegate に report を内包するのは CLI レベルの密結合で Unix 哲学に反する。kick→report の閉ループ
（ワンラリー）は組み込み subagent の劣化版でしかなく、delegate の価値「開いた対話セッションへの
キック」を損なう。よって delegate は spawn+kick に純化する:

- oe-report 案内 suffix を **削除**（delegate は report を一切知らない）
- `/tmp/oe-parent-*` 書き出しを **削除**（oe-report 専用配線）
- `PARENT_TMUX_PANE` env は「親ペイン」**汎用コンテキストとして維持**。戻しは子が汎用の `oe-send "$PARENT_TMUX_PANE"` で行う
- 位置引数の1行 task（`$1`）と `--` デリミタ規約（#141）は維持。`--kickoff`/`--label` を追加
- auto-Enter は `oe-send` / `oe_send_line` の `--no-enter` フラグに内包（既定=発火）。挙動はスキルでなくコマンドが持つ（ai-middleware-cli 構想）
- oe-report は legacy 化（薄い alias 化／廃止は論点E）

> so v1 は「suffix を消すと戻し経路が沈黙＝回帰」と指摘したが、それは互換維持前提。
> 本変更は **意図的な疎結合化**であり回帰ではない（戻しは oe-send に一本化）。反映後に再 so する。

## 検証 / ゲート

- 各 step で `shellcheck`
- so ゲート（v1 で穴 12 件 → v2 で全反映、方向性3者一致）
- E2E: 親で delegate→子→ad-hoc 付きキック着弾、別の既存ペインへ `oe-send %N`、ラベル送信、`oe-list` で source 付き一覧
- 完成した 1 PR に対して so / Copilot レビューを投げる（分断レビュー回避）

## リスク / 前提

- **`#N` 解決は `wt switch` 経由が前提**: 素の `git checkout` で issue ブランチに入った子は session-keyed state（pane なし）で pane-issue エントリが無く `#N` 解決不能。その場合は spawn registry の仮ラベル or 生 `%N` にフォールバック
- side 会話ペイン（master / リポ名命名）は `#N` を持たない → 生 `%N` 指定で吸収
- ラベルドリフト（子の issue 乗換）は pane-issue 優先で吸収
- tmux server 再起動の pane renumber → 順引き + pid-aware GC で stale を弾く
- tmux 外では全機能不可（前提として明示）
- `send-keys -l` の改行途中送信 → safe-send の改行拒否で根本封じ

## 参照

- so ゲート出力: `tmp/so-142/`（gitignore、揮発）
- 現行実装: `projects/orchestration-engine/bin/oe-delegate` / `oe-report`
- 流用する state: `scripts/wt/wt-pane-issue.sh` / `canonical/hooks/scripts/session-name.sh`
- 追従するスキル: `canonical/skills/delegate-task/SKILL.md`
