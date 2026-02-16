#!/usr/bin/env sh
set -eo pipefail -o nounset

: "${NODE_ID}"
: "${AGENT_SCRIPT_PATH}"
exec </dev/null stdbuf -oL -eL "${AGENT_SCRIPT_PATH}" 2>&1 | stdbuf -i0 /opt/fluent-bit/bin/fluent-bit --config=/opt/fluent-bit/config/agent-fluent-bit.conf
