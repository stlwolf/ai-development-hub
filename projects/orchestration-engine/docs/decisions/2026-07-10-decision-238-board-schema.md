---
id: "01KX3TKYHM8R07YY8DVT2HTHMT"
title: "#238 段階1 board schema — cockpit 統括 succession board の declared 層契約"
date: 2026-07-10
type: decision
status: draft
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/238"
    reason: "統括 succession を第一級概念に。board schema = declared 層（PR-C）"
  - type: design_context
    ref: ".oe/ref-plan-stage1.md"
    reason: "段階1 実装計画の正本。§2 PR-C（schema/validator の内容）・§4 Q8（置き場・粒度・advisory）。注: .oe/ は gitignore 済みの machine-local 資料で、この checkout には含まれない（out-of-repo）。durable な上位アーキは #238 と decisions/ の succession-watchdog 決定 doc を参照。"
  - type: reference
    ref: "projects/orchestration-engine/scripts/validate-envelope.sh"
    reason: "踏襲した validator idiom（exit code・VERBOSE・helper 構造）"
  - type: reference
    ref: "projects/orchestration-engine/scripts/validate-session-state.sh"
    reason: "同上。必須フィールド + 型 + enum を jq で検証する MVP validator の前例"
---

# #238 段階1 board schema — cockpit 統括 succession board の declared 層契約

## 1. 目的・位置づけ

cockpit 統括の **succession board**（START HERE board）に、構造と鮮度を強制する schema を与える。統括は使い捨てで state が正本という #238 の前提のもと、board は「統括が死んでも handoff が成立する唯一の外部化 state」である。散文の board で 4 代の handoff は成立してきたが、残る gap は **構造の欠落と鮮度の不明**（後任がどの節を頼れるか、その内容がいつ時点のものかが自明でない）だった。

本 schema は上位アーキ（lean + sidecar）の **declared 層**にあたる。observed 層（watchdog）が読み取る liveness の ground truth を declared 層が補完する（例: `gone + stale` な pane が orderly handoff か crash かを、board の `現統括` / `succession` と突き合わせて判別する）。

- schema の強制手段は advisory validator `projects/orchestration-engine/scripts/validate-board.sh`（後述 §4）。
- 検証内容は 3 点: **(1) 必須 frontmatter キーの存在 / (2) 鮮度 date が N 日以内 / (3) 必須 section 見出しの存在**。

## 2. 対象と非対象

- **in-repo に足すもの**: 本 schema/spec doc と advisory validator script の 2 点のみ。
- **board 実体は in-repo に足さない**。board は live な pane 番号や環境 state（machine-local で ephemeral な値）を含むため commit しない。board 実体は external の置き場（`.oe/` = gitignored、または統括の memory 領域）に置いたままにする。
- したがって本 doc が定義するのは **契約（どんな board が valid か）**であって、特定の board インスタンスではない。schema の adoption（実 board を本 frontmatter 形式へ移行すること）は board 保守側の運用であり、PR-C の scope 外。

## 3. schema 定義

### 3.1 必須 frontmatter

board は YAML frontmatter で始まる（1 行目が `---`、以降に閉じ `---`）。次のキーを必須とする。

| キー | 型 | 説明 | 例 |
|---|---|---|---|
| `鮮度` | date（`YYYY-MM-DD`） | board を最後に更新した日。鮮度判定の基準 | `2026-07-10` |
| `現統括` | string（pane） | 現統括の pane。`%NNN` 形式を推奨（YAML では `%` 始まりは引用符が要る） | `"%144"` |
| `succession` | string | succession の状態。推奨語彙は `完了` / `進行中` / `未着手`（enum は強制しない） | `完了` |

- **値の形式は advisory では強制しない**（キーの存在のみを必須とする）。正当な board variation を "invalid" と誤検知しないため、必須集合を最小に保つ方針（過剰な必須化をしない）。`現統括` の pane 形式や `succession` の語彙は推奨であって、validator は検査しない。

### 3.2 必須 section

現 board 準拠の H2 見出し（`## `）を必須とする。実見出しは括弧付きの注記を後続させてよい（例 `## 戦略（不変）`）ため、validator は **部分一致**で存在を確認する。

| section | 役割 |
|---|---|
| `戦略` | 不変の方針。統括が何を目指すか |
| `in-flight` | 現統括が担当中の委譲・queued-next |
| `repo / 環境 state` | master HEAD・worktree・panes 等の環境スナップショット |
| `統括規律` | succession で必ず引き継ぐ規律（HG・報告 2 段構え等） |
| `succession 手順` | 後任がやること |

- 上記以外の section（`直近やったこと` / `次タスク候補` / `gotchas` 等）は任意。board の自由度を残すため必須にしない。

### 3.3 鮮度ルール

- `鮮度` の date が **現在から N 日以内**であることを確認する。既定 N = 7 日。
- N は運用ヒューリスティック（証拠に基づく閾値ではなく、運用でチューニングする値）。環境変数 `OE_BOARD_MAX_AGE_DAYS` で上書きできる。
- 未来日付は stale 扱いにしない（誤入力の可能性はあるが advisory のため flag しない）。

## 4. validator: `scripts/validate-board.sh`

