# Registry

- `/issue-debug` -> `canonical/commands/investigation/issue-debug.md`
- `/research-intake` -> `canonical/commands/investigation/research-intake.md`
- `/pr-review` -> `canonical/commands/review/pr-review.md`
- `/pr-review-checklist` -> `canonical/commands/review/pr-review-checklist.md`
- `/copilot-review-response` -> `canonical/commands/review/copilot-review-response.md`
- `/peer-ai-review` -> `canonical/commands/verification/peer-ai-review.md`
- `/arena-perspectives` -> `canonical/commands/verification/arena-perspectives.md`

## Runtime Behavior

1. ユーザーが上記疑似コマンドを入力したら、対応する実体ドキュメントを読む
2. ドキュメント内のStep/Gateに沿って実行する
3. ツール固有語彙がある場合はCodexの同等機構（skills/subagents/CLI実行）に置換して運用する
