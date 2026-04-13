# Subagent Strategy

## Principles
- Actively use subagents to keep the main context clean.
- Delegate investigation, exploration, and parallel analysis to subagents.
- One task per subagent — keep them focused.
- When delegating implementation, enforce the `implementer-contract` skill (status enum, report format, self-review).

## Custom Agents First
- Prefer domain-specific custom agents over generic subagents.
- Before delegating, check project-level and user-level `agents/` directories for a matching custom agent.
- If a match exists, use it over the standard subagent.
  - Use the tool's native agent launch mechanism when available.
  - Otherwise, read the definition file and inject its full content into the subagent prompt.
- Fall back to standard subagents only when no custom agent matches.
