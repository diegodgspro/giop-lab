# GIOP-LAB v0.1 Architecture

## Diagram

```text
Browser → localhost:8080 → Zabbix Web → Zabbix Server → PostgreSQL volume
                              │                │
                              └── bootstrap ───┘
                                               │ agent protocol
workload network ← Agent 2 ← monitor network  │
      Nginx /healthz ─────────────────────────┘
```

## Components

| Component | Role | Persistence / exposure |
|---|---|---|
| PostgreSQL | Zabbix data store | `giop-lab-zabbix-postgres-data`; no host port |
| Zabbix Server | Poller and event engine | Internal monitor network only |
| Zabbix Web | Operator interface/API | Host `8080` by default |
| Zabbix Agent 2 | Synthetic health probe executor | Internal networks only |
| Nginx | Stoppable synthetic workload | No host port; no automatic restart |
| Bootstrap job | Idempotent API configuration | Exits after setup |

## Networks, data flow, and boundaries

`giop-lab-monitor` is internal and contains PostgreSQL, Zabbix, Agent 2, and the bootstrap job. `giop-lab-workload` is internal and contains Zabbix Server, Agent 2, and Nginx. Zabbix Server performs the controlled TCP service check directly; Agent 2 remains a synthetic test target and health probe executor. `giop-lab-frontend` is a dedicated edge network attached only to Zabbix Web so its explicitly published port works. No database, server, agent, or workload port is published to the host.

The local `.env` is the credential boundary. It is ignored by Git and `.env.example` contains placeholders only.

## Monitoring and recovery flow

Every 15 seconds Zabbix Server runs `net.tcp.service[http,gua-lab-srv-web-001,80]`. A `0` creates the `GIOP-LAB: controlled web workload TCP unavailable` problem event. Restarting the workload returns `1`, which resolves the event. The workload uses `restart: "no"` so an intentional stop remains observable.
