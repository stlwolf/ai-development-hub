---
name: so-compare
description: so-compare.shでセカンドオピニオン（Codex/Claude/Cursor）を取得し、結果を比較する。ピアレビュー、修正方針の検証、設計判断の反証に使用する。**弱 SO**（1周可・partial=disclose・0はなし）。プロンプト設計原則、結果読み込み手順、合意判定基準を含む。
depends:
  - cli: so-compare
---

# SO Compare — セカンドオピニオン比較

> **SO モード: 弱 SO**（強/弱の定義は `canonical/orchestration-spec/document-format.md` の「SO モード」節〔§4.1〕）。**1 周で終了可**（iteration は推奨だが任意）。**終了条件**: partial（**実返却が 1 レーン以上**）=**disclose して進む**（advisory）／**"0"（全レーン実返却なし）=SO 未実施扱いで再試行/escalate＝最低 1 レーン実返却必須（"0 はなし"）**。※`success_empty`〔exit0 だが空〕は機構上 partial（exit1）計上だが、**全レーンがこれ＝実返却ゼロなら "0" 扱い**（consumer 判定・`so-compare.sh` は success_empty を PARTIAL 集計）。機構: `SO_TIMEOUT`（既定 240・codex / cursor）と `SO_CLAUDE_TIMEOUT`（既定 1200・claude）が**初回試行の基準**・`timeout_empty` 時のみ **そのレーンの基準の** `×1.5` に延長して**1回リトライ**（なお空なら "0" 扱い）。**claude だけ既定が長い理由は「レーンごとの所要時間」節を見よ**。レーン数/モデルは mode と直交（都度指定・既定ポリシーは `orchestration-toolkit`）。全レーン合意まで詰める **強 SO** が要る局面は `peer-ai-review`。

## スクリプトの場所

```
so-compare   (~/bin/ にシンボリックリンク。本体: scripts/so-compare.sh)
```

## 呼び出し方法

Shell ツールで実行する:

```bash
so-compare [OPTIONS] "プロンプト"
```

### オプション一覧

| オプション | 説明 | デフォルト |
|-----------|------|-----------|
| `-w PATH` | ワークスペースパス（推奨）。Codex/Claude にパス参照で渡す | なし |
| `-f FILE` | プロンプトをファイルから読み込み | - |
| `-c FILE...` | コンテキストファイル添付（**非推奨**。`-w` を使うこと） | - |
| `-o DIR` | 出力ディレクトリ指定 | `tmp/so-YYYYMMDD-HHMMSS` |
| `-s MODE` | Codex sandbox モード | `read-only` |
| `--with LIST` | 実行プロバイダを明示指定（`codex,claude,cursor` のカンマ区切り）。`--codex-only` / `--claude-only` / `--cursor-only` / `--cursor` と併用不可 | なし（未指定時は codex+claude） |
| `--codex-only` | Codex のみ実行 | 両方実行 |
| `--claude-only` | Claude のみ実行 | 両方実行 |
| `--cursor` | Cursor CLI (agent) も実行（デフォルト: 無効） | 無効 |
| `--cursor-only` | Cursor のみ実行 | 両方実行 |
| `--cursor-model MODEL` | Cursor で使用するモデル | `auto` |
| `--claude-model MODEL` | Claude で使用するモデル（エイリアス `opus`/`sonnet`/`haiku` 可） | CLI 既定 |
| `--codex-model MODEL` | Codex で使用するモデル | CLI 既定 |
| `--claude-effort LEVEL` | Claude のエフォート（`low`/`medium`/`high`/`xhigh`/`max`） | CLI 既定 |
| `--claude-web` | Claude Code に WebFetch を許可（`-p` で外部URL参照を要するタスク用） | 無効 |
| `--prev DIR` | 前回出力を追記（イテレーション用） | なし |

### 環境変数

