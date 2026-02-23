# Arena Perspectives

同一プロンプトを複数モデルに並列投入し、モデルごとの回答を並べて表示する。
各モデルの得意領域や視点の違いから、メインスレッドのモデルだけでは出てこない情報をキャッチアップする。

## 入力形式

- プロンプト（自然言語）
- （任意）コンテキストファイルパス

入力例:
- "この設計の問題点を指摘して"
- "CONVENTIONS.md を読み、曖昧なルールを列挙して"
- "`src/handler.ts` のエラーハンドリングを改善する方法"

## フロー

```
入力受付 → arena-compare.sh 実行 → 各モデルの回答を表示
```

## 前提条件確認

```bash
command -v agent &>/dev/null && echo "agent CLI: $(agent --version 2>&1 | head -1)" || echo "agent CLI: 未インストール"

ARENA_SCRIPT="$HOME/work/repos/github.com/stlwolf/ai-development-hub/projects/arena-compare/arena-compare.sh"
[[ -x "$ARENA_SCRIPT" ]] && echo "arena-compare.sh: OK" || echo "arena-compare.sh: 未配置"
```

## Step 1: プロンプト構成

入力からプロンプトを構成する。

- 入力テキストをそのまま使う（加工・判断の方向付けはしない）
- 入力中の `@ファイル名` や相対パスは、ワークスペース内のフルパスに置き換える（エージェントが動的に読みに行ける形にする）
- `-c` によるファイル内容のベタ貼りは原則使わない（プロンプトが肥大化しタイムアウトの原因になるため。`--workspace` 経由でエージェントがファイルを読める）

## Step 2: arena-compare 実行

```bash
ARENA_SCRIPT="$HOME/work/repos/github.com/stlwolf/ai-development-hub/projects/arena-compare/arena-compare.sh"

# 基本形: デフォルト3モデルに並列投入（モード別デフォルト）
$ARENA_SCRIPT \
  -w "$(pwd)" \
  "プロンプト"

# コンテキストファイル付き
$ARENA_SCRIPT \
  -c path/to/file.ts \
  -w "$(pwd)" \
  "プロンプト"

# モデル明示指定（Claude系を含めたい場合など）
$ARENA_SCRIPT \
  -m "sonnet-4.6,gpt-5.2,gemini-3.1-pro" \
  -w "$(pwd)" \
  "プロンプト"

# セッション継続（前回の回答を踏まえて追加質問）
$ARENA_SCRIPT \
  --resume-from tmp/arena-XXXXXXXX-XXXXXX \
  -w "$(pwd)" \
  "追加の質問"
```

## Step 3: 結果表示

各モデルの回答を読み込み、以下の形式で表示する。

```bash
OUT_DIR="tmp/arena-XXXXXXXX-XXXXXX"  # Step 2 の出力先

cat "$OUT_DIR/opus-4.6-stdout.txt"
cat "$OUT_DIR/sonnet-4.6-stdout.txt"
cat "$OUT_DIR/gpt-5.2-stdout.txt"
```

表示形式:

```
### opus-4.6
[回答内容]

### sonnet-4.6
[回答内容]

### gpt-5.2
[回答内容]
```

## 運用ガイド

- **判断はコマンドの仕事ではない**: 回答を並べるだけ。合成・採用判断は人間が行う
- **メインスレッドの補助として使う**: メインスレッドで得た回答に「他のモデルならどう答えるか」を確認する用途
- **resume で深掘り可能**: 気になった回答があれば、同じセッションで追加質問できる。各モデルが前回の文脈を保持している
- **モデル選択の目安**: デフォルトは GPT / Gemini / Composer の異なるファミリー3つ。メインスレッドが Claude 系のため、デフォルトから Claude を外して多様性を確保。`-m` で任意のモデルを指定可能

## モデル変更例

```bash
# 思考モデルを含める
-m "opus-4.6-thinking,sonnet-4.6-thinking,gpt-5.2"

# 軽量モデルで素早く比較
-m "gemini-3-flash,sonnet-4.6,gpt-5.2"

# 5モデル比較（時間がかかる）
-m "opus-4.6,sonnet-4.6,gpt-5.2,gemini-3.1-pro,grok"
```
