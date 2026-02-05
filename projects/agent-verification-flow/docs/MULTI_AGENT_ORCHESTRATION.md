# マルチエージェント・オーケストレーション

## 概要

単体のAIエージェントでは複雑な検証タスクに限界がある。本ドキュメントでは、複数のエージェントが協調して動作する**マルチエージェント構成**と、それらを統括する**オーケストレーション**のアーキテクチャを定義する。

---

## 対象アーキテクチャ

本ツールは以下のような一般的なWebサービス構成を想定しています:

| レイヤー | 想定技術 |
|---------|---------|
| **フロントエンド** | SPA（Single Page Application） |
| **バックエンド** | REST API（OpenAPI/Swagger定義） |
| **認証・認可** | JWT（OAuth2/OIDC）、Session + CSRF |
| **IdP** | AWS Cognito, Auth0, Firebase Auth 等 |
| **エラー監視** | Sentry, Datadog, New Relic 等 |

マルチエージェント構成では、この各レイヤーに対応する専門エージェントを配置することで、効率的な検証を実現します。

---

## 単体エージェントの限界

### 現状の課題

| 課題 | 詳細 |
|------|------|
| **コンテキスト長の制限** | 長いセッションで初期の文脈が薄れる |
| **並列処理の困難さ** | 1エージェントは逐次処理が基本 |
| **専門性の分散** | 1エージェントが全領域をカバーするのは非効率 |
| **状態管理の複雑さ** | 複数のタスクを同時追跡すると混乱 |
| **障害の伝播** | 1箇所の失敗が全体を停止させる |

### 具体例

```
単体エージェントの場合:

User: "PR #123 を検証して"

Agent: 1. PRのコード変更を確認
       2. 影響するAPIを特定
       3. 認証を実行
       4. 各APIを順次呼び出し      ← ここで時間がかかる
       5. Sentryを確認
       6. UIを確認                 ← ブラウザ操作で時間がかかる
       7. レポートを生成

問題: 
- ステップ4と6が逐次実行（並列化できない）
- 長いセッションでステップ1の情報を忘れる
- UIテスト中にAPIテストの詳細を忘れる
```

---

## マルチエージェント・アーキテクチャ

### 基本構成

```
                    ┌─────────────────────┐
                    │    Orchestrator     │
                    │   (統括エージェント)  │
                    └──────────┬──────────┘
                               │
           ┌───────────────────┼───────────────────┐
           │                   │                   │
           ▼                   ▼                   ▼
    ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
    │ API Agent   │     │ UI Agent    │     │ Monitor     │
    │             │     │             │     │ Agent       │
    │ - API検証   │     │ - ブラウザ  │     │ - Sentry    │
    │ - 認証      │     │   操作      │     │ - ログ監視  │
    │ - レスポンス│     │ - スクショ  │     │ - アラート  │
    └─────────────┘     └─────────────┘     └─────────────┘
```

### エージェントの役割分担

| エージェント | 責務 | ツール/スキル |
|-------------|------|--------------|
| **Orchestrator** | タスク分解、進捗管理、結果統合 | タスク管理、他エージェント呼び出し |
| **API Agent** | REST API検証、JWT/Session認証、レスポンス検証 | curl, jq, 認証スクリプト |
| **UI Agent** | SPA操作、画面検証、スクリーンショット | Playwright, MCP Browser |
| **Monitor Agent** | エラー監視（Sentry等）、ログ分析、アラート確認 | Sentry/Datadog API, ログ解析 |
| **Code Agent** | コード分析、OpenAPI/Swagger解析、影響範囲特定 | grep, AST解析, OpenAPI Parser |
| **Report Agent** | 結果集約、レポート生成、通知 | Markdown, Slack API |

---

## オーケストレーション・パターン

### Pattern 1: 並列実行（Fork-Join）

独立したタスクを複数エージェントで並列実行し、結果を統合。

```
Orchestrator
    │
    ├──→ API Agent ────→ API検証結果
    │
    ├──→ UI Agent ─────→ UI検証結果      ──→ 結果統合 ──→ レポート
    │
    └──→ Monitor Agent ─→ エラー状況
```

**ユースケース**: PR検証、リリース前検証

**実装例**（疑似コード）:

```python
async def verify_pr(pr_number: int):
    # 並列実行
    api_task = api_agent.verify_apis(pr_number)
    ui_task = ui_agent.verify_ui(pr_number)
    monitor_task = monitor_agent.check_errors(pr_number)
    
    # 結果収集
    api_result, ui_result, monitor_result = await asyncio.gather(
        api_task, ui_task, monitor_task
    )
    
    # レポート生成
    return report_agent.generate(api_result, ui_result, monitor_result)
```

### Pattern 2: パイプライン（Sequential）

前のエージェントの出力を次のエージェントの入力とする。

```
Code Agent ──→ API Agent ──→ Monitor Agent ──→ Report Agent
   │              │               │                │
   │              │               │                │
   ▼              ▼               ▼                ▼
影響範囲      API検証        エラー確認        レポート
特定          実行           結果
```

