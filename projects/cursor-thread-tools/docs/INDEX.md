# ドキュメント関連マップ

本プロジェクト配下の全ドキュメントの関連性を示す。

## ドキュメント構造

```
docs/
├── INDEX.md                    # このファイル（関連マップ）
├── VERIFICATION_MATRIX.md      # 検証マトリクス（A: ツール / B: プロセス）
├── plans/                      # 計画・キックオフ（type: plan）
│   ├── 2026-02-20-kickoff-cursor-thread-tools.md
│   └── 2026-02-20-kickoff-phase1-db-foundation.md
├── episodes/                   # 作業記録・議論経緯（type: episode）
├── decisions/                  # 確定した判断 ADR形式（type: decision）
└── raw-logs/                   # 生ログ 層3（gitignore対象、一時保管）
```

## 種別と配置ルール

DOCUMENT_CONVENTION v0 準拠。`second-opinion-verification` で確立した規約を踏襲。

| type | 配置先 | 命名 | 性質 |
|------|--------|------|------|
| `plan` | `plans/` | `YYYY-MM-DD-{kickoff\|plan}-topic.md` | 新スレッドの初期コンテキスト、検証計画 |
| `episode` | `episodes/` | `YYYY-MM-DD-topic.md` | 作業記録、セッション統合記録 |
| `decision` | `decisions/` | `ADR-NNN-topic.md` | 確定した設計判断（上書き禁止） |
| (生ログ) | `raw-logs/` | 任意（SpecStory出力そのまま等） | 一時保管、抽出後破棄可 |

### スレッド分化時のドキュメントフロー

```
スレッド N（議論・ブレスト）
  │
  ├── [raw-log] SpecStory出力 → raw-logs/ に一時保管
  │
  └── [plan/kickoff] 次スレッドの開始プロンプト
        → plans/YYYY-MM-DD-kickoff-{topic}.md
            │
            スレッド N+1（実装・検証）
              │
              ├── [episode] 作業記録
              ├── [decision] 確定した判断（ADR）
              └── [plan/kickoff] さらに次のスレッドへ...
```

キックオフは**前スレッドの議論を圧縮したスタートプロンプト**。スレッドが分化するたびに `plans/` に蓄積される。

## 全体の流れ

```
2/20  プロジェクトキックオフ（本スレッド）
      │
      ├── [plan/kickoff] 2026-02-20-kickoff-cursor-thread-tools
      │       目的、スコープ、技術的根拠（DB構造・コマンドID）
      │       4層モデルの位置づけ、検証計画
      │
      ├── [plan] VERIFICATION_MATRIX.md
      │       検証マトリクス（A: ツール実装 / B: 開発プロセス）
      │       各項目の状態・根拠を追跡し、フィードバックループを形成
      │
      ├── [raw-log] SpecStory出力（ブレスト全文）
      │       → raw-logs/ に保管、エピソード・ADR抽出の一次資料
      │
      ├── [plan/kickoff] 2026-02-20-kickoff-phase1-db-foundation
      │       Phase 1 キックオフ（peer-ai-review 3者合意済み）
      │       DB読み取り基盤検証: SQLiteライブラリ選定、agentKv:blob解明
      │       → Phase 1 子スレッドの開始プロンプトとして使用
      │
      └── Phase 1 子スレッド（DB読み取り基盤実装）
              │
              ├── [decision] ADR-001-sqlite-library.md
              │       better-sqlite3 採用（sql.js 棄却、3者合意）
              │
              ├── [episode] 2026-02-20-phase1-db-foundation.md
              │       agentKv:blob マッピング解明、拡張スキャフォールド
              │       検証マトリクス A-1-1〜A-1-5 更新
              │
              └── VERIFICATION_MATRIX.md 更新
                      A-1-1〜A-1-5 状態更新済み
```

## 他プロジェクトの関連成果物

| ファイル | 配置先 | 関連 |
|---------|--------|------|
| [DOCUMENT_CONVENTION.md](../../second-opinion-verification/docs/DOCUMENT_CONVENTION.md) | second-opinion-verification | ドキュメント規約（本プロジェクトも踏襲） |
| [context-persistence-4layer-model.md](../../../ideas/20260220/context-persistence-4layer-model.md) | ideas/ | 4層モデル（本プロジェクトは層3パイプライン） |
| [hypothesis-intentional-compression-and-promotion-flow.md](../../../ideas/20260208/hypothesis-intentional-compression-and-promotion-flow.md) | ideas/ | 意図的圧縮と昇格フロー |
| [peer-ai-review.md](../../../cursor/command/verification/peer-ai-review.md) | cursor/command | 設計判断のピアレビュー用コマンド |
| [BACKLOG #2](https://github.com/stlwolf/ai-development-hub/issues/2) | GitHub | 「会話ログ保存の仕組み構築」Issue |
