# Spring Boot Configuration for MySQL and Redis via Domain

## Overview
This guide shows how to configure Spring Boot applications to connect to MySQL and Redis using domain names through Cloudflare Tunnel.

## Domain Mappings

- **MySQL Database**: `db.duongbd.site:3306`
- **Redis Cache**: `cache.duongbd.site:6379`

## MySQL Configuration

### application.properties
```properties
# MySQL Database Configuration
spring.datasource.url=jdbc:mysql://db.duongbd.site:3306/scangoo
spring.datasource.username=scangoo
spring.datasource.password=Duong02vodoi
spring.datasource.driver-class-name=com.mysql.cj.jdbc.Driver

# JPA Configuration
spring.jpa.hibernate.ddl-auto=update
spring.jpa.show-sql=true
spring.jpa.properties.hibernate.dialect=org.hibernate.dialect.MySQL8Dialect

# Connection Pool (HikariCP)
spring.datasource.hikari.maximum-pool-size=10
spring.datasource.hikari.minimum-idle=5
spring.datasource.hikari.connection-timeout=30000
spring.datasource.hikari.idle-timeout=600000
spring.datasource.hikari.max-lifetime=1800000
```

### application.yml
```yaml
spring:
  datasource:
    url: jdbc:mysql://db.duongbd.site:3306/scangoo
    username: scangoo
    password: Duong02vodoi
    driver-class-name: com.mysql.cj.jdbc.Driver
    hikari:
      maximum-pool-size: 10
      minimum-idle: 5
      connection-timeout: 30000
      idle-timeout: 600000
      max-lifetime: 1800000

  jpa:
    hibernate:
      ddl-auto: update
    show-sql: true
    properties:
      hibernate:
        dialect: org.hibernate.dialect.MySQL8Dialect
```

### pom.xml Dependency
```xml
<dependency>
    <groupId>com.mysql</groupId>
    <artifactId>mysql-connector-j</artifactId>
    <scope>runtime</scope>
</dependency>
```

## Redis Configuration

### application.properties
```properties
# Redis Configuration
spring.data.redis.host=cache.duongbd.site
spring.data.redis.port=6379
spring.data.redis.timeout=60000

# Redis Connection Pool (Lettuce)
spring.data.redis.lettuce.pool.max-active=8
spring.data.redis.lettuce.pool.max-idle=8
spring.data.redis.lettuce.pool.min-idle=0
spring.data.redis.lettuce.pool.max-wait=-1ms

# Cache Configuration
spring.cache.type=redis
spring.cache.redis.time-to-live=600000
```

### application.yml
```yaml
spring:
  data:
    redis:
      host: cache.duongbd.site
      port: 6379
      timeout: 60000
      lettuce:
        pool:
          max-active: 8
          max-idle: 8
          min-idle: 0
          max-wait: -1ms

  cache:
    type: redis
    redis:
      time-to-live: 600000
```

### pom.xml Dependencies
```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-data-redis</artifactId>
</dependency>
<dependency>
    <groupId>io.lettuce</groupId>
    <artifactId>lettuce-core</artifactId>
</dependency>
```

## Redis Cache Configuration Class

```java
package com.example.config;

import org.springframework.cache.annotation.EnableCaching;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.data.redis.cache.RedisCacheConfiguration;
import org.springframework.data.redis.cache.RedisCacheManager;
import org.springframework.data.redis.connection.RedisConnectionFactory;
import org.springframework.data.redis.serializer.GenericJackson2JsonRedisSerializer;
import org.springframework.data.redis.serializer.RedisSerializationContext;
import org.springframework.data.redis.serializer.StringRedisSerializer;

import java.time.Duration;

@Configuration
@EnableCaching
public class RedisConfig {

    @Bean
    public RedisCacheManager cacheManager(RedisConnectionFactory connectionFactory) {
        RedisCacheConfiguration config = RedisCacheConfiguration.defaultCacheConfig()
            .entryTtl(Duration.ofMinutes(10))
            .serializeKeysWith(
                RedisSerializationContext.SerializationPair.fromSerializer(new StringRedisSerializer())
            )
            .serializeValuesWith(
                RedisSerializationContext.SerializationPair.fromSerializer(new GenericJackson2JsonRedisSerializer())
            );

        return RedisCacheManager.builder(connectionFactory)
            .cacheDefaults(config)
            .build();
    }
}
```

## Connection Testing

### MySQL Connection Test
```java
package com.example.service;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import javax.sql.DataSource;
import java.sql.Connection;

@Service
public class DatabaseTestService {

    @Autowired
    private DataSource dataSource;

    public boolean testMySQLConnection() {
        try (Connection conn = dataSource.getConnection()) {
            return conn.isValid(5);
        } catch (Exception e) {
            e.printStackTrace();
            return false;
        }
    }
}
```

### Redis Connection Test
```java
package com.example.service;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.stereotype.Service;

@Service
public class RedisTestService {

    @Autowired
    private RedisTemplate<String, Object> redisTemplate;

    public boolean testRedisConnection() {
        try {
            redisTemplate.opsForValue().set("test:connection", "success");
            String result = (String) redisTemplate.opsForValue().get("test:connection");
            redisTemplate.delete("test:connection");
            return "success".equals(result);
        } catch (Exception e) {
            e.printStackTrace();
            return false;
        }
    }
}
```

## Environment-Specific Configuration

### Development (application-dev.properties)
```properties
spring.datasource.url=jdbc:mysql://localhost:3306/scangoo
spring.data.redis.host=localhost
```

### Production (application-prod.properties)
```properties
spring.datasource.url=jdbc:mysql://db.duongbd.site:3306/scangoo
spring.data.redis.host=cache.duongbd.site
```

## Security Considerations

1. **Never commit credentials**: Use environment variables or secret management
2. **Use SSL/TLS**: For production, enable SSL for MySQL and Redis connections
3. **Network Security**: Cloudflare Tunnel provides encrypted connection
4. **Access Control**: Configure MySQL user permissions appropriately

### Using Environment Variables
```properties
spring.datasource.url=jdbc:mysql://${DB_HOST:db.duongbd.site}:${DB_PORT:3306}/${DB_NAME:scangoo}
spring.datasource.username=${DB_USERNAME:scangoo}
spring.datasource.password=${DB_PASSWORD}

spring.data.redis.host=${REDIS_HOST:cache.duongbd.site}
spring.data.redis.port=${REDIS_PORT:6379}
```

## Troubleshooting

### Connection Timeout
- Check Cloudflare Tunnel is running
- Verify DNS records for db.duongbd.site and cache.duongbd.site
- Increase connection timeout in application.properties

### MySQL Access Denied
- Verify username/password
- Check MySQL user has correct host permissions: `scangoo@%` or `scangoo@db.duongbd.site`

### Redis Connection Refused
- Ensure Redis container is running
- Check Redis is not protected by password (or add password to config)
- Verify tunnel.yml has correct Redis port mapping

## Architecture Flow

```
Spring Boot App → db.duongbd.site:3306 → Cloudflare Tunnel → localhost:3306 → MySQL Container
Spring Boot App → cache.duongbd.site:6379 → Cloudflare Tunnel → localhost:6379 → Redis Container
```
