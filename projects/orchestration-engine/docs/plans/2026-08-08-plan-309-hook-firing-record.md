---
id: "01KZGJSJNWD962B0KBSS5DKH5J"
title: "#309 フックの発火記録を残す — 実装プラン"
date: 2026-08-08
type: plan
status: draft
source: "https://github.com/stlwolf/ai-development-hub/issues/309"
scope: canonical
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/309"
    reason: "本プランの起点"
  - type: parent_epic
    ref: "https://github.com/stlwolf/ai-development-hub/issues/37"
    reason: "制御ループ5要素のうち Sensor が空という中核課題。本単位はその最小増分"
  - type: integration_target
    ref: "https://github.com/stlwolf/ai-development-hub/issues/310"
    reason: "cc-lint の inherit_errexit 依存。trap 採用で影響範囲が3ツールへ広がるため、gate 3 の追加判断で本単位の Step 1 として先に塞ぐ"
  - type: derived_from
    ref: "projects/orchestration-engine/docs/episodes/2026-08-08-episode-309-hook-firing-record.md"
    reason: "gate 1 / gate 2 の探索と実測の経緯。設計が3度変わった記録"
  - type: design_context
    ref: "tmp/dj-309-exploration-tree.md"
    reason: "確定前の探索木（gate 1 の証跡・作業層）"
tags: [hooks, sensor, observability, engine, fail-closed]
so:
  design: weak
  impl: weak
  reason: "fail-closed なフックを3ツール分触るので影響範囲が日常作業全体。ただし本質的な protection は SO の周回数より実機の失敗経路テストなので、モードを強にせずレーンの多様性と実機検証で担保する（設計3レーン・実装3レーン）"
---

# #309 フックの発火記録を残す — 実装プラン

## Context

### なぜこの作業をするか

止める側のフック3本（`block-destructive.sh` / `block-force-push.sh` / `cc-lint.sh`）は発火したことを1行も記録しない。そのため「強制点が本当に発火したか」を当事者以外が確かめられない。#305 のアンカー設計が3ラウンド続けて反証された原因は、遡ると全部この1点に帰着した。閉ループ制御の5要素でいうと、フックは Actuator を担えているのに Sensor を担っていない。

### 動かせない制約（owner が gate 0 で確定）

- 記録の失敗で操作をブロックしない。記録は best-effort で、本来の判定経路に影響させない。
- 記録は `~/.claude/state/oe-events.jsonl` に混ぜず、別ファイルにする。
- 止めたときも通したときも記録する。
- 記録の改ざん耐性を暗号的に保証しない。当事者が書ける場所であることを前提として明記する側に倒す。

### gate 3 で owner が下した判断（2026-08-09・本プランの前提を置き換えた）

**trap 案を本単位で採る。** 3本に `trap` を張り、**想定外の終了（0 / 2 以外）を必ず deny へ収束させる**。`jq` 不在も deny に倒す。

owner の理由: `jq` は実際に環境へ入っており、パッケージ化するなら必須にすればよい。したがって「`jq` 不在で日常が止まる」という引き換えは、この環境では成立しない。

この判断で**複式記入（入口記録 `inv` と出口の差で欠測を検出する仕組み）は落ちる**。「呼ばれたが判定を出す前に死んだ」が構造的に発生しなくなるので、差を数える必要がない。入口記録・差分の解釈・ウォーターマークがまとめて消える。

**ただし trap は複式記入の置き換えであって、発火記録（tally）の置き換えではない。** ここを混同しない。

- trap が捕まえるのは「**走ったが途中で死んだ**」である。
- 本設計がいちばん恐れているのは「**そもそも走らない**」（Codex の silent skip・trust されていない・登録されていない・dangling symlink）である。**走らないフックに trap は張れない。**

したがって #309 の中心（発火したことを記録する）は残り、縮むのは「死を数える」部分だけである。

**副次的に、記録の質は上がる。** trap で収束した内部エラーは `deny.jsonl` に `rule: "internal-error"` として **1件ずつ時刻つきで**残る。累計値の差を解釈していた複式記入より分解能が高く、gate 2 が指摘した「差は残高であって死因の件数ではない」という弱さが消える。

### gate 3 の追加判断（2026-08-09・#310 を本単位に入れる）

**`cc-lint` の `inherit_errexit` 依存（#310）を、この単位で先に塞ぐ。** 前版では「別 issue にして触らない」としていたが、trap を入れるとこの穴の影響範囲が Cursor 1本から3ツール全部へ広がるため、順序を変えて先に塞ぐ。

**コミット順は「#310 の修正 → trap → tally」で固定する。広がった穴を抱えた状態を一瞬も作らない。** 3つとも別コミット・別検証にする（owner の明示指示。作業単位と検証単位に余計な変数を入れない）。

修正は `|| true` の握り潰しで解決しない（negative knowledge item `01KYA7C9NN4VDM7H2NYXZB2PSX` の型）。詳細は Step 1。

### gate 1 / gate 2 で足された制約

- **要求Aの鏡: 記録の失敗でブロックが解除されてはならない。** `deny()` は `exit 2` に到達して初めてブロックになる。到達前に死ぬと exit code が 1 や 127 になり、Claude Code と Codex では 0/2 以外が non-blocking なので、止めるべきコマンドが通る。要求Aの違反（余計に止まる）は騒がしいが、鏡側の違反（止まらない）は静かで取り返しがつかない。

### 実測で確定した事実（すべて一次証跡あり・推測ではない）

| 事実 | 台本 |
|---|---|
| `record \|\| :` は `set -u` 違反を封じ込めない。呼び出し元ごと rc=1 で死ぬ | `tmp/probe-errexit.sh` ケース4 |
| `( record ) \|\| :` は `set -u` 違反・`exit N`・書込失敗・command not found を封じ込める | `tmp/probe-errexit2.sh` |
| `\|\|` 左辺のサブシェル内では errexit が抑止され、失敗した後ろの行にも到達する | `tmp/probe-a1.sh` 前提1 |
| 隔離しない素の追記は親を殺す（隔離または `\|\|` によるテスト文脈が必須） | `tmp/probe-a1.sh` 前提2 |
| 壊れた lib / 存在しない lib の `source` も隔離で封じ込まれる | `tmp/probe-a1.sh` 前提3 |
| 1バイト追記は並行60プロセス×50回で 3000/3000 バイト。ロストなし。サイズ＝正確な件数 | `tmp/probe-a1.sh` 前提4 |
| `jq` 不在時、3本とも rc=127 で allow/deny を通らずに落ちる | `tmp/probe-bypass.sh` |
| `cc-lint.sh` は `&&` を含む非 commit コマンドで落ちない（`inherit_errexit` 既定 off のため）。**有効にすると4ケースで rc=1 になる** | `tmp/probe-inherit.sh` / `tmp/probe-310-fix.sh` |
| #310 の修正案は `inherit_errexit` off で旧版と判定が全16ケース一致し、on では 0/2 以外を返さない | `tmp/probe-310-fix.sh` |
| **今日は `grep` が PATH に無いと `cc-lint` が黙って全コマンドを allow する**（非0が「マッチ無し」に化ける）。#310 の修正で deny になる | `tmp/probe-310-fix.sh` |
| trap は正常系を壊さず、`jq` 不在・`set -u` 違反・想定外の exit をすべて rc=2 へ収束させる。収束時の stdout は妥当な JSON | `tmp/probe-trap.sh` / `tmp/probe-trap2.sh` |
| bash 3.2.57（macOS system）と 5.2.37（Homebrew）で封じ込めの挙動は同じ | 上記各台本 |
| Bash 呼び出しは1日あたり約 200〜670 回（Claude Code のみ・サンプリング上限ありの下限） | transcript 集計 |
| 3ツールの配備先は `~/.cursor/hooks/` `~/.claude/hooks/` `~/.codex/hooks/` の symlink。`sync_hook_scripts` が `*.sh` を全件配る | `scripts/sync/sync-*.sh` |
| `~/.claude/state/` は sync の対象外 | `scripts/sync/*.sh` に `state` の参照なし |

