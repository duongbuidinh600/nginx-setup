# Nginx Setup - Deployment Summary

## 📦 What You Received

A complete, production-ready Nginx reverse proxy configuration following best practices with loose coupling and modular design.

## 🎯 Key Features

### Architecture Principles
✅ **Loose Coupling** - Each service has independent configuration
✅ **Separation of Concerns** - Configuration split into logical components
✅ **DRY Principle** - Reusable snippets for common settings
✅ **Single Responsibility** - Each config file handles one concern
✅ **Easy Extensibility** - Simple pattern to add new services

### Security
✅ Server tokens hidden
✅ Security headers (X-Frame-Options, X-XSS-Protection, etc.)
✅ Services bound to localhost only
✅ Proper timeout and buffer configurations
✅ Request size limits per service type

### Performance
✅ Auto-scaled worker processes
✅ Connection pooling (keepalive)
✅ Gzip compression
✅ Optimized buffer sizes
✅ Health check endpoints

### Maintainability
✅ Comprehensive logging with metrics
✅ Management scripts for common tasks
✅ Easy enable/disable of services
✅ Clear documentation
✅ Automated installation

## 📂 File Structure

```
nginx/
├── README.md                       # Complete documentation
├── QUICK_REFERENCE.md              # Quick command reference
├── install.sh                      # Automated installation script
├── manage.sh                       # Management script
│
├── nginx.conf                      # Main Nginx configuration
│   └── Includes all other configs
│
├── conf.d/
│   └── upstreams.conf             # All backend service definitions
│       ├── kafka_ui_backend
│       ├── kibana_backend
│       ├── elasticsearch_backend
│       ├── adminer_backend
│       ├── redis_commander_backend
│       └── nexus_backend
│
├── snippets/                       # Reusable configuration blocks
│   ├── proxy-headers.conf         # Standard proxy headers + WebSocket
│   └── security-headers.conf      # Security headers
│
└── sites-available/                # Individual service configurations
    ├── default.conf               # Default/test site
    ├── kafka.conf                 # Kafka UI (unbuffered streaming)
    ├── kibana.conf                # Kibana (extended timeouts)
    ├── elasticsearch.conf         # Elasticsearch (long queries)
    ├── mysql.conf                 # Adminer (large uploads)
    ├── redis.conf                 # Redis Commander
    └── nexus.conf                 # Nexus (1GB uploads)

docker-compose-updated.yml          # Updated Docker Compose with port bindings
```

## 🚀 Quick Start

### 1. Upload Files to Server
```bash
# Upload the nginx directory to your server
scp -r nginx/ user@your-server:/home/user/
scp docker-compose-updated.yml user@your-server:/home/user/
```

### 2. Replace Docker Compose
```bash
# On your server
cd /path/to/docker-compose
cp docker-compose.yml docker-compose.yml.backup
cp /home/user/docker-compose-updated.yml docker-compose.yml

# Restart containers with new port bindings
docker-compose down
docker-compose up -d
```

### 3. Install Nginx
```bash
cd /home/user/nginx
chmod +x install.sh manage.sh
sudo ./install.sh
```

### 4. Verify
```bash
# Check Nginx status
sudo systemctl status nginx

# Check upstream services
sudo ./manage.sh check

# View logs
sudo ./manage.sh logs all
```

## 🔗 Service Access

After installation, services are accessible via:

| Service | URL | Backend Port |
|---------|-----|--------------|
| Kafka UI | http://kafka.duongbd.site | localhost:8080 |
| Kibana | http://kibana.duongbd.site | localhost:5601 |
| Elasticsearch | http://es.duongbd.site | localhost:9200 |
| MySQL Adminer | http://mysql.duongbd.site | localhost:8081 |
| Redis Commander | http://redis.duongbd.site | localhost:8082 |
| Nexus | http://nexus.duongbd.site | localhost:8083 |
| Test/Default | http://test.duongbd.site | /var/www/html |

## 🏗️ How It Works

### Request Flow
```
1. Cloudflare Tunnel receives request
   ↓
2. Routes to localhost:80
   ↓
3. Nginx matches server_name (e.g., kafka.duongbd.site)
   ↓
4. Applies security headers (from snippets/security-headers.conf)
   ↓
5. Adds proxy headers (from snippets/proxy-headers.conf)
   ↓
6. Forwards to upstream (from conf.d/upstreams.conf)
   ↓
7. Backend service processes request
   ↓
8. Response flows back through Nginx to client
```

### Modular Design Benefits

**Adding a new service:**
1. Add service to docker-compose.yml with localhost port
2. Add upstream definition in upstreams.conf
3. Create site config in sites-available/
4. Enable with `sudo ./manage.sh enable service-name`
5. Done! No need to touch other configurations

**Modifying a service:**
- Edit only that service's configuration file
- Other services remain unaffected
- Zero coupling between service configs

**Removing a service:**
1. Disable with `sudo ./manage.sh disable service-name`
2. Remove config file
3. Remove upstream definition
4. Done!

## 🛠️ Common Operations

### Daily Operations
```bash
# View logs
sudo ./manage.sh logs access
sudo ./manage.sh logs error

# Check service health
sudo ./manage.sh check

# Reload after config changes
sudo ./manage.sh test
sudo ./manage.sh reload
```

### Adding New Service
```bash
# 1. Add to docker-compose.yml
myapp:
  ports:
    - "127.0.0.1:8090:8080"

# 2. Add upstream
echo "upstream myapp_backend { server localhost:8090; keepalive 16; }" | \
  sudo tee -a /etc/nginx/conf.d/upstreams.conf

# 3. Create site config (copy template)
sudo cp /etc/nginx/sites-available/default.conf /etc/nginx/sites-available/myapp.conf
# Edit myapp.conf with your settings

# 4. Enable
sudo ./manage.sh enable myapp
```

