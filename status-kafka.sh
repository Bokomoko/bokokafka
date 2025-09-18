#!/bin/bash

set -euo pipefail

# Kafka environment status script
# Project: BokoKafka

# Load .env if present
if [ -f .env ]; then
	# shellcheck disable=SC1091
	source .env
fi

BOKO_HOST=${BOKO_HOST:-bokodell14.local}
BROKER_PORT=${BROKER_PORT:-19092}
ZK_PORT=${ZK_PORT:-12181}
UI_PORT=${UI_PORT:-8087}
POD_NAME=${POD_NAME:-bk-kafka}

echo "📊 Kafka environment status (pod: ${POD_NAME})"
echo "=========================="

echo "🧩 Pod:"
podman pod ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}" | grep -E "(NAME|${POD_NAME})" || true

# Containers
echo "🐳 Containers:"
podman ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "(NAME|${POD_NAME}-)" || true

echo ""

# Ports in use (configured)
echo "🔌 Ports in use (configured):"
printf "Zookeeper: %s:%s  |  Kafka: %s:%s  |  UI: %s:%s\n" "$BOKO_HOST" "$ZK_PORT" "$BOKO_HOST" "$BROKER_PORT" "$BOKO_HOST" "$UI_PORT"
ss -tlnp | grep -E "(${ZK_PORT}|${BROKER_PORT}|${UI_PORT})" | awk '{print $4 "\t" $1}' || true

echo ""

# Connectivity test
echo "🌐 Connectivity:"
curl -s -o /dev/null -w "Kafka Web UI (${UI_PORT}): %{http_code}\n" http://${BOKO_HOST}:${UI_PORT} || echo "UI unavailable"

# Cluster status via API
echo ""
echo "🔧 Cluster status:"
curl -s http://${BOKO_HOST}:${UI_PORT}/api/clusters 2>/dev/null | jq -r '.[0] | "Status: " + (.status//"?") + " | Brokers: " + ((.brokerCount//0)|tostring)' 2>/dev/null || echo "API unavailable"