| 変数 | 説明 | デフォルト |
|------|------|-----------|
| `SO_TIMEOUT` | codex / cursor のタイムアウト秒数 | `240` |
| `SO_CLAUDE_TIMEOUT` | claude のタイムアウト秒数（claude だけ既定が長い。下記「レーンごとの所要時間」を見よ） | `1200` |
| `PREV_MAX_BYTES` | `--prev` で追記する回答の上限バイト数 | `4000` |
| `SO_CURSOR_MODEL` | Cursor のデフォルトモデル（`--cursor-model` で上書き可） | `auto` |
| `SO_CLAUDE_MODEL` | Claude のデフォルトモデル（`--claude-model` で上書き可） | CLI 既定 |
| `SO_CODEX_MODEL` | Codex のデフォルトモデル（`--codex-model` で上書き可） | CLI 既定 |
| `SO_CLAUDE_EFFORT` | Claude のデフォルトエフォート（`--claude-effort` で上書き可） | CLI 既定 |

### 基本パターン

```bash
# 推奨: -w でワークスペースを渡す
so-compare -w "$(pwd)" "この修正方針を検証してください"

# プロンプトファイルから
so-compare -f prompt.txt -w "$(pwd)"

# イテレーション（前回の回答を踏まえて再質問）
so-compare --prev tmp/so-20260304-001234 -w "$(pwd)" "前回の指摘を踏まえて再評価してください"

# Codex のみ（claude-safe 未導入環境）
so-compare -w "$(pwd)" "プロンプト" --codex-only

# 任意の2社（従来は codex+cursor / claude+cursor が指定不可だった）
so-compare --with codex,cursor -w "$(pwd)" "プロンプト"
so-compare --with claude,cursor -w "$(pwd)" "プロンプト"

# Cursor も含めた3者比較
so-compare --cursor -w "$(pwd)" "この設計方針を検証してください"

# Cursor でモデル指定
so-compare --cursor --cursor-model composer-1.5 -w "$(pwd)" "プロンプト"

# Cursor のみ
so-compare --cursor-only -w "$(pwd)" "プロンプト"

# Claude を上位モデル + 高エフォートで（設計判断など重い SO）
so-compare --claude-model opus --claude-effort high -w "$(pwd)" "この設計方針を検証してください"

# Codex のモデル指定
so-compare --codex-model gpt-5.5 -w "$(pwd)" "プロンプト"
```

## モデル / エフォート選択ガイド

セカンドオピニオンを投げるエージェント向けの選択指針。**動的なモデル一覧コマンドが実在するのは Cursor のみ**（`agent models`）。Claude / Codex は以下を目安にする。

- **Claude**: エイリアス `opus` / `sonnet` / `haiku` で指定する。**エイリアスはそのティアの最新を指す**ため、バージョン ID（`claude-opus-4-8` 等）を追いかける必要はない（フル ID も透過で渡せる）。エフォートは `--claude-effort` に `low`/`medium`/`high`/`xhigh`/`max`
- **Codex**: 既定モデルは `~/.codex/config.toml` の `model`。任意のモデル名はそのまま透過で渡る
- **Cursor**: `agent models` で「アカウントで使えるモデル一覧」を取得できる。`--cursor-model` に渡す

### 使い分けの目安

- 設計判断・反証など重い SO → Claude を `--claude-model opus --claude-effort high`（必要なら `max`）に上げる
- 軽い確認 → 既定モデルのまま（フラグ未指定＝従来挙動）
- 指定したモデル名が無効・未契約の場合、そのレーンはエラー（`error` / `error_partial`）として結果サマリに現れる

未指定なら各 CLI の既定モデルで動作し、従来と挙動は変わらない。

## 出力ディレクトリ構成

```
tmp/so-YYYYMMDD-HHMMSS/
├── prompt.txt          # 最終プロンプト全文
├── codex-stdout.txt    # Codex の回答
├── codex-stderr.txt    # Codex の stderr
├── codex-meta.txt      # メタデータ（tool, model_requested, model_resolved, model_resolved_source, exit_code, timeout_status, elapsed_seconds, stdout_lines, stdout_bytes）
├── claude-stdout.txt   # Claude の回答
├── claude-raw.json     # Claude の生 JSON（jq がある場合のみ。回答本文はここから取り出される）
├── claude-stderr.txt   # Claude の stderr
├── claude-meta.txt     # メタデータ（model_requested, effort_requested, model_resolved, models_all, model_resolved_source, body_source を含む）
├── cursor-stdout.txt   # Cursor の回答（--cursor 時のみ）
├── cursor-stderr.txt   # Cursor の stderr（--cursor 時のみ）
└── cursor-meta.txt     # メタデータ（model_requested, model_resolved, model_resolved_source 含む。--cursor 時のみ）
```

