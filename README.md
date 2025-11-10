# Nginx Reverse Proxy for Backend Services

Professional, production-ready nginx setup for proxying Docker services with best practices including loose coupling, security, performance optimization, and scalability.

## 📋 Architecture Overview

```
Internet → Cloudflare Tunnel → Nginx (Port 80) → Docker Containers
```

### Configured Services

| Service | Domain | Backend Port | Container | Purpose |
|---------|--------|--------------|-----------|---------|
| Kafka UI | kafka.duongbd.site | 8080 | kafka-ui | Kafka management |
| Kibana | kibana.duongbd.site | 5601 | kibana | Elasticsearch UI |
| Elasticsearch | es.duongbd.site | 9200 | elasticsearch | Search/Analytics |
| MySQL Adminer | mysql.duongbd.site | 8081 | adminer | Database management |
| Redis Commander | redis.duongbd.site | 8082 | redis-commander | Redis management |
| Nexus | nexus.duongbd.site | 8083 | nexus | Artifact repository |
| Test Site | test.duongbd.site | - | Static files | Test/Status page |

## 🚀 Quick Start (Automated Installation)

### Prerequisites

- Ubuntu Server 20.04+ or Debian 10+
- Root or sudo access
- Docker and Docker Compose installed
- Cloudflare Tunnel configured (optional)

### One-Command Installation

```bash
# Download repository or upload files to server
cd /path/to/nginx-setup-complete

# Make installation script executable
chmod +x install-nginx.sh

# Run automated installation
sudo ./install-nginx.sh
```

The script will:
- ✅ Install nginx (if not already installed)
- ✅ Backup existing configuration
- ✅ Copy all configuration files
- ✅ Enable all sites
- ✅ Set correct permissions
- ✅ Test configuration
- ✅ Start/restart nginx service

### Manual Installation (Alternative)

If you prefer manual control:

```bash
# 1. Install nginx
sudo apt update
sudo apt install -y nginx

# 2. Backup existing config
sudo cp -r /etc/nginx /etc/nginx.backup-$(date +%Y%m%d)

# 3. Copy configuration files
sudo cp nginx/nginx.conf /etc/nginx/
sudo cp nginx/conf.d/upstreams.conf /etc/nginx/conf.d/
sudo cp -r nginx/snippets/* /etc/nginx/snippets/
sudo cp nginx/sites-available/*.conf /etc/nginx/sites-available/

# 4. Enable sites
sudo rm -f /etc/nginx/sites-enabled/default
cd /etc/nginx/sites-available
for conf in *.conf; do
    sudo ln -sf /etc/nginx/sites-available/$conf /etc/nginx/sites-enabled/$conf
done

# 5. Test and restart
sudo nginx -t
sudo systemctl restart nginx
```

## 📁 File Structure

```
/etc/nginx/
├── nginx.conf                           # Main configuration
├── upstreams/
│   └── upstreams.conf                  # Backend service definitions
├── snippets/
│   ├── security-headers.conf           # Common security headers
│   ├── proxy-settings.conf             # Common proxy settings
│   └── websocket-upgrade.conf          # WebSocket support
├── sites-available/
│   ├── kafka.duongbd.site.conf
│   ├── kibana.duongbd.site.conf
│   ├── es.duongbd.site.conf
│   ├── mysql.duongbd.site.conf
│   ├── redis.duongbd.site.conf
│   ├── nexus.duongbd.site.conf
│   └── test.duongbd.site.conf
└── sites-enabled/
    └── [symlinks to sites-available]
```

## 🏗️ Architecture Design Principles

### 1. **Loose Coupling**
- Each service has its own configuration file
- Shared settings are in reusable snippets
- Upstream definitions are separate from server blocks
- Easy to add/remove/modify individual services

### 2. **Security Best Practices**
- Security headers (XSS protection, clickjacking prevention)
- Rate limiting per service
- Connection limits
- Real IP detection for Cloudflare
- Minimal server information disclosure

### 3. **Performance Optimization**
- Connection pooling with keepalive
- Gzip compression
- Optimized buffer sizes
- Efficient worker configuration
- Upstream health checks

### 4. **Scalability**
- Easy to add new services
- Modular configuration
- Clear separation of concerns
- Environment-agnostic design

### 5. **Maintainability**
- Comprehensive logging
- Clear naming conventions
- Documented configuration
- Version-controlled friendly

