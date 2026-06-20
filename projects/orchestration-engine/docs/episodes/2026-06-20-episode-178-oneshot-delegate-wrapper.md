---
id: "01KVJQJG9XJ3RBBV5QZ11NYX4N"
title: "#178 oe-kick — kickoff/issue 参照からのワンショット委譲ラッパー（tmux）実装"
date: 2026-06-20
type: episode
status: in-development
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/178"
    reason: "本 episode の対象 Issue（oe-delegate の薄いワンショットラッパー + 対話委譲レイヤ hardening 2点）"
  - type: design_context
    ref: "projects/orchestration-engine/docs/episodes/2026-06-17-episode-oe-select.md"
    reason: "hardening 2点（--label 改行 fail-fast / oe_reg_list sanitize）の出自＝oe-select 実装SO の follow-up routing"
  - type: design_context
    ref: "canonical/skills/delegate-task/SKILL.md"
    reason: "ラッパーが展開する oe-delegate のフラグ列・基本パターン（--label '#N' + task 文）の正本"
tags: [orchestration, delegate, oe-kick, oneshot, hardening, episode]
---

# #178 oe-kick — ワンショット委譲ラッパー 実装 episode

> 本文は作業中リアルタイム追記（reconstructed ではない）。closure は `episode-retrospective`。
> 親 = `%32`。本セッションは worktree（`feature/#178_oneshot_delegate_wrapper`）で並行子（#199）と非衝突に作業。

## ミッション（kickoff `.oe/2026-06-20-kickoff-178-oneshot-delegate.md`）

- `oe-delegate`（tmux 子 spawn + kick）の薄いワンショットラッパー。`#N` or kickoff パスを 1 引数で受け、`oe-delegate` の妥当なフラグ列に展開（`--label` 自動付与＝Issue 番号→ラベル / workspace 既定化）。
- 実装時 hardening（#178 本文・oe-select 実装SO 由来）併せて対応:
  - `oe-delegate --label` が改行（LF/CR）を含む値を fail-fast 拒否。
  - `oe_reg_list` 出力でラベル / pane_title の改行を sanitize（消費者 `oe-list`/`oe-select` で偽 `%N` 行を防ぐ）。

## 設計フェーズ（2026-06-20）

駆動層フロー（engine 規約）: kickoff/DJ → 設計SO（predecision 兼）→ 実装 → 実装SO（oe-review）→ Episode → PR → Copilot。

### 設計判断と探索（predecision-exploration の確定前証跡）

初期案セットと暗黙の前提を列挙し、ゼロベース代替を `oe-refute --rubric exploration` で1回反証する（証跡＝本節 + tmp/oe-refute 出力の verdict/reason 転記）。

```text
DJ-1: verb 名
├── oe-kick（初期） → 差分軸: 既存「キック」用語（oe-send が "キック" 注入）と一致・短い・spawn/delegate と非衝突 → 採用候補
├── oe-oneshot → 差分軸: 説明的だが冗長・他 verb（list/send/select）と語感不一致 → ❌
├── oe-spawn → 差分軸: lib/spawn.sh（engine 非対話 claude -p）と語が衝突＝誤解の元 → ❌
├── oe-run / oe-go → 差分軸: 汎用すぎ・engine 本体 oe と紛らわしい → ❌
└── verb を作らず oe-delegate のモード（--issue N）に畳む → 差分軸: 責務分界。issue は「薄い別ラッパー」を明示要求 → ❌（kickoff 指定に反する）

DJ-2: 1引数 ref の判定優先順位
├── 明示モードフラグ（--issue / --kickoff）必須 → 差分軸: 明示的だが「1引数ワンショット」目標に反する → ❌
└── 自動判定: 既存ファイル → kickoff / それ以外で ^#?[0-9]+$ → issue（初期・採用） → 差分軸: file-exists 優先で「178 という名のファイル」も直観的に解決

DJ-3: kickoff パス時の label 自動導出
├── ファイル名から kickoff-<N> 抽出 → #N ラベル（初期・採用） → 差分軸: 命名規約 kickoff-<N> にアンカー・日付誤検出を回避
├── kickoff doc の frontmatter/body を解析 → 差分軸: 脆弱・スコープ増 → ❌
└── kickoff 時はラベル無し（wt switch 後の pane-issue に委ねる）→ フォールバックとして採用（kickoff-<N> 不検出時）

DJ-4: フラグ範囲（薄さの境界）
├── <ref> + -w + --claude-arg passthrough + -h（採用） → 差分軸: --claude-arg は純 passthrough（oe-delegate が検証/quote）・cockpit 自律導線で必須
├── 最小（<ref> + -w のみ） → 差分軸: 自律 spawn（--permission-mode）が組めない → ❌
└── 最大（--label override / --dry-run 追加） → 差分軸: スコープ増・auto-label が spec → ❌（defer）

DJ-5: tmux 前提の扱い
├── oe-kick 側で軽量 preflight（TMUX_PANE 空ならエラー・初期/採用） → 差分軸: 受入条件「tmux 外で明示エラー」を踏襲・gh task 文組立前に fail-fast
└── oe-delegate の検査に委譲（inherit のみ） → 差分軸: エラー文が oe-delegate 主体になる・薄いが UX 劣 → 併用（oe-kick で先に弾く）

テスト seam: oe-kick は `OE_DELEGATE_BIN`（既定=兄弟 oe-delegate）経由で exec。テストはモック oe-delegate に差し替えて argv 展開を検証（OE_SELECT_TTY と同型の seam・ユーザ向けフラグではない）。
```

