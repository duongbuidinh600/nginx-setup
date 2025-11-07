# 🚀 QUICK START GUIDE

## Installation (5 minutes)

### 1. Upload Files to Server
```bash
# Create directory
mkdir -p ~/nginx-setup && cd ~/nginx-setup

# Upload all files to this directory
```

### 2. Run Setup Script
```bash
# Make executable
chmod +x setup-nginx.sh

# Run installation
sudo ./setup-nginx.sh
```

### 3. Update Docker Services
```bash
# Stop current services
cd /path/to/docker
docker-compose down

# Replace docker-compose.yml with the new one
cp ~/nginx-setup/docker-compose.yml .

# Start services
docker-compose up -d
```

### 4. Verify Everything Works
```bash
# Make health check script executable
chmod +x check-nginx-health.sh

# Run health check
sudo ./check-nginx-health.sh
```

## Testing Your Services

### Quick URL Tests
```bash
# Test each service health endpoint
curl http://kafka.duongbd.site/health
curl http://kibana.duongbd.site/health
curl http://es.duongbd.site/health
curl http://mysql.duongbd.site/health
curl http://redis.duongbd.site/health
curl http://nexus.duongbd.site/health
curl http://test.duongbd.site
```

### Access Your Services
Open in browser (through Cloudflare Tunnel):
- http://kafka.duongbd.site - Kafka UI
- http://kibana.duongbd.site - Kibana Dashboard
- http://es.duongbd.site - Elasticsearch API
- http://mysql.duongbd.site - MySQL Adminer
- http://redis.duongbd.site - Redis Commander
- http://nexus.duongbd.site - Nexus Repository
- http://test.duongbd.site - Test Page

## Common Management Commands

### Using Nginx Manager Tool
```bash
# Make executable
chmod +x nginx-manager.sh

# View all commands
sudo ./nginx-manager.sh help

# Common operations
sudo ./nginx-manager.sh status      # Check status
sudo ./nginx-manager.sh reload      # Reload config (zero downtime)
sudo ./nginx-manager.sh test        # Test config
sudo ./nginx-manager.sh logs        # View all logs
sudo ./nginx-manager.sh health      # Run health check
sudo ./nginx-manager.sh stats       # Show statistics
sudo ./nginx-manager.sh backup      # Backup configuration
```

### Direct systemctl Commands
```bash
sudo systemctl status nginx         # Check status
sudo systemctl reload nginx         # Reload (zero downtime)
sudo systemctl restart nginx        # Full restart
sudo nginx -t                       # Test configuration
```

## Monitoring

### View Logs
```bash
# All logs
sudo tail -f /var/log/nginx/*.log

# Specific service
sudo tail -f /var/log/nginx/kafka-access.log
sudo tail -f /var/log/nginx/kafka-error.log
```

### Run Health Checks
```bash
# Full system health check
sudo ./check-nginx-health.sh

# Quick nginx test
sudo nginx -t
```

## Troubleshooting

### Service Not Responding?
```bash
# 1. Check Docker container
docker ps | grep <container-name>
docker logs <container-name>

# 2. Check nginx configuration
sudo nginx -t

# 3. Check nginx logs
sudo tail -f /var/log/nginx/error.log

# 4. Restart if needed
sudo systemctl restart nginx
```

### 502 Bad Gateway?
```bash
# Check if backend is running
curl localhost:8080  # For kafka-ui
curl localhost:5601  # For kibana
# etc.

# Check Docker containers
docker ps
docker-compose ps
```

### Configuration Changes Not Applied?
```bash
# Test configuration
sudo nginx -t

# Reload nginx (if test passed)
sudo systemctl reload nginx
```

## File Locations Reference

```
Configuration:
/etc/nginx/nginx.conf                    # Main config
/etc/nginx/upstreams/                    # Upstream definitions
/etc/nginx/snippets/                     # Reusable configs
/etc/nginx/sites-available/              # All site configs
/etc/nginx/sites-enabled/                # Enabled sites (symlinks)

Logs:
/var/log/nginx/*-access.log              # Access logs
/var/log/nginx/*-error.log               # Error logs

Web Root:
/var/www/test/                           # Test site files
```

## Port Mapping

| Service | Container Port | Exposed Port | Domain |
|---------|---------------|--------------|---------|
| Kafka UI | 8080 | 127.0.0.1:8080 | kafka.duongbd.site |
| Kibana | 5601 | 127.0.0.1:5601 | kibana.duongbd.site |
| Elasticsearch | 9200 | 127.0.0.1:9200 | es.duongbd.site |
| Adminer | 8080 | 127.0.0.1:8081 | mysql.duongbd.site |
| Redis Commander | 8081 | 127.0.0.1:8082 | redis.duongbd.site |
| Nexus | 8081 | 127.0.0.1:8083 | nexus.duongbd.site |

## Security Checklist

- ✓ Security headers enabled
- ✓ Rate limiting configured
- ✓ Connection limits set
- ✓ Cloudflare real IP detection
- ✓ Minimal server info disclosure
- ✓ Service-specific timeouts
- ⚠️ Consider adding basic auth for admin interfaces
- ⚠️ Consider IP whitelisting for sensitive services
- ⚠️ Monitor access logs regularly

## Next Steps

1. **Test all services** - Verify each endpoint works
2. **Monitor logs** - Watch for any errors
3. **Set up alerting** - Configure monitoring tools
4. **Backup configuration** - Use `nginx-manager.sh backup`
5. **Review security** - Add authentication where needed
6. **Optimize performance** - Tune based on your traffic

## Getting Help

**Configuration Issues:**
```bash
sudo nginx -t                    # Test config
sudo ./check-nginx-health.sh     # Run diagnostics
```

**Service Issues:**
```bash
docker ps                        # Check containers
docker-compose logs <service>    # Check Docker logs
```

**Nginx Issues:**
```bash
sudo systemctl status nginx      # Check service
sudo journalctl -u nginx -n 50   # Check system logs
```

## Important Notes

- All administrative UIs (Adminer, Redis Commander, etc.) are exposed without authentication by default
- Consider adding basic authentication or IP restrictions for production
- Logs rotate automatically every day (14 days retention)
- Configuration backups are stored in `/root/nginx-backups/`
- Health check endpoints are available at `/health` for each domain

---

**Need more details?** See [README.md](README.md) for comprehensive documentation.

**Report issues?** Check logs first:
```bash
sudo tail -f /var/log/nginx/error.log
docker-compose logs --tail=100
```
