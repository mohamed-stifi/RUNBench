# 01 — Overview

## Goal

Systematic benchmarking framework + runtime to evaluate AI agents automating data operations on Cloudera CDP. End goal: zero humans in operating loop.

## Scope

- RUN task classes only (see `09-task-classes.md`, source `tasks-examples.md`).
- Platform: CDP · Airflow · Spark · Impala · Hive · Ozone · Nifi · Ranger · YARN · Cloudera Manager.

## Non-goals (v1)

- No BUILD/GOV lanes, no production CDP cluster, no general chat eval.

## Principles

1. Reproducible: pinned image + fault injection + oracle `solution.sh`.
2. Pluggable: agent and scenario added without core changes.
3. Objective: execution-based scoring vs ground truth.
4. Safe: read-only by default, destructive actions gated, `abstain` scored.
5. Comparable: versioned results, mean ± CI, never overwrite history.

## Definition of Done

- Any agent (harness separate) plugs in and is evaluated.
- Any scenario added is evaluable by existing/future agents.
- Results in leaderboard, filterable by agent, scenario, L0-L5, metrics via dashboard.
