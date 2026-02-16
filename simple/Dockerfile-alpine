# syntax = docker/dockerfile:1.19
# The repo (including the .git directory) is extracted into a scratch layer for improved caching.

FROM scratch as repo
ADD ./repo.tar .

# OpsChain Step Runner Docker images must be based on an opschain-runner(-*) base image.
FROM alpine

COPY --link --chown=10001:10001 --from=repo --exclude=.git / /opt/opschain/

COPY --from=repo --chmod=0755 simple/simple-agent.sh /opt/opschain/agent.sh
