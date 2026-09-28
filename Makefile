# RUNBench scenario lifecycle (Issue #04) + snapshot replay (Issue #13).
COMPOSE := docker compose -f env/cdp-slim/docker-compose.yml
SEED ?= 7
REPLAY_AGENT ?= null
N ?= 3

.PHONY: start-scenario stop-scenario snapshot replay

# Brings up env, waits healthy, injects fault, shows failed DAG state.
# Usage: make start-scenario SCENARIO=run.dag-failure.001 [SEED=7]
start-scenario:
ifndef SCENARIO
	$(error SCENARIO required, e.g. make start-scenario SCENARIO=run.dag-failure.001)
endif
ifeq ($(SCENARIO),run.dag-failure.001)
	SEED=$(SEED) $(COMPOSE) up --build -d
	sh env/cdp-slim/waiters/wait-healthy.sh 120
	SEED=$(SEED) sh scenarios/$(SCENARIO)/fault-inject.sh $(SEED)
else
	$(error unsupported SCENARIO=$(SCENARIO) — v1 supports run.dag-failure.001 only)
endif

# Tears everything down (containers + volumes + built image state).
stop-scenario:
	$(COMPOSE) down -v

# Captures a versioned snapshot of the (already started+injected) scenario env.
# Usage: make snapshot SCENARIO=run.dag-failure.001 [SEED=7]
snapshot:
ifndef SCENARIO
	$(error SCENARIO required, e.g. make snapshot SCENARIO=run.dag-failure.001)
endif
	sh env/snapshot/capture.sh $(SCENARIO) $(SEED)

# Deterministic diagnosis-only replay: runs the agent N times against the
# read-only snapshot with zero live containers; outputs must be diff-clean.
# Usage: make replay SCENARIO=run.dag-failure.001 [REPLAY_AGENT=null] [SEED=7] [N=3]
replay:
ifndef SCENARIO
	$(error SCENARIO required, e.g. make replay SCENARIO=run.dag-failure.001)
endif
ifeq ($(REPLAY_AGENT),null)
	$(eval AGENT_SH := harness/null-agent/run.sh)
else ifeq ($(REPLAY_AGENT),baseline)
	$(eval AGENT_SH := agents/baseline/run.sh)
else
	$(error unsupported REPLAY_AGENT=$(REPLAY_AGENT) — v1 supports null|baseline)
endif
	rm -rf replay && mkdir -p replay
	if [ ! -f env/snapshots/$(SCENARIO)/snap-seed$(SEED)/manifest.json ]; then \
	  sh env/snapshot/capture.sh --from-state env/snapshot/seed-states/$(SCENARIO)-seed$(SEED) $(SCENARIO) $(SEED) env/snapshots || exit 1; \
	fi
	for i in $$(seq 1 $(N)); do \
	  sh env/snapshot/replay.sh env/snapshots/$(SCENARIO)/snap-seed$(SEED) $(AGENT_SH) replay/out-$$i || exit 1; \
	done
	for i in $$(seq 2 $(N)); do \
	  diff -q replay/out-1/result.json replay/out-$$i/result.json || { echo "REPLAY-FLAKE: run $$i differs"; exit 1; }; \
	done
	echo "REPLAY-DETERMINISTIC: $(N) runs diff-clean (zero live containers)"
	sh evaluator/evaluate.sh scenarios/$(SCENARIO).yaml replay/out-1/result.json env/snapshots/$(SCENARIO)/snap-seed$(SEED)/state replay/verdict.json 4
	cat replay/verdict.json; echo
