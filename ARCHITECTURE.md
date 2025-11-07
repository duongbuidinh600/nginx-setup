# System Architecture

## Overall Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                       Cloudflare Tunnel                          │
│                     (*.duongbd.site → :80)                       │
└───────────────────────────┬─────────────────────────────────────┘
                            │
                            ↓
┌─────────────────────────────────────────────────────────────────┐
│                         Ubuntu Server                            │
│                                                                   │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │                    Nginx (:80)                               ││
│  │                                                               ││
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      ││
│  │  │   Main       │  │  Upstreams   │  │  Snippets    │      ││
│  │  │  Config      │  │   Config     │  │   (Reusable) │      ││
│  │  │ nginx.conf   │  │upstreams.conf│  │proxy-headers │      ││
│  │  │              │  │              │  │  security    │      ││
│  │  └──────────────┘  └──────────────┘  └──────────────┘      ││
│  │                                                               ││
│  │  ┌───────────────────────────────────────────────────────┐  ││
│  │  │           Site Configurations (Loose Coupling)        │  ││
│  │  │  ┌─────┐ ┌──────┐ ┌────┐ ┌─────┐ ┌─────┐ ┌──────┐  │  ││
│  │  │  │Kafka│ │Kibana│ │ ES │ │MySQL│ │Redis│ │Nexus │  │  ││
│  │  │  │.conf│ │.conf │ │.conf│ │.conf│ │.conf│ │.conf │  │  ││
│  │  │  └─────┘ └──────┘ └────┘ └─────┘ └─────┘ └──────┘  │  ││
│  │  │    ↓        ↓       ↓       ↓       ↓       ↓      │  ││
│  │  │   :8080   :5601   :9200   :8081   :8082   :8083    │  ││
│  │  └───────────────────────────────────────────────────────┘  ││
│  └─────────────────────────────────────────────────────────────┘│
│                              ↓                                    │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │              Docker Network (scangoo-network)                ││
│  │                                                               ││
│  │  ┌──────────┐  ┌────────┐  ┌──────────────┐  ┌──────────┐ ││
│  │  │ Kafka UI │  │ Kibana │  │Elasticsearch │  │ Adminer  │ ││
│  │  │  :8080   │  │ :5601  │  │    :9200     │  │  :8080   │ ││
│  │  └────┬─────┘  └───┬────┘  └──────┬───────┘  └────┬─────┘ ││
│  │       │            │              │                │        ││
│  │  ┌────▼────┐  ┌────▼──────┐  ┌───▼────┐  ┌───────▼─────┐ ││
│  │  │  Kafka  │  │    ES     │  │ MySQL  │  │    Redis    │ ││
│  │  │:29092   │  │           │  │ :3306  │  │    :6379    │ ││
│  │  │         │  │           │  │        │  │             │ ││
│  │  └─────────┘  └───────────┘  └────────┘  └─────────────┘ ││
│  │                                                              ││
│  │  ┌─────────────────┐  ┌──────────────────┐                ││
│  │  │Redis Commander  │  │      Nexus       │                ││
│  │  │     :8081       │  │      :8081       │                ││
│  │  └─────────────────┘  └──────────────────┘                ││
│  └─────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────┘
```

## Request Flow Diagram

```
┌─────────────┐
│   Client    │
└──────┬──────┘
       │ 1. HTTP Request
       │    kafka.duongbd.site
       ↓
┌─────────────────────┐
│ Cloudflare Tunnel   │
│   (Port 80 only)    │
└──────┬──────────────┘
       │ 2. Forward to localhost:80
       ↓
┌─────────────────────────────────────────┐
│              Nginx                       │
│                                          │
│  3. Match server_name                   │
│     → kafka.duongbd.site                │
│                                          │
│  4. Include security-headers.conf       │
│     ✓ X-Frame-Options                   │
│     ✓ X-Content-Type-Options            │
│     ✓ X-XSS-Protection                  │
│                                          │
│  5. Include proxy-headers.conf          │
│     ✓ Host                               │
│     ✓ X-Real-IP                          │
│     ✓ X-Forwarded-For                    │
│     ✓ X-Forwarded-Proto                  │
│     ✓ WebSocket support                  │
│                                          │
│  6. Route to upstream                   │
│     → kafka_ui_backend                   │
│     → localhost:8080                     │
│                                          │
│  7. Apply buffering rules               │
│     (service-specific)                  │
└──────┬──────────────────────────────────┘
       │ 8. Proxy to backend
       ↓
┌─────────────────────┐
│    Kafka UI         │
│  Container :8080    │
└──────┬──────────────┘
       │ 9. Process request
       │ 10. Generate response
       ↓
┌─────────────────────┐
│      Nginx          │
│  11. Add headers    │
│  12. Log metrics    │
└──────┬──────────────┘
       │ 13. Return response
       ↓
┌─────────────────────┐
│ Cloudflare Tunnel   │
└──────┬──────────────┘
       │ 14. Response to client
       ↓