## 解決後モデルの記録（どのモデルが答えたかを後から言うために）

SO の判定は plan / episode / discussion から証跡リンクで引かれ、committed 層に残る。したがって「この判定を出したのはどのモデルか」を後から言えることに意味がある。`model_requested` だけでは言えない。cursor の既定は `auto` で実行時に選ばれるし、claude はエイリアス（`opus` / `sonnet`）と CLI 既定の解決が入るためである。

各レーンの meta には次のキーが入る。

| キー | 意味 |
|---|---|
| `model_requested` | 起動時に要求した値。従来どおりで変わらない |
| `model_resolved` | 解決後のモデル ID、または `unavailable:<種別>` |
| `model_resolved_source` | `model_resolved` を**どこから取ろうとしたか**。値の確からしさがレーンごとに違うので明示する。`model_resolved` が `unavailable:*` のときは何も取れていない（出所が書いてあること自体は取得成功を意味しない） |
| `models_all` | claude のみ。その実行で使われた全モデル ID（補助モデルを含む） |
| `body_source` | claude のみ。回答本文をどこから取り出したか。`json-result`（JSON の `.result` から取り出した）／`direct`（`jq` が無く従来の text 形式で受けた）／`extract-failed`（取り出せず `claude-stdout.txt` は空。生の出力は `claude-raw.json` に残る） |

### レーンごとの確からしさ（同じ `model_resolved` でも強さが違う）

| レーン | `model_resolved_source` | 意味 |
|---|---|---|
| claude | `cli-json` | `--output-format json` の `.modelUsage` 由来。**どのモデルが動いたかは観測値**で、エイリアス解決の結果がそのまま出る。ただし下記のとおり `model_resolved` 単体は推定を含む |
| codex | `config` | **観測値ではない。** 要求値がそれならその値、無ければ `~/.codex/config.toml` の `model` を読んだ値である。実行後に確認したわけではないので、設定と実際が食い違えば嘘になる |
| cursor | `none` | 取得していない（下記） |

**codex の `model_resolved` を「実行されたモデルの記録」として引用しないこと。** 証跡として引くときは claude より一段弱い値である。

### claude の `model_resolved` は観測と推定が混ざっている

同じ claude レーンの中でも、2 つのキーで強さが違う。

- **`models_all` は観測値である。** その実行で実際に使われたモデル ID がすべて並ぶ。claude は補助用途で別のモデル（haiku 等）を併用するため、通常は複数になる。
- **`model_resolved` は推定である。** 複数のうち「回答を書いた主モデルはどれか」を、トークン投入量（input + cache 読み + cache 作成）が最大のキー、という規則で選んでいる。CLI が「これが主モデルだ」と言っているわけではない。

この推定が外れる条件がある。補助モデルが何度も呼ばれて累積量が主モデルを超えた場合、cache 生成を別のモデルが担った場合、実行途中でモデルが切り替わった場合、合計が同点の場合などである。

**証跡として厳密に引くときは `models_all` を併記すること。** `model_resolved` だけを引いて「このモデルが答えた」と断定しない。

### `unavailable` の種別（空欄にはしない）

取得できなかった場合もキーは必ず書かれる。空欄にすると「記録し忘れた」のか「取得できなかった」のかが区別できなくなるためである。種別は理由ごとに分かれている。

| 値 | 意味 |
|---|---|
| `unavailable:cli-not-exposed` | CLI が解決後のモデルを出力しない（cursor が常にこれ） |
| `unavailable:query-failed` | `jq` が無い、または実行に失敗した。**環境エラー** |
| `unavailable:parse-failed` | 出力が JSON として読めなかった（タイムアウトで途中で切れた場合など） |
| `unavailable:no-modelusage` | JSON は読めたが `.modelUsage` が無かった。**データ不在**であって失敗ではない |
| `unavailable:schema-unexpected` | `.modelUsage` はあるが中身が想定の形でなく、モデル ID を取り出せなかった |

