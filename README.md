# BokoKafka

Apache Kafka development environment with Web UI using Podman, organized in a Podman pod and configured via `.env`.

## Prerequisites

- Podman (rootless recommended)
- Utilities: `curl`, `jq`, `ss`, `nc` (netcat)

## Configuration (.env)

Copy `.env.example` to `.env` and adjust as needed. Default values avoid port conflicts with other pods (Stalwart Email, Plane PM):

- LAN host: `BOKO_HOST=bokodell14.local`
- Ports:
  - `BROKER_PORT=19092` (Kafka Broker)
  - `ZK_PORT=12181` (Zookeeper)
  - `UI_PORT=8087` (Kafka UI)
- Versions:
  - `CP_VERSION=7.5.3` (Kafka/ZK)
  - `KAFKA_UI_TAG=latest`
- Pod/Volumes:
  - `POD_NAME=bk-kafka`
  - `ZK_DATA_VOL=bk_zk_data`, `ZK_LOG_VOL=bk_zk_log`, `KAFKA_DATA_VOL=bk_kafka_data`
- Kafka:
  - `KAFKA_ADVERTISED_LISTENERS` is set automatically to `PLAINTEXT://$BOKO_HOST:$BROKER_PORT`

Note: for access from other machines on the LAN, ensure `bokodell14.local` resolves to the host IP (mDNS/avahi) or use a fixed IP.

## Files

- `start-kafka.sh` - Starts pod, volumes, and containers (ZK, Kafka, UI) with restart policy and health waits
- `status-kafka.sh` - Shows pod/containers status, ports, and cluster state via UI
- `stop-kafka.sh` - Stops containers and the pod
- `logs-kafka.sh` - Tails logs (`./logs-kafka.sh [zk|broker|ui|all]`)
- `kafka-ports-registry.md` - Ports registry
- `.env.example` - Configuration example

## Quick start

```bash
# Start environment
./start-kafka.sh

# Check status
./status-kafka.sh

# Tail logs (optional)
./logs-kafka.sh all

# Stop environment
./stop-kafka.sh
```

## Services (defaults)

- Kafka Broker: bokodell14.local:19092
- Kafka Web UI: <http://bokodell14.local:8087>
- Zookeeper: bokodell14.local:12181

## Avoiding port conflicts

This project uses non-standard ports by default. If other pods use the same ports, change them in `.env`:

- `BROKER_PORT` to another free port (e.g., 29092)
- `UI_PORT` to another free HTTP port (e.g., 8090)
- `ZK_PORT` to another free TCP port (e.g., 22181)

Check ports in use:

```bash
ss -tlnp | grep -E "(19092|8087|12181)"
```

## Persistence

Data is persisted in Podman volumes: `bk_kafka_data`, `bk_zk_data`, `bk_zk_log`.

## Firewall (optional)

Example UFW rules to allow access on local network 192.168.0.0/16:

```bash
sudo ufw allow from 192.168.0.0/16 to any port 19092 proto tcp
sudo ufw allow from 192.168.0.0/16 to any port 8087 proto tcp
```

## Troubleshooting

- UI not loading: check `http://$BOKO_HOST:$UI_PORT` and view logs with `./logs-kafka.sh ui`.
- Remote producers/consumers not connecting: ensure `bokodell14.local` resolves or replace with IP in `.env`.
- Ports in use: change them in `.env` and restart (`stop` -> `start`).
