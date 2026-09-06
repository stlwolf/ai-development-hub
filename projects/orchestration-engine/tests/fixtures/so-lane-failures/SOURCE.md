# so-lane-failures — fixture の出所

`oe-lane-explain`（#303 の I-1）の回帰テスト用。**すべて当リポの実際の SO 出力から取った。**

`tmp/` は gitignore 対象で消えるので、判定に要る部分だけを切り出して置いてある。切り出したのは meta と、stdout / stderr である。**プロンプト本文は入れていない。**

| fixture | 出所（`tmp/` 配下・消える） | 日付 | 再現するもの | 生成した版の目印 |
|---|---|---|---|---|
| `codex-usage-limit` | `so-359-design/`（attempt2） | 2026-09-05 | 使用量上限。exit 1・4秒・stderr に文言 | `limit-recorded` |
| `codex-timeout-busy` | `so-359-design/`（attempt1） | 2026-09-05 | 時間切れ。stderr が育つ型 | `limit-recorded` |
| `codex-invalid-utf8` | `so-288-gate2-r2/` | 2026-08-04 | 不正な UTF-8。exit 2・0秒 | `limit-not-recorded` |
| `codex-untrusted-dir` | `so-20260616-173340/` | 2026-06-16 | 環境エラー。信頼済みディレクトリでない | `limit-not-recorded` |
| `codex-echoed-phrase` | `so-288-h3/`（attempt1） | 2026-08-04 | **陰性対照。** 故障の文言が散文の中にエコーされているだけ | `limit-not-recorded` |
| `claude-session-limit-legacy` | `so-293-y4/` | 2026-08-02 | 上限。**旧 text 経路**なので `claude-raw.json` が**不在** | `claude-raw-absent` |
| `claude-timeout-silent` | `so-e5-impl/` | 2026-08-03 | 無言の空返し。`raw.json` は**空で実在** | `claude-raw-present` |
| `claude-api-error` | `so-20260820-pure-so/` | 2026-08-20 | 通信断 | `claude-raw-absent` |
| `claude-not-permitted` | `so-20260616-172236/` | 2026-06-16 | 環境エラー。claude-safe が書けない | `claude-raw-absent` |
| `cursor-timeout-silent` | `so-295-impl/` | 2026-08-02 | 無言の空返し。手がかりゼロ | `limit-not-recorded` |
| `success-quoting-limit-phrase` | **構成した** | — | **陰性対照。** exit 0 で回答が上限の文言を引用している | — |

## 構成したものは1件だけである

`success-quoting-limit-phrase` だけは実物が無いので作った。**回答が故障の文言を引用したときに誤検出しないこと**を固定するためで、この形の実物は当リポの履歴に無い。他の10件は実物からの切り出しである。

**cursor の認証切れは fixture にしていない。** 当リポに実物が無く（#303 のコメントの観測は別リポ）、作文した fixture を実物の表に混ぜないためである。シグネチャ表には載せてあるが未検証である。

## 2つの陰性対照が守っているもの

- `codex-echoed-phrase`: **exit は 124（非ゼロ）で、故障の文言はファイルに実在する。** それでも `unknown` になる。文言が行の途中（散文の引用）にあるためで、**行頭の錨が効いていることを直接示す。** 錨を外すとこの fixture は `invalid_input` に化ける。
- `success-quoting-limit-phrase`: exit 0 なのでシグネチャを当てない、という手前の規則を守る。

## 「不在」と「空」の弁別

`claude-session-limit-legacy` には `claude-raw.json` が**存在しない**。`claude-timeout-silent` には**空で存在する**。この2件を並べて置いてあるのは、走査が両者を畳まないことを固定するためである（`knowledge/items/01M1VX9MH72K7G940R6WC7M218.md`）。
