# Facts Template — エラー深掘り検証用

事実と解釈を物理的に分離し、AIエージェントへのコンテキスト供給を標準化するテンプレート。

## 使い方

1. このテンプレートをコピーして `tmp/facts.md` として使用
2. Phase 1（事実収集）で各セクションを埋める
3. 品質ゲートを確認してから Phase 2（仮説生成）に進む

---

## facts.md テンプレート

```yaml
# facts.md
# エラー深掘り検証 — 確定事実ドキュメント
# 事実（観測）と解釈（仮説）を完全分離する

analysis_freeze_time: "YYYY-MM-DDTHH:MM:SS+09:00"

# ============================================================
# 1. 観測事実（Observations）
# confidence: confirmed | inferred | unknown
# ============================================================

sentry:
  issue_id: ""
  event_id: ""
  error_message: ""
  environment: ""              # staging | production
  first_seen: ""
  last_seen: ""
  count: 0
  user_count: 0
  frequency: ""                # 常時 | 特定条件 | 不明

  # --- 発火コンテキスト ---
  url: ""                      # 発火時のURL
  user_agent: ""               # ブラウザ/クライアント判別用
  request_params: {}           # GET/POSTパラメータ（最重要）
  stack_trace: ""              # 関連部分のみ
  local_variables: {}          # スタックトレース上のローカル変数
  breadcrumbs: []              # Sentry breadcrumbs（関連部分のみ）

  confidence: confirmed        # Sentry APIから直接取得 → confirmed

backend:
  api_endpoint: ""             # 例: GET /api/v1/resource/action
  http_method: ""
  routing_file: ""             # ルーティング定義のファイル:行番号
  controller_action: ""        # 例: Controller::method()
  error_line: 0                # 発火行番号
  branching_conditions:        # メソッド内の分岐条件（複数パスがある場合）
    - condition: ""
      affected_line: 0
      formula: ""
  confidence: confirmed        # コードから直接確認 → confirmed

frontend:
  component: ""                # API呼び出し元コンポーネント
  page_path: ""                # 画面パス
  api_function: ""             # API呼び出し関数名
  api_file: ""                 # API定義ファイルパス
  trigger_method: ""           # mounted | click | watch 等
  in_main_repo: true           # メインリポジトリ内にあるか
  alternative_pages: []        # 同じAPIを呼ぶ別ページ
  confidence: confirmed        # confirmed | inferred

code_slices:                   # 実際のコードスニペット（プロンプト埋め込み用）
  - file: ""
    lines: ""                  # 例: "100-120"
    relevance: ""              # このコードが重要な理由
    snippet: |
      # 実際のコードをここに貼る

# ============================================================
# 2. 解釈・仮説（Interpretations）
# 事実セクションとは明確に分離する
# ============================================================

interpretations:
  - hypothesis: ""
    basis: ""                  # どの事実に基づくか
    confidence: inferred       # inferred | speculative

# ============================================================
# 3. 再現に必要なデータ条件（Preconditions）
# ============================================================

preconditions:
  - ""                         # 例: 特定のデータ型、権限、期間、データ状態

# ============================================================
# 4. 未確定事項（Unknowns）
# ============================================================

unknowns:
  - ""

# ============================================================
# 5. 否定済み経路（Excluded Paths）— 再調査防止
# ============================================================

excluded_paths:
  - path: ""
    reason: ""

# ============================================================
# 6. 品質ゲートチェックリスト
# ============================================================

quality_gate:
  request_params_available: false    # Sentry の request_params が取得できたか
  code_path_narrowed: false          # 複数パスが絞れたか
  frontend_identified: false         # 発火元のフロントエンドが特定できたか
  code_snippet_embedded: false       # 最低1つのコードスニペットが埋め込まれたか
  facts_interpretation_separated: false  # 事実と解釈が分離されているか
  gate_passed: false                 # 全項目 true → Phase 2 に進める

  # 特定不能出口（品質ゲートを通過できない場合）
  unable_to_determine:
    - item: ""                       # どの項目が特定不能か
      fallback: ""                   # 候補列挙など、代替の進め方
      propagation: ""                # Phase 2 への影響（仮説分岐等）
```

---

## 記述ルール

- **事実（観測）と解釈（仮説）を完全分離する**
- facts セクションには「おそらく〜だろう」「〜と推測される」等の解釈を含めない
- 各事実に `confidence: confirmed | inferred | unknown` を付与する
- `inferred` の場合は推定根拠を明記する
- `code_slices` には実際のコードを埋め込む（ファイルパスだけでなく）

## 品質ゲートの使い方

Phase 2（仮説生成）に進む前に `quality_gate` の5項目を確認する。

- **全項目 true**: Phase 2 に進む
- **一部 false**: `unable_to_determine` に記録し、候補列挙の上で Phase 2 に進む
- Phase 2 の仮説に `confidence: inferred` として伝播させる
