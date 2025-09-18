#!/bin/bash

set -euo pipefail

# Script to tail Kafka environment logs

if [ -f .env ]; then
  # shellcheck disable=SC1091
  source .env
fi

POD_NAME=${POD_NAME:-bk-kafka}
TARGET=${1:-all}

case "$TARGET" in
  zk|zookeeper)
    podman logs -f ${POD_NAME}-zookeeper
    ;;
  broker|kafka)
    podman logs -f ${POD_NAME}-broker
    ;;
  ui)
    podman logs -f ${POD_NAME}-ui
    ;;
  all)
  echo "Tailing pod logs (${POD_NAME})"
    podman logs -f ${POD_NAME}-zookeeper &
    P1=$!
    podman logs -f ${POD_NAME}-broker &
    P2=$!
    podman logs -f ${POD_NAME}-ui &
    P3=$!
    wait $P1 $P2 $P3
    ;;
  *)
  echo "Usage: $0 [zk|broker|ui|all]";
    exit 1
    ;;
esac