### Troubleshooting
```bash
# Service not accessible
sudo ./manage.sh check              # Check if backend is up
sudo ./manage.sh logs error         # Check for errors
docker-compose ps                   # Check Docker status

# Configuration issues
sudo nginx -t                       # Test syntax
sudo nginx -T                       # Dump full config

# Performance issues
sudo ./manage.sh connections        # Check active connections
htop                               # Check system resources
```

## 📊 Monitoring

### Built-in Endpoints

Every site has:
- `/health` - Returns 200 OK (for monitoring)
- Access logs - In `/var/log/nginx/[service].access.log`
- Error logs - In `/var/log/nginx/[service].error.log`

Default site has:
- `/nginx_status` - Nginx status page

### Log Analysis
```bash
# Request rate
awk '{print $4}' /var/log/nginx/access.log | cut -d: -f1,2 | uniq -c

# Top URLs
awk '{print $7}' /var/log/nginx/access.log | sort | uniq -c | sort -rn | head

# Slow requests (> 1 second)
awk '$NF > 1.0' /var/log/nginx/access.log

# Error summary
grep "error" /var/log/nginx/error.log | cut -d] -f3 | sort | uniq -c
```

## 🔐 Security Enhancements (Optional)

### Rate Limiting
```nginx
# Add to nginx.conf in http block
limit_req_zone $binary_remote_addr zone=general:10m rate=10r/s;

# Add to location blocks in site configs
limit_req zone=general burst=20 nodelay;
```

### IP Whitelisting
```nginx
# Add to location block
allow 192.168.1.0/24;  # Your office network
allow 10.0.0.0/8;      # VPN network
deny all;
```

### Basic Authentication
```bash
# Create password file
sudo htpasswd -c /etc/nginx/.htpasswd admin

# Add to site config
auth_basic "Restricted Access";
auth_basic_user_file /etc/nginx/.htpasswd;
```

### SSL/HTTPS (future)
```nginx
# Add to each site config
listen 443 ssl http2;
ssl_certificate /path/to/cert.pem;
ssl_certificate_key /path/to/key.pem;
```

## 📈 Performance Tuning

Based on your system (16GB RAM, i5 CPU):

```nginx
# Already optimized in nginx.conf:
worker_processes auto;              # Uses all CPU cores
worker_connections 4096;            # 4096 connections per worker
keepalive_timeout 65;               # Connection reuse
keepalive_requests 100;             # Requests per connection

# Adjust if needed:
worker_rlimit_nofile 65535;        # Open file limit
client_max_body_size 100M;          # Max upload (per service)
```

## 🔄 Maintenance

### Regular Tasks
```bash
# Weekly: Check for updates
sudo apt update && sudo apt upgrade nginx

# Weekly: Review logs
sudo ./manage.sh logs error | grep -i error

# Monthly: Check disk usage
df -h /var/log/nginx/

# Monthly: Rotate logs (automatic with logrotate)
sudo logrotate -f /etc/logrotate.d/nginx

# Quarterly: Backup configuration
sudo tar -czf nginx-backup-$(date +%Y%m%d).tar.gz /etc/nginx/
```

## 🆘 Emergency Procedures

### Nginx won't start
```bash
# Check configuration
sudo nginx -t

# Check port conflicts
sudo ss -tlnp | grep :80

# View logs
sudo journalctl -u nginx -n 50

# Reset to backup
sudo cp /etc/nginx/nginx.conf.backup /etc/nginx/nginx.conf
sudo systemctl restart nginx
```

### All sites down
```bash
# Check Nginx status
sudo systemctl status nginx

# Check Docker services
docker-compose ps

# Emergency restart
sudo systemctl restart nginx
docker-compose restart
```

### High load
```bash
# Check connections
sudo ./manage.sh connections

# Check logs for issues
sudo ./manage.sh logs error

# Restart problem service
docker-compose restart <service-name>
```

## 📚 Documentation

- **README.md** - Complete guide with examples
- **QUICK_REFERENCE.md** - Command cheat sheet
- **This file** - Deployment overview

## ✅ Best Practices Implemented

### Configuration Management
- ✅ Version control friendly (text files)
- ✅ Clear naming conventions
- ✅ Comments explaining non-obvious settings
- ✅ Logical file organization

### Reliability
- ✅ Health check endpoints
- ✅ Graceful reload (zero downtime)
- ✅ Upstream health checks
- ✅ Proper timeout handling

### Observability
- ✅ Detailed logging with metrics
- ✅ Per-service log files
- ✅ Status endpoint
- ✅ Connection monitoring

### Security
- ✅ Principle of least privilege (localhost binding)
- ✅ Security headers
- ✅ Hidden server tokens
- ✅ Request size limits

### Maintainability
- ✅ Management scripts
- ✅ Automated installation
- ✅ Clear documentation
- ✅ Easy to extend

## 🎓 Learning Resources

If you need to customize further:

1. **Nginx Documentation**: https://nginx.org/en/docs/
2. **Performance Tuning**: https://www.nginx.com/blog/tuning-nginx/
3. **Security**: https://www.nginx.com/blog/nginx-security-best-practices/
4. **Monitoring**: https://www.nginx.com/blog/monitoring-nginx/

## 🤝 Support

For issues:
1. Check QUICK_REFERENCE.md for common commands
2. Review logs: `sudo ./manage.sh logs error`
3. Test configuration: `sudo nginx -t`
4. Check upstream connectivity: `sudo ./manage.sh check`

---

**This setup follows industry best practices and is production-ready.**
**All configurations use loose coupling for easy maintenance and extensibility.**

Good luck with your deployment! 🚀