┌─────────────┐
│   Client    │
└─────────────┘
```

## Configuration Hierarchy

```
/etc/nginx/
│
├── nginx.conf (Main Configuration)
│   │
│   ├── Global Settings
│   │   ├── Worker processes
│   │   ├── Events (connections)
│   │   └── Error handling
│   │
│   ├── HTTP Block
│   │   ├── Basic settings (sendfile, tcp_nopush, etc.)
│   │   ├── Buffer sizes
│   │   ├── Timeouts
│   │   ├── SSL settings
│   │   ├── Logging format
│   │   ├── Gzip compression
│   │   │
│   │   ├── Include conf.d/*.conf
│   │   │   └── upstreams.conf
│   │   │       ├── kafka_ui_backend
│   │   │       ├── kibana_backend
│   │   │       ├── elasticsearch_backend
│   │   │       ├── adminer_backend
│   │   │       ├── redis_commander_backend
│   │   │       └── nexus_backend
│   │   │
│   │   └── Include sites-enabled/*
│   │       ├── default.conf
│   │       ├── kafka.conf ──┐
│   │       ├── kibana.conf  │
│   │       ├── elasticsearch.conf
│   │       ├── mysql.conf   │  Each includes:
│   │       ├── redis.conf   │  ├── snippets/security-headers.conf
│   │       └── nexus.conf ──┘  └── snippets/proxy-headers.conf
│
└── snippets/ (Reusable Blocks)
    ├── proxy-headers.conf
    │   ├── Host
    │   ├── X-Real-IP
    │   ├── X-Forwarded-*
    │   ├── Upgrade (WebSocket)
    │   ├── Connection
    │   ├── Proxy timeouts
    │   └── Buffering
    │
    └── security-headers.conf
        ├── X-Frame-Options
        ├── X-Content-Type-Options
        ├── X-XSS-Protection
        └── Referrer-Policy
```

## Loose Coupling Design

```
┌──────────────────────────────────────────────────────────┐
│                   Nginx Architecture                      │
│                   (Loose Coupling)                        │
└──────────────────────────────────────────────────────────┘

Each service is independently configurable:

┌─────────────┐  ┌─────────────┐  ┌─────────────┐
│   Kafka     │  │   Kibana    │  │     ES      │
│   Config    │  │   Config    │  │   Config    │
│             │  │             │  │             │
│  - Hostname │  │  - Hostname │  │  - Hostname │
│  - Upstream │  │  - Upstream │  │  - Upstream │
│  - Logs     │  │  - Logs     │  │  - Logs     │
│  - Headers  │  │  - Headers  │  │  - Headers  │
│  - Timeouts │  │  - Timeouts │  │  - Timeouts │
│  - Buffering│  │  - Buffering│  │  - Buffering│
└─────────────┘  └─────────────┘  └─────────────┘
      ↓                 ↓                 ↓
     Uses             Uses              Uses
      ↓                 ↓                 ↓
┌─────────────────────────────────────────────────┐
│            Shared Components                     │
│  ┌──────────────┐  ┌──────────────────────┐    │
│  │   Snippets   │  │      Upstreams       │    │
│  │              │  │                      │    │
│  │ - proxy-     │  │ - Connection pools   │    │
│  │   headers    │  │ - Health checks      │    │
│  │ - security-  │  │ - Failover           │    │
│  │   headers    │  │ - Load balancing     │    │
│  └──────────────┘  └──────────────────────┘    │
└─────────────────────────────────────────────────┘

Benefits:
✓ Modify one service without affecting others
✓ Add new services easily
✓ Remove services cleanly
✓ Test individual services
✓ Different teams can own different services
```

## Port Mapping

```
External Domain          Nginx        Docker Container
(Cloudflare Tunnel)       ↓                  ↓

kafka.duongbd.site    → :80 → localhost:8080 → kafka-ui:8080
                              ┌─────────────────────────────────┐
                              │ kafka_ui_backend upstream       │
                              │ - max_fails: 3                  │
                              │ - fail_timeout: 30s             │
                              │ - keepalive: 32                 │
                              └─────────────────────────────────┘

kibana.duongbd.site   → :80 → localhost:5601 → kibana:5601
                              ┌─────────────────────────────────┐
                              │ kibana_backend upstream         │
                              │ - Extended timeouts (300s)      │
                              │ - keepalive: 16                 │
                              └─────────────────────────────────┘

es.duongbd.site       → :80 → localhost:9200 → elasticsearch:9200
                              ┌─────────────────────────────────┐
                              │ elasticsearch_backend upstream  │
                              │ - Long query support            │
                              │ - Unbuffered responses          │
                              └─────────────────────────────────┘

mysql.duongbd.site    → :80 → localhost:8081 → adminer:8080
                              ┌─────────────────────────────────┐
                              │ adminer_backend upstream        │
                              │ - 100MB upload limit            │
                              │ - 300s timeout                  │
                              └─────────────────────────────────┘

redis.duongbd.site    → :80 → localhost:8082 → redis-commander:8081
                              ┌─────────────────────────────────┐
                              │ redis_commander_backend         │
                              │ - Standard configuration        │
                              └─────────────────────────────────┘

nexus.duongbd.site    → :80 → localhost:8083 → nexus:8081
                              ┌─────────────────────────────────┐
                              │ nexus_backend upstream          │
                              │ - 1GB upload limit              │
                              │ - Request unbuffering           │
                              └─────────────────────────────────┘

test.duongbd.site     → :80 → /var/www/html (static files)
```

## Security Layers

```
┌─────────────────────────────────────────────────────────┐
│                  Security Architecture                   │
└─────────────────────────────────────────────────────────┘

Layer 1: Network Security
┌─────────────────────────────────────────────────────────┐
│  - Cloudflare DDoS Protection                           │
│  - Cloudflare WAF                                       │
│  - Cloudflare Rate Limiting                             │
└─────────────────────────────────────────────────────────┘
                          ↓
Layer 2: Port Binding (Docker)
┌─────────────────────────────────────────────────────────┐
│  - Services bound to 127.0.0.1 only                     │
│  - Not accessible from external network                 │
│  - Only Nginx can access (localhost)                    │
└─────────────────────────────────────────────────────────┘
                          ↓
Layer 3: Nginx Security
┌─────────────────────────────────────────────────────────┐
│  - Server tokens hidden                                 │
│  - Security headers (X-Frame-Options, etc.)             │
│  - Request size limits                                  │
│  - Timeout protection                                   │
│  - Buffer overflow protection                           │
└─────────────────────────────────────────────────────────┘
                          ↓
Layer 4: Application Security (Optional - Add as needed)
┌─────────────────────────────────────────────────────────┐
│  - Rate limiting (per IP)                               │
│  - IP whitelisting                                      │
│  - Basic authentication                                 │
│  - JWT validation                                       │
└─────────────────────────────────────────────────────────┘
```

## Monitoring & Logging Flow

```
┌─────────────────────────────────────────────────────────┐
│                 Request Processing                       │
└─────────────────────────────────────────────────────────┘
                          ↓
          ┌───────────────┴───────────────┐
          ↓                               ↓
┌──────────────────┐           ┌──────────────────┐
│   Access Log     │           │   Error Log      │
│                  │           │                  │
│ - Timestamp      │           │ - Error level    │
│ - Client IP      │           │ - Error message  │
│ - Request        │           │ - Stack trace    │
│ - Status code    │           │ - Context        │
│ - Response size  │           │                  │
│ - Referrer       │           └──────────────────┘
│ - User agent     │                     ↓
│ - Response time  │           /var/log/nginx/error.log
│ - Upstream time  │
└──────────────────┘
          ↓
Service-specific logs:
├── /var/log/nginx/access.log (main)
├── /var/log/nginx/kafka-ui.access.log
├── /var/log/nginx/kibana.access.log
├── /var/log/nginx/elasticsearch.access.log
├── /var/log/nginx/mysql-adminer.access.log
├── /var/log/nginx/redis-commander.access.log
└── /var/log/nginx/nexus.access.log

Each service also has:
└── [service].error.log

Monitoring endpoints:
├── /health (each service)
├── /nginx_status (main only)
└── Custom health checks in upstreams
```

## Scalability Design

```
Current Setup (Single Server):
┌────────────────────────────────────────┐
│            Single Server                │
│                                         │
│  Nginx ──→ Docker Services             │
│    │                                    │
│    └─→ Can handle:                     │
│        - Thousands of concurrent       │
│          connections                    │
│        - Multiple services              │
│        - Health checks                  │
└────────────────────────────────────────┘

Easy Scaling Path:

1. Horizontal Scaling (Multiple Backends):
   ┌─────────┐
   │  Nginx  │
   └────┬────┘
        ├──→ Backend Server 1
        ├──→ Backend Server 2
        └──→ Backend Server 3

   Update upstream:
   upstream kafka_ui_backend {
       server server1.internal:8080;
       server server2.internal:8080;
       server server3.internal:8080;
   }

2. Load Balancer (Multiple Nginx):
   ┌───────────────┐
   │ Load Balancer │
   └───────┬───────┘
           ├──→ Nginx 1 ──→ Backends
           ├──→ Nginx 2 ──→ Backends
           └──→ Nginx 3 ──→ Backends

3. Geographic Distribution:
   Cloudflare (Global)
         ↓
   Regional Nginx Clusters
         ↓
   Regional Backend Services
```

---

This architecture ensures:
✓ **Loose Coupling** - Each component can be modified independently
✓ **Scalability** - Easy to add more services or backends
✓ **Maintainability** - Clear separation of concerns
✓ **Security** - Multiple security layers
✓ **Observability** - Comprehensive logging and monitoring
✓ **Reliability** - Health checks and failover support
