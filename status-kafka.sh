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
ZK_PORT=${ZK_PORT:-19181}
UI_PORT=${UI_PORT:-19081}
POD_NAME=${POD_NAME:-bk-kafka}

echo "📊 Kafka environment status (pod: ${POD_NAME})"
echo "=========================="

echo "🧩 Pod:"
podman pod ps --format "table {{.Name}}\t{{.Status}}" | grep -E "(NAME|${POD_NAME})" || true

# Containers
echo "🐳 Containers:"
podman ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "(NAME|${POD_NAME}-)" || true

# Detect legacy containers (not part of our pod naming)
echo ""
echo "🕵️ Legacy containers (potential duplicates):"
legacy=$(podman ps --format "{{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "^(zookeeper|kafka-broker|kafka-ui)\b" || true)
if [ -n "${legacy}" ]; then
	echo "⚠️ Found legacy containers running that may conflict:"
	echo "${legacy}"
else
	echo "None detected"
fi

echo ""

# Ports in use (configured)
echo "🔌 Ports in use (configured):"
printf "Zookeeper: %s:%s  |  Kafka: %s:%s  |  UI: %s:%s\n" "$BOKO_HOST" "$ZK_PORT" "$BOKO_HOST" "$BROKER_PORT" "$BOKO_HOST" "$UI_PORT"
ss -tlnp | grep -E "(${ZK_PORT}|${BROKER_PORT}|${UI_PORT})" | awk '{print $4 "\t" $1}' || true

# Also check standard ports that may be used by legacy stack
echo ""
echo "🔌 Standard ports (legacy defaults) in use:"
ss -tlnp | grep -E "(:2181|:9092|:8081)\b" | awk '{print $4 "\t" $1}' || echo "None"

echo ""

# Connectivity test (external)
echo "🌐 Connectivity (external):"
curl -s -o /dev/null -w "Kafka Web UI (${UI_PORT}): %{http_code}\n" http://${BOKO_HOST}:${UI_PORT} || echo "UI unavailable"

# External TCP checks for Broker and Zookeeper
host_tcp_check() {
	local host=$1 port=$2
	if timeout 1 bash -lc "</dev/tcp/${host}/${port}" 2>/dev/null; then
		echo OK
	else
		echo FAIL
	fi
}
printf "Kafka Broker (%s): %s\n" "${BROKER_PORT}" "$(host_tcp_check "${BOKO_HOST}" "${BROKER_PORT}")"
printf "Zookeeper (%s): %s\n" "${ZK_PORT}" "$(host_tcp_check "${BOKO_HOST}" "${ZK_PORT}")"

# Internal health checks (inside containers)
echo ""
echo "🩺 Internal health checks (pod network):"

# Pick a container with bash to perform port checks from within the pod network
pick_container_with_bash() {
	for c in ${POD_NAME}-broker ${POD_NAME}-zookeeper ${POD_NAME}-ui; do
		if podman container exists "$c" >/dev/null 2>&1; then
			if podman exec "$c" bash -lc 'exit 0' >/dev/null 2>&1; then
				echo "$c"; return 0
			fi
		fi
	done
	echo ""; return 1
}

check_from_container() {
	local container=$1 port=$2
	if [ -z "$container" ]; then
		echo "N/A"; return 0
	fi
	if podman exec "$container" bash -lc "</dev/tcp/127.0.0.1/${port}" >/dev/null 2>&1; then
		echo OK
	else
		echo FAIL
	fi
}

CHECK_CONTAINER=$(pick_container_with_bash)
ui_check=$(check_from_container "$CHECK_CONTAINER" 8080)
broker_check=$(check_from_container "$CHECK_CONTAINER" 9092)
zk_check=$(check_from_container "$CHECK_CONTAINER" 2181)
printf "UI(8080): %s | Broker(9092): %s | Zookeeper(2181): %s\n" "$ui_check" "$broker_check" "$zk_check"

# Cluster status via API (external)
echo ""
echo "🔧 Cluster status:"
curl -s http://${BOKO_HOST}:${UI_PORT}/api/clusters 2>/dev/null | jq -r '.[0] | "Status: " + (.status//"?") + " | Brokers: " + ((.brokerCount//0)|tostring)' 2>/dev/null || echo "API unavailable"
