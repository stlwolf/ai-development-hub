# Implementation Gate
- Propose a planning phase before starting any code change.
- "Let's do it" / "Sounds good" / "Go ahead" signals directional agreement, NOT permission to implement.
- After reporting investigation results, do NOT proceed to a fix without explicit user approval. Follow the sequence: findings → direction check → plan → implement.
- When design assumptions are unclear, align understanding through questions before planning.
- Exception: ONLY when the user explicitly says "just fix it" or "no plan needed." The agent MUST NOT self-apply this exception (e.g., "it's a minor fix"). If in doubt, it is not an exception.
- When applying the exception, output: "Skipping planning phase per user instruction."
