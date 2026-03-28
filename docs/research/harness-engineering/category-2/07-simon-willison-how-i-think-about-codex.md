---
source_url: https://simonwillison.net/2026/Feb/22/how-i-think-about-codex/
fetched_at: 2026-03-28
capture: cursor-web-fetch
note: "Link-blog post; site chrome after main item omitted."
---
How I think about Codex

# Simon Willison's Weblog

[Subscribe](https://simonwillison.net/about/#subscribe)

 

Sponsored by: [WorkOS](https://fandf.co/4bTWrW5)— Ready to sell to Enterprise clients? Build and ship securely with WorkOS.

22nd February 2026 - Link Blog

[How I think about Codex](https://www.linkedin.com/pulse/how-i-think-about-codex-gabriel-chua-ukhic). Gabriel Chua (Developer Experience Engineer for APAC at OpenAI) provides his take on the confusing terminology behind the term "Codex", which can refer to a bunch of of different things within the OpenAI ecosystem:

In plain terms, Codex is OpenAI's software engineering agent, available through multiple interfaces, and an agent is a model plus instructions and tools, wrapped in a runtime that can execute tasks on your behalf. [...]

At a high level, I see Codex as three parts working together:

Codex = Model + Harness + Surfaces [...]

- Model + Harness = the Agent
- Surfaces = how you interact with the Agent

He defines the harness as "the collection of instructions and tools", which is notably open source and lives in the [openai/codex](https://github.com/openai/codex) repository.

Gabriel also provides the first acknowledgment I've seen from an OpenAI insider that the Codex model family are directly trained for the Codex harness:

Codex models are trained in the presence of the harness. Tool use, execution loops, compaction, and iterative verification aren't bolted on behaviors — they're part of how the model learns to operate. The harness, in turn, is shaped around how the model plans, invokes tools, and recovers from failure.

Posted [22nd February 2026](https://simonwillison.net/2026/Feb/22/) at 3:53 pm