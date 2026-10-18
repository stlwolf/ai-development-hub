# ADR-003: Skip unsupported / empty thread formats

- **Status:** Accepted
- **Date:** 2026-02-21 (rewritten 2026-10-18)

## Context

Some threads have `conversationState` values that do not yield turn data (e.g. empty / `"~"` placeholders, or storage paths this tool does not know).

## Decision

**Do not aggressively reverse-engineer every Cursor format.** Skip those threads with an explicit warning; continue exporting the rest.

## Rationale

- Empty threads have nothing to export
- Unknown storage layouts track Cursor internals; chasing them is unbounded work
- Fail-soft keeps batch export usable (`export --all`)

## Consequences

- Users may see “newer data format not yet supported” (or equivalent) for some IDs
- Adding a new storage path later is localized to the conversation-state lookup