`validate-envelope.sh` / `validate-session-state.sh` の idiom（exit code・`--verbose`・helper 構造）を踏襲する。ただし検証対象が JSON でなく markdown + YAML frontmatter のため、frontmatter 抽出と section 見出し確認は bash のテキスト処理で行う。

```bash
# 使い方
./scripts/validate-board.sh path/to/board.md
./scripts/validate-board.sh path/to/board.md --verbose
OE_BOARD_MAX_AGE_DAYS=14 ./scripts/validate-board.sh board.md   # 鮮度しきい値を上書き
```

- **exit code**: `0 = valid` / `1 = invalid`（1 件以上の WARN） / `2 = file not found / jq 不在 / usage エラー / 非数値の OE_BOARD_* env`。
- **advisory（warn・非ブロッキング）**: validator は何もブロックしない。問題は `WARN:` 行として stderr に出し、呼び出し側（人 / cron）が対処を判断する。exit 1 は「flag された」ことを programmatic に伝える信号であって、build や hook を落とすためではない。read-only / HG 姿勢と #78 advisory-hook の前例に整合する。
- **fail-fast しない**: 1 回の実行で全 WARN を出す（board のどこが崩れているかを一望できる）。
- **env ノブ**:
  - `OE_BOARD_MAX_AGE_DAYS`（既定 `7`）— 鮮度しきい値（日数）。非負整数のみ。
  - `OE_BOARD_NOW_EPOCH` — now を固定する epoch。テストの決定化に使う（`oe-undelivered` の `OE_*_NOW_EPOCH` と同型）。非負整数のみ。
  - いずれも非数値だと `set -u` 下の算術で cryptic に落ちる代わりに、exit 2（環境エラー）で明示的に弾く。
- **jq の用途**: 鮮度 date（`YYYY-MM-DD`）→ epoch 変換に jq の `strptime | mktime` を使う。BSD / GNU の `date` パース差を避けられる可搬な手段。now は `date +%s`（両系可搬）。
- **既知の制約**: frontmatter block の判定は「1 行目が `---` かつ以降に `---` 行がある」ヒューリスティック。1 行目が `---` で始まりつつ frontmatter でない（本文冒頭が水平線）board では、本文中の `---` を閉じフェンスと誤認しうる。board は frontmatter で始まる前提のため実害は小さいが、厳密化は将来課題。

## 5. valid な board の最小例

```markdown
---
鮮度: 2026-07-10
現統括: "%144"
succession: 完了
---

# START HERE — cockpit 統括 succession board

## 戦略（不変）
cockpit を早めに整備し運用に回して改善を続ける。

## in-flight（現統括 %144 の担当）
- アクティブな委譲: なし

## repo / 環境 state
- master: `6896289` / worktree: main のみ

## 統括規律
- HG: 子は mutation を自律発火しない。マージ・worktree 掃除は親/人間。

## succession 手順
1. このボードと MEMORY.md を読む。
```

## 6. 設計判断・根拠

- **doc 型 = `decision`**: 本 doc は board 形式の契約を定義する仕様書である。type enum（`discussion`/`kickoff`/`plan`/`episode`/`decision`）に `spec` は無く、リポジトリ内で「形式仕様書」の前例である `docs/specs/document-format.md` が `type: decision` を採る。その前例に倣った。`status: draft` は運用検証を経て `stable` に昇格する想定。
- **advisory に留める根拠**: board は HG 前提の人手保守物であり、機械が更新を強制する対象ではない。read-only / HG 姿勢、および #78 の advisory-hook 前例と整合させ、validator は検知のみ・ブロックしない。
- **必須集合を最小に保つ根拠**: advisory validator の主リスクは「正当な board variation を invalid と誤検知」すること。よって必須は frontmatter 3 キーの存在 + 鮮度 + section 5 見出しに絞り、値の形式（pane 形・succession 語彙）は推奨に留める。
- **jq でも date 演算だけ使う根拠**: sibling validator は JSON を jq で検証するが、board は markdown。frontmatter 抽出と見出し確認は bash のテキスト処理が素直で、jq は可搬な date→epoch 変換にのみ使う。

## 7. 非対象・将来 defer

- **複数 seat の board**: MVP は単一 `supervisor` board のみ。複数 seat は seat 概念自体が defer のため不要（`.oe/ref-plan-stage1.md` §4 Q8）。
- **full JSON Schema 化**: 現状は必須 + 存在 + 鮮度の最小検証。厳密な schema 化（値の形式・enum の強制）が要るなら将来 ajv-cli 等へ移行しうる（sibling validator と同じ defer 方針）。
- **schema の adoption**: 実 board を本 frontmatter 形式へ移行する運用は board 保守側の作業で、本 PR の scope 外。

## 8. 関連リンク

- Issue #238: https://github.com/stlwolf/ai-development-hub/issues/238
- 段階1 実装計画（正本・§2 PR-C / §4 Q8）: `.oe/ref-plan-stage1.md`（out-of-repo・`.oe/` は gitignore 済みの machine-local。この checkout には含まれない）
- validator: `projects/orchestration-engine/scripts/validate-board.sh`
- 踏襲した sibling validator: `projects/orchestration-engine/scripts/validate-envelope.sh` / `projects/orchestration-engine/scripts/validate-session-state.sh`
