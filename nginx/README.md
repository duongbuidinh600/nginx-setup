# Nginx Configuration Module

## 📁 Configuration Files

This directory contains the complete Nginx configuration for the Docker services setup.

**📖 Main Documentation:** See `../README.md` for complete setup instructions and usage guide.

## 📁 Directory Structure

```
nginx/
├── nginx.conf                      # Main Nginx configuration
├── conf.d/
│   └── upstreams.conf             # Backend service definitions
├── snippets/
│   ├── proxy-headers.conf         # Common proxy headers
│   └── security-headers.conf      # Security headers
├── sites-available/
│   ├── default.conf               # Default/test site
│   ├── kafka.conf                 # Kafka UI configuration
│   ├── kibana.conf                # Kibana configuration
│   ├── elasticsearch.conf         # Elasticsearch configuration
│   ├── mysql.conf                 # Adminer configuration
│   ├── redis.conf                 # Redis Commander configuration
│   └── nexus.conf                 # Nexus configuration
└── sites-enabled/                 # Symbolic links to enabled sites
```

## 🚀 Installation

### Prerequisites

- Ubuntu Server (20.04 or later)
- Docker and Docker Compose installed
- Root or sudo access
- Services defined in docker-compose.yml

### Step 1: Update Docker Compose

Replace your current `docker-compose.yml` with the updated version that exposes web UI ports:

```yaml
# Web UI ports are now bound to localhost only for security
# Example:
kafka-ui:
  ports:
    - "127.0.0.1:8080:8080"  # Only accessible via Nginx
```

**Port Mapping:**
- Kafka UI: localhost:8080
- Kibana: localhost:5601
- Elasticsearch: localhost:9200
- Adminer (MySQL): localhost:8081
- Redis Commander: localhost:8082
- Nexus: localhost:8083

### Step 2: Run Installation Script

```bash
# Clone or download the nginx directory
cd /path/to/nginx

# Make scripts executable
chmod +x install.sh manage.sh

# Run installation (requires sudo)
sudo ./install.sh
```

The installation script will:
1. Install Nginx
2. Create directory structure
3. Copy configuration files
4. Enable all services
5. Test configuration
6. Start Nginx
7. Configure firewall (if UFW is present)

### Step 3: Restart Docker Services

```bash
# Apply the updated docker-compose.yml
docker-compose down
docker-compose up -d

# Verify services are running
docker-compose ps
```

### Step 4: Verify Installation

```bash
# Check Nginx status
sudo systemctl status nginx

# Test configuration
sudo nginx -t

# Check upstream services
sudo ./manage.sh check

# View logs
sudo ./manage.sh logs all
```

## 🔧 Configuration Details

### Main Configuration (nginx.conf)

- **Worker processes**: Auto-scaled based on CPU cores
- **Connections**: 4096 per worker
- **Buffer sizes**: Optimized for various content types
- **Gzip compression**: Enabled for text/json/javascript
- **Logging**: Detailed access and error logs with performance metrics

### Upstream Definitions (upstreams.conf)

Each backend service has:
- Connection pooling (keepalive)
- Health check parameters (max_fails, fail_timeout)
- Load balancing ready (can add multiple servers)

Example:
```nginx
upstream kafka_ui_backend {
    server localhost:8080 max_fails=3 fail_timeout=30s;
    keepalive 32;
}
```

### Site Configurations

Each service has its own configuration file with:

**Common features:**
- Virtual host (server_name)
- Proxy headers for proper request forwarding
- Security headers
- Health check endpoints
- Service-specific optimizations

**Service-specific settings:**

- **Kafka UI**: Unbuffered streaming responses
- **Kibana**: Extended timeouts for queries, kbn-xsrf header
- **Elasticsearch**: Long-running query support, unbuffered responses
- **Adminer**: Large file upload support (100M)
- **Redis Commander**: Standard proxy configuration
- **Nexus**: Large artifact uploads (1G), request unbuffering

### Reusable Snippets

#### proxy-headers.conf
```nginx
proxy_set_header Host $host;
proxy_set_header X-Real-IP $remote_addr;
proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
proxy_set_header X-Forwarded-Proto $scheme;
# WebSocket support
proxy_http_version 1.1;
proxy_set_header Upgrade $http_upgrade;
proxy_set_header Connection $connection_upgrade;
```

#### security-headers.conf
```nginx
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-XSS-Protection "1; mode=block" always;
add_header Referrer-Policy "no-referrer-when-downgrade" always;
```

## 🛠️ Management Script

The `manage.sh` script provides convenient operations:

```bash
# Test configuration
sudo ./manage.sh test

# Reload Nginx (zero downtime)
sudo ./manage.sh reload

# Restart Nginx
sudo ./manage.sh restart

# Check service status
sudo ./manage.sh status

# View logs
sudo ./manage.sh logs access      # Access logs
sudo ./manage.sh logs error       # Error logs
sudo ./manage.sh logs kafka       # Kafka UI logs
sudo ./manage.sh logs all         # Follow all logs

# Enable/disable sites
sudo ./manage.sh enable nexus
sudo ./manage.sh disable redis

# List all sites
sudo ./manage.sh list

# Check upstream connectivity
sudo ./manage.sh check

# Show active connections
sudo ./manage.sh connections
```

## 🔐 Security Best Practices

### Implemented

- ✅ Server tokens hidden (`server_tokens off`)
- ✅ Security headers (X-Frame-Options, X-XSS-Protection, etc.)
- ✅ Services bound to localhost only
- ✅ Proper timeout configurations
- ✅ Buffer size limits
- ✅ Request size limits per service

