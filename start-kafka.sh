#!/bin/bash

set -euo pipefail

# Kafka environment startup script (Podman pod)
# Project: BokoKafka

# Load .env if present
if [ -f .env ]; then
    # shellcheck disable=SC1091
    source .env
fi

# Defaults
BOKO_HOST=${BOKO_HOST:-bokodell14.local}
BROKER_PORT=${BROKER_PORT:-19092}
ZK_PORT=${ZK_PORT:-19181}
UI_PORT=${UI_PORT:-19081}
CP_VERSION=${CP_VERSION:-7.5.3}
KAFKA_UI_TAG=${KAFKA_UI_TAG:-latest}
POD_NAME=${POD_NAME:-bk-kafka}
RESTART_POLICY=${RESTART_POLICY:-unless-stopped}
ZK_DATA_VOL=${ZK_DATA_VOL:-bk_zk_data}
ZK_LOG_VOL=${ZK_LOG_VOL:-bk_zk_log}
KAFKA_DATA_VOL=${KAFKA_DATA_VOL:-bk_kafka_data}
KAFKA_BROKER_ID=${KAFKA_BROKER_ID:-1}
KAFKA_AUTO_CREATE_TOPICS=${KAFKA_AUTO_CREATE_TOPICS:-true}
KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR=${KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR:-1}

echo "🚀 Starting Kafka environment (pod: ${POD_NAME})..."

# Basic checks
command -v podman >/dev/null 2>&1 || { echo "❌ Podman not found"; exit 1; }

# Helper: wait for port to be ready
wait_for_port() {
    local host=$1
    local port=$2
    local retries=${3:-30}
    for i in $(seq 1 $retries); do
        if command -v nc >/dev/null 2>&1; then
            if nc -z "$host" "$port" 2>/dev/null; then return 0; fi
        else
            if (echo >"/dev/tcp/${host}/${port}") >/dev/null 2>&1; then return 0; fi
        fi
        sleep 1
    done
    return 1
}

# Create volumes if absent
podman volume inspect "$ZK_DATA_VOL" >/dev/null 2>&1 || podman volume create "$ZK_DATA_VOL" >/dev/null
podman volume inspect "$ZK_LOG_VOL" >/dev/null 2>&1 || podman volume create "$ZK_LOG_VOL" >/dev/null
podman volume inspect "$KAFKA_DATA_VOL" >/dev/null 2>&1 || podman volume create "$KAFKA_DATA_VOL" >/dev/null

# Create pod if needed
if ! podman pod exists "$POD_NAME"; then
        echo "📦 Creating pod ${POD_NAME}..."
    podman pod create \
        --name "$POD_NAME" \
        -p ${ZK_PORT}:2181 \
        -p ${BROKER_PORT}:9092 \
                -p ${UI_PORT}:8080 >/dev/null
else
        echo "📦 Pod ${POD_NAME} already exists"
        # Ensure published ports match desired config; if not, recreate pod
        current_ports=$(podman pod inspect "$POD_NAME" | jq -r '.Config.PortMappings[]? | "\(.HostPort):\(.ContainerPort)"')
        need_recreate=0
        echo "$current_ports" | grep -q "${ZK_PORT}:2181" || need_recreate=1
        echo "$current_ports" | grep -q "${BROKER_PORT}:9092" || need_recreate=1
        echo "$current_ports" | grep -q "${UI_PORT}:8080" || need_recreate=1
        if [ "$need_recreate" -eq 1 ]; then
                echo "♻️ Recreating pod to apply new ports..."
                podman pod stop "$POD_NAME" >/dev/null || true
                podman pod rm "$POD_NAME" >/dev/null || true
                podman pod create \
                        --name "$POD_NAME" \
                        -p ${ZK_PORT}:2181 \
                        -p ${BROKER_PORT}:9092 \
                        -p ${UI_PORT}:8080 >/dev/null
        fi
fi

# Zookeeper
if podman container exists ${POD_NAME}-zookeeper; then
        echo "📋 Zookeeper exists, starting..."
    podman start ${POD_NAME}-zookeeper >/dev/null || true
else
        echo "📋 Creating Zookeeper..."
    podman run -d \
        --name ${POD_NAME}-zookeeper \
        --pod ${POD_NAME} \
        --restart=${RESTART_POLICY} \
        -e ZOOKEEPER_CLIENT_PORT=2181 \
        -e ZOOKEEPER_TICK_TIME=2000 \
        -v ${ZK_DATA_VOL}:/var/lib/zookeeper/data:Z \
        -v ${ZK_LOG_VOL}:/var/lib/zookeeper/log:Z \
        confluentinc/cp-zookeeper:${CP_VERSION} >/dev/null
fi

# Wait for Zookeeper (2181 inside pod)
echo "⏳ Waiting for Zookeeper (${BOKO_HOST}:${ZK_PORT})..."
if wait_for_port 127.0.0.1 ${ZK_PORT} 30; then
        echo "✅ Zookeeper OK"
else
        echo "❌ Zookeeper did not respond"; exit 1
fi

# Kafka Broker
if podman container exists ${POD_NAME}-broker; then
        echo "🔧 Kafka broker exists, starting..."
    podman start ${POD_NAME}-broker >/dev/null || true
else
        echo "🔧 Creating Kafka broker..."
    podman run -d \
        --name ${POD_NAME}-broker \
        --pod ${POD_NAME} \
        --restart=${RESTART_POLICY} \
        -e KAFKA_BROKER_ID=${KAFKA_BROKER_ID} \
        -e KAFKA_ZOOKEEPER_CONNECT=127.0.0.1:2181 \
        -e KAFKA_LISTENERS=PLAINTEXT://0.0.0.0:9092 \
        -e KAFKA_ADVERTISED_LISTENERS=PLAINTEXT://${BOKO_HOST}:${BROKER_PORT} \
        -e KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR=${KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR} \
        -e KAFKA_AUTO_CREATE_TOPICS_ENABLE=${KAFKA_AUTO_CREATE_TOPICS} \
        -v ${KAFKA_DATA_VOL}:/var/lib/kafka/data:Z \
        confluentinc/cp-kafka:${CP_VERSION} >/dev/null
fi

# Wait for broker to accept connections
echo "⏳ Waiting for Kafka broker (${BOKO_HOST}:${BROKER_PORT})..."
if wait_for_port 127.0.0.1 ${BROKER_PORT} 60; then
        echo "✅ Broker OK"
else
        echo "❌ Broker did not respond"; exit 1
fi

# Kafka UI
if podman container exists ${POD_NAME}-ui; then
        echo "🌐 Kafka UI exists, starting..."
    podman start ${POD_NAME}-ui >/dev/null || true
else
        echo "🌐 Creating Kafka UI..."
        podman run -d \
        --name ${POD_NAME}-ui \
        --pod ${POD_NAME} \
        --restart=${RESTART_POLICY} \
        -e KAFKA_CLUSTERS_0_NAME=local \
                -e KAFKA_CLUSTERS_0_BOOTSTRAP_SERVERS=localhost:9092 \
        -e SERVER_PORT=8080 \
        provectuslabs/kafka-ui:${KAFKA_UI_TAG} >/dev/null
fi

echo "✅ Kafka environment is up!"
echo "📊 Web UI: http://${BOKO_HOST}:${UI_PORT}"
echo "🔌 Broker: ${BOKO_HOST}:${BROKER_PORT}"
echo "📋 Zookeeper: ${BOKO_HOST}:${ZK_PORT}"
