# AGENTS.md

## Goal

Build systematic benchmarking framework and runtime environment designed to evaluate AI agents tasked with automating data operations (see task classes in `tasks-examples.md`).

The framework must contain a robust architecture comprising:

- **AI Agent** – the system under test, tasked with automating data operations.
- **Scenario Specification** – declarative definition of tasks, initial state, and success criteria (derived from `tasks-examples.md` task classes).
- **Environment** – reproducible runtime (Cloudera CDP · Airflow · Spark · Impala · Hive · Ozone · Nifi and other CDP/Hadoop ecosystem) in which the agent operates.
- **Evaluator** – objective scoring of agent runs against ground truth / human baselines, with support for abstention and evidence-linked diagnosis.
- **Leaderboard** – comparable, versioned results across agents, scenarios, and autonomy layers L0 (manual) to L5 (full autonomy).

End goal: Zero humans in the operating loop.

## Reference

ITBench paper https://arxiv.org/pdf/2502.05352, repo https://github.com/itbench-hub/ITBench/tree/main. We will build a platform like this to evaluate candidate agents in data operations.

## Working Agreements

- Commits are atomic: one logical change per commit, always in a working state.
- Every commit message serves as docs for agent communication: what changed, why, and how it was verified.

Sample commit description:

```
feat(scenarios): add Airflow DAG failure scenario spec

Context: Job and DAG failure diagnosis (RUN class, L1->L4).
Change: add scenario YAML + initial state + success criteria.
Verification: `scenario validate` passes; evaluator scores ground truth run.
Refs: tasks-examples.md
```

## Design Guidance

- Implementation and designs must follow best practices at all times.
- Stay continuously inspired by ITBench: when building specs and implementing, analyze ITBench and extract its design decisions, plus survey similar benchmarks.
- Use web search and subagents for that analysis (deferred — do this during spec-building and implementation).
- Skills provide specialized instructions and workflows for specific tasks. Use the skill tool to load a skill when a task matches its description.

## Documentation

- Documentation is the source of truth, lives in `docs/`.
- Any code change (added, updated, deleted) must be followed by the same change in documentation: grep it, find target parts, apply the change.
- Keep docs short, structured, and easy to read so humans and agents can extract information easily.

## Specs

- Specs are the source of truth for guiding all work toward the system target, live in `specs/`.
- Create specs in a very structured and organized way so they easily guide implementation and docs.
- When specs change, adapt the equivalent implementation and docs to match.

## Context Gathering

When something needs more context, gather it in this order:

1. ITBench first — grill the paper, repo, and other related ITBench resources.
2. Similar benchmarks — survey comparable systems and extract design decisions.
3. Web search and subagents — use for broader research.
4. Human — ask the human only as a last resort.

## Definition of Done

Done when:

- Any agent (harness implemented separately) can be plugged in and evaluated without changing the core system.
- Any scenario can be added to the benchmark, and existing/future agents can be evaluated on it.
- Results appear in the leaderboard, comparable and filterable via dashboard by agent, scenario, autonomy layer (L0-L5), and metrics.
