#!/bin/bash

set -euo pipefail

# Script to stop Kafka environment
# Project: BokoKafka

# Load .env if present
if [ -f .env ]; then
	# shellcheck disable=SC1091
	source .env
fi

POD_NAME=${POD_NAME:-bk-kafka}

echo "🛑 Stopping Kafka environment (pod: ${POD_NAME})..."

if podman container exists ${POD_NAME}-ui; then
		echo "🌐 Stopping Kafka UI..."
	podman stop ${POD_NAME}-ui 2>/dev/null || true
fi

if podman container exists ${POD_NAME}-broker; then
		echo "🔧 Stopping Kafka broker..."
	podman stop ${POD_NAME}-broker 2>/dev/null || true
fi

if podman container exists ${POD_NAME}-zookeeper; then
		echo "📋 Stopping Zookeeper..."
	podman stop ${POD_NAME}-zookeeper 2>/dev/null || true
fi

if podman pod exists ${POD_NAME}; then
		echo "📦 Stopping pod..."
	podman pod stop ${POD_NAME} 2>/dev/null || true
fi

echo "✅ Kafka environment stopped!"