### Recommended Additional Steps

1. **Enable HTTPS** (when using SSL certificates):
```bash
# Add SSL configuration to each site
listen 443 ssl http2;
ssl_certificate /path/to/cert.pem;
ssl_certificate_key /path/to/key.pem;
```

2. **Rate Limiting**:
```nginx
# Add to http block in nginx.conf
limit_req_zone $binary_remote_addr zone=general:10m rate=10r/s;

# Add to location blocks
limit_req zone=general burst=20 nodelay;
```

3. **IP Whitelisting** (for admin interfaces):
```nginx
location / {
    allow 10.0.0.0/8;      # Your internal network
    allow 192.168.1.0/24;  # Your office network
    deny all;
    # ... rest of config
}
```

4. **Basic Authentication**:
```bash
# Create password file
sudo htpasswd -c /etc/nginx/.htpasswd admin

# Add to location block
auth_basic "Restricted Access";
auth_basic_user_file /etc/nginx/.htpasswd;
```

## 📊 Monitoring

### Access Logs

```bash
# Real-time monitoring
tail -f /var/log/nginx/access.log

# Show requests with response times > 1s
awk '$NF > 1.0' /var/log/nginx/access.log

# Top requested URLs
awk '{print $7}' /var/log/nginx/access.log | sort | uniq -c | sort -rn | head
```

### Error Logs

```bash
# Monitor errors
tail -f /var/log/nginx/error.log

# Count errors by type
grep "error" /var/log/nginx/error.log | cut -d] -f3 | sort | uniq -c | sort -rn
```

### Nginx Status

```bash
# Enable status endpoint (already in default.conf)
curl http://localhost/nginx_status

# Output:
# Active connections: 10
# server accepts handled requests
#  100 100 200
# Reading: 0 Writing: 1 Waiting: 9
```

## 🐛 Troubleshooting

### Service Not Accessible

```bash
# Check if upstream service is running
docker ps

# Check if port is accessible
nc -zv localhost 8080

# Check Nginx error logs
sudo tail -f /var/log/nginx/error.log

# Verify site is enabled
sudo ./manage.sh list
```

### 502 Bad Gateway

**Causes:**
- Upstream service not running
- Incorrect upstream port
- Service taking too long to respond

**Solutions:**
```bash
# Check Docker containers
docker-compose ps

# Restart specific service
docker-compose restart kafka-ui

# Check upstream connectivity
sudo ./manage.sh check

# Increase proxy timeouts (in site config)
proxy_read_timeout 300s;
```

### Configuration Errors

```bash
# Test configuration
sudo nginx -t

# Check syntax errors in specific file
nginx -t -c /etc/nginx/sites-available/kafka.conf

# View detailed error
sudo journalctl -u nginx -n 50
```

### High Memory/CPU Usage

```bash
# Check worker processes
ps aux | grep nginx

# Adjust worker_processes in nginx.conf
worker_processes 2;  # Or specific number

# Monitor connections
sudo ./manage.sh connections

# Check for connection leaks
netstat -an | grep :80 | wc -l
```

## 🔄 Adding New Services

### 1. Add to docker-compose.yml

```yaml
myservice:
  image: myservice:latest
  ports:
    - "127.0.0.1:8084:8080"  # Bind to localhost only
  networks:
    - scangoo-network
```

### 2. Add upstream definition

```nginx
# /etc/nginx/conf.d/upstreams.conf
upstream myservice_backend {
    server localhost:8084 max_fails=3 fail_timeout=30s;
    keepalive 16;
}
```

### 3. Create site configuration

```nginx
# /etc/nginx/sites-available/myservice.conf
server {
    listen 80;
    server_name myservice.duongbd.site;

    access_log /var/log/nginx/myservice.access.log main;
    error_log /var/log/nginx/myservice.error.log warn;

    include snippets/security-headers.conf;

    location / {
        include snippets/proxy-headers.conf;
        proxy_pass http://myservice_backend;
    }

    location /health {
        access_log off;
        return 200 "OK";
        add_header Content-Type text/plain;
    }
}
```

### 4. Enable and test

```bash
sudo ./manage.sh enable myservice
sudo ./manage.sh test
sudo ./manage.sh reload
```

## 📝 Maintenance

### Regular Tasks

```bash
# Rotate logs (configure in logrotate)
sudo logrotate -f /etc/logrotate.d/nginx

# Check for Nginx updates
sudo apt update && sudo apt upgrade nginx

# Backup configuration
sudo tar -czf nginx-backup-$(date +%Y%m%d).tar.gz /etc/nginx/

# Test after updates
sudo nginx -t && sudo systemctl reload nginx
```

### Performance Tuning

Adjust based on your server resources:

```nginx
# nginx.conf
worker_processes auto;              # Or specific number
worker_connections 4096;            # Increase for more concurrent connections
keepalive_timeout 65;               # Adjust based on traffic patterns
client_max_body_size 100M;          # Increase if handling larger files
```

## 🤝 Contributing

To improve this setup:
1. Test changes in development first
2. Use `sudo nginx -t` before applying
3. Monitor logs after changes
4. Document any custom configurations

## 📄 License

This configuration is provided as-is for use in your infrastructure.

## 🆘 Support

For issues:
1. Check logs: `sudo ./manage.sh logs error`
2. Verify configuration: `sudo nginx -t`
3. Check upstream services: `sudo ./manage.sh check`
4. Review Nginx documentation: https://nginx.org/en/docs/

---

**Created with best practices for production environments**