この 4 つ（`cli-not-exposed` を除く）は意図的に別の値にしてある。**環境エラー・データ不在・形の不一致は、原因も対処も違う。** ひとつの `unavailable` に潰すと、取得できなかった理由が読めなくなり、記録漏れとの区別もつかなくなる。

判定は `jq` の終了コードで機械的に分けている。判定式が正常に `false` を返した場合（終了コード 1）だけがデータ不在で、実行そのものが失敗した場合（終了コード 2 以上）は環境エラーとして扱う。両者をまとめて「非ゼロ」として扱わない。

### cursor の解決後モデルを手で調べる手順

**cursor の具体的なモデル名は自動記録していない。** CLI が出さないためで、`--output-format json` / `stream-json` に出る `model` は表示名止まりである（既定の `auto` では `Auto Balance` としか出ない）。

具体名は Cursor 内部の SQLite に残っており、手で辿れば取得できる。**ただしこれは公開された形式ではなく、Cursor の更新で変わりうる。** 自動記録がこれに依存していないのは意図的な判断である（内部形式への無言の依存を作らないため）。

必要になったときは次の手順で辿る。`--output-format json` か `stream-json` で走らせて `session_id` を得ることが前提になる。

```bash
# 1. session_id を得る（text 形式では出ないので json 系で走らせる）
SID=$(jq -r 'select(.session_id) | .session_id' <cursor の生出力> | awk 'NR==1')

# 2. session_id からセッションの保管場所を引く
D=$(find ~/.cursor/chats -maxdepth 2 -type d -name "$SID" -print -quit)

# 3. 具体的なモデル ID を取り出す
sqlite3 "$D/store.db" "select data from blobs;" | grep -oE '"modelName":"[^"]+"' | sort -u
```

### `auto` は実行ごとに解決先が変わる（レーンの多様性を読むときの注意）

同一プロンプト・同一条件で `auto` を3回走らせ、解決先を上の手順で確認した実測がある。

| 実行 | 解決先 |
|---|---|
| 1回目（`auto`） | `cursor-grok-4.5-high` |
| 2回目（`auto`） | `cursor-grok-4.5-high` |
| 3回目（`auto`） | `composer-2.5` |

**同じ `model_requested=auto` でも実行ごとに違うモデルへ解決される。** ここから2つ言える。

- 過去の SO 出力について、`model_requested=auto` から解決先を事後に推測してはいけない。記録が無ければ分からない、が正しい。
- **「他族レーンを混ぜた」という多様性の主張は、tool の別までしか保証しない。** cursor が実際に何に解決されたかを確認していない限り、別のレーンと同じ基盤モデルだった可能性は否定できない。多様性を根拠にするなら、上の手動手順で確認するか、主張の強さを落とすこと。

## 結果読み込み手順

1. 実行完了後、出力ディレクトリパスを確認する
2. `codex-stdout.txt`、`claude-stdout.txt`（`--cursor` 時は `cursor-stdout.txt` も）を Read ツールで読み込む
3. 両回答を比較テーブルにまとめる

```markdown
| 観点 | 自分 | Codex | Claude | Cursor | 合意? |
|------|------|-------|--------|--------|-------|
| 問題認識 | ... | ... | ... | ✅/❌ |
| 修正方針 | ... | ... | ... | ✅/❌ |
| リスク対応 | ... | ... | ... | ✅/❌ |
```

## レーンごとの所要時間（claude だけ既定タイムアウトが長い理由）

**「この環境では claude レーンは返らない」は誤りである。** 返らなかったのは環境が非対応だからではなく、共通の既定タイムアウト（240秒）が claude には短すぎたためである。

### 実測値

レビュー級のプロンプト2件について、同一プロンプトを各レーンへ投げたときの所要時間である。

| プロンプト | codex | cursor | claude |
|---|---|---|---|
| 設計レビュー（7.4KB） | 296秒 | 254秒 | **652秒** |
| 実装レビュー（1.4KB） | 241秒 | 334秒 | **777秒 / 739秒**（2回） |

読み取れることが4つある。

