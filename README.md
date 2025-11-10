# Nginx Configuration for Docker Services

This is a professional, production-ready nginx setup for your services with best practices including loose coupling, security, and scalability.

## 📋 Architecture Overview

```
Cloudflare Tunnel → Nginx (Port 80) → Docker Containers
```

### Services Configuration

| Service | Domain | Backend Port | Container |
|---------|--------|--------------|-----------|
| Kafka UI | kafka.duongbd.site | 8080 | kafka-ui |
| Kibana | kibana.duongbd.site | 5601 | kibana |
| Elasticsearch | es.duongbd.site | 9200 | elasticsearch |
| MySQL Adminer | mysql.duongbd.site | 8081 | adminer |
| Redis Commander | redis.duongbd.site | 8082 | redis-commander |
| Nexus | nexus.duongbd.site | 8083 | nexus |
| Test Site | test.duongbd.site | - | Static files |

## 🚀 Quick Start

### Prerequisites

- Ubuntu Server (20.04 or later)
- Docker and Docker Compose installed
- Cloudflare Tunnel configured
- Root or sudo access

### Installation

1. **Upload all configuration files to your server:**
   ```bash
   # Create a working directory
   mkdir -p ~/nginx-setup
   cd ~/nginx-setup
   
   # Upload all files here
   ```

2. **Make the setup script executable:**
   ```bash
   chmod +x nginx/install.sh
   ```

3. **Run the setup script:**
   ```bash
   sudo ./nginx/install.sh
   ```

4. **Update your Docker services:**
   ```bash
   # Backup your current docker-compose.yml
   cp docker-compose.yml docker-compose.yml.backup
   
   # Replace with the new one
   cp docker-compose.yml /path/to/your/docker/directory/
   
   # Restart services
   cd /path/to/your/docker/directory
   docker-compose down
   docker-compose up -d
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

**1. 502 Bad Gateway**
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
