# Nginx Quick Reference

## 🚀 Installation
```bash
sudo ./install.sh
```

## 🔧 Common Commands

### Configuration Testing
```bash
sudo nginx -t                           # Test configuration
sudo nginx -T                           # Test and dump configuration
```

### Service Control
```bash
sudo systemctl start nginx              # Start Nginx
sudo systemctl stop nginx               # Stop Nginx
sudo systemctl restart nginx            # Restart (brief downtime)
sudo systemctl reload nginx             # Reload (zero downtime)
sudo systemctl status nginx             # Check status
sudo systemctl enable nginx             # Enable on boot
```

### Management Script
```bash
sudo ./manage.sh test                   # Test config
sudo ./manage.sh reload                 # Reload Nginx
sudo ./manage.sh status                 # Service status
sudo ./manage.sh check                  # Check upstreams
sudo ./manage.sh list                   # List sites
sudo ./manage.sh logs [type]            # View logs
```

## 📋 Service URLs

| Service | URL | Port |
|---------|-----|------|
| Kafka UI | kafka.duongbd.site | 8080 |
| Kibana | kibana.duongbd.site | 5601 |
| Elasticsearch | es.duongbd.site | 9200 |
| MySQL (Adminer) | mysql.duongbd.site | 8081 |
| Redis Commander | redis.duongbd.site | 8082 |
| Nexus | nexus.duongbd.site | 8083 |
| Test/Default | test.duongbd.site | - |

## 📁 Important Files

```
/etc/nginx/nginx.conf                   # Main configuration
/etc/nginx/conf.d/upstreams.conf        # Backend definitions
/etc/nginx/sites-available/             # Available sites
/etc/nginx/sites-enabled/               # Enabled sites
/etc/nginx/snippets/                    # Reusable configs
/var/log/nginx/                         # Log files
```

## 📊 Logs

```bash
# Access logs
tail -f /var/log/nginx/access.log

# Error logs
tail -f /var/log/nginx/error.log

# Service-specific
tail -f /var/log/nginx/kafka-ui.access.log
tail -f /var/log/nginx/kibana.access.log

# All logs
tail -f /var/log/nginx/*.log
```

## 🔍 Debugging

```bash
# Check if service is reachable
curl -I http://localhost:8080
nc -zv localhost 8080

# Check nginx processes
ps aux | grep nginx

# Check listening ports
netstat -tlnp | grep nginx
ss -tlnp | grep nginx

# Check active connections
ss -tn | grep :80

# Check configuration syntax
nginx -t 2>&1 | grep -v "successful"
```

## 🔄 Enable/Disable Sites

```bash
# Enable site
sudo ln -sf /etc/nginx/sites-available/kafka.conf /etc/nginx/sites-enabled/
sudo systemctl reload nginx

# Disable site
sudo rm /etc/nginx/sites-enabled/kafka.conf
sudo systemctl reload nginx

# Or use management script
sudo ./manage.sh enable kafka
sudo ./manage.sh disable kafka
```

## 🛠️ Troubleshooting

### 502 Bad Gateway
```bash
# Check if backend is running
docker ps
curl -I http://localhost:8080

# Check logs
tail -f /var/log/nginx/error.log

# Restart backend
docker-compose restart kafka-ui
```

### 504 Gateway Timeout
```bash
# Increase timeout in site config
proxy_read_timeout 300s;
proxy_connect_timeout 75s;

# Reload
sudo systemctl reload nginx
```

### Configuration Error
```bash
# Test config
sudo nginx -t

# View detailed errors
sudo journalctl -u nginx -n 50

# Restore backup
sudo cp /etc/nginx/nginx.conf.backup /etc/nginx/nginx.conf
```

## 🔐 Security

```bash
# Check open ports
sudo ss -tlnp

# View firewall rules
sudo ufw status

# Allow Nginx through firewall
sudo ufw allow 'Nginx Full'

# Check SELinux (if applicable)
sudo getenforce
```

## 📈 Performance Monitoring

```bash
# Nginx status
curl http://localhost/nginx_status

# Connection count
ss -tn | grep :80 | wc -l

# Top IPs
awk '{print $1}' /var/log/nginx/access.log | sort | uniq -c | sort -rn | head

# Response times
awk '{print $NF}' /var/log/nginx/access.log | sort -n | tail

# Request rate per minute
awk '{print $4}' /var/log/nginx/access.log | cut -d: -f1,2 | uniq -c
```

## 🔄 Reload vs Restart

**Reload (Recommended)**
- Zero downtime
- Graceful worker shutdown
- New workers start with new config
```bash
sudo systemctl reload nginx
```

**Restart**
- Brief service interruption
- All workers stop immediately
- Clean slate restart
```bash
sudo systemctl restart nginx
```

## 📦 Backup & Restore

```bash
# Backup
sudo tar -czf nginx-backup-$(date +%Y%m%d).tar.gz /etc/nginx/

# Restore
sudo tar -xzf nginx-backup-20240101.tar.gz -C /

# Test after restore
sudo nginx -t && sudo systemctl reload nginx
```

## 🎯 Quick Fixes

### Clear all sites and start fresh
```bash
sudo rm /etc/nginx/sites-enabled/*
sudo ./manage.sh enable default
sudo systemctl reload nginx
```

### Reset to default configuration
```bash
sudo cp /etc/nginx/nginx.conf.backup /etc/nginx/nginx.conf
sudo nginx -t && sudo systemctl restart nginx
```

### Force configuration reload
```bash
sudo nginx -s reload
```

### Kill all Nginx processes (emergency)
```bash
sudo killall -9 nginx
sudo systemctl start nginx
```

## 📞 Get Help

```bash
# Nginx version and modules
nginx -V

# System logs
sudo journalctl -u nginx --since "1 hour ago"

# Full status
sudo systemctl status nginx -l

# Configuration dump
nginx -T > nginx-config-dump.txt
```