## 🔧 Configuration Details

### Upstream Configuration

Upstreams are defined in `/etc/nginx/upstreams/upstreams.conf`:

```nginx
upstream kafka_ui_backend {
    server localhost:8080 max_fails=3 fail_timeout=30s;
    keepalive 32;
}
```

**Benefits:**
- Centralized backend definitions
- Easy to add load balancing
- Health check configuration
- Connection pooling

### Security Headers

Defined in `/etc/nginx/snippets/security-headers.conf`:

- **X-Frame-Options:** Prevents clickjacking
- **X-Content-Type-Options:** Prevents MIME type sniffing
- **X-XSS-Protection:** XSS attack protection
- **Referrer-Policy:** Controls referrer information

### Rate Limiting

Three zones configured for different use cases:

```nginx
limit_req_zone $binary_remote_addr zone=general:10m rate=10r/s;  # General traffic
limit_req_zone $binary_remote_addr zone=api:10m rate=30r/s;      # API endpoints
limit_req_zone $binary_remote_addr zone=auth:10m rate=5r/s;      # Auth/admin
```

## ✅ Configuration Testing

### Test Configuration Syntax

Use the included test script for comprehensive configuration validation:

```bash
# Make test script executable
chmod +x test-nginx-config.sh

# Run configuration test
./test-nginx-config.sh

# Or test with automatic reload
./test-nginx-config.sh --reload

# Or test with restart
./test-nginx-config.sh --restart
```

### Manual Testing

```bash
# Test nginx syntax
sudo nginx -t

# Reload configuration (zero-downtime)
sudo systemctl reload nginx

# Restart nginx (full restart)
sudo systemctl restart nginx

# Check service status
sudo systemctl status nginx
```

### Verify Configuration

After installation, verify each component:

```bash
# 1. Check nginx is running
sudo systemctl is-active nginx

# 2. Verify sites are enabled
ls -la /etc/nginx/sites-enabled/

# 3. Test each health endpoint
curl http://localhost/health                    # Default site
curl http://kafka.duongbd.site/health          # If DNS configured
curl http://localhost -H "Host: kafka.duongbd.site"  # Without DNS

# 4. Check upstream connectivity
curl localhost:8080  # Kafka UI
curl localhost:5601  # Kibana
curl localhost:9200  # Elasticsearch
# ... test other backends
```

## 📊 Monitoring & Troubleshooting

### View Logs

```bash
# All access logs
tail -f /var/log/nginx/*-access.log

# All error logs
tail -f /var/log/nginx/*-error.log

# Specific service
tail -f /var/log/nginx/kafka-access.log
tail -f /var/log/nginx/kafka-error.log
```

### Check Nginx Status

```bash
# Service status
systemctl status nginx

# Test configuration
sudo nginx -t

# Reload configuration
sudo systemctl reload nginx

# Restart nginx
sudo systemctl restart nginx
```

### Health Checks

Each service has a `/health` endpoint:

```bash
curl http://kafka.duongbd.site/health
curl http://kibana.duongbd.site/health
curl http://es.duongbd.site/health
# etc.
```

### Common Issues

**1. Duplicate Directive Errors**
```bash
# Error: "proxy_buffering" directive is duplicate
# Cause: Buffering settings defined in both snippet and site config
# Fix: Already fixed in this version - buffering settings removed from snippets

# Verify fix
grep -r "proxy_buffering" /etc/nginx/snippets/    # Should not return results
grep -r "proxy_buffering" /etc/nginx/sites-available/  # Should show per-site settings
```

**2. 502 Bad Gateway**
```bash
# Check if Docker containers are running
docker ps

# Check upstream connectivity
curl localhost:8080  # For kafka-ui

# Check nginx error logs
tail -f /var/log/nginx/kafka-error.log
```

**2. Configuration Errors**
```bash
# Test configuration
sudo nginx -t

# Check syntax
nginx -c /etc/nginx/nginx.conf -t
```

**3. Port Conflicts**
```bash
# Check what's using a port
sudo netstat -tulpn | grep :80
sudo ss -tulpn | grep :80
```

## 🔄 Adding a New Service

1. **Define upstream in `/etc/nginx/upstreams/upstreams.conf`:**
```nginx
upstream newservice_backend {
    server localhost:9999 max_fails=3 fail_timeout=30s;
    keepalive 32;
}
```

