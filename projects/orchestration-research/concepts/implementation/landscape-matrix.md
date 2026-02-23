# Landscape Matrix — 21ツール実装特性マトリクス

> 21ツールの実装特性を一覧化し、自前ツール構築時のプラットフォーム選定の参考とする。

## 全体マトリクス

| ツール | 言語 | IF型 | デプロイ | ラッパー分類 | 設定スタイル | 外部依存 |
|---|---|---|---|---|---|---|
| **TAKT** | TypeScript | CLI | npm global | スタンドアロン（SDK統合） | YAML宣言 | Node.js ≥18, LLM API |
| **Agent Orchestrator** | TypeScript | CLI + Web UI | git clone + local | CLIラッパー（複数対象） | YAML宣言 | tmux, Node.js, pnpm |
| **CAO** | Python | API Server + CLI | uv install (PyPI未公開) | CLIラッパー（複数対象） | Markdown + YAML | tmux 3.3+, Python |
| **Agent Squad** | Python / TS | Library | npm / pip | スタンドアロン | Code-first | LLM API (langchain_core) |
| **LangGraph** | Python / TS | Library | npm / pip | スタンドアロン | Code-first | LLM API (langchain-core) |
| **Mastra** | TypeScript | Library + CLI + Web UI | npm | スタンドアロン | Code-first | Node.js, LLM API |
| **ControlFlow** | Python | Library | pip (archived) | スタンドアロン | Code-first | Prefect 3.0, langchain_core |
| **AutoGen** | Python (.NETも) | Library + GUI | pip | スタンドアロン | Code-first | LLM API, Docker (optional) |
| **CrewAI** | Python | Library + CLI | pip (uv) | スタンドアロン | Code + YAML hybrid | LLM API |
| **OpenAI Agents SDK** | Python / TS | Library | pip / npm | スタンドアロン | Code-first | LLM API (OpenAI + LiteLLM) |
| **Google ADK** | Python / Go / Java / TS | Library + Web UI | pip | スタンドアロン | Code-first | LLM API, Google Cloud (opt) |
| **MetaGPT** | Python | Library + CLI | pip | スタンドアロン | Code + config.yaml | LLM API (10+プロバイダ) |
| **BeeAI** | TypeScript / Python | Library + Serve Module | npm / pip | スタンドアロン | Code-first | LLM API (20+プロバイダ) |
| **PydanticAI** | Python | Library + CLI (clai) | pip | スタンドアロン | Code-first | LLM API (20+プロバイダ) |
| **OpenHands** | Python | CLI + Web UI + API | Docker container | スタンドアロン | YAML + Code | Docker必須, LLM API |
| **SWE-agent** | Python | CLI | pip / Docker | スタンドアロン | YAML駆動 | Docker (opt), LLM API |
| **Aider** | Python | CLI | pip / standalone binary | スタンドアロン | YAML (.aider.conf.yml) | git, LLM API |
| **Claude Flow** | TypeScript | CLI | npm | CLIラッパー（Claude Code） | Code-first | Claude Code CLI |
| **oh-my-claude-code** | JavaScript | Plugin | npm / local | CLIラッパー（Claude Code） | YAML frontmatter | Claude Code, Node.js 18+ |
| **o-m-cc** | Shell (Bash) | Plugin | local (ビルドなし) | CLIラッパー（Claude Code） | Markdown frontmatter | Claude Code, git/jj |
| **PentAGI** | Go / TypeScript | CLI + API + Web UI | Go binary / Docker | スタンドアロン | Template (.tmpl) | Docker, Neo4j, LLM API |
| **Orca** | Rust | Library | Library (未公開) | スタンドアロン | Handlebars + Code | LLM API, Qdrant (opt) |

**凡例**:
- **IF型**: インターフェース型（Library / CLI / Web UI / API Server / Plugin / GUI）
- **ラッパー分類**: 詳細は [wrapper-vs-standalone.md](./wrapper-vs-standalone.md)
- **外部依存**: ランタイムに必要な外部サービス・ツール（LLM APIは全ツール共通のため省略可）

## 詳細は個別ファイルを参照

- [interface-types.md](./interface-types.md) — インターフェース型の分析
- [wrapper-vs-standalone.md](./wrapper-vs-standalone.md) — ラッパー vs スタンドアロンの分析
- [config-styles.md](./config-styles.md) — 設定スタイルの分析