### 呼び出し形ごとの実測コスト

1回の起動あたりの記録呼び出しは、trap 採用で `inv` が落ちたので **出口の1回だけ**になった。1 Bash コマンドでは3本走るので3回分である。

| 形 | 1回 | 1 Bash コマンドあたり（3回分＝3本 × 出口のみ） |
|---|---|---|
| 素の `printf` 追記 | 0.176 ms | 0.5 ms |
| サブシェル + 毎回 `mkdir -p` | 2.189 ms | 6.6 ms |
| サブシェルのみ | 0.567 ms | 1.7 ms |
| 独立レコーダーを子プロセスで起動 | 7.450 ms | 22.4 ms |
| **採用形（成功時 fork ゼロ・失敗時だけ隔離）** | **0.186 ms** | **0.6 ms** |

現行のフック3本ぶんが約 35 ms なので、採用形の追加は約 +2%。trap 自体は正常系に I/O を1バイトも足さない（収束時にだけ動く）。

### 設計の骨子

**2つの機構を、担当する故障で分ける。混ぜない。**

| 機構 | 捕まえる故障 | 捕まえられない故障 |
|---|---|---|
| **trap（判定側）** | 走ったが途中で死んだ（`jq` 不在・malformed payload・想定外の exit） | そもそも走らなかった |
| **tally（記録側）** | そもそも走らなかった（silent skip・未登録・dangling symlink） | 走ったが死んだ（trap が deny へ収束させるので deny として現れる） |

**trap。** 想定外の終了を deny へ収束させる。今日 `jq` を PATH から外すと3本とも rc=127 で allow/deny を通らずに落ち、Claude Code と Codex では non-blocking なので**素通りする**。trap を張ると rc=2 になる（実測で確認）。収束した内部エラーは `deny.jsonl` に `rule: "internal-error"` と exit code つきで1件ずつ残る。

**tally。** 発火したことを1イベント1バイトの追記で残す。ファイルサイズが件数、mtime が最終発火時刻。スロットは `allow` と `deny` の2つ（`inv` は複式記入と一緒に落ちた）。1 Bash コマンドあたり 3フック × 1スロット = **3 バイト**なので、100万コマンドで約 **3 MB**（ツール1つあたり）。ローテーションは要らない。

**成立条件を限定する。** O_APPEND の原子性はローカルの通常ファイルでの実測である。NFS / FUSE / 同期ドライブ上、tally パスが symlink・FIFO・device に置き換わった場合、ENOSPC・quota・inode 枯渇では件数性が崩れる。`fsync` していないので、クラッシュ時は成功済みの書き込みも耐久しない。

**記録先**（ツール次元を持たせる。混ぜると「Cursor だけ死んでいる」を Claude の発火が緑に見せてしまう）:

```text
${HOOK_FIRING_DIR:-$HOME/.claude/state/hook-firing}/
├── tally/<tool>/<hook>.allow    # 通した
├── tally/<tool>/<hook>.deny     # 止めた（trap 収束ぶんを含む）
├── deny.jsonl                   # deny の詳細（稀なので1行 JSON・internal-error もここ）
└── diag.jsonl                   # 記録そのものが失敗したときの環境エラー
```

`inv` と `watermark.json` は gate 3 の trap 採用で不要になった（複式記入と一緒に落ちた）。「直近 N 日で発火したか」には `mtime` が直接答えるので、窓の増分を出すためのウォーターマークが要らない。

`<tool>` は **`$0`（ホストが使った呼び出しパス）** から `codex` / `cursor` / `claude` / `unknown` を判別する。`$0` は symlink の解決先ではなく呼び出しパスなので、`~/.codex/hooks/...` と `~/.cursor/hooks/...` を見分けられる（実測で確認）。環境変数（`CURSOR_PROJECT_DIR` / `CLAUDE_PROJECT_DIR`）による判別も考えたが、**Codex はどちらも立てないので Codex を識別できない**。Codex の silent skip はこの設計がいちばん恐れている故障型なので、それを名指しできない判別方法は採らない。

## Pre-Implementation

- [ ] READ: `projects/orchestration-engine/docs/episodes/2026-08-08-episode-309-hook-firing-record.md` — 設計が3度変わった経緯と、棄却した案の理由
- [ ] READ: `tmp/design-309-revised.md` — gate 2 に投げた設計（本プランの Context が上書きしている箇所に注意）
- [ ] READ: `canonical/hooks/scripts/oe-prompt-receipt.sh` — 環境エラーとデータ不在を分ける先例、`_json_escape` のバックスラッシュ処理順
- [ ] READ: `canonical/hooks/README.md` — exit code 意味論と fail-open リスクの節（更新対象でもある）
- [ ] READ: `projects/orchestration-engine/bin/oe-selfcheck` — 3値（`ok` / `broken` / `indeterminate`）と exit code の規約。読み出しはこれに合わせる
- [ ] READ: issue #310（`gh issue view 310`）— Step 1 で塞ぐ穴の分析と再現手順。受け入れ条件もここにある
- [ ] 実装前に `tmp/probe-*.sh` を1回ずつ流し、Context の実測表が今の環境でも再現することを確認する（環境が変われば前提が変わる）

## Step 0: 記録関数の雛形を単体で作り、失敗経路を先に固める（概算: 1h）

実装をフックへ入れる前に、記録関数だけを単体で検証する。fail-closed な面へ入れてから壊れると影響が日常作業全体に及ぶため、順序を逆にしない。

