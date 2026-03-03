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

## Step 2: arena-compare 実行（サブエージェント委譲）

Arena の実行・summary 読み込み・要約をサブエージェントに委譲し、メインコンテキストを節約する。

**サブエージェントに以下を指示する**（Task tool の shell subagent を使用）:

```
以下のタスクを実行してください:

1. まず Arena スキルを読み込む:
   Read ~/.cursor/skills/arena-compare/SKILL.md

2. スキルに従い、arena-compare.sh を実行:
   ./projects/arena-compare/arena-compare.sh -w "$(pwd)" "[プロンプト]"
   [モデル指定がある場合は -m オプションを追加]
   [セッション継続の場合は --resume-from を追加]

3. 実行完了後、summary.md を読み込む

4. 以下の形式で差分ポイントのみ返す:
   - 出力ディレクトリパス
   - メタデータテーブル（モデル名・実行時間・exit code）
   - 各モデルの回答の要約（一致点と相違点のみ。全文は含めない）
   - resume 用コマンド

注意: summary.md の全文は返さないこと。差分ポイントの要約のみ。
```

**フォールバック**: サブエージェントが利用できない場合は、従来通り直接実行する:

```bash
./projects/arena-compare/arena-compare.sh -w "$(pwd)" "[プロンプト]"
```

## Step 3: 結果確認

サブエージェントが返した差分ポイントの要約を確認する。

詳細を確認したい場合は、個別モデルの回答を直接読む:

```bash
OUT_DIR="tmp/arena-XXXXXXXX-XXXXXX"
cat "$OUT_DIR/summary.md"
cat "$OUT_DIR/{model}-stdout.txt"
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
