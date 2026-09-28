# Fixture image for the Harbor task-dir contract (Issue #01).
# Base digest resolved via `docker inspect alpine:3.20` — repin on upgrade.
FROM alpine:3.20@sha256:d9e853e87e55526f6b2917df91a2115c36dd7c696a35be12163d44e6e2a4b6bc

WORKDIR /task

# Agent-visible files ONLY. solution/ and tests/ are mounted :ro at verify
# time and must NEVER be baked into the image (verified in Issue #01 acceptance).
COPY task.toml instruction.md ./

CMD ["sh"]
