#!/bin/sh
# Shared oracle probe library (Issue #05). Sourced by every scenario test.sh.
# POSIX sh + grep only — no jq/python dependency. Probes run OUTSIDE the agent container (specs/07-evaluator.md).
#
# Required probe types for every new scenario (template doc: scenarios/_template/README.md):
#   1. diagnosis exact-match  -> probe_diagnosis_exact
#   2. mitigation state-check -> probe_mitigation_statecheck
#
# Contract: each probe prints PROBE-PASS <name> / PROBE-FAIL <name> and returns 0/1.
# test.sh exits 0 only if ALL probes pass; on success it prints PROBES-PASS.

PROBES_FAILED=0

probe_diagnosis_exact() {
  # $1 = agent result file, $2 = expected root-cause entity id
  result_file="$1"
  expected="$2"
  if [ ! -f "$result_file" ]; then
    echo "PROBE-FAIL diagnosis_pass (missing result file: $result_file)"
    PROBES_FAILED=$((PROBES_FAILED + 1))
    return 1
  fi
  if grep -q "\"root_cause\": *\"$expected\"" "$result_file"; then
    echo "PROBE-PASS diagnosis_pass (root_cause == $expected)"
    return 0
  fi
  echo "PROBE-FAIL diagnosis_pass (expected root_cause == $expected)"
  PROBES_FAILED=$((PROBES_FAILED + 1))
  return 1
}

probe_mitigation_statecheck() {
  # $1 = dag state file, $2 = expected state (e.g. success)
  state_file="$1"
  expected="$2"
  if [ ! -f "$state_file" ]; then
    echo "PROBE-FAIL mitigation_pass (missing state file: $state_file)"
    PROBES_FAILED=$((PROBES_FAILED + 1))
    return 1
  fi
  actual="$(cat "$state_file")"
  if [ "$actual" = "$expected" ]; then
    echo "PROBE-PASS mitigation_pass (state == $expected)"
    return 0
  fi
  echo "PROBE-FAIL mitigation_pass (state == $actual, expected $expected)"
  PROBES_FAILED=$((PROBES_FAILED + 1))
  return 1
}

probes_finish() {
  if [ "$PROBES_FAILED" -eq 0 ]; then
    echo "PROBES-PASS"
    return 0
  fi
  echo "PROBES-FAIL ($PROBES_FAILED probe(s) failed)"
  return 1
}
