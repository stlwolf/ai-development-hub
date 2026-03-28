---
source_url: https://cobusgreyling.medium.com/the-rise-of-ai-harness-engineering-5f5220de393e
fetched_at: 2026-03-28
capture: cursor-web-fetch
note: "Medium header, byline, and tail author/tags/footer stripped; title block preserved."
---
# **The Rise of AI Harness Engineering**

## AI Agents needed SDKs, then Frameworks, then Scaffolding. Now they need a Harness.

I’ve written about the three architectural approaches to building AI Agents: [SDKs, Frameworks and Scaffolding](https://cobusgreyling.substack.com/p/architecting-agentic-ai-how-sdks).

Each one sits at a different point on the [flexibility-versus-structure](https://cobusgreyling.substack.com/p/architecting-agentic-ai-sdks-vs-frameworks) spectrum.

> A fourth pattern has emerged in 2026 that sits above all three. It’s called a Harness.

Both [OpenAI](https://openai.com/index/harness-engineering/) and [Anthropic](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents) are now using the term formally.

[Martin Fowler](https://martinfowler.com/articles/exploring-gen-ai/harness-engineering.html) has written about it. An [arXiv paper](https://arxiv.org/abs/2603.05344) formalises it.

This is not a **_buzzword_**, it’s the missing architectural layer that determines whether AI Agents actually work in production.

> Harness Engineering is the missing architectural layer that determines whether AI Agents actually work in production.

## Bottom line

A harness is not the agent.

It’s the software system that governs how the agent operates.

It manages the full lifecycle…tools, memory, retries, human approvals, context engineering, sub-agents…so the model can focus on reasoning.

[Philipp Schmid](https://www.philschmid.de/agent-harness-2026) put it best with a computer analogy…

Press enter or click to view image in full size

![Image 4](https://cobusgreyling.medium.com/the-rise-of-ai-harness-engineering-5f5220de393e)

The model is raw processing capability.

The context window is limited working memory.

The harness is the operating system…managing context, initialisation sequences and standard tool drivers.

The agent is the application that runs on top.

## Where a harness fits in the architecture stack

I previously covered [three architectural approaches](https://cobusgreyling.substack.com/p/architecting-agentic-ai-how-sdks) for building AI Agents.

Here is how a harness relates to each.

Press enter or click to view image in full size

![Image 5](https://cobusgreyling.medium.com/the-rise-of-ai-harness-engineering-5f5220de393e)

SDKs, Scaffolding and Frameworks answer the question of **_how you build_**an AI Agent.

A Harness answers a different question entirely, _how the agent runs_.

You can build a harness using any of the three. The harness is not a replacement for them. It’s a layer above.

## Four approaches compared

Press enter or click to view image in full size

![Image 6](https://cobusgreyling.medium.com/the-rise-of-ai-harness-engineering-5f5220de393e)

## Six components of a harness

The [parallel.ai](https://parallel.ai/articles/what-is-an-agent-harness) team identified six core components…

This aligns with what both [OpenAI](https://openai.com/index/harness-engineering/) and [Anthropic](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents) have published.

Press enter or click to view image in full size

![Image 7](https://cobusgreyling.medium.com/the-rise-of-ai-harness-engineering-5f5220de393e)

### Tool Integration Layer

Connects the model to external APIs, databases, code execution environments, and custom tools via defined protocols.

### Memory and State Management

Multi-layered memory (working context, session state, long-term memory) that persists beyond a single context window.

[Anthropic’s approach](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents) uses progress files and git history to bridge sessions.

### Context Engineering and Prompt Management

Dynamically curates what information appears in each model invocation.

Not static prompt templates, active context selection based on the current task state.

### Planning and Decomposition

Guides models through structured task sequences rather than attempting everything in one pass.

### Verification and Guardrails

Validation checks, format verification, safety filters. The self-correcting loop. When the agent struggles, the harness treats it as a signal to identify what’s missing.

### Modularity and Extensibility

Pluggable components that can be enabled, disabled, or replaced independently.

## Real harnesses in production

Claude Code is a harness.

It reads entire codebases, manages filesystem access, spawns sub-agents, handles tool orchestration, maintains memory across sessions and implements guardrails.

> Developers focus on the task. The harness manages everything else.

[OpenAI Codex](https://openai.com/index/harness-engineering) uses harness engineering.

Their team built a codebase of over 1 million lines with **_no manually typed code at all_**, treating the harness as the primary interface.

When the agent struggles, they feed improvements back into the repository. Context engineering, architectural constraints, and periodic cleanup agents form the core.

[OpenAI’s CUA Sample App](https://github.com/openai/openai-cua-sample-app) is a harness for computer use.

The runner manages the screenshot → actions → verify → repeat loop.

The model decides what to do. The harness executes it safely.

## The Framework Layer is Collapsing into the Harness

In my recent piece on [the disappearing framework layer](https://cobusgreyling.substack.com/p/when-the-ai-framework-layer-disappears), I argued that models are absorbing capabilities traditionally handled by multi-agent frameworks.

Agent definition, message routing, task lifecycle, dependency management, spawning workers…roughly 80% of what developers use a framework for, the model now handles natively.

The remaining 20%: persistence, deterministic replay, cost control, observability, error recovery — is exactly what a harness provides.

Press enter or click to view image in full size

![Image 8](https://cobusgreyling.medium.com/the-rise-of-ai-harness-engineering-5f5220de393e)

The framework layer isn’t just disappearing. It’s splitting. The intelligence moves into the model. The infrastructure moves into the harness.

## Harness vs Framework

A framework tells the developer how to structure an application.

A harness tells the agent how to operate safely.

With a framework, the developer writes the orchestration logic.

With a harness, the model makes the plan. The harness keeps it on track.

Press enter or click to view image in full size

![Image 9](https://cobusgreyling.medium.com/the-rise-of-ai-harness-engineering-5f5220de393e)

## Practical Implications

For teams building AI Agents today, the question is shifting.

It’s no longer “which framework should we use?” It’s “what does our harness look like?”

The harness determines whether an agent succeeds or fails.

Great harnesses manage human approvals, filesystem access, tool orchestration, sub-agents, prompts, and lifecycle — intervening minimally but preventing catastrophic failures.

Start simple.

Build robust atomic tools. Let the model make the plan.

Add guardrails, retries, and verification.

That’s harness engineering.

## Lastly

**Markdown/prompt harness** (like Anthropic’s CLAUDE.md skills) embeds the orchestration instructions directly in the system prompt or structured markdown files.

The LLM itself becomes the loop controller — it reads the harness rules and follows them.

Best when the LLM is capable enough to self-direct and you want rapid iteration without code changes.

Press enter or click to view image in full size

![Image 10](https://cobusgreyling.medium.com/the-rise-of-ai-harness-engineering-5f5220de393e)

[**_Chief AI Evangelist_**](https://www.linkedin.com/in/cobusgreyling/)**_@_**[_Kore.ai_](https://blog.kore.ai/cobus-greyling/the-shifting-vocabulary-of-ai//?utm_medium=OrganicSocial&utm_source=Medium&utm_campaign=CobusPostFeed&utm_term=Medium22112024)_| I’m passionate about exploring the intersection of AI and language. From Language Models, AI Agents to Agentic Applications, Development Frameworks & Data-Centric Productivity Tools, I share insights and ideas on how these technologies are shaping the future._

Press enter or click to view image in full size

![Image 11](https://cobusgreyling.medium.com/the-rise-of-ai-harness-engineering-5f5220de393e)

[Software Engineering](https://medium.com/tag/software-engineering?source=post_page-----5f5220de393e---------------------------------------)

[Software Development](https://medium.com/tag/software-development?source=post_page-----5f5220de393e---------------------------------------)

[Machine Learning](https://medium.com/tag/machine-learning?source=post_page-----5f5220de393e---------------------------------------)

[Large Language Models](https://medium.com/tag/large-language-models?source=post_page-----5f5220de393e---------------------------------------)

[Artificial Intelligence](https://medium.com/tag/artificial-intelligence?source=post_page-----5f5220de393e---------------------------------------)

[](https://medium.com/m/signin?actionUrl=https%3A%2F%2Fmedium.com%2F_%2Fvote%2Fp%2F5f5220de393e&operation=register&redirect=https%3A%2F%2Fcobusgreyling.medium.com%2Fthe-rise-of-ai-harness-engineering-5f5220de393e&user=Cobus+Greyling&userId=b0fbe613be9d&source=---footer_actions--5f5220de393e---------------------clap_footer------------------)

--

[](https://medium.com/m/signin?actionUrl=https%3A%2F%2Fmedium.com%2F_%2Fvote%2Fp%2F5f5220de393e&operation=register&redirect=https%3A%2F%2Fcobusgreyling.medium.com%2Fthe-rise-of-ai-harness-engineering-5f5220de393e&user=Cobus+Greyling&userId=b0fbe613be9d&source=---footer_actions--5f5220de393e---------------------clap_footer------------------)

--

1

[](https://medium.com/m/signin?actionUrl=https%3A%2F%2Fmedium.com%2F_%2Fbookmark%2Fp%2F5f5220de393e&operation=register&redirect=https%3A%2F%2Fcobusgreyling.medium.com%2Fthe-rise-of-ai-harness-engineering-5f5220de393e&source=---footer_actions--5f5220de393e---------------------bookmark_footer------------------)

[![Image 12: Cobus Greyling](https://miro.medium.com/v2/resize:fill:96:96/1*nzfAEuujMN0s-aK6R7RcNg.jpeg)](https://cobusgreyling.medium.com/?source=post_page---post_author_info--5f5220de393e---------------------------------------)

[![Image 13: Cobus Greyling](https://miro.medium.com/v2/resize:fill:128:128/1*nzfAEuujMN0s-aK6R7RcNg.jpeg)](https://cobusgreyling.medium.com/?source=post_page---post_author_info--5f5220de393e---------------------------------------)

[## Written by Cobus Greyling](https://cobusgreyling.medium.com/?source=post_page---post_author_info--5f5220de393e---------------------------------------)

[29K followers](https://cobusgreyling.medium.com/followers?source=post_page---post_author_info--5f5220de393e---------------------------------------)

·[0 following](https://cobusgreyling.medium.com/following?source=post_page---post_author_info--5f5220de393e---------------------------------------)

at the intersection of AI & language. [www.cobusgreyling.com](http://www.cobusgreyling.com/)

## Responses (1)

[](https://policy.medium.com/medium-rules-30e5502c4eb4?source=post_page---post_responses--5f5220de393e---------------------------------------)

See all responses

[Help](https://help.medium.com/hc/en-us?source=post_page-----5f5220de393e---------------------------------------)

[Status](https://status.medium.com/?source=post_page-----5f5220de393e---------------------------------------)

[About](https://medium.com/about?autoplay=1&source=post_page-----5f5220de393e---------------------------------------)

[Careers](https://medium.com/jobs-at-medium/work-at-medium-959d1a85284e?source=post_page-----5f5220de393e---------------------------------------)

[Press](mailto:pressinquiries@medium.com)

[Blog](https://blog.medium.com/?source=post_page-----5f5220de393e---------------------------------------)

[Privacy](https://policy.medium.com/medium-privacy-policy-f03bf92035c9?source=post_page-----5f5220de393e---------------------------------------)

[Rules](https://policy.medium.com/medium-rules-30e5502c4eb4?source=post_page-----5f5220de393e---------------------------------------)

[Terms](https://policy.medium.com/medium-terms-of-service-9db0094a1e0f?source=post_page-----5f5220de393e---------------------------------------)

[Text to speech](https://speechify.com/medium?source=post_page-----5f5220de393e---------------------------------------)