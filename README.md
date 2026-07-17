# The Godot Benchmark: GPT 5.6 Sol, Fable & Kimi 3

Three frontier LLMs, one prompt, **one turn each**, working as autonomous agents inside the
[Ziva](https://ziva.sh) Godot harness. The task: from an empty project, build a playable 3D
parkour world where you race bots across three courses, using the CC0
[Kenney Platformer Kit](https://kenney.nl/assets/platformer-kit).

📝 Writeup: **https://ziva.sh/blogs/godot-ai-benchmark** (publishing soon)

## The prompt (given once, verbatim)

> Make a 3D parkour world where you compete against bots for time. There should be 3 races in
> the world, and you can start any of the races by walking over to their start point. Use the
> assets in Kenny_Platformer_Kit/ to build your world.

## Results

| Model | Result | Cost | Wall time | Tool calls | Play in browser | Source |
|---|---|---|---|---|---|---|
| **GPT 5.6 Sol** | ✅ Shipped | $2.94 | 9.7 min | 73 | [▶ play](https://ziva-sh.github.io/godot-llm-parkour-benchmark/sol/) | [`sol/`](sol) |
| **Claude Fable 5** | ✅ Shipped | ~$46 \* | 32.5 min | 66 | [▶ play](https://ziva-sh.github.io/godot-llm-parkour-benchmark/fable/) | [`fable/`](fable) |
| **Kimi 3** | ❌ Did not finish | $0.95 \* | DNF | 20+ | — | [`kimi/`](kimi) |

\* Sol ran on its ChatGPT login (with prompt caching). Fable and Kimi ran through a metered
gateway that did **not** cache, which inflates their cost and time; on their native subscription
logins the cost is far lower (and $0 to a subscriber). Kimi's run was killed three times by
gateway socket drops before it built a scene — an infra failure, not a model verdict.

## What's in each folder

- `<model>/` — the exact Godot 4.7 project the model produced. Open it in Godot and press Play.
- `<model>/TRANSCRIPT.md` — the model's full agent conversation (narration + every tool call).
- `<model>/stats.json` — tokens, cost, time, and the per-tool breakdown.

## How it was run

Each model got the single prompt above at its **default reasoning effort**, in a fresh copy of
the same empty project, and ran uninterrupted (no follow-up messages). Tool permissions were
auto-approved so the run was fully autonomous. Worlds were verified by each model's own in-run
playtests plus a manual code review.

Built with [Ziva](https://ziva.sh) — the AI agent that lives inside the Godot editor.
