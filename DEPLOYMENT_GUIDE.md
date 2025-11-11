# Deployment Guide - MySQL/Redis Timeout Fix

## Overview
This guide walks through deploying the MySQL operation timeout fixes for remote connections through Cloudflare Tunnel.

## Changes Summary

### 1. docker-compose.yml
- Added MySQL timeout parameters for long-running operations
- Increased `net_read_timeout` and `net_write_timeout` from 30s to 300s (5 minutes)
- Set `connect_timeout` to 60s for initial connections
- Added `max_allowed_packet=256M` for large data transfers

### 2. tunnel.yml
- Added TCP keepalive settings for MySQL and Redis
- `tcpKeepAlive: 30s` - sends keepalive packets every 30 seconds
- `connectTimeout: 60s` - initial TCP connection timeout
- `keepAliveConnections: 100` - maintains connection pool

### 3. springboot-connection-example.md
- Updated JDBC URL with connection and socket timeouts
- Enhanced HikariCP configuration with keepalive settings
- Added comprehensive troubleshooting guide

## Deployment Steps

### Step 1: Stop Services
```bash
cd /Users/smartbpm/duongbd/code/infrastructure/nginx-setup-complete

# Stop Docker containers
docker-compose down
```

### Step 2: Restart MySQL with New Configuration
```bash
# Start only MySQL to verify new timeout settings
docker-compose up -d mysql

# Wait for MySQL to start
sleep 10

# Verify MySQL timeout settings
docker exec -it mysql mysql -u root -prootpassword -e "SHOW VARIABLES LIKE '%timeout%';"
```

Expected output should include:
```
wait_timeout              | 28800  (8 hours)
interactive_timeout       | 28800  (8 hours)
net_read_timeout          | 300    (5 minutes)
net_write_timeout         | 300    (5 minutes)
connect_timeout           | 60     (60 seconds)
```

### Step 3: Start All Services
```bash
# Start all services
docker-compose up -d

# Verify all containers are running
docker-compose ps
```

### Step 4: Update Cloudflare Tunnel Configuration
```bash
# Backup current tunnel configuration
sudo cp /etc/cloudflared/config.yml /etc/cloudflared/config.yml.backup

# Copy updated tunnel.yml to Cloudflare config location
sudo cp tunnel.yml /etc/cloudflared/config.yml

# Validate tunnel configuration
sudo cloudflared tunnel ingress validate

# Restart Cloudflare Tunnel
sudo systemctl restart cloudflared

# Verify tunnel is running
sudo systemctl status cloudflared

# Check tunnel logs for any errors
sudo journalctl -u cloudflared -n 50 --no-pager
```

### Step 5: Verify DNS Records (Cloudflare Dashboard)

Ensure these DNS records exist in your Cloudflare domain:

| Type  | Name  | Target                                    |
|-------|-------|-------------------------------------------|
| CNAME | db    | d46bfa9f-b5ef-4393-8191-dc058a9577db.cfargotunnel.com |
| CNAME | cache | d46bfa9f-b5ef-4393-8191-dc058a9577db.cfargotunnel.com |

### Step 6: Test Local Connections
```bash
# Test MySQL locally
mysql -h 127.0.0.1 -P 3306 -u scangoo -pDuong02vodoi scangoo -e "SELECT 'MySQL OK';"

# Test Redis locally
redis-cli -h 127.0.0.1 -p 6379 ping
```

### Step 7: Test Remote Connections

**From a remote machine** (e.g., your Spring Boot server):

```bash
# Test MySQL connection
mysql -h db.duongbd.site -P 3306 -u scangoo -pDuong02vodoi scangoo -e "SELECT 'Remote MySQL OK';"

# Test long-running operation (60 second sleep)
mysql -h db.duongbd.site -P 3306 -u scangoo -pDuong02vodoi scangoo -e "SELECT SLEEP(60) AS test;"

# Test Redis connection
redis-cli -h cache.duongbd.site -p 6379 ping
```

### Step 8: Update Spring Boot Application

Update your `application.properties` or `application.yml`:

**application.properties**:
```properties
spring.datasource.url=jdbc:mysql://db.duongbd.site:3306/scangoo?connectTimeout=60000&socketTimeout=300000&autoReconnect=true&maxReconnects=3
spring.datasource.hikari.keepalive-time=300000
spring.datasource.hikari.connection-timeout=60000
```

**application.yml**:
```yaml
spring:
  datasource:
    url: jdbc:mysql://db.duongbd.site:3306/scangoo?connectTimeout=60000&socketTimeout=300000&autoReconnect=true&maxReconnects=3
    hikari:
      keepalive-time: 300000
      connection-timeout: 60000
```