- [ ] `tmp/hfr-proto.sh` に記録関数の雛形を書く（まだ3本には入れない）
- [ ] 変数はスクリプト先頭で `${...:-}` 付きの代入に固定する。`set -u` 違反を hot path から構造的に排除する
- [ ] ツール判別は `case "$0"` で書く（builtin・fork なし・Codex も識別できる）。**`[ -n "${VAR:-}" ] && X="y"` の形にしない** — 条件が偽のとき `&&` リスト全体が非ゼロを返し、`set -e` が発動する
- [ ] hot path は builtin 1つ（`printf ... >> file`）に限る。`mkdir` と診断は失敗時の fallback へ寄せる
- [ ] fallback はサブシェルで隔離し、`set +e +u` を明示する（防御。`||` 左辺では errexit が抑止されることは実測済みだが、呼び出し文脈が変わった場合の保険）
- [ ] 診断は `diag.jsonl` と stderr の2経路に出す。**どちらも「正本」とは呼ばない** — `diag.jsonl` は tally と同じファイルシステムに在るので、記録先ごと書けない状況（親が書けない・ENOSPC・read-only mount）では一緒に失敗する。stderr もホストが保存する保証がない。**要求Bがいちばん要る場面でどちらも消えうる**ことを認めた上で、両方に出して生存確率を上げる
- [ ] **`2>/dev/null` で握り潰さない。** fast path の `2>/dev/null` はシェルの重複エラー文言を抑えるだけで、失敗自体は直後の `||` が捕まえて fallback が記録する。この区別をコメントに明記する

採用する形:

```bash
# 置き場。HOME が無いときは /tmp へ落とさない（world-writable な場所を
# 記録先にすると、先に FIFO を置かれてブロック経路を作られる。下記 [ -f ] ガード参照）
HFR_DIR="${HOOK_FIRING_DIR:-${HOME:-}/.claude/state/hook-firing}"

# ツール判別は $0 で行う。$0 は「ホストが使った呼び出しパス」であって symlink の
# 解決先ではない（実測で確認）。環境変数による推測と違い Codex も判別でき、fork も要らない。
case "$0" in
  *.codex/*)  HFR_TOOL="codex"  ;;
  *.cursor/*) HFR_TOOL="cursor" ;;
  *.claude/*) HFR_TOOL="claude" ;;
  *)          HFR_TOOL="unknown" ;;
esac

HFR_HOOK="block-destructive"          # 各スクリプトで固定リテラル
HFR_BASE="${HFR_DIR}/tally/${HFR_TOOL}/${HFR_HOOK}"

hfr() {
  local slot="${1:-}"
  # スロット名を白名簿で縛る。引数を忘れると `block-destructive.`（末尾ドット）へ
  # 静かに追記し続ける欠陥になるが、検出器が無い。builtin の case で無料で閉じる。
  case "$slot" in allow|deny) ;; *) return 0 ;; esac
  # 追記先が通常ファイルでない（FIFO・device・ディレクトリ）なら触らない。
  # FIFO への追記は open がブロックし、deny が exit 2 に到達しなくなる（実測で確認）。
  # HFR_DIR は環境から差し替えられるので、このガードが無いと fail-open のレバーになる。
  # `[ ... ] && [ ... ] && return 0` と書かないこと。条件が偽のとき && リストが
  # 非ゼロを返し、set -e が発動して記録がブロックに化ける（この plan の Step 0 の規約）。
  if [ -e "${HFR_BASE}.${slot}" ] && [ ! -f "${HFR_BASE}.${slot}" ]; then
    return 0
  fi
  # fast path: builtin 1つだけ。fork も exec もしない（実測 0.186 ms）。
  # 2>/dev/null は >> より前に置く。順序が逆だとリダイレクトの open 失敗メッセージが
  # stderr へ漏れる（実測）。これは握り潰しではない — 失敗は直後の || が捕まえ、
  # fallback が diag と意図的な stderr 1行を残す。抑えているのは事故の重複文言だけである。
  printf 'x' 2>/dev/null >> "${HFR_BASE}.${slot}" || {
    # slow path: 稀にしか通らない。サブシェルで隔離するので set -u 違反も exit も封じ込まれる。
    ( set +e +u
      mkdir -p "${HFR_DIR}/tally/${HFR_TOOL}" 2>/dev/null
      printf 'x' 2>/dev/null >> "${HFR_BASE}.${slot}" && exit 0
      printf '{"ts":"%s","hook":"%s","tool":"%s","kind":"env-error","reason":"tally-append-failed","slot":"%s"}\n' \
        "$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null)" "$HFR_HOOK" "$HFR_TOOL" "$slot" \
        2>/dev/null >> "${HFR_DIR}/diag.jsonl"
      printf 'hook-firing: tally-append-failed (%s)\n' "$slot" >&2
    ) >/dev/null || :
  }
  return 0                            # 呼び出しは素の `hfr allow`（テスト文脈でない）なので必ず 0 を返す
}
```

3つとも実測で確かめた必須事項である。

- **`return 0` は必須。** 呼び出しは `hfr allow` という素の単純コマンドで、テスト文脈ではない。関数が非ゼロを返すと `set -e` が発動し、記録の失敗がそのままブロックに化ける（trap 採用後は「ブロック」ではなく「内部エラーとして deny へ収束」になるが、記録の失敗を判定の失敗に化けさせてはいけない点は変わらない）。
- **`2>/dev/null` はリダイレクトより前に置く。** 後ろに置くと、追記先を開けなかったときシェルのエラー文言が stderr へ漏れる。フックの stderr はツールへ渡るので、記録先が無い間ずっと雑音が出続ける。
- **fallback のサブシェルは `>/dev/null` だけにして `2>&1` を付けない。** 付けると「記録できなかった」という**意図的な**1行まで消え、要求Bに反する。事故の文言は各コマンド側の `2>/dev/null` で個別に抑える。

- [ ] GATE 用の観点として、呼び出し側で変数を展開しないことを規約としてコメントに書く（`hfr "$SOME_VAR"` は展開が隔離の**外**で起きるので `set -u` に殺される。引数はリテラルのみ）
- [ ] **`a && b` の形で文を書かない。** 条件が偽のとき `&&` リスト全体が非ゼロを返し `set -e` が発動する。判定は `if / then` で書く（このプランの執筆中に1度この罠を踏んで直した）
- [ ] **`HOOK_FIRING_DIR` は新しい fail-open のレバーであることを自覚して扱う。** 環境から記録先を差し替えられるので、`${HOME:-/tmp}` のような world-writable へのフォールバックを作らない（先に FIFO を置かれると deny がブロックする）。`HOME` が空なら記録を諦める側に倒す
- [ ] 上記を実測で確かめる（`tmp/probe-hfr-v3.sh` が plan の本体をそのまま抜き出して検証する形になっている。写経ミスを防ぐためこの形を維持する）

**GATE: Step 0 記録関数の単体検証**（すべて `tmp/probe-hfr-v3.sh` で実測済み・実装時に再実行する）

- [ ] 正常時: `hfr allow` を呼んで tally が1バイト増える
- [ ] 記録先が書けない: `HOOK_FIRING_DIR` を存在しないパス配下や `chmod 0500` したディレクトリに向け、**呼び出し元が生き残る**ことを確認する
- [ ] **鏡: 同じ状態で `deny` 経路が rc=2 に到達する**ことを確認する
- [ ] `set -u` 違反（引数欠落）を意図的に起こしても呼び出し元が生き残り、末尾ドットのファイルが出来ないことを確認する
- [ ] 不正なスロット名で呼んでも何も作られないことを確認する
- [ ] **追記先を FIFO に置き換えても deny が rc=2 に到達する**ことを確認する（ガードが効いていないとここでブロックし、鏡が破れる）
- [ ] stdout が制御 JSON だけであることを確認する（記録が1バイトも混ざらない）
- [ ] 意図的な診断 stderr が**届く**ことを確認する（`( ... ) >/dev/null 2>&1` にすると消える）
- [ ] `$0` によるツール判別が codex / cursor / claude / unknown を正しく振り分けることを確認する
- [ ] `mkdir` が hot path に無いこと（正常時の実測が 0.2 ms 前後であること）

