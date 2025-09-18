# Apache Kafka - Ports Registry

Default host: `bokodell14.local`

## Active Services (defaults)

### Kafka Broker

- Port: 19092
- Protocol: TCP
- Access: Local network (192.168.0.0/16)
- Container: bk-kafka-broker
- Status: ✅ Active
- Activated at: 2025-09-17 22:17

### Kafka Web UI

- Port: 19081
- Protocol: TCP/HTTP
- Access: Local network (192.168.0.0/16)
- Container: bk-kafka-ui
- URL: <http://bokodell14.local:8087>
- Status: ✅ Active
- Activated at: 2025-09-17 20:22

### Zookeeper

- Port: 19181
- Protocol: TCP
- Access: Local/Containers
- Container: bk-kafka-zookeeper
- Status: ✅ Active
- Activated at: 2025-09-17 20:22

## Firewall Settings

### UFW Rules

```bash
# Kafka Broker - Local network
sudo ufw allow from 192.168.0.0/16 to any port 19092 proto tcp

# Kafka Web UI - Local network
sudo ufw allow from 192.168.0.0/16 to any port 19081 proto tcp
```

## Management Commands

### Check Status

```bash
# Check containers
podman ps

# Check ports
ss -tlnp | grep -E "(19092|19081|19181)"

# Test connectivity
curl -s http://bokodell14.local:19081
```

## Avoiding Conflicts

If there are pods for Stalwart Email or Plane PM using nearby ports, change this project's ports via `.env`:

- `BROKER_PORT`, `UI_PORT`, `ZK_PORT`

### Stop/Start Services

```bash
# Stop Kafka
podman stop kafka-broker

# Start Kafka
podman start kafka-broker

# Kafka logs
podman logs kafka-broker
```

---
Last update: 2025-09-17 22:17:00