### 設計SO（predecision 兼）= `oe-refute --rubric exploration --lanes 2`（codex+cursor）R1

- verdict=**refuted**（2/2 material・conservative 集約）。reason: 「1引数判定の失敗系・oe_reg_list 消費者範囲・sanitize 脅威モデル・OE_DELEGATE_BIN seam のテスト到達範囲が未確定」（codex）/「第三分類エラー未設計・hardening/実装/設計SO が一次未検証・seam 単独でラッパー核心をテスト不能」（cursor）。
- 証跡（揮発）: `tmp/oe-refute-202606201441234C6G4CH847AZ/`（codex-stdout / cursor-stdout）。audit_id=`202606201441234C6G4CH847AZ`。verdict/reason は本節へ転記済。
- **生き残り（survived）**: verb `oe-kick` / `--claude-arg` passthrough / tmux 二段 preflight / hardening を delegate 入力 + registry 出力に置く大枠（いずれも一次情報で支持・棄却なし）。
- **反証の織り込み（確定前に design を更新）**:
  1. **DJ-2 第三分類**: `-f`→kickoff / `^#?[0-9]+$`→issue / **それ以外→明示エラー（usage + exit 2）**。壊れ symlink・`kickoff-178`(dir)・`abc`/`178a` は第三分類でエラー。`0178` は `10#` で先頭ゼロ正規化（label/コマンドの `#N` ドリフト回避）。file-first の tradeoff（`./178` が issue 意図を潰す可能性）は意図的・受入条件準拠で許容、help に明記。
  2. **oe-status も消費者**: sanitize を**消費者ごとでなく producer `oe_reg_list` の出力チョークポイント**に置くことで oe-list/oe-select/**oe-status**（`:174/:181/:247` awk）を一括防御（確認済）。
  3. **脅威モデル境界（過剰主張の訂正）**: CR/LF は消費者の `while read`/`awk RS=\n` のレコード境界＝**偽 `%N` 行注入の主経路**。U+2028/ANSI/TAB は consumer のレコード分割に影響せず `%N` 行を偽造**しない**（視覚偽装のみ・低リスク）→ #178 は CR/LF を断ち、視覚偽装は scope 外 follow-up と明記（「断つ」→「文書化された偽行注入経路を断つ」へ後退）。
  4. **書き込み側 hardening は #178 外**: `oe_reg_record`/`wt-pane-issue.sh`(branch 由来・git ref に改行不可)/`oe_reg_resolve`(出力は list-panes 由来の信頼 `%N` のみ・label を出さない＝偽造ベクタでない)。issue スコープ（delegate 入力 fail-fast + list 出力 sanitize）と oe-select episode の cross-cutting routing に従い follow-up。
  5. **テスト到達**: モック `oe-delegate` への展開 argv を assert することで ref 判定 / `kickoff-<N>` 抽出 / issue task 文 / **tmux preflight 順序（mock 呼出前に fail）** まで覆う（argv は核心ロジックの出力＝exec のみではない）。第三分類エラーも直接ケース化。
  6. **task 非対称の解消**: issue/kickoff 双方で**末尾 ad-hoc 1行を任意受理**（issue=既定テンプレに連結 / kickoff=oe-delegate の task へ）。delegate-task の可変 task 例と整合。
  7. frontmatter `status` を作業中 `in-development`→closure で `stable`。
- **停止判断**: 核心カテゴリは survived・反証は breadth/grounding 補完（再方向づけではない）。1回ゼロベース完了し全点を design に織込済 → 確定に進む。実装の正否は**実装SO `oe-review`（diff-bound）**で検証（#192/#175 の教訓＝設計SO は実装SO の代替にならない）。

## 実装フェーズ

- **`bin/oe-kick`**（新規）: 薄いワンショットラッパー。1引数 ref を `-f`→kickoff / `^#?[0-9]+$`→issue / それ以外→明示エラー(exit 2) で判定。issue は `--label '#N'` + gh task 文、kickoff は `kickoff-<N>` 抽出ラベル(不検出は空) + `--kickoff`。末尾 ad-hoc を両モードで任意受理。`TMUX_PANE` preflight(空→exit 1)。`OE_DELEGATE_BIN` seam で実体を差替可。`exec "$OE_DELEGATE_BIN" ...`。bash 3.2 互換（空配列ガード `${#CLAUDE_ARGS[@]}`・declare -A/mapfile 不使用）。
- **hardening-1 `bin/oe-delegate`**: `--label` 値の LF/CR を spawn 前に fail-fast 拒否（既存 `--claude-arg` と同型）。
- **hardening-2 `lib/delegate-registry.sh`**: `oe_reg_list` 出力チョークポイントで label の LF/CR を空白へ畳む（消費者 oe-list/oe-select/**oe-status** を producer 1点で一括防御）。
- **付随修正（実機 3.2 検証で検出した既存バグ）**: `oe-delegate` の `build_child_command` が `for arg in "${CLAUDE_ARGS[@]}"`（空配列）で bash 3.2 + `set -u` 下 `unbound variable` 落ち。`oe-kick #N`（--claude-arg 無し）は CLAUDE_ARGS 空で必ずこの経路 → ADR-005 環境で feature が壊れる。`${CLAUDE_ARGS[@]+"${CLAUDE_ARGS[@]}"}` イディオム（oe-select 前例）で修正。**master にも存在する pre-existing バグ**で、本機能の 3.2 動作に直結するため #178 で吸収（PR で明示）。
- **テスト**:
  - `tests/test_oe_kick.sh`（新規・24 assert）: モック `oe-delegate`（`OE_DELEGATE_BIN`）への展開 argv を assert＝ref 判定 / `kickoff-<N>` 抽出 / 0178 正規化 / issue task 文 / ad-hoc 連結 / `--claude-arg` passthrough / workspace 既定 / 第三分類・178a・ref 省略・tmux 外・unknown option・file 優先 の各エラー経路（mock 未呼出含む）。
  - `tests/test_oe_delegate.sh`（+4 assert）: `--label` LF/CR 拒否（rc2・未 spawn）。
  - `tests/test_delegate_registry.sh`（+4 assert）: `oe_reg_list` sanitize（pane_title 由来 / pane-issue .name 由来の両経路で偽 `%N` 行非注入・本来 label 保持）。
- **ドキュメント**: `bin/README.md`（oe-kick 節 + 索引）/ `README.md`（構成ツリー + delegate CLI リスト）。canonical `delegate-task` SKILL は更新せず（sibling 便利 verb の oe-select も未収録＝先例踏襲・Minimal Scope）。
- **検証**: `shellcheck bin/oe-kick bin/oe-delegate lib/delegate-registry.sh tests/*` PASS。bash **5.x** で test_oe_kick 24 / test_oe_delegate 18 / test_delegate_registry 20 / **回帰 test_oe_select 35 / test_oe_status 27** 全 PASS。**/bin/bash 3.2.57（macOS・runner+inner 双方を 3.2 強制）でも 24/18/20 PASS**（ADR-005。付随修正前は test_oe_delegate が CLAUDE_ARGS[@] で fail＝修正を実証）。

### 実装SO = `oe-review`（diff-bound・code-defect/到達可能性レンズ）

(commit 後に実行・verdict をここへ転記)
