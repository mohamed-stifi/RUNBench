# RUNBench scenario lifecycle (Issue #04).
COMPOSE := docker compose -f env/cdp-slim/docker-compose.yml
SEED ?= 7

.PHONY: start-scenario stop-scenario

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
