#!/bin/bash

set -euo pipefail

# Stop and remove legacy containers that are not part of the bk-kafka pod
# Targets: zookeeper, kafka-broker, kafka-ui (old names)

targets=(zookeeper kafka-broker kafka-ui)

echo "🧹 Cleaning up legacy containers (non-pod)..."
for name in "${targets[@]}"; do
  if podman container exists "$name"; then
    echo "Stopping $name..."
    podman stop "$name" || true
    echo "Removing $name..."
    podman rm "$name" || true
  fi
done

echo "✅ Cleanup done. If ports :2181, :9092, :8081 were in use, they should be freed now."
