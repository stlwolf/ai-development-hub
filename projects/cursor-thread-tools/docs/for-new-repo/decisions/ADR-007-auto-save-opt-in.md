# ADR-007: Auto-save defaults to off (opt-in)

- **Status:** Accepted
- **Date:** 2026-02-21 (rewritten 2026-10-18)

## Context

Background export of updated threads is useful for archiving, but writing Markdown into the workspace by default can surprise users and duplicate other transcript tools.

## Decision

Default `cursorThreadTools.autoSave.intervalMinutes` to **`0` (disabled)**. Users enable explicitly.

## Rationale

- Least surprise: no unexpected `.thread-exports/` growth
- Avoid silent archival of sensitive chats
- Reduce periodic DB read load unless requested

## Consequences

- `setupAutoSave()` no-ops when interval ≤ 0
- Extension still activates on startup; timer only runs when configured
