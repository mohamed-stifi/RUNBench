#!/bin/sh
# Reference solution for the hello-task fixture. Runs OUTSIDE the agent
# container at verify time (Terminal-Bench solution.sh pattern).
# POSIX sh: fixture images are slim (no bash).
set -eu

grep -E '^(id|version)' /task/task.toml