**ユースケース**: 影響分析から検証まで一貫したフロー

### Pattern 3: 階層型（Hierarchical）

サブオーケストレーターを置き、複雑なタスクをさらに分解。

```
                    Orchestrator
                         │
          ┌──────────────┼──────────────┐
          ▼              ▼              ▼
    API Orchestrator  UI Orchestrator  ...
          │              │
     ┌────┼────┐    ┌────┼────┐
     ▼    ▼    ▼    ▼    ▼    ▼
   Auth JWT  Session Login List Detail
   Agent API  API Agent Agent Agent
```

**ユースケース**: 大規模システム、マイクロサービス構成

### Pattern 4: リアクティブ（Event-Driven）

イベントに応じてエージェントが動的に起動。

```
                    Event Bus
                        │
    ┌───────────────────┼───────────────────┐
    │                   │                   │
    ▼                   ▼                   ▼
┌─────────┐       ┌─────────┐       ┌─────────┐
│ On API  │       │ On Error│       │ On Build│
│ Failure │       │ Detected│       │ Complete│
└────┬────┘       └────┬────┘       └────┬────┘
     │                 │                 │
     ▼                 ▼                 ▼
 Debug Agent      Alert Agent      Deploy Agent
```

**ユースケース**: CI/CD統合、継続的監視

---

## 実装アプローチ

### 短期: Cursor Task機能の活用

Cursorの `Task` ツールでサブエージェントを起動し、簡易的なマルチエージェント構成を実現。

```
Main Agent (User対話)
    │
    ├── Task: "API Agent" ────→ api_call.sh でAPI検証
    │
    ├── Task: "UI Agent" ─────→ MCP Browser で画面確認
    │
    └── Task: "Monitor Agent" ─→ Sentry API でエラー確認
```

**利点**:
- 既存のCursor機能で実現可能
- 追加のインフラ不要

**制限**:
- エージェント間の通信が限定的
- 状態の共有が困難

### 中期: Agent Framework の導入

専用のマルチエージェントフレームワークを使用。

**候補フレームワーク**:

| フレームワーク | 特徴 | 適用場面 |
|--------------|------|---------|
| **LangGraph** | LangChain系、グラフベース | 複雑なワークフロー |
| **AutoGen** | Microsoft製、会話ベース | 協調的タスク |
| **CrewAI** | 役割ベース、シンプル | チーム型タスク |
| **Agency Swarm** | OpenAI Assistants API活用 | カスタムエージェント |

**LangGraph 実装イメージ**:

```python
from langgraph.graph import StateGraph

# 状態定義
class VerificationState(TypedDict):
    pr_number: int
    api_results: list
    ui_results: list
    monitor_results: list
    report: str

# グラフ定義
graph = StateGraph(VerificationState)

graph.add_node("analyze", code_agent.analyze)
graph.add_node("verify_api", api_agent.verify)
graph.add_node("verify_ui", ui_agent.verify)
graph.add_node("check_monitor", monitor_agent.check)
graph.add_node("generate_report", report_agent.generate)

# エッジ定義（並列実行）
graph.add_edge("analyze", "verify_api")
graph.add_edge("analyze", "verify_ui")
graph.add_edge("analyze", "check_monitor")

# 結果統合
graph.add_edge("verify_api", "generate_report")
graph.add_edge("verify_ui", "generate_report")
graph.add_edge("check_monitor", "generate_report")

# 実行
app = graph.compile()
result = app.invoke({"pr_number": 123})
```

### 長期: 自律型エージェントシステム

エージェントが自律的にタスクを分解・実行する完全自動化。

```
                    ┌─────────────────────┐
                    │   Meta Orchestrator │
                    │   (自律判断)         │
                    └──────────┬──────────┘
                               │
                    ┌──────────▼──────────┐
                    │   Knowledge Base    │
                    │   (学習・記憶)       │
                    └──────────┬──────────┘
                               │
           ┌───────────────────┼───────────────────┐
           ▼                   ▼                   ▼
    ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
    │ Dynamic     │     │ Dynamic     │     │ Dynamic     │
    │ Agent Pool  │     │ Agent Pool  │     │ Agent Pool  │
    └─────────────┘     └─────────────┘     └─────────────┘
```

**特徴**:
- タスクに応じてエージェントを動的生成
- 過去の実行履歴から学習
- 失敗時の自動リトライ・代替戦略

---

## 状態管理とコミュニケーション

### エージェント間の状態共有

```yaml
# shared_state.yaml
verification:
  pr_number: 123
  started_at: "2026-02-05T10:00:00Z"
  
  agents:
    api_agent:
      status: completed
      results:
        - endpoint: /api/users
          status: 200
          passed: true
        - endpoint: /api/items
          status: 500
          passed: false
          error: "Internal Server Error"
    
    ui_agent:
      status: running
      current_step: "login"
    
    monitor_agent:
      status: pending

  artifacts:
    - type: screenshot
      path: /tmp/screenshots/login.png
    - type: api_response
      path: /tmp/responses/users.json
```