### Step 9: Restart Spring Boot Application
```bash
# Restart your Spring Boot application
# Example for systemd service:
sudo systemctl restart your-spring-boot-app

# Or if running as jar:
./mvnw spring-boot:run
```

### Step 10: Monitor and Validate

**Check Cloudflare Tunnel Logs**:
```bash
sudo journalctl -u cloudflared -f
```

**Monitor MySQL Connections**:
```bash
# Connect to MySQL
docker exec -it mysql mysql -u root -prootpassword

# Run monitoring queries
SHOW PROCESSLIST;
SHOW STATUS LIKE 'Threads_connected';
SHOW STATUS LIKE 'Aborted_connects';
```

**Monitor Spring Boot Logs**:
```bash
# Check for connection pool warnings
tail -f /path/to/spring-boot/logs/application.log | grep -i "hikari\|connection\|timeout"
```

## Verification Checklist

- [ ] MySQL container started with new timeout settings
- [ ] All Docker containers running (`docker-compose ps`)
- [ ] Cloudflare Tunnel restarted successfully
- [ ] DNS records verified in Cloudflare dashboard
- [ ] Local MySQL connection works
- [ ] Local Redis connection works
- [ ] Remote MySQL connection from different machine works
- [ ] Long-running query (60s+) completes without timeout
- [ ] Remote Redis connection works
- [ ] Spring Boot application connects successfully
- [ ] No connection timeout errors in application logs

## Rollback Procedure

If issues occur:

```bash
# Stop services
docker-compose down

# Restore original tunnel config
sudo cp /etc/cloudflared/config.yml.backup /etc/cloudflared/config.yml
sudo systemctl restart cloudflared

# Restore original docker-compose.yml from git
git checkout docker-compose.yml

# Restart services
docker-compose up -d
```

## Common Issues

### MySQL Still Timing Out
1. Check Cloudflare Tunnel logs: `sudo journalctl -u cloudflared -f`
2. Verify MySQL timeout settings: `docker exec -it mysql mysql -u root -prootpassword -e "SHOW VARIABLES LIKE '%timeout%';"`
3. Check Spring Boot connection pool settings
4. Ensure DNS is resolving correctly: `nslookup db.duongbd.site`

### Cloudflare Tunnel Not Starting
1. Validate config: `sudo cloudflared tunnel ingress validate`
2. Check logs: `sudo journalctl -u cloudflared -xe`
3. Verify tunnel credentials file exists
4. Test manual start: `sudo cloudflared tunnel --config /etc/cloudflared/config.yml run`

### Spring Boot Connection Pool Exhausted
1. Increase pool size: `spring.datasource.hikari.maximum-pool-size=20`
2. Reduce max-lifetime: `spring.datasource.hikari.max-lifetime=900000` (15 min)
3. Enable leak detection: `spring.datasource.hikari.leak-detection-threshold=30000`

## Performance Tuning

### For High-Traffic Applications
```properties
# Increase connection pool
spring.datasource.hikari.maximum-pool-size=20
spring.datasource.hikari.minimum-idle=10

# Faster failover
spring.datasource.hikari.connection-timeout=30000
spring.datasource.hikari.validation-timeout=3000
```

### For Long-Running Operations
```properties
# Extend timeouts
jdbc:mysql://db.duongbd.site:3306/scangoo?connectTimeout=60000&socketTimeout=600000&autoReconnect=true

spring.datasource.hikari.max-lifetime=3600000  # 1 hour
```

## Monitoring

### Set Up MySQL Slow Query Log
```bash
docker exec -it mysql mysql -u root -prootpassword -e "
SET GLOBAL slow_query_log = 'ON';
SET GLOBAL long_query_time = 2;
SET GLOBAL log_queries_not_using_indexes = 'ON';
"
```

### Monitor Cloudflare Tunnel Metrics
```bash
# Real-time tunnel stats
watch -n 5 'sudo cloudflared tunnel info'
```

### Spring Boot Actuator Monitoring
```properties
# Add to application.properties
management.endpoints.web.exposure.include=health,metrics,info
management.endpoint.health.show-details=always
```

Access metrics at: `http://your-app:8080/actuator/metrics/hikaricp.connections.active`

## Support

For issues, check:
1. Docker logs: `docker-compose logs -f mysql redis`
2. Cloudflare Tunnel logs: `sudo journalctl -u cloudflared -f`
3. Spring Boot logs: Application-specific location
4. Network connectivity: `ping db.duongbd.site`, `telnet db.duongbd.site 3306`
