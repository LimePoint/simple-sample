#!/usr/bin/env bash

env

echo '---'

opschain-exec env

echo '---'

opschain-write-files

echo '---'

opschain-show-properties | jq

echo '---'

opschain-show-context | jq

echo '---'

tail -F /dev/null