### メッセージング・パターン

**1. 共有ファイルシステム**

```
/tmp/ai_verify/
├── state.yaml          # 全体状態
├── api_results.json    # API Agent の出力
├── ui_results.json     # UI Agent の出力
└── artifacts/          # スクリーンショット等
```

**2. イベントログ**

```
[2026-02-05 10:00:01] ORCHESTRATOR: Starting verification for PR #123
[2026-02-05 10:00:02] API_AGENT: Started API verification
[2026-02-05 10:00:03] UI_AGENT: Started UI verification
[2026-02-05 10:00:05] API_AGENT: Completed /api/users (200 OK)
[2026-02-05 10:00:10] UI_AGENT: Login successful
[2026-02-05 10:00:15] API_AGENT: Failed /api/items (500 Error)
[2026-02-05 10:00:20] ORCHESTRATOR: API verification completed with errors
```

**3. 構造化メッセージ**（将来）

```json
{
  "type": "TASK_COMPLETED",
  "agent": "api_agent",
  "timestamp": "2026-02-05T10:00:15Z",
  "payload": {
    "task_id": "verify_api_items",
    "status": "failed",
    "error": "HTTP 500",
    "suggestion": "Check server logs"
  }
}
```

---

## エラーハンドリングと回復

### 障害パターンと対処

| 障害 | 検知方法 | 対処 |
|------|---------|------|
| エージェントタイムアウト | タイムアウト検知 | リトライ or スキップ |
| JWT期限切れ | 401 レスポンス | JWT再取得 → リトライ |
| Session期限切れ | 401/403 レスポンス | 再ログイン → リトライ |
| ブラウザクラッシュ | プロセス監視 | 再起動 → リトライ |
| 依存サービス障害 | ヘルスチェック | 待機 or 代替手段 |

### リトライ戦略

```python
class RetryPolicy:
    max_attempts: int = 3
    initial_delay: float = 1.0
    backoff_multiplier: float = 2.0
    max_delay: float = 30.0

async def with_retry(task, policy: RetryPolicy):
    for attempt in range(policy.max_attempts):
        try:
            return await task()
        except RecoverableError as e:
            if attempt == policy.max_attempts - 1:
                raise
            delay = min(
                policy.initial_delay * (policy.backoff_multiplier ** attempt),
                policy.max_delay
            )
            await asyncio.sleep(delay)
```

### グレースフル・デグレード

一部のエージェントが失敗しても、可能な範囲で検証を継続。

```
Orchestrator: "UI Agent がタイムアウトしました。
              API検証とMonitor確認の結果でレポートを生成します。
              UI検証は後で手動確認が必要です。"
```

---

## 実装ロードマップ

### Phase 1: 手動オーケストレーション（現在）

- シェルスクリプトによるAPI検証
- 人間がエージェントの役割を担当
- 結果は手動でドキュメント化

### Phase 2: Cursor Task 活用

- Cursorの Task 機能でサブエージェント起動
- 並列実行の初歩的実現
- 共有ファイルで状態管理

### Phase 3: 軽量フレームワーク導入

- Python スクリプトでオーケストレーション
- asyncio による並列実行
- 構造化された状態管理

### Phase 4: 本格的エージェントフレームワーク

- LangGraph / AutoGen 等の導入
- 動的なエージェント構成
- 学習と最適化

### Phase 5: 完全自律システム

- 自己修復機能
- 継続的学習
- 人間の介入を最小化

---

## 検討事項・今後の課題

### 技術的課題

- **コスト管理**: 複数エージェント起動によるAPI呼び出し増加
- **レイテンシ**: エージェント間通信のオーバーヘッド
- **デバッグ**: 分散システムのトラブルシューティング
- **テスト**: マルチエージェント構成のテスト方法

### 運用的課題

- **可観測性**: 各エージェントの状態監視
- **アラート**: 異常検知と通知
- **バージョニング**: エージェント定義の管理
- **セキュリティ**: エージェント間の認証・認可

### 研究課題

- **最適なタスク分解**: どの粒度でタスクを分割するか
- **エージェント間協調**: 競合の回避、協調の最適化
- **学習と適応**: 過去の実行からの学習
- **人間との協調**: Human-in-the-Loop の最適な設計

---

## 関連ドキュメント

- [README.md](../README.md) - 使用方法
- [DESIGN_PRINCIPLES.md](./DESIGN_PRINCIPLES.md) - 設計思想
- [LESSONS_LEARNED.md](./LESSONS_LEARNED.md) - 実践から学んだ教訓
- [USAGE.md](./USAGE.md) - 詳細な使用方法

## 参考リソース

- [LangGraph Documentation](https://langchain-ai.github.io/langgraph/)
- [AutoGen Documentation](https://microsoft.github.io/autogen/)
- [CrewAI Documentation](https://docs.crewai.com/)
- [Multi-Agent Systems (Stanford)](https://web.stanford.edu/class/cs224n/)