- **観測した範囲では claude が他レーンの2〜3倍（最大3.2倍）かかった。** ただし実測はこの環境・この日・CLI 既定モデルでのプロンプト2種・claude 側3点にすぎない。モデルや effort、時間帯で比率は動くので、**「claude は常に2〜3倍遅い」と一般化しない**。軽い質問では claude が最速である（下記）。言えるのは「レビュー級の課題では大幅に長かった」までである。
- **所要時間はプロンプトの大きさに比例しない。** 小さいほうのプロンプト（1.4KB）のほうが長くかかっている。要求される分析の深さが効いていると考えられるが、**この3点から因果を確定はできない**（推測）。いずれにせよ入力量からは見積もれない。
- **軽い質問なら claude は速い。** 1行の確認では8秒で返っている。遅いのはレビュー級の課題のときだけである。
- **同じプロンプトでも実行ごとに5%ほど振れる**（777秒と739秒）。実測の最大値ぎりぎりに既定を置くと足りなくなる。

### 通説ができた仕組み

既定の240秒では**3レーンとも返らない**。ところがリトライ（`timeout_empty` のときだけ ×1.5 = 360秒）は codex（296秒）と cursor（254秒）には届き、claude（652〜777秒）には届かない。

その結果、**codex と cursor はリトライで救われ、claude だけが構造的に取り残される**。これが「claude だけ返らない」という観測になり、環境の非対応と解釈されていた。原因は環境ではなく、リトライ幅が2レーンにだけ届いていたことである。

**この誤解には実害が出ている。** 「claude は返らない」という前提で SO を組んだ単位があり、他族2レーンのつもりが事実上2レーンではなく、レーンの多様性の主張が1レーン分弱っていた。

### 対応

claude だけ既定を分けた（`SO_CLAUDE_TIMEOUT` = 1200秒。`SO_TIMEOUT` = 240秒は codex / cursor 用のまま）。

- 一律に引き上げなかったのは、360秒で足りている codex と cursor の失敗検出まで遅くする理由が無いためである。
- リトライ幅を広げる案を採らなかったのは、初回の240秒を捨ててから長い2回目に入ることになり、成功までの総時間が最も長くなるためである。claude は初回から長くしたほうが速い。
- 1200秒は最大実測（777秒）に対して約54%の余裕である。
- **claude のリトライは基準を増やさない**（もう一度1200秒）。codex / cursor の `×1.5` は初回基準がきつい分の逃し弁だが、claude は初回を実測から十分に取ってあるため、そこで出力ゼロなら「遅い」より「止まっている」公算が高く、さらに1.5倍を張る根拠が無い。最悪待ち時間の膨張も抑えられる。

### 未解決: codex / cursor 側の既定（240秒）も実は足りていない

**このタイムアウト分離では codex / cursor の既定を変えていないが、実測はそこにも問題があることを示している。**

上の表のレビュー級4点（codex 296 / 254、cursor 254 / 334）は**すべて240秒を超えている**。つまりレビュー級の SO では、codex と cursor は「240秒を捨ててからリトライ（360秒）で成功する」のが既定の経路になっている。実際、本変更のレビュー時にも codex が初回241秒で `timeout_empty` になり、リトライで返っている。

さらに **cursor の334秒はリトライ上限360秒に対して余裕7%しかない**。同じプロンプトでも5%程度は振れるので、claude で直したばかりの「リトライにも届かず構造的に落ちる」故障モードは、cursor では一歩手前にある。

**レビュー級の SO を投げるときは `SO_TIMEOUT` の引き上げ（400〜480秒程度）を検討すること。** 既定を変えていないのは本 issue の scope 外だからであって、240秒で足りているからではない。

**観測したレビュー級のプロンプトでは、既定のままで claude レーンが返っている。** タイムアウトを手で指定する必要はなかった。環境変数を一切設定せずレビュー級のプロンプトを投げ、`timeout_status=success` / 739秒 / 11748 bytes / リトライなしで返ることを確かめた。

**ただし「必ず返る」保証ではない。** 3点の実測では分布の裾は縛れない。より深い課題で 1200秒 を超えることはありうる。その場合は弱 SO の "0 はなし" フロア（再試行 / escalate）が受け皿になる。**既定の 1200秒 で `timeout_empty` が一度でも観測されたら、既定値を測り直すこと。**

## プロンプト設計原則

### やってはいけないこと

