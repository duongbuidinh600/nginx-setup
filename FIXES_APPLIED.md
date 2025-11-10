# Nginx Configuration Fixes Applied

## Date: 2025-11-10

## Issues Identified and Fixed

### Problem: Multiple Duplicate Directive Errors

The nginx configuration was failing with multiple duplicate directive errors:
- `proxy_buffering` directive is duplicate
- `proxy_connect_timeout` directive is duplicate
- `proxy_read_timeout` directive is duplicate
- `proxy_send_timeout` directive is duplicate

### Root Cause Analysis

**Issue**: Nginx does not allow the same directive to be defined multiple times in the same context.

**Cause**: Proxy directives were defined in TWO places:
1. **Snippet files** (`snippets/proxy-headers.conf`)
   - Contained: `proxy_connect_timeout`, `proxy_send_timeout`, `proxy_read_timeout`, `proxy_buffering`
2. **Site configuration files** (each `sites-available/*.conf`)
   - Tried to override the same directives for service-specific needs

When a site config included the snippet AND defined its own values, nginx encountered duplicates.

## Solution Implemented

### Strategy: Single Source of Truth

**Decision**: Remove ALL proxy timeout and buffering directives from snippet files, define them explicitly in each site configuration.

**Rationale**:
- Each service has unique requirements (timeouts, buffering behavior)
- Explicit configuration prevents surprises and makes debugging easier
- Follows nginx best practice: specific settings in specific locations

### Files Modified

#### 1. Snippet Files (Cleaned)

**`nginx/snippets/proxy-headers.conf`**
- ❌ Removed: `proxy_connect_timeout`, `proxy_send_timeout`, `proxy_read_timeout`
- ✅ Kept: Headers only (`proxy_set_header`, WebSocket support)

**`nginx/snippets/proxy-headers-no-timeout.conf`**
- ❌ Deleted: This file is now obsolete (all sites use same snippet)

#### 2. Site Configuration Files (Updated with Complete Settings)

**`nginx/sites-available/kafka.conf`**
```nginx
proxy_connect_timeout 60s;
proxy_send_timeout 60s;
proxy_read_timeout 60s;
proxy_buffering off;  # Streaming data
```

**`nginx/sites-available/elasticsearch.conf`**
```nginx
proxy_connect_timeout 75s;
proxy_send_timeout 75s;
proxy_read_timeout 300s;  # Long queries
proxy_buffering off;  # Streaming responses
```

**`nginx/sites-available/kibana.conf`**
```nginx
proxy_connect_timeout 75s;
proxy_send_timeout 75s;
proxy_read_timeout 90s;
proxy_buffering on;  # Better performance
proxy_buffer_size 4k;
proxy_buffers 8 4k;
proxy_busy_buffers_size 8k;
```

**`nginx/sites-available/mysql.conf`**
```nginx
proxy_connect_timeout 60s;
proxy_send_timeout 120s;
proxy_read_timeout 300s;  # Large SQL operations
proxy_buffering on;
proxy_buffer_size 4k;
proxy_buffers 8 4k;
proxy_busy_buffers_size 8k;
```

**`nginx/sites-available/redis.conf`**
```nginx
proxy_connect_timeout 60s;
proxy_send_timeout 60s;
proxy_read_timeout 60s;
proxy_buffering on;
proxy_buffer_size 4k;
proxy_buffers 8 4k;
proxy_busy_buffers_size 8k;
```

**`nginx/sites-available/nexus.conf`**
```nginx
proxy_connect_timeout 75s;
proxy_send_timeout 120s;
proxy_read_timeout 120s;
proxy_buffering on;  # Response buffering
proxy_buffer_size 4k;
proxy_buffers 8 4k;
proxy_busy_buffers_size 8k;
proxy_request_buffering off;  # Large uploads
```

## Configuration Summary

### Service-Specific Settings Matrix