## Step 1: #310 の穴を先に塞ぐ（`cc-lint` の `inherit_errexit` 依存・概算: 1h）

**この順序でなければならない。** trap（Step 2）を先に入れると、この穴の影響範囲が Cursor 1本から3ツール全部へ広がる。**広がった穴を抱えた状態が一瞬も存在しないように、修正を先に置く**（owner の gate 3 追加判断）。

| ツール | 今日 | trap を先に入れた場合 |
|---|---|---|
| Cursor | `failClosed` で**ブロック** | 変わらず**ブロック** |
| Claude Code | 非0（2以外）は non-blocking で**素通り** | rc=2 に収束して**ブロック**（悪化） |
| Codex | 同じく**素通り** | **ブロック**（悪化） |

`PreToolUse` で実際にブロックするのは exit 2 だけで、1 を含む他の非0は non-blocking である（[公式ドキュメント](https://code.claude.com/docs/en/hooks)）。

**別コミット・別検証にする。** #310 は独立した修正なので、trap や tally と混ぜない。

### 何が壊れているか

`cc-lint.sh:27` の `segment="$(echo "$cmd" | grep -oE '...' | head -1 | sed '...')"` で、`grep` は非マッチのとき 1 を返す。`pipefail` があるのでパイプライン全体が 1 になり、代入が 1 を返す。今は `inherit_errexit` が既定 off でコマンド置換の中へ errexit が伝播しないため致命にならないが、有効にされた瞬間に `&&` を含むコマンドすべてでフックが非0終了する。

**他2本に同型は無い**（確認済み）。`block-destructive.sh` と `block-force-push.sh` のコマンド置換は `$(cat)` と `$(jq ...)` の単一コマンドで、パイプラインを含まない。

### 修正方針（`|| true` で握り潰さない）

**非マッチ（`grep` の 1）は正常なデータ不在**として扱い、**環境エラー（2 以上）とは分ける**。`|| true` で潰すと両者が同じ見え方になり、negative knowledge item `01KYA7C9NN4VDM7H2NYXZB2PSX` が名指ししている型そのものになる。

**パイプラインをやめる。** `head` の早期終了は `pipefail` 下で SIGPIPE 由来の非0を生みうるので（item `01KYA7C9M4EN1EZM3HBEN5WDRP`）、非マッチと環境エラーの区別を壊す。`grep` は here-string で1回だけ呼び、`head -1` と `sed` の役割は bash のパラメータ展開に置き換える（外部プロセスが2つ減るので、全 Bash 呼び出しで走るフックとしては速くもなる）。

**正規表現そのものは変えない。** マッチ意味論を変えると非回帰の証明が難しくなるため、`grep -oE` に渡すパターンは現行のまま据え置く。

```bash
extract_commit_segment() {
  local cmd="$1"
  if [[ "$cmd" == *"&&"* ]]; then
    local matches rc=0
    matches="$(grep -oE '(^|&&)[[:space:]]*git[[:space:]]+commit[^&]*' <<< "$cmd")" || rc=$?
    case "$rc" in
      0) ;;                 # マッチした
      1) matches="" ;;      # マッチ無し = 正常なデータ不在
      *) return "$rc" ;;    # 環境エラー。呼び出し側が deny に倒す
    esac
    if [[ -n "$matches" ]]; then
      local segment="${matches%%$'\n'*}"                    # head -1 相当
      local trimmed="${segment#"${segment%%[![:space:]]*}"}"
      if [[ "$trimmed" == "&&"* ]]; then                    # sed の条件付き除去に対応
        trimmed="${trimmed#&&}"
        segment="${trimmed#"${trimmed%%[![:space:]]*}"}"
      fi
      if [[ -n "$segment" ]]; then
        printf '%s\n' "$segment"
        return 0
      fi
    fi
  fi
  printf '%s\n' "$cmd"
}
```

呼び出し側は環境エラーを deny に倒す。**`deny` を関数の中で呼んではいけない** — `extract_commit_segment` はコマンド置換の中で走るので、そこで出した制御 JSON は本物の stdout に届かず置換の戻り値に化ける。呼び出し側で処理する。

```bash
  local commit_segment ecs_rc=0
  commit_segment="$(extract_commit_segment "$cmd")" || ecs_rc=$?
  if (( ecs_rc >= 2 )); then
    deny "cc-lint: could not parse the command (grep failed with ${ecs_rc}). Blocked conservatively."
  fi
```

**GATE: Step 1 非回帰の証明**（`tmp/probe-310-fix.sh` で実測済み・実装時に再実行する）

- [ ] **`inherit_errexit` off（今日の状態）で、旧版と新版の判定が全ケース一致する。** 16 ケースで rc の差分 0 件を確認済み
- [ ] **`inherit_errexit` on で、新版は 0 か 2 以外を返さない。** 旧版は4ケースで rc=1 を返す（`cd /tmp && ls` / `echo a && echo b` / `make build && make test` / `cd x && git -C . commit -m "bad"`）。新版は 0 件
- [ ] **両方の状態を実機で測った証跡を残す**（受け入れ条件が「有効・無効の両方を測る」ことを求めている）
- [ ] `|| true` による握り潰しをしていない（差分を目視で確認する）
- [ ] `shellcheck` が通る（新版で指摘なしを確認済み）
- [ ] 他2本に同型が無いことを確認した旨を記録する

### 副次的に閉じる穴（実測で見つけた・issue 本文に無い）

**今日は `grep` が PATH から消えると `cc-lint` が黙って全コマンドを allow する。** 実測では旧版が rc=0 を返した。パイプラインの非0が「マッチ無し」に化け、関数が `echo "$cmd"` にフォールスルーして、呼び出し側の正規表現に当たらず allow へ抜けるためである。**強制が静かに消える**型で、本 issue が潰そうとしているものと同種である。新版は rc=2（deny）になる。

- [ ] この挙動変化を PR 本文に書く（`grep` 不在時に allow → deny へ変わる）

## Step 2: 3本に trap を張り、想定外の終了を deny へ収束させる（概算: 1.5h）

**記録とは別のコミットにする**（owner の明示指示。作業単位と検証単位に余計な変数を入れない）。これは**強制の挙動を変える**変更なので、記録を足す変更と混ぜると、何が原因で挙動が変わったのかを切り分けられなくなる。

対象は `canonical/hooks/scripts/` の3本。判定ロジックそのものには触らない。

- [ ] `HFR_*` の代入の**後**に `trap` を張る。前に張ると、trap が発火したとき記録先の変数が未定義になり、記録が空パスへ飛ぶ（実測で確認）
- [ ] `trap` ハンドラの中で最初に `trap - EXIT` して**再入を止める**
- [ ] `0` と `2` は**そのまま通す**。EXIT trap は正常終了でも発火するので、ここを忘れると allow が deny に化ける
- [ ] ハンドラの先頭で `set +e +u` する。収束処理の途中で死んだら元も子もない
- [ ] **収束先の deny は `jq` に頼らず素の `printf` で組む。** `jq` 不在こそ trap が捕まえたい死因なので、収束先が `jq` を要求してはならない。メッセージは固定リテラル + exit code（数値）だけにして、JSON escape の問題を作らない
- [ ] 収束した内部エラーを `deny.jsonl` に `rule: "internal-error"` と exit code つきで残す
- [ ] `jq` 不在は trap 任せにせず、**入口で明示的に検査して deny に倒す**（trap は backstop）。そのほうが利用者に出るメッセージが具体的になる

採用する形（実測済み・`tmp/probe-trap.sh` / `tmp/probe-trap2.sh`）:

```bash
# jq に頼らない deny の出力。trap の収束先はこれを使う。
emit_deny() {
  local msg="$1"
  if [[ -n "${CURSOR_PROJECT_DIR:-}" || -n "${CLAUDE_PROJECT_DIR:-}" ]]; then
    printf '{"permission":"deny","user_message":"%s"}\n' "$msg"
  else
    printf '%s\n' "$msg" >&2
  fi
}

# 想定外の終了（0/2 以外）を deny へ収束させる。HFR_* の代入より後に張ること。
on_unexpected_exit() {
  local ec=$?
  trap - EXIT                        # 再入を止める
  case "$ec" in 0|2) exit "$ec" ;; esac   # 正常な終了はそのまま通す
  set +e +u                          # ここから先は何があっても止まらない
  emit_deny "hook internal error (exit ${ec}); blocked conservatively"
  hfr deny
  ( set +e +u
    printf '{"ts":"%s","hook":"%s","tool":"%s","rule":"internal-error","exit":%s}\n' \
      "$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null)" "$HFR_HOOK" "$HFR_TOOL" "$ec" \
      2>/dev/null >> "${HFR_DIR}/deny.jsonl"
  ) >/dev/null || :
  exit 2
}
trap on_unexpected_exit EXIT
```

**GATE: Step 2 trap の収束**（実測済み・実装時に再実行する）

- [ ] 正常系が壊れていない: allow → rc=0 / deny → rc=2（trap が邪魔していない）
- [ ] 内部エラー（`false`）→ rc=2 に収束する
- [ ] `set -u` 違反 → rc=2 に収束する
- [ ] 想定外の exit code（`exit 9`）→ rc=2 に収束する
- [ ] **`jq` を PATH から外す → rc=2 になる**（今日は rc=127 で、Claude Code と Codex では素通りしている）
- [ ] 収束時の **stdout が妥当な JSON** であることを確認する（ホストがパースできる形。`jq .` に通す）
- [ ] 記録先も同時に壊れている最悪ケースでも再入せず rc=2 で終わる
- [ ] `deny.jsonl` に `rule: "internal-error"` の行が exit code つきで残る

**GATE: Step 2 挙動変化の申告（重要）**

- [ ] この変更で**今日は素通りしているものが止まるようになる**。何が止まるようになったかを PR 本文に列挙する（`jq` 不在・malformed payload・想定外の exit）
- [ ] `deny()` の `jq -n` が失敗すると `exit 2` に届かない既存の穴が、この変更で閉じることを確認して書く

## Step 3: 3本へ発火記録（tally）を差し込む（概算: 1.5h）

**Step 2 とは別のコミットにする。**

対象は `canonical/hooks/scripts/` の `block-destructive.sh` / `block-force-push.sh` / `cc-lint.sh`。判定ロジックには一切触らない。

**DJ-4 は内蔵（3本それぞれに書く）で確定した。** 共通ライブラリ案は gate 1 で一度復活させたが、gate 2 で復活の根拠そのものが崩れた。`( . lib.sh ) || :` は失敗を封じ込めるが、**サブシェルの中で定義した関数は親に残らない**（実測）。つまり「隔離の中で source する」形では `hfr` を定義できない。素の `. lib.sh || :` にすると、lib が無いときに `hfr` が未定義のまま最初の呼び出しに達して command not found で死ぬ（trap 採用後はそれが internal-error の deny に化ける＝全ツールでブロックされる）。生き延びさせるには lib + ガード + stub を結局3本に書くことになり、「1箇所 vs 三重化」の比較が成り立たない。さらに `source` は最初の `hfr` 呼び出しより前に起きるので、**source の失敗は台帳に現れず「配線されていない」と区別できない**。gate 2 の2レーンとも内蔵を推した。

- [ ] 三重化の drift は規律でなく**機械的なテスト**で閉じる。2つの目印コメントの間を3本から抜き出し、byte 一致することを確かめるテストを1本置く（「3か所のうち1か所を直し忘れる」を潜在的欠陥から落ちるテストへ変える）

- [ ] 各スクリプトの先頭（`set -euo pipefail` の直後）に `HFR_*` の代入と `hfr()` を置く
- [ ] `allow()` の中、制御 JSON を出した**後**・`exit 0` の**直前**に `hfr allow` を置く
- [ ] `deny()` の中、制御 JSON を出した**後**・`exit 2` の**直前**に `hfr deny` を置く
- [ ] `deny()` にはさらに詳細行を1行足す（deny は稀なので `date` の exec を許す）。隔離サブシェルで書く

制御出力の**後**に置くのが意味の上で重要である。そうすると記録の意味が「判定が実際に配送された」になる。前に置くと、記録があるのに配送されていない状態と区別がつかない。

`deny.jsonl` の1行（機微情報を素で残さない）:

```json
{"ts":"2026-08-08T12:00:00Z","hook":"block-destructive","tool":"claude","rule":"sql-drop","argv0":"echo","cmd_len":34}
```

- [ ] コマンドの生文字列全体は残さない。`rule`（発火した規則の識別子）と `argv0`（先頭トークン）と `cmd_len` だけにする
- [ ] 各 `deny` 呼び出し位置に `rule` の識別子を渡せるよう、既存の `deny "..."` 呼び出しへ規則名を追加する。**`deny` の第1引数（利用者向けメッセージ）の意味は変えない**（第2引数として足す）
- [ ] `cc-lint.sh` の deny はコミットメッセージを扱うので、メッセージ本文を `deny.jsonl` に入れないことを特に確認する

**GATE: Step 3 判定挙動の非回帰**

- [ ] `tmp/probe-hooks.sh` と `tmp/probe-bypass.sh` を流し、変更前と同じ allow / deny 判定になることを確認する
- [ ] `bash -n` で3本の構文を確認する
- [ ] `shellcheck canonical/hooks/scripts/block-destructive.sh canonical/hooks/scripts/block-force-push.sh canonical/hooks/scripts/cc-lint.sh` が通る

**GATE: Step 3 要求Aとその鏡**

- [ ] 記録先を書けない状態にして、`allow` 側でコマンドが**通る**ことを確認する（要求A）
- [ ] 記録先を書けない状態にして、`deny` 側が**なお rc=2 を返す**ことを確認する（要求Aの鏡。ここが破れると止めるべきコマンドが通る）
- [ ] 記録が1回成功したことを合格条件にしない。**失敗経路を実機で作った結果**を合格条件にする

## Step 4: 読み出しを作る（概算: 2h）

「直近 N 日で発火したか」に答えられる最小手段。`oe-selfcheck` の3値規約に合わせる。

- [ ] 3値を返す: `ok`（前提は成り立っている）/ `broken`（前提が崩れている）/ `indeterminate`（検査自体が成立しなかった）
- [ ] exit code: `broken` が1つでもあれば 1 / `broken` は無いが `indeterminate` が在れば 2 / 全部 `ok` なら 0。**`indeterminate` を exit 0 にしない**
- [ ] **窓の判定は `mtime` で行う。** trap 採用で複式記入が落ちたので、増分を出すためのウォーターマークは要らない。「直近 N 日で発火したか」には各 tally の `mtime` が直接答える
- [ ] **累計で `ok` を出さない。** 「これまでに1件でもあれば ok」にすると、停止した後も永久に緑を返す（既知の失敗型）。判定は必ず `mtime` が窓の中にあるかで行う
- [ ] ツール × フックごとに分けて報告する。合計に畳むと「3本のうち1本だけ落ちた」「Cursor だけ落ちた」が消える
- [ ] **`unknown` ツールの件数を必ず表に出す**（owner の裁定条件）。`$0` によるツール判別は、ホストが解決済みの絶対パスで起動する形に変われば静かに `unknown` へ落ちる。**静かに消えるのが本 issue の敵**なので、`unknown` が増えていること自体が読み出しに見えれば変化に気づける
- [ ] 在庫が全く無い（tally が1つも無い）状態を `ok` にしない。`indeterminate` にする
- [ ] **`deny.jsonl` の `rule: "internal-error"` の件数を窓で出す。** trap が収束させた内部エラーの発生率であり、複式記入が累計差で見ようとしていたものを、1件ずつ時刻つきで置き換える
- [ ] 同じ窓の `diag.jsonl`（記録そのものの失敗）を併読して報告する。記録が失敗している間の tally は過小になっているので、`ok` の根拠に使えない
- [ ] サイズ取得は `wc -c < f` を使う。`stat -f %z`（BSD）と `stat -c %s`（GNU）は非互換で、分岐が要る
- [ ] **3本の `allow` はほぼ同じ値になるはず**なので、相互検算に使う。設定を読まずに「3本のうち1本だけ設定から落ちた」を局在化できる。ただし正当なズレの幅は未測定（下記 test plan で1回測る）
- [ ] サイズが後退している場合は `indeterminate`（truncate・バックアップ復元が起きたので連続性が切れている）

置き場（gate 3 で確定）:

- [ ] **`projects/orchestration-engine/bin/` の read-only verb として置く**（`oe-selfcheck` の隣・同じ3値契約）。brief が `canonical/hooks/scripts/` を指定していたのは統括の誤りで、gate 3 で訂正された。あそこへ置くと sync が3ツールの hooks ディレクトリへ symlink し、hook でないものが hook の場所に並ぶ
- [ ] 名前は `oe-hookfire` を提案する（`oe-*` の既存命名に合わせる）。異論があれば owner が決める
- [ ] `~/bin` への配布が要るかは #301（読み手の配線）と一緒に決まるので、本単位では engine bin に置くまでとする

## Step 5: 陽性対照の手順を文書化する（概算: 1h）

「記録が0件」を「発火しなかった」と読むための条件を、記録の設計と同じ場所に書く。

陽性対照は**2段**で書く。1段目だけで済ませない。

- [ ] **1段目（配備物を直接叩く・弱い）**: `~/.cursor/hooks/` / `~/.claude/hooks/` / `~/.codex/hooks/` の**3配備パスすべて**へ payload を流す。repo のコピーを叩く検査より強い（dangling symlink と sync 漏れを検出できる）が、**これで確かめられるのはファイル／symlink とスクリプトの動作までである**
- [ ] **1段目が確かめられないものを明記する**（gate 2 の指摘。ここを曖昧にすると「緑なのに死んでいる」を作る）: `~/.claude/settings.json` への登録、Cursor の `hooks.json`、Codex の `hooks.json`、matcher、フックの順序と short-circuit、dispatcher が実際にフックを起動すること、Codex の workspace trust。**「settings.json からの脱落も検出できる」とは書かない**
- [ ] **2段目（ツール自身にシェルを撃たせる・強い）**: 各ツールのセッションから実際に対照コマンドを実行し、前後の tally 差と操作結果の両方を検査する。dispatcher を通る唯一の形なので、これが本来の陽性対照である
- [ ] Codex の trust は **workspace 単位**なので、ある trusted workspace で成功しても別 workspace の silent skip を否定できない。この限界を書く
- [ ] 無害な対照コマンドを3本ぶん文書化する（実スクリプトへ通して deny することを確認済み）

| フック | 対照コマンド | フックが死んでいた場合 |
|---|---|---|
| `block-destructive.sh` | SQL の `DROP TABLE` 文を含む `echo` | `echo` が文字列を表示するだけ |
| `block-force-push.sh` | `git push --force` に存在しない remote 名 | git が未知の remote でエラー終了する |
| `cc-lint.sh` | 使い捨て repo で非 CC 形式のメッセージで `git commit` | 使い捨て repo なので実害なし |

- [ ] **対照コマンドを検査スクリプトの外側のコマンド行に置かない。** 生きているフックが検査コマンド自体をブロックする（実測済み）。payload はファイルの中で組み立てる
- [ ] `allow` の流量だけを陽性対照にしない理由を書く。allow が0件なのは「フックが死んでいる」だけでなく「エージェントが Bash を使っていない（idle）」でも起きる。Codex は trust されていない hook を警告ゼロで黙って skip するのでこれも0件になる。区別できるのは意図的に撃つプローブだけである
- [ ] 記録の置き場が**当事者の書ける場所**であることを明記する。「改変不能」と書かない

## Step 6: README を更新する（概算: 30m）

- [ ] フック一覧・カバレッジ表に発火記録を反映する
- [ ] 記録の置き場・形式・保持方針の節を足す
- [ ] 陽性対照の手順（Step 5）を置く
- [ ] **trap による挙動変更を明記する。** 想定外の終了（`jq` 不在・malformed payload・想定外の exit）が deny へ収束するようになったこと、そのため**今日は Claude Code と Codex で素通りしていたものが止まる**ことを、利用者が読む場所に書く。`jq` が前提条件であることは README の「前提条件」節に既にあるが、**満たさないとどうなるかが変わった**ので更新する
- [ ] **#310 による挙動変更も明記する。** `grep` が PATH に無いとき、今日は `cc-lint` が黙って全コマンドを allow するが、修正後は deny になる。`jq` と同じく `grep` も前提条件であることを書く
- [ ] 「fail-open リスク」の節に、要求Aの鏡（記録の失敗でブロックが解除されない）と、ハングでは満たせないこと（下記「残るリスク」）を足す
- [ ] **`diag.jsonl` を「正本」と書かない。** tally と同じファイルシステムに在るので、ENOSPC や mount 停止では一緒に失敗する。best-effort な診断である。stderr もホストが保存する保証が無いので第三の正本にはならない
- [ ] 保持方針を明記する
  - tally: **truncate しない。** 当面は伸ばし続ける（1ツール・100万コマンドで約 3MB）。読み出しがサイズ後退を検出したら `indeterminate` を返す
  - `deny.jsonl` / `diag.jsonl`: 日付分割。`deny` より `diag` を長めに保つ
  - ローテーションは **`copytruncate` を使わない**（追記中のファイルを切ると件数が壊れる）。rename して次回追記で新規作成させる
  - 保守処理はフックの中に入れない。読み出し／保守の側に置く（hot path に失敗要因を足さない）

**REVIEW: gate 4 実装SO** — 実装後、3レーン（`so.impl=weak` / lanes=3）で反証にかける。観点は設計SO と別（実装の正しさ・見落とし・回帰）

**GATE: 3ツールへの影響確認**

- [ ] Claude Code で**実機確認**する。`.claude/settings.local.json` にプロジェクト単位で worktree 版のフックを追加登録し、実際の Bash コマンドが hook 経路を通って tally が増えることを確認する（README にあるとおり、手動 hooks は `settings.local.json` に書く）
- [ ] **`./scripts/sync.sh` を worktree から実行しない。** 実行すると `~/.claude` などの symlink が worktree 側へ張り替わり、worktree 削除で dangling になってフックが無言で止まる。配布は owner がマージ後にメイン worktree で行う
- [ ] Cursor と Codex については配布経路（`sync_hook_scripts` が `*.sh` を全件 symlink する）と `failClosed` の扱いを文書で確認し、実機確認できない旨を明記する
- [ ] Codex の trust ゲートに触れる。trust されていない hook は警告ゼロで skip されるため、配布後に trust の再確認が要る可能性がある

**STOP: 実装完了 — owner へ報告し、マージ・sync の指示を待つ**

## 最終検証（受け入れ基準との対応）

- [ ] 3本が **allow と deny の両方**で記録を残す（`tally/<tool>/<hook>.allow` と `.deny` が両方増える）
- [ ] **失敗経路を実機で作って、操作がブロックされないことを確認した。** 記録先を書けない状態を実際に作り、その状態でコマンドが通ることを示した。記録が1回成功したことを合格条件にしていない
- [ ] **#310 が閉じている**（`inherit_errexit` on でも `&&` を含むコマンドでフックが非0終了しない・on と off の両方を実機で測った証跡がある・`|| true` で握り潰していない）
- [ ] **#310 の修正で判定が変わっていない**（`inherit_errexit` off で旧版と新版の判定が全ケース一致）
- [ ] **trap が想定外の終了を deny へ収束させる**（`jq` を PATH から外して rc=2 になり、stdout が妥当な JSON であること）
- [ ] **trap が正常系を壊していない**（allow は rc=0 のまま・deny は rc=2 のまま）
- [ ] **コミット順が「#310 → trap → tally」になっている**（広がった穴を抱えた状態が一瞬も存在しない・3つとも別コミット別検証・owner の明示指示）
- [ ] **欠測と非発火を区別する手順が文書に在る**（陽性対照の取り方を含む・3配備パス）
- [ ] 記録に機微情報を無条件に含めていない（コマンドの生文字列全体を素で残していない）
- [ ] **ローテーションの方針が決まっている**（tally は不要・`deny.jsonl` / `diag.jsonl` は日付分割・`copytruncate` 禁止）
- [ ] **読み出しが `unknown` ツールの件数を表に出す**（gate 3 の裁定条件。`$0` 判別が静かに壊れたことに気づけるようにする）
- [ ] `shellcheck` が3本 + 読み出しスクリプトで通る
- [ ] **3ツールへの影響を確認した**（Claude で実機・Cursor / Codex は配布経路と `failClosed` の扱いに言及）
- [ ] `./scripts/sync.sh` を worktree から実行していない
- [ ] **成立条件の但し書きを書いた。** この台帳の値打ちは「読み手が実際に走ること」に条件付けられており、定期実行の配線は #301 で未着手である。先例（`oe-prompt-receipt.sh` のヘッダ）が同じ未達条件を明記しているのと同じ形で、成果物にも書く。**書かないと「読まれない台帳を作って Sensor が埋まったことにする」という、この issue が潰そうとしている型の失敗を自分で作る**
- [ ] **ホストの意味論を1回実測した**（下記 test plan）

## test plan に入れる実測（証拠として残っていないので1回測る）

- [ ] **3本が deny の後に短絡されるか、逐次か並行か。** 1本が deny を返したとき残り2本が呼ばれるかどうかで、3本の `allow` を相互検算するときに許される正当なズレの幅が決まる。Claude Code と Cursor で違いうる。**trap 採用で内部エラーも deny になるため、短絡があるならこの影響も受ける**
- [ ] **Claude Code が PreToolUse の stdout で未知キーの JSON を受け取ったときの扱い。** 記録が stdout を汚した場合の危険が Cursor 限定なのか、プロトコル全体なのかが決まる
- [ ] **`deny` の全文が Codex の transcript に残るか。** Cursor / Claude では `user_message` として残るので `deny.jsonl` に全文を持たなくてよいと判断したが、Codex は `else` 枝に落ちて stderr へ書くので、この判断の前提が Codex では成り立たない可能性がある

## 残るリスク（消えないので明記する）

### ハングは封じ込められない（両レーンが一致して指摘した最大の限界）

`( ... ) || :` が捨てるのは**終了した子の exit code** であって、子が終わらなければ親も進まない。`deny()` の中で記録がハングすると `exit 2` に到達せず、Claude と Codex では non-blocking になって**止めるべきコマンドが通る**（鏡の違反）。Cursor では逆に `failClosed` によって**通すべきコマンドまで止まる**（要求Aの違反）。同じ機構が両側を壊す。

ハングしうる箇所は、停止したネットワーク FS（hard mount の NFS / SMB・固まった FUSE 層）上の追記と、ディスク I/O が戻らない場合である。

**FIFO 経路は塞いだ。** 追記先が通常ファイルでないとき触らない builtin ガードを入れ、記録先に FIFO を置いた状態でも `deny` が rc=2 に到達することを実測で確認した。これは `HOOK_FIRING_DIR` という差し替え可能な指定を新設したことで**この単位が自分で作った** fail-open 面だったので、同じ単位の中で閉じた。`${HOME:-/tmp}` のような world-writable へのフォールバックも作らない（`HOME` が空なら記録を諦める）。TOCTOU は残るが、うっかり型と「先に置いておく」型は消えている。

**gate 3 で owner が「deny 優先で残存リスクを受け入れる」と裁定した。** 上限時間つき記録は `timeout` の exec を hot path に増やすので、守ろうとしたものを自分で汚す、というのが理由である。

**trap 採用でハング面が増えていないかを再評価した。結論は「減っている」。**

- 複式記入が落ちたことで、**1回の起動あたりの記録呼び出しが2回（`inv` + 出口）から1回（出口のみ）へ減った。** ハングしうる追記の回数がそのまま半分になる。
- trap のハンドラが増やす I/O は、収束時（＝すでに異常が起きているとき）の `hfr deny` と `deny.jsonl` の1行だけで、**正常系の hot path には1バイトも足していない**。
- 収束先の deny は `jq` に頼らない素の `printf` で組むので、外部コマンドを1つも増やしていない。
- FIFO 経路は `[ -f ]` ガードで塞いだ（実測で確認）。

**任意の I/O ハングまで含めて「操作結果を変えない」と「同期的に必ず記録する」を同時には保証できない。** これは緩和ではなく、設計上の選択が要る点である。本プランは次の立場を採る。

> **deny 優先。** 記録経路は hot path をローカル FS の単一 builtin 追記だけに限り、`mkdir` も `date` も外部コマンドも hot path に置かない（ハングしうる面を最小化する）。それでも残るハングについては、記録より判定の配送を優先する立場を明文化し、残存リスクとして受け入れる。

受け入れられない場合の方向は2つあり、どちらも本単位のスコープを超える（owner 判断）。

- 記録処理に明示の上限時間を設け、超過したら記録を捨てて deny を優先する。
- 記録を blocking hook のプロセス外へ移し、非同期・非ブロッキングにする（各ツールの dispatcher 側で記録する案。同期 I/O と deny の循環依存を根から外す唯一の方向だが、本単位の最小増分としては重い）。

### その他

- **記録は当事者が書ける場所にある。** 改ざん耐性はスコープ外なので、これは前提として明記する側に倒す。
- **trap は「走らなかった」を捕まえられない。** trap が張れるのは走ったプロセスの中だけである。Codex の silent skip・trust されていない・登録されていない・dangling symlink は、trap から見えない。そこは tally と陽性対照が担う（だから trap を採っても tally は落とさない）。
- **tally はシグナル kill とホスト側 timeout の下では出口記録を落とす。** trap も EXIT では拾えない（SIGKILL）。この経路は記録に現れない。
- **O_APPEND の原子性はローカルの通常ファイルで実測した範囲の主張である。** ネットワークマウントされた `$HOME`、FUSE、同期ドライブでは崩れうる。`fsync` していないのでクラッシュ時の耐久性も保証しない。
- **1段目の陽性対照は dispatcher を通らない。** 登録・matcher・trust の脱落は2段目（ツール自身にシェルを撃たせる）でしか検出できない。

## スコープ外（実装しない）

- 定期実行の配線（#301）
- どのゲートを強制側に置くかの設計（#305）
- 31イベント全部への拡張（まず止める側の3本）
- 記録の改ざん耐性を暗号的に保証すること
- `notify` / `session-name` / `oe-prompt-receipt` / `commit-gate` / `hypothesis-gate` への拡張

## surface していた既存の穴 — いずれも本単位で閉じる

### `cc-lint.sh` の `inherit_errexit` 依存 → **本単位に入った**（gate 3 追加判断・#310）

前版では「別 issue にして本単位では触らない」としていたが、**gate 3 で owner が本単位に含めると判断した**。理由は、trap を入れるとこの穴の影響範囲が Cursor 1本から3ツール全部へ広がるためで、私が統括の見立てを訂正した内容がそのまま採用の根拠になった。**Step 1** として、trap より前に置く。

残る surface はここには無い（下記の `jq -n` の件も Step 2 で閉じる）。

### `deny()` の `jq -n` 失敗で `exit 2` に届かない — 本単位で閉じる

これは trap 採用の対象そのものなので、Step 2 で閉じる。`jq -n` が失敗しても trap が拾って `exit 2` へ収束させる（収束先の deny は `jq` を使わない素の `printf` で組むため、`jq` が壊れていても出せる）。**閉じたことを Step 2 の GATE で確認する。**

## gate 3 の裁定（2026-08-09・owner 判断・すべて反映済み）

前版で owner へ上げた6件は、すべて裁定が下りた。ここに記録して未決を残さない。

| # | 論点 | 裁定 | 反映先 |
|---|---|---|---|
| 1 | trap 案（死を数えるのをやめ、死を消す） | **採る。** `jq` は環境に入っており、パッケージ化するなら必須にすればよいので「`jq` 不在で日常が止まる」引き換えは成立しない | Step 2 を新設。複式記入を落とし Step 3 を縮小 |
| 2 | ハングの残存リスク | **受容してよい。** 上限時間つき記録は `timeout` の exec を hot path に増やし、守ろうとしたものを自分で汚す | 「残るリスク」に再評価を追記（trap で記録呼び出しが半減し、面は**減っている**） |
| 3 | 読み手が未配線（#301）のまま | **但し書きで足りる。** `oe-prompt-receipt.sh` と同じく条件付きの主張であることをヘッダに書く | 「最終検証」に但し書き項目。#301 への申し送りを新設 |
| 4 | 読み出しの置き場 | **`projects/orchestration-engine/bin/` の read-only verb。** brief の `canonical/hooks/scripts/` 指定は統括の誤りで訂正 | Step 4 の置き場を確定 |
| 5 | ツール識別を `$0` に頼る | **よい。ただし `unknown` に落ちたことが読み出しで見えること** が条件 | Step 4 に `unknown` 件数の表示を必須項目として追加 |
| 6 | `deny.jsonl` にハッシュ | **v1 では入れない**（`shasum` の exec を deny 経路に増やさない） | 変更なし |
| 7 | 記録の置き場の名前 | **`~/.claude/state/hook-firing/` でよい。** 既存の読み出し規約に合わせる利益が勝つ | 変更なし |
| 8 | `cc-lint` の `inherit_errexit` 依存（追加判断） | **本単位で先に塞ぐ（#310）。** trap で影響範囲が3ツールへ広がるため。コミット順は「#310 → trap → tally」 | Step 1 を新設。surface から実装対象へ移動 |

**変わらない制約として再確認されたもの**: 「記録の失敗で操作をブロックしない」「別ファイルにする」「allow も deny も記録する」の3件は不変。trap を採っても発火したことの記録は要る。

## #301（定期実行の配線）への申し送り

本単位では読み手を配線しない。ただし #301 で使える材料を1つ残す。

**statusline の拍動 producer が既に10秒間隔で配線されて動いている**（`~/.claude/statusline/statusline-oe-heartbeat.sh`）。「新しく cron を組む」より「既に走っている読み手に相乗りする」ほうが、配線という未達条件を早く埋められる可能性がある。本単位では実装しないが、#301 の選択肢としてここに置く。

あわせて、本単位の成果物が抱える条件付きの性質も申し送る。**この台帳の値打ちは読み手が実際に走ることに条件付けられている。** 読み手が走らないうちは「記録は溜まっているが誰も見ていない」状態であり、それは Sensor が埋まったこととは違う。