2. **Create site configuration in `/etc/nginx/sites-available/newservice.duongbd.site.conf`:**
```nginx
server {
    listen 80;
    server_name newservice.duongbd.site;
    
    access_log /var/log/nginx/newservice-access.log main;
    error_log /var/log/nginx/newservice-error.log warn;
    
    include /etc/nginx/snippets/security-headers.conf;
    limit_req zone=general burst=20 nodelay;
    
    location / {
        include /etc/nginx/snippets/proxy-settings.conf;
        proxy_pass http://newservice_backend;
    }
}
```

3. **Enable the site:**
```bash
sudo ln -s /etc/nginx/sites-available/newservice.duongbd.site.conf \
            /etc/nginx/sites-enabled/newservice.duongbd.site.conf
```

4. **Test and reload:**
```bash
sudo nginx -t
sudo systemctl reload nginx
```

## 🔐 Security Considerations

### Production Recommendations

1. **Enable HTTPS** (if not using Cloudflare):
```bash
# Install certbot
sudo apt install certbot python3-certbot-nginx

# Get certificates
sudo certbot --nginx -d kafka.duongbd.site
```

2. **Implement IP Whitelisting** for admin interfaces:
```nginx
location / {
    allow 1.2.3.4;    # Your IP
    deny all;
    # ... rest of config
}
```

3. **Add Basic Authentication** for sensitive services:
```bash
# Create password file
sudo htpasswd -c /etc/nginx/.htpasswd admin

# In nginx config
location / {
    auth_basic "Restricted Access";
    auth_basic_user_file /etc/nginx/.htpasswd;
    # ... rest of config
}
```

4. **Enable ModSecurity** (Web Application Firewall):
```bash
sudo apt install libnginx-mod-security
```

## 📈 Performance Tuning

### For High Traffic

1. **Increase worker connections:**
```nginx
events {
    worker_connections 4096;
}
```

2. **Enable caching:**
```nginx
proxy_cache_path /var/cache/nginx levels=1:2 keys_zone=my_cache:10m max_size=1g;

location / {
    proxy_cache my_cache;
    proxy_cache_valid 200 60m;
    # ... rest of config
}
```

3. **Tune buffer sizes:**
```nginx
client_body_buffer_size 256k;
proxy_buffers 8 32k;
```

## 🧪 Testing

### Load Testing with ApacheBench

```bash
# Install ApacheBench
sudo apt install apache2-utils

# Test endpoint
ab -n 1000 -c 10 http://kafka.duongbd.site/health
```

### Connection Testing

```bash
# Test upstream connectivity
curl -v http://localhost:8080

# Test through nginx
curl -v http://kafka.duongbd.site

# Check headers
curl -I http://kafka.duongbd.site
```

## 📝 Maintenance Tasks

### Regular Maintenance

```bash
# Rotate logs (done automatically via logrotate)
sudo logrotate -f /etc/logrotate.d/nginx

# Check disk usage
du -sh /var/log/nginx/*

# Clean old logs
find /var/log/nginx -name "*.gz" -mtime +30 -delete
```

### Backup Configuration

```bash
# Backup all configs
sudo tar -czf nginx-backup-$(date +%Y%m%d).tar.gz /etc/nginx/

# Restore
sudo tar -xzf nginx-backup-20240101.tar.gz -C /
```

## 🔄 Updating Configuration

1. **Edit configuration files**
2. **Test configuration:**
   ```bash
   sudo nginx -t
   ```
3. **Reload nginx (zero downtime):**
   ```bash
   sudo systemctl reload nginx
   ```

## 📚 Additional Resources

- [Nginx Documentation](https://nginx.org/en/docs/)
- [Nginx Best Practices](https://www.nginx.com/blog/nginx-caching-guide/)
- [Security Headers Guide](https://securityheaders.com/)

## 🐛 Debugging

### Enable Debug Logging

```nginx
error_log /var/log/nginx/error.log debug;
```

### Verbose Output

```bash
# Check configuration with verbose output
sudo nginx -t -v

# Check installed modules
nginx -V
```

## 📞 Support

For issues or questions:
1. Check error logs: `/var/log/nginx/`
2. Test configuration: `sudo nginx -t`
3. Verify Docker containers: `docker ps`
4. Check port bindings: `sudo netstat -tulpn`

---

**Version:** 1.0.0  
**Last Updated:** 2024  
**Maintainer:** System Administrator