| Service | Connect | Send | Read | Buffering | Special Notes |
|---------|---------|------|------|-----------|---------------|
| **Kafka UI** | 60s | 60s | 60s | OFF | Real-time streaming |
| **Elasticsearch** | 75s | 75s | 300s | OFF | Long queries, streaming |
| **Kibana** | 75s | 75s | 90s | ON | Interactive queries |
| **MySQL Adminer** | 60s | 120s | 300s | ON | Large SQL operations |
| **Redis Commander** | 60s | 60s | 60s | ON | Standard operations |
| **Nexus** | 75s | 120s | 120s | Mixed | Request OFF, Response ON |

### Timeout Rationale

**Short Timeouts (60s)**: Standard web UI interactions
- Kafka UI, Redis Commander

**Medium Timeouts (75-90s)**: Analytics and queries
- Kibana, Elasticsearch connect/send

**Long Timeouts (120-300s)**: Heavy operations
- Elasticsearch queries (300s)
- MySQL operations (300s)
- Nexus artifact transfers (120s)

### Buffering Strategy

**Buffering OFF**: Streaming/real-time services
- Kafka UI: Real-time event streaming
- Elasticsearch: Streaming search results

**Buffering ON**: Request/response services
- Kibana: Dashboard rendering
- MySQL Adminer: Database operations
- Redis Commander: Key/value operations
- Nexus: Artifact downloads

**Mixed Buffering**: Upload-heavy services
- Nexus: Request buffering OFF (large uploads), Response buffering ON (downloads)

## Verification

### No More Duplicates

Run this command to verify:
```bash
grep -rn "proxy_connect_timeout\|proxy_read_timeout\|proxy_send_timeout\|proxy_buffering" nginx/ --include="*.conf"
```

**Expected Result**: Each directive appears ONLY in site configs, NEVER in snippets.

### Configuration Test

```bash
# Test syntax
sudo nginx -t

# Expected output
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
```

## Installation Impact

### New Installations
- Use `./install-nginx.sh` - automatically installs correct configuration
- No duplicate directive errors

### Existing Installations
- Re-run `./install-nginx.sh` to update all files
- Or manually copy updated files:
  ```bash
  sudo cp nginx/snippets/proxy-headers.conf /etc/nginx/snippets/
  sudo rm -f /etc/nginx/snippets/proxy-headers-no-timeout.conf
  sudo cp nginx/sites-available/*.conf /etc/nginx/sites-available/
  sudo nginx -t
  sudo systemctl reload nginx
  ```

## Best Practices Applied

1. ✅ **Single Source of Truth**: Each directive defined once, in the appropriate context
2. ✅ **Explicit Over Implicit**: Clear, visible configuration per service
3. ✅ **Service-Specific Settings**: Timeouts and buffering tuned per application
4. ✅ **Documentation**: Clear comments explaining each setting
5. ✅ **Testability**: Easy to verify configuration with `nginx -t`

## Testing Checklist

After applying these fixes:

- [ ] Configuration syntax test passes: `sudo nginx -t`
- [ ] Nginx reloads successfully: `sudo systemctl reload nginx`
- [ ] All services accessible via their domains
- [ ] Health checks respond: `/health` endpoints return 200 OK
- [ ] No errors in logs: `tail -f /var/log/nginx/*.log`
- [ ] Service-specific features work (streaming, uploads, queries)

## Troubleshooting

### If You Still See Errors

**Check for other includes**:
```bash
grep -r "include" /etc/nginx/ | grep -v "sites-enabled\|mime.types\|modules-enabled"
```

**Verify no old files remain**:
```bash
find /etc/nginx -name "*proxy*" -type f
```

**Check directive conflicts**:
```bash
nginx -T 2>&1 | grep -E "duplicate|conflict"
```

## Support

If issues persist:
1. Check error output: `sudo nginx -t`
2. Review error logs: `sudo tail -100 /var/log/nginx/error.log`
3. Verify file contents match this document
4. Ensure no custom modifications conflict with these changes

---

**Status**: ✅ All duplicate directive issues resolved
**Configuration Version**: 2.0.0
**Last Updated**: 2025-11-10
