# syntax = docker/dockerfile:1.19
# The repo (including the .git directory) is extracted into a scratch layer for improved caching.

ARG OPSCHAIN_BASE_RUNNER
FROM ${OPSCHAIN_BASE_RUNNER} as runner

FROM scratch as repo
ADD ./repo.tar .

# OpsChain Step Runner Docker images must be based on an opschain-runner(-*) base image.
FROM alpine

RUN apk add coreutils

COPY --from=runner --link /opt/fluent-bit /opt/fluent-bit
COPY --from=repo --link --chown=10001:10001 --exclude=.git / /opt/opschain/

COPY --from=repo --link --chmod=0755 simple/opschain-run-agent.sh /usr/bin/opschain-run-agent.sh
COPY --from=repo --chmod=0755 simple/simple-agent.sh /opt/opschain/agent.sh