- **`-c` でファイル全文を渡す** → アンカリングが起き、渡したコードしか見ない。95KB超のプロンプトで278秒/414秒のタイムアウト実績あり
- **結論を含むプロンプト** → 追認を誘発する。「Xが正しいことを確認して」ではなく「Xを検証して」
- **1回のプロンプトに複数の質問を詰め込む** → 回答が散漫になる

### やるべきこと

- **`-w` でワークスペースパスを渡し、エージェントに自分で読ませる**
- **検証ポイントを具体的に列挙**（「X, Y, Z を検証して」）
- **事実と仮定を分離**（「確認済み: A。未検証の仮定: B」）
- **反証可能性を確保**（「違う可能性はあるか？」）

### 選択肢拡張（設計を確定する SO のとき）

設計を確定する（複数案から1つを選ぶ・PoC を本採用するなど、後戻りコストのある決定を伴う）SO では、初期選択肢セットの外にある代替案を出させる構造を与える。wez notify で初期 A/B に無かった option C（TTY 直接書き込み）がゼロベース再レビューで最適解として発見された経緯に基づく（`exhaustion-before-conclusion-rule` の探索網羅性に対応）。ただし本テンプレは層1の最小手当てで、網羅を保証する機構ではない（探索の質はモデル依存）。確定の前でも後でも使う（option C は「A で確定しかけた後」のゼロベース再探索で出た）。

プロンプトにまず初期選択肢セットと暗黙の前提を列挙し、その上で以下を足す:

```markdown
## 選択肢拡張（設計確定 SO では必須）
- 初期案とは異なる技術カテゴリ・責務分界・データフロー・実行経路・運用前提を持つ代替案を、ゼロベースで提案してください（既存案の小変形は不可）
- 各代替案に「差分軸」「成立条件」「反証可能な検証方法」「期待される観測結果」を付けてください
- その代替案が初期選択肢に含まれていなかった理由を「隠れていた前提」か「探索漏れ」に分解して述べてください
- 新規案なしと判断する場合は、探索した軸と除外理由を示してください
```

- 適用は設計確定 SO に限る。低リスクで確定を伴わない壁打ちや、欠陥検出のみが目的のレビューには付けない（「A/B のどちらか」でも、設計を確定するなら対象 — wez notify はこのケース）。
- 出てきた代替案は「良さそう」で止めず、検証可能な条件で即検証し、結果を比較テーブル／`--prev` イテレーションに載せる。
- arena-compare（発散）側への同型の横展開は別途（本件は so-compare の最小実装）。

### プロンプト品質チェック

SO 実行前に以下を確認する:

1. 具体的な検証対象が列挙されているか
2. 確認済みの事実と未検証の仮定が区別されているか
3. SO がプロンプトだけで回答できる十分なコンテキストがあるか
4. SO が「違う」と言える余地があるか
5. （設計確定 SO の場合）初期選択肢セットと暗黙の前提を列挙し、差分軸・検証可能条件つきの選択肢拡張セクションを入れたか

## 合意判定基準

以下の**すべて**を満たした場合に「3者合意」とする:

1. **問題認識が一致**: 3者が同じ問題を認識している
2. **修正方針の方向性が一致**: 具体的な実装は異なっても、アプローチの方向性が同じ
3. **重大なリスク指摘が未解決でない**: いずれかが指摘したリスクに対して、反論または対策が示されている

### 合意に至らない場合

1. 差異の特定と原因分析
2. 修正案の改善
3. プロンプトの改善（不足コンテキスト追加）
4. `--prev` を使って再実行（最大3イテレーション）

### フォールバック

`claude-safe` 未導入等で2者しか参加できない場合、「2者合意 + ユーザーの明示承認」で代替可。

## 注意事項

- 実行には `codex` CLI と `claude-safe` が PATH 上に必要（片方のみの場合は `--codex-only` / `--claude-only`）
- Cursor レーンは `--cursor` でオプトイン。`agent` CLI が PATH 上に必要（未インストール時はエラー終了）
- `SO_TIMEOUT` のデフォルトは240秒（codex / cursor）。claude は `SO_CLAUDE_TIMEOUT` の1200秒で、既定が分かれている。理由は下記「レーンごとの所要時間」
- 出力は `tmp/` 配下で gitignore 対象
