---
id: "01KYA7C9MWDKQK79FGDWRC8W6H"
type: knowledge
status: active
date: 2026-07-24
trigger: "shell から外部コマンド（jq 等）へ、サイズが入力依存で膨らみうる値を argv（--arg / --argjson / 位置引数）で渡すとき"
prediction: "値が ARG_MAX を超えると exec 時に `Argument list too long`（exit 126）で落ち、宣言した exit code 契約（0/1/2 等）を破る。printf（shell builtin）+ stdin / here-string で渡せば argv 長制限を受けず同じ結果を得られる"
source:
  ref: "projects/orchestration-engine/docs/episodes/2026-07-24-episode-273-nk-match-inject.md"
landing: guard-candidate
observations: []
exclusions:
  - "渡す値が定数、または明確に小さい（サイズ上限が入力に依らず保証できる）ケース"
---

外部コマンドの argv には OS の `ARG_MAX` 上限がある。入力由来で膨らむ値（ファイル本文・frontmatter フィールド・JSON 配列全体）を `jq --arg` / `--argjson` や位置引数で渡すと、ある入力サイズで `exec` が `Argument list too long` を返し、コマンドが exit 126 で落ちる。read-only の列挙のつもりでも、宣言した exit code 契約を破る到達可能なサービス不能経路になる。

非自明なのは (1) **shell builtin（`printf` 等）は exec を経ないので argv 制限を受けない**こと、(2) **同じ欠陥が値の流れる箇所ごとに再発する**ことである。今回は excerpt→frontmatter フィールド→出力組立の 3 経路で順番に露呈した。1 箇所直しても別経路に同種が残りやすい。

次にどう行動を変えるか: 大きくなりうる値は argv でなく **stdin（`printf '%s' "$v" | cmd` や here-string `cmd <<<"$v"`）で渡す**。派生値（要約・抜粋）は生成側で長さを bound する。レビュー/lint では「shell 変数を `--arg/--argjson` へ渡していて、その変数が入力サイズに比例しうる」箇所を anti-pattern として洗う。
