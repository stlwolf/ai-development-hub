---
researched_at: "2026-06-09"
topic: "apple/python-apple-fm-sdk — Apple Intelligence のオンデバイス Foundation Model を Python から推論・評価する公式バインディング"
primary_url: "https://github.com/apple/python-apple-fm-sdk"
agent: oss-researcher
skill: oss-research-session
---

## python-apple-fm-sdk 調査結果

> 検証ステータス凡例（`evidence-verification-rule`）: `verified` = 一次ソース実体（`file:line` / 公式URL）を実際に確認 / `unverified-summary` = ソースはあるが entailment 未確認（README・二次情報の言い換え、AI要約のデフォルト）/ `speculation` = 根拠なし推測。
> 本調査はソースを WebFetch / WebSearch 経由で取得しており、ローカルにクローンしていない。したがって個別の `file:line` 確認は行えておらず、コード由来の主張は原則 `unverified-summary`（取得URLを併記）に留める。一次ソース実体を直接開いて文言を確認できたもの（README 原文・公式ドキュメントURL・GitHub メタデータ・HN API・Apple 公式リサーチ）は `verified` とする。

### 基本情報
- **リポジトリ:** [apple/python-apple-fm-sdk](https://github.com/apple/python-apple-fm-sdk)
- **言語:** Python 85.2% / Swift 10.7% / Shell 2.5% / C 1.6% [verified] (https://github.com/apple/python-apple-fm-sdk)
- **最終更新:** 最新リリース v0.2.0 = 2026-06-08（WWDC2026 と同日）[verified] (https://github.com/apple/python-apple-fm-sdk/releases)
- **規模:** ★ 約1.1k / fork 64 / watch 11 / コミット 6 / リリース 4 / コントリビュータは GitHub 上で確認できず（小規模 Apple 内部チームと推測）[verified（star/fork/commit 数）] (https://github.com/apple/python-apple-fm-sdk) / [speculation（チーム規模）]
- **ライセンス:** Apache-2.0（リポジトリ表記）。README 末尾は "Copyright (C) 2026 Apple Inc. All Rights Reserved." [verified] (https://github.com/apple/python-apple-fm-sdk) / [verified] (https://raw.githubusercontent.com/apple/python-apple-fm-sdk/main/README.md)
- **PyPI パッケージ名:** `apple-fm-sdk`（`pip install apple-fm-sdk`）[verified] (https://raw.githubusercontent.com/apple/python-apple-fm-sdk/main/README.md)
- **一言で:** Apple Intelligence のコアであるオンデバイス Foundation Model を、Apple の Swift フレームワークを介して Python から推論・評価するための公式バインディング（FFI ラッパー）。

### これは何か・何を解決するのか
Apple が WWDC2025 で公開した **Foundation Models framework**（Swift 製）への Python バインディング。フレームワーク本体は Swift / Xcode 前提のため「Apple Intelligence のオンデバイスモデルを使いたいが、評価・データ処理は Python エコシステムでやりたい」という需要に応える。[unverified-summary] (https://raw.githubusercontent.com/apple/python-apple-fm-sdk/main/README.md)

README は用途の筆頭に **「Swift の Foundation Models アプリ機能を評価する（batch inference を実行し Python から結果を分析する）」** を挙げる。公式ドキュメント序文には *"these Python bindings run the Apple's Foundation Models framework in Swift under the hood, so you can be confident that your evaluations reflect real on-device performance and behavior"* とあり、**「実機と同じ Swift フレームワークを叩くので評価結果が本番挙動を反映する」** ことを価値の中心に据えている。[verified（README 用途リスト）] (https://raw.githubusercontent.com/apple/python-apple-fm-sdk/main/README.md) / [verified（ドキュメント序文の引用）] (https://apple.github.io/python-apple-fm-sdk/)

ただしドキュメントの各ページ（Getting Started / Basic Usage）は「評価専用」という制約や「本番 Python アプリには使うな」という警告は明記しておらず、汎用のオンデバイス推論 SDK としても記述されている。**「評価ツール」フレーミングは README が最も強く打ち出し、ドキュメント本体はより汎用的**、という温度差がある。[verified（Getting Started に評価専用の制約・本番禁止の文言が無いこと）] (https://apple.github.io/python-apple-fm-sdk/getting_started.html) / [verified（Basic Usage が汎用テキスト生成として記述）] (https://apple.github.io/python-apple-fm-sdk/basic_usage.html)

**ターゲットユーザー:** Apple Intelligence 対応 Mac を持ち、Swift アプリの AI 機能を Python のテスト/データ基盤で回帰評価したい開発者、およびオンデバイス推論を Python から手軽に試したい層。

### 設計思想・アーキテクチャ
**コア抽象 = Swift フレームワークの薄い忠実な写像。** 独自の推論エンジンは持たず、Apple の `FoundationModels` Swift API をそのまま Python へ写し取る。Python の公開 API は Swift 版とほぼ一対一対応する（`SystemLanguageModel` / `LanguageModelSession` / `Generable` / `GenerationSchema` / `GenerationGuide` / `Tool` / `Transcript` など）。[unverified-summary] (https://raw.githubusercontent.com/apple/python-apple-fm-sdk/main/src/apple_fm_sdk/__init__.py)

**3 層 FFI アーキテクチャ（最大の特徴）:**

```
Python (ctypes)                ← src/apple_fm_sdk/*.py（公開 API + 型変換）
   │  _ctypes_bindings（ctypesgen 生成）
   ▼
C ABI 層                        ← foundation-models-c/Sources/FoundationModelsCBindings/
   │  FoundationModelsCBindings.swift + include/FoundationModels.h
   │  FM* プレフィックスの C 関数（例: FMSystemLanguageModelCreate, FMSystemLanguageModelIsAvailable）
   ▼
Apple FoundationModels.framework（Swift, OS 同梱）
```

- Python 側は `from . import _ctypes_bindings as lib` で生成済み ctypes バインディングを読み込み、`lib.FMSystemLanguageModelCreate(...)` のように C 関数を呼ぶ。`ctypes.byref()` で out パラメータを受け取るなど、典型的な ctypes マーシャリング。[unverified-summary] (https://raw.githubusercontent.com/apple/python-apple-fm-sdk/main/src/apple_fm_sdk/core.py)
- C 層は単一 Swift ファイル `FoundationModelsCBindings.swift` + ヘッダ `include/FoundationModels.h` で構成。Swift Package として **dynamic（`FoundationModels`）と static（`FoundationModelsStatic`）の両ライブラリ** をビルドし、`fm-c-example` という C 実行例も持つ。[verified（include に FoundationModels.h が存在）] (https://github.com/apple/python-apple-fm-sdk/tree/main/foundation-models-c/Sources/FoundationModelsCBindings/include) / [verified（products = dynamic/static + executable）] (https://raw.githubusercontent.com/apple/python-apple-fm-sdk/main/foundation-models-c/Package.swift)
- `Package.swift`: Swift tools 6.2、`platforms: [.macOS(.v26), .iOS(.v26), .visionOS(.v26)]`、C 言語標準 C99。[verified] (https://raw.githubusercontent.com/apple/python-apple-fm-sdk/main/foundation-models-c/Package.swift)
- ビルド成果物（`.a` / `.dylib`）は `setuptools` の `package_data`（`lib/*.a`, `lib/*.dylib`）として同梱配布される。ビルドバックエンドは独自 `build_backend`（`build_backend.py`）。dev 依存に `ctypesgen`（C ヘッダ→ctypes 自動生成）。[verified（package_data / build_backend / ctypesgen）] (https://github.com/apple/python-apple-fm-sdk/blob/main/pyproject.toml)
- `bin/` にビルド・配布スクリプト群（`build-distribution.sh`, `clean-build-files.sh`, `verify-license-header.sh`, `install-git-hooks.sh`, `publish-docs.sh` 等）。Swift→dylib のビルドパイプラインを内包。[verified（bin/ のファイル名一覧）] (https://github.com/apple/python-apple-fm-sdk/blob/main/bin)

**プロジェクト固有の用語/概念**（いずれも Swift 版 Foundation Models から継承）:
- **Generable**: モデルに「この Python クラスの構造で生成させる」と宣言するための型。`@fm.generable` デコレータで付与（Swift の `@Generable` マクロ相当）。[unverified-summary] (https://raw.githubusercontent.com/apple/python-apple-fm-sdk/main/src/apple_fm_sdk/generable.py)
- **Guide / `fm.guide()`**: フィールド単位の生成制約。Swift の `@Guide` マクロ相当。[unverified-summary] (https://raw.githubusercontent.com/apple/python-apple-fm-sdk/main/src/apple_fm_sdk/generation_guide.py)
- **Guided generation**: スキーマ/制約付きで構造化出力を強制する仕組み。`generating=<class>` / `schema=` / `json_schema=` の 3 経路。[unverified-summary] (https://raw.githubusercontent.com/apple/python-apple-fm-sdk/main/src/apple_fm_sdk/session.py)
- **Transcript**: 会話履歴（ユーザー発話・応答・ツール呼び出し）。Swift アプリからエクスポートした Transcript を Python に読み込み、過去履歴からセッションを再開できる。[unverified-summary] (https://raw.githubusercontent.com/apple/python-apple-fm-sdk/main/src/apple_fm_sdk/session.py)
- **Tool**: モデルが呼び出せる関数（function calling）。[unverified-summary] (https://github.com/apple/python-apple-fm-sdk/tree/main/src/apple_fm_sdk)

**ディレクトリ構成の意図:** `src/apple_fm_sdk/`（Python 公開 API）と `foundation-models-c/`（Swift→C ブリッジ）が明確に分離。前者は概念ごとにファイルを割る（`session.py`, `generable.py`, `generation_guide.py`, `generation_schema.py`, `generation_options.py`, `tool.py`, `transcript.py`, `prompt.py`, `errors.py`, `type_conversion.py`, `c_helpers.py`）。`type_conversion.py` / `c_helpers.py` の存在が FFI 境界でのデータ変換を担う層であることを示す。[unverified-summary（ファイル名からの推測）] (https://github.com/apple/python-apple-fm-sdk/tree/main/src/apple_fm_sdk)

### 機能一覧
分類: **[core]** 中核 / **[diff]** 差別化要素 / **[util]** 補助。位置は確認できたファイル/ディレクトリパス。

| 機能 | 概要 | 位置 | 区分 |
|---|---|---|---|
| オンデバイス推論（`respond`） | システム Foundation Model に同期的にプロンプトを投げ応答取得。async/await ベース | `src/apple_fm_sdk/session.py`（`LanguageModelSession.respond`）[unverified-summary] | core |
| ストリーミング生成（`stream_response`） | 生成途中のテキストスナップショットを `AsyncIterator[str]` で逐次取得 | `session.py`（`stream_response`）[unverified-summary]; `examples/streaming_example.py`; `tests/test_streaming.py` | core |
| Guided generation（型指定） | `@fm.generable` クラスを `generating=` に渡し型安全な構造化出力を得る | `generable.py` / `session.py`; `tests/test_guided_generation.py`, `test_generable_protocol.py` | diff |
| Guided generation（スキーマ/JSON Schema） | `schema=GenerationSchema` または `json_schema=dict` で制約 | `generation_schema.py` / `session.py`; `tests/test_json_guided_generation.py` | diff |
| 生成ガイド（`fm.guide`） | フィールド制約: `range / minimum / maximum / count / min_items / max_items / anyOf / constant / regex / element` | `generation_guide.py`（`guide()` 署名で確認）[unverified-summary]; `tests/test_guides.py` | diff |
| Tools / function calling | モデルが呼べる関数を `tools=[...]` で登録 | `tool.py`; `tests/test_tool.py`; docs `tools.html` | core |
| Transcript ロード/再開 | Swift アプリからエクスポートした Transcript を Python へ読み込み、`from_transcript` でセッション再開 | `transcript.py` / `session.py`（`from_transcript`）[unverified-summary]; `tests/test_transcript.py` | diff |
| GenerationOptions | サンプリングモード等の生成オプション設定（v0.1.1 で追加） | `generation_options.py`; `tests/test_generation_options.py` | util |
| 画像入力（Attachment / ImageAttachment） | プロンプトに画像を添付（v0.2.0 で追加、Swift の Attachment API 対応） | `prompt.py`（`Attachment`/`ImageAttachment`）[unverified-summary]; `tests/test_image_prompts.py` | diff |
| モデル可用性チェック | `is_available()` が `(bool, 理由)` を返す。未対応理由は enum 化 | `core.py`（`SystemLanguageModel.is_available`）[unverified-summary]; `tests/test_system_model.py` | core |
| ユースケース/ガードレール設定 | `SystemLanguageModelUseCase`（GENERAL 等）/ `SystemLanguageModelGuardrails`（DEFAULT 等） | `core.py` コンストラクタ引数[unverified-summary] | util |
| 構造化エラー体系 | `FoundationModelsError` を基底に 13 種前後の例外（`GuardrailViolationError`, `ExceededContextWindowSizeError`, `RateLimitedError`, `RefusalError`, `ToolCallError` 等） | `errors.py`; `tests/test_error_handling.py` | util |
| メモリ管理 / リーク検証 | FFI 境界のリソース解放を検証するテスト（`_ManagedObject` パターン） | `tests/test_memory.py`, `test_memory_stress.py` | util |

機能の存在根拠は主に `__init__.py` のエクスポート、`tests/` のテストファイル名、リリースノートの 3 系統。各実装本体は未読（深掘り候補参照）。[verified（テストファイル名一覧）] (https://github.com/apple/python-apple-fm-sdk/tree/main/tests) / [verified（リリースノート）] (https://github.com/apple/python-apple-fm-sdk/releases)

### 特徴的な点・注目ポイント
1. **「実機 Swift を叩く」ことで評価の忠実性を担保（最大の差別化）。** MLX や llama.cpp のように重みを別実装で再現するのではなく、OS 同梱の `FoundationModels.framework` をそのまま呼ぶため、Python での評価結果が Swift アプリの本番挙動と一致する。Apple 純正バインディングならではの設計上の強み。[verified（ドキュメント序文の文言）] (https://apple.github.io/python-apple-fm-sdk/)
2. **Swift API の忠実な写像。** `@generable` / `guide()` / `GenerationSchema` / `Transcript` まで Swift 版の概念を Python の語彙（デコレータ・型ヒント）に翻訳。Swift で書いた評価対象を Python に移植しやすい。[unverified-summary] (https://raw.githubusercontent.com/apple/python-apple-fm-sdk/main/src/apple_fm_sdk/__init__.py)
3. **dynamic + static 両ライブラリのビルドと ctypesgen 自動生成。** C ABI を介する設計により Python と Swift を疎結合に保つ。`foundation-models-c/Sources/FoundationModelsCBindings/`。[verified] (https://raw.githubusercontent.com/apple/python-apple-fm-sdk/main/foundation-models-c/Package.swift)
4. **FFI のメモリリークを専用テストで検証。** `tests/test_memory.py` / `test_memory_stress.py` と `_ManagedObject` 基底クラスは、ネイティブリソースのライフサイクル管理を意識した設計を示す（ctypes 越しのポインタ管理は漏れやすいため）。[verified（テスト名）] (https://github.com/apple/python-apple-fm-sdk/tree/main/tests) / [unverified-summary（_ManagedObject）] (https://raw.githubusercontent.com/apple/python-apple-fm-sdk/main/src/apple_fm_sdk/session.py)
5. **画像入力（マルチモーダル）への素早い追従。** v0.2.0（2026-06-08）で Attachment API を取り込み、テキスト＋画像プロンプトに対応。WWDC2026 のフレームワーク更新に同期。[verified] (https://github.com/apple/python-apple-fm-sdk/releases)

### 使い方・典型的なワークフロー
**前提（要件）:** macOS 26.0+ / Xcode 26.0+（SDK 利用許諾に同意）/ Python 3.10+ / Apple Intelligence 対応 Mac で Apple Intelligence を ON。**macOS 専用**（iOS/visionOS はフレームワーク側のターゲットだが、この Python SDK の動作前提は macOS）。[verified] (https://raw.githubusercontent.com/apple/python-apple-fm-sdk/main/README.md)

**インストール:**
```bash
pip install apple-fm-sdk
# 開発時: git clone → uv venv → uv sync → uv pip install -e . → pytest
```
[verified] (https://raw.githubusercontent.com/apple/python-apple-fm-sdk/main/README.md)

**基本（テキスト生成）:** README より verbatim 抜粋 [verified] (https://raw.githubusercontent.com/apple/python-apple-fm-sdk/main/README.md)
```python
import apple_fm_sdk as fm
import asyncio

async def main():
    model = fm.SystemLanguageModel()
    is_available, reason = model.is_available()
    if is_available:
        session = fm.LanguageModelSession()
        response = await session.respond("Hello, how are you?")
        print(f"Model response: {response}")
    else:
        print(f"Foundation Models not available: {reason}")

asyncio.run(main())
```

**Guided generation（構造化出力）:** README より verbatim 抜粋 [verified] (https://raw.githubusercontent.com/apple/python-apple-fm-sdk/main/README.md)
```python
import apple_fm_sdk as fm

@fm.generable  # このデコレータでモデル生成対象の型を宣言
class Cat:
    name: str
    age: int = fm.guide("Age in years", range=(0, 20))

async def generate_cat():
    model = fm.SystemLanguageModel()
    is_available, reason = model.is_available()
    if is_available:
        session = fm.LanguageModelSession()
        cat = await session.respond("Generate an adorable rescue cat", generating=Cat)
        print(f"Model response: {cat}")
```

**典型ワークフロー（README の用途リストより）:** ① Swift アプリの AI 機能に対する batch inference を Python で回す → ② 結果を Python のデータ/評価基盤で分析、③ Swift からエクスポートした Transcript を読み込んで品質分析、④ ストリーミング/guided generation/tools を Python から検証。`examples/` は `simple_inference.py` / `streaming_example.py` / `transcript_processing.py` の 3 本。[verified（用途リスト）] (https://raw.githubusercontent.com/apple/python-apple-fm-sdk/main/README.md) / [verified（examples の 3 ファイル）] (https://github.com/apple/python-apple-fm-sdk/tree/main/examples)

### エコシステム・実利用状況
- **採用事例:** この Python SDK 固有の本番採用事例は確認できず（新しく小規模）。[unverified-summary] 一方、土台の **Foundation Models framework（Swift）** は Apple 公式ニュースルーム（2025-09-29）が SmartGym / Stoic / SwingVision / OmniFocus 4 / Agenda / VLLO 等の採用を列挙。SmartGym CEO のコメントあり。ただしこれらは Swift フレームワークの事例であり、本 Python SDK の事例ではない点に注意。[verified] (https://www.apple.com/newsroom/2025/09/apples-foundation-models-framework-unlocks-new-intelligent-app-experiences/)
- **盛り上がりの文脈:** ① Apple が公式に Python の口を用意したこと自体が珍しい（Foundation Models は元来 Swift 専用）。② WWDC2026（2026-06-08）の第 3 世代 Foundation Models 発表と同日に v0.2.0（画像入力）を出し、フレームワーク更新に追随。[verified（リリース日）] (https://github.com/apple/python-apple-fm-sdk/releases) / [verified（第 3 世代発表が同日）] (https://machinelearning.apple.com/research/introducing-third-generation-of-apple-foundation-models)
- **コミュニティ:** **想定よりかなり静か。** HN では「Apple Foundation Models SDK for Python」(2026-02-26) が 2 points / 0 comments、「…Documentation」(同日) が 4 points / 1 comment。バズと呼べる反応は無い。[verified（HN Algolia API の points/comments/日付）] (https://hn.algolia.com/api/v1/search?query=apple%20foundation%20models%20python&tags=story) GitHub Issues/Discussions の活発度は本調査では未取得。日本では excite/macotakara が公開を報道。[verified] (https://www.excite.co.jp/news/article/Macotakara_macotakara_50562/)
- **周辺ツール:** コミュニティ製 MCP サーバ **`yihan2099/apple-fm-mcp`** が本 SDK の上に構築（`pip install git+https://github.com/apple/python-apple-fm-sdk.git` を明記、"Built on python-apple-fm-sdk"）。Apple のオンデバイスモデルを Claude Code / Cursor / Windsurf から MCP 経由で使えるようにする。ただし ★2 と極小。[verified（README の依存記述・用途）] (https://github.com/yihan2099/apple-fm-mcp) また日本の開発者が Apple Foundation Models を **OpenAI API 互換** で叩けるようにする試み（HTTP API が無いため）を Zenn に投稿（※こちらは Swift/別経路の可能性、本 SDK 利用かは未確認）。[unverified-summary] (https://zenn.dev/platina/articles/foundation-model-fameuse)
- **評判:** 一次情報での賛否は HN の低エンゲージメントが示す通り「注目はされたが議論は薄い」。明確な否定的レビューも肯定的レビューも一次ソースでは収集できなかった。[unverified-summary] (https://hn.algolia.com/api/v1/search?query=apple%20foundation%20models%20python&tags=story)

### 他ツールとの比較・ポジショニング
| 観点 | python-apple-fm-sdk | MLX (apple/mlx) | llama.cpp / Ollama |
|---|---|---|---|
| 実行するモデル | OS 同梱の Apple Intelligence オンデバイスモデル（モデル選択不可・差し替え不可） | 任意モデルを Apple Silicon 上で実行（重みは自分で用意） | 任意の GGUF モデル（汎用 OSS） |
| 推論の実体 | Apple の Swift `FoundationModels.framework` を FFI で呼ぶ | MLX 独自エンジン（Metal） | 独自 C/C++ 推論エンジン |
| 主目的 | Swift アプリ機能の **評価**＋オンデバイス推論 | 研究・学習・任意モデル推論/学習 | ローカル汎用推論サーバ |
| HTTP API | 無し（ライブラリのみ。MCP/OpenAI 互換は別途自作） | 無し（ライブラリ） | あり（Ollama はサーバ常駐） |
| プラットフォーム | macOS 26+ / Apple Intelligence 必須 | macOS（Apple Silicon） | クロスプラットフォーム |
| ライセンス | Apache-2.0（バインディング）。モデルは OS 同梱・規約準拠 | MIT | MIT |

要点: **本 SDK は「Apple のオンデバイスモデルそのもの」を使う唯一の Python 公式経路**であり、MLX/llama.cpp/Ollama のような「任意モデルを動かす汎用ランタイム」とは目的が異なる。差し替え自由度はゼロだが、Apple Intelligence と完全に同一のモデル・ガードレールで評価できる点が代替不能。[verified（比較の各要素は本文の各一次ソースに対応）] / 比較表のうち MLX/llama.cpp の性質は一般的事実（一次再確認は本調査範囲外、`unverified-summary`）。

### 制約・注意点
- **成熟度: ごく初期（alpha）。** pyproject の classifier も Alpha。リリースは beta.1(2026-02-25)→0.1.0/0.1.1(2026-03-08)→0.2.0(2026-06-08) の 4 本。GitHub 上のコミットは 6（履歴が squash/再作成された可能性が高い＝実際の開発量はこれより多いはず）。[verified（リリース4本・コミット6）] (https://github.com/apple/python-apple-fm-sdk/releases) / [verified（Alpha classifier）] (https://github.com/apple/python-apple-fm-sdk/blob/main/pyproject.toml) / [speculation（履歴 squash）]
- **コントリビューション受付停止中:** README 明記 *"This project is not yet taking contributions. Stay tuned!"*。外部 PR は当面不可。[verified] (https://raw.githubusercontent.com/apple/python-apple-fm-sdk/main/README.md)
- **強いプラットフォームロックイン:** macOS 26.0+ / Xcode 26.0+ / Apple Silicon かつ Apple Intelligence 有効が必須。Linux/Windows・非対応 Mac では一切動かない。[verified] (https://raw.githubusercontent.com/apple/python-apple-fm-sdk/main/README.md)
- **モデルの能力上限:** 土台のオンデバイスモデルは Apple 自身が「要約・抽出・分類向け、ワールドナレッジや高度推論は非対象」と位置づけ（WWDC2025 世代は約 3B/2bit 量子化）。汎用 LLM 代替にはならない。[verified（用途・3B/2bit）] (https://machinelearning.apple.com/research/introducing-apple-foundation-models) — ただし「本 SDK が今どの世代モデルを叩くか」は SDK 側ドキュメントに明記が無く、OS/フレームワークが提供するモデル（WWDC2026 で第 3 世代 = 20B スパースが追加）に依存。SDK は特定モデル名を主張しない。[verified（第 3 世代 20B スパース・2026-06-08）] (https://machinelearning.apple.com/research/introducing-third-generation-of-apple-foundation-models) / [verified（SDK ドキュメントがモデル名/諸元に言及しないこと）] (https://apple.github.io/python-apple-fm-sdk/)
- **アダプタ学習は対象外（混同注意）:** 本 SDK は **推論・評価専用**。LoRA アダプタ学習は別の Apple 製ツールキット **Foundation Models adapter training toolkit**（`.fmadapter` を生成、PEFT/LoRA、アダプタ約 160MB）が担う。両者は別物。[verified（adapter toolkit が LoRA 学習用で別物）] (https://developer.apple.com/apple-intelligence/foundation-models-adapter/) / [verified（本 SDK の用途は評価/推論）] (https://raw.githubusercontent.com/apple/python-apple-fm-sdk/main/README.md)
- **HTTP サーバ非搭載:** ライブラリのみ。OpenAI 互換 API / MCP で使うには自作またはコミュニティ製ラッパー（`apple-fm-mcp` 等）が要る。[verified] (https://github.com/yihan2099/apple-fm-mcp)
- **二次情報の混乱に注意:** 一部の二次記事（byteiota）は「WWDC2026 で発表」「Claude/Gemini に差し替え可能なモデル抽象化層」等を述べるが、本 SDK のリリースは 2026-02 beta が初出で、モデル差し替え機能は本 SDK の一次ソースで確認できない。これらは `speculation` 扱いとし採用しない。[speculation]

### 深掘り候補（コードリーディング対象）
本サブエージェントは実装本体を未読。以下は vendor-inspector 等での深掘り推奨箇所（パスは GitHub default branch `main`）:
- `foundation-models-c/Sources/FoundationModelsCBindings/FoundationModelsCBindings.swift` と `include/FoundationModels.h` — Swift→C で**どの Foundation Models API が露出/非露出か**の確定（本調査で C 関数の網羅列挙は未達: ヘッダ raw が 404 だった）。
- `src/apple_fm_sdk/core.py` — ネイティブライブラリのロード戦略、`SystemLanguageModel` のライフサイクル、`is_available` の失敗理由マッピング。
- `src/apple_fm_sdk/session.py` の `_ManagedObject` / `_reset_task_state` — FFI リソース管理とキャンセル処理、async とネイティブ呼び出しの橋渡し。
- `src/apple_fm_sdk/type_conversion.py` / `c_helpers.py` — Python⇄C のマーシャリング（メモリ安全性の要）。
- `src/apple_fm_sdk/generable.py` / `generation_schema.py` / `generation_guide.py` — `@generable` がクラスからどうスキーマを構築し、`guide()` 制約を C 層へ渡すか。
- `build_backend.py` + `bin/build-distribution.sh` — Swift パッケージを dylib にビルドし wheel へ同梱する独自ビルドパイプライン。
- `tests/test_memory_stress.py` — FFI リーク検証の具体的観点（深掘りで設計意図が読める）。
