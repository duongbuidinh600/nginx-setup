#!/bin/bash

###############################################################################
# Nginx Setup Script for Docker Services
# Author: Claude
# Description: Automated setup for Nginx reverse proxy with best practices
###############################################################################

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "Please run this script as root or with sudo"
        exit 1
    fi
}

###############################################################################
# Main Installation
###############################################################################

print_info "Starting Nginx installation and configuration..."

# Check if running as root
check_root

# Update system packages
print_info "Updating system packages..."
apt-get update

# Install Nginx
print_info "Installing Nginx..."
apt-get install -y nginx

# Stop Nginx for configuration
print_info "Stopping Nginx for configuration..."
systemctl stop nginx

# Backup original configuration
print_info "Backing up original Nginx configuration..."
if [ -f /etc/nginx/nginx.conf ]; then
    cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.backup.$(date +%Y%m%d_%H%M%S)
fi

# Create necessary directories
print_info "Creating directory structure..."
mkdir -p /etc/nginx/conf.d
mkdir -p /etc/nginx/sites-available
mkdir -p /etc/nginx/sites-enabled
mkdir -p /etc/nginx/snippets
mkdir -p /var/www/html

# Copy main configuration
print_info "Installing main Nginx configuration..."
cp nginx/nginx.conf /etc/nginx/nginx.conf

# Copy upstream configuration
print_info "Installing upstream definitions..."
cp nginx/conf.d/upstreams.conf /etc/nginx/conf.d/

# Copy snippets
print_info "Installing configuration snippets..."
cp nginx/snippets/proxy-headers.conf /etc/nginx/snippets/
cp nginx/snippets/security-headers.conf /etc/nginx/snippets/

# Copy site configurations
print_info "Installing site configurations..."
cp nginx/sites-available/*.conf /etc/nginx/sites-available/

# Enable sites by creating symbolic links
print_info "Enabling sites..."
ln -sf /etc/nginx/sites-available/default.conf /etc/nginx/sites-enabled/
ln -sf /etc/nginx/sites-available/kafka.conf /etc/nginx/sites-enabled/
ln -sf /etc/nginx/sites-available/kibana.conf /etc/nginx/sites-enabled/
ln -sf /etc/nginx/sites-available/elasticsearch.conf /etc/nginx/sites-enabled/
ln -sf /etc/nginx/sites-available/mysql.conf /etc/nginx/sites-enabled/
ln -sf /etc/nginx/sites-available/redis.conf /etc/nginx/sites-enabled/
ln -sf /etc/nginx/sites-available/nexus.conf /etc/nginx/sites-enabled/

# Remove default Nginx site if exists
if [ -f /etc/nginx/sites-enabled/default ]; then
    print_info "Removing default Nginx site..."
    rm /etc/nginx/sites-enabled/default
fi

# Create a simple test page
print_info "Creating test page..."
cat > /var/www/html/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Nginx is running</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            max-width: 800px;
            margin: 50px auto;
            padding: 20px;
            background-color: #f5f5f5;
        }
        .container {
            background-color: white;
            padding: 30px;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        h1 { color: #333; }
        .success { color: #28a745; }
        .info { color: #17a2b8; }
        ul { list-style-type: none; padding: 0; }
        li { padding: 8px; margin: 5px 0; background-color: #f8f9fa; border-radius: 4px; }
        a { color: #007bff; text-decoration: none; }
        a:hover { text-decoration: underline; }
    </style>
</head>
<body>
    <div class="container">
        <h1 class="success">✓ Nginx is running successfully!</h1>
        <p class="info">Your reverse proxy is configured and ready.</p>
        
        <h2>Available Services:</h2>
        <ul>
            <li><a href="http://kafka.duongbd.site">Kafka UI</a> - kafka.duongbd.site</li>
            <li><a href="http://kibana.duongbd.site">Kibana</a> - kibana.duongbd.site</li>
            <li><a href="http://es.duongbd.site">Elasticsearch</a> - es.duongbd.site</li>
            <li><a href="http://mysql.duongbd.site">MySQL Adminer</a> - mysql.duongbd.site</li>
            <li><a href="http://redis.duongbd.site">Redis Commander</a> - redis.duongbd.site</li>
            <li><a href="http://nexus.duongbd.site">Nexus Repository</a> - nexus.duongbd.site</li>
        </ul>

        <h2>System Info:</h2>
        <ul>
            <li>Server: test.duongbd.site</li>
            <li>Status: <a href="/nginx_status">Nginx Status</a></li>
            <li>Health: <a href="/health">Health Check</a></li>
        </ul>
    </div>
</body>
</html>
EOF

# Test Nginx configuration
print_info "Testing Nginx configuration..."
if nginx -t; then
    print_success "Nginx configuration is valid!"
else
    print_error "Nginx configuration test failed!"
    exit 1
fi

# Enable and start Nginx
print_info "Enabling and starting Nginx..."
systemctl enable nginx
systemctl start nginx

# Check Nginx status
if systemctl is-active --quiet nginx; then
    print_success "Nginx is running!"
else
    print_error "Failed to start Nginx!"
    systemctl status nginx
    exit 1
fi

# Configure firewall if UFW is installed
if command -v ufw &> /dev/null; then
    print_info "Configuring UFW firewall..."
    ufw allow 'Nginx Full'
    print_success "Firewall configured!"
fi

# Print summary
print_success "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
print_success "Nginx installation and configuration completed!"
print_success "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo
print_info "Services are accessible via:"
echo "  - Kafka UI:          http://kafka.duongbd.site"
echo "  - Kibana:            http://kibana.duongbd.site"
echo "  - Elasticsearch:     http://es.duongbd.site"
echo "  - MySQL Adminer:     http://mysql.duongbd.site"
echo "  - Redis Commander:   http://redis.duongbd.site"
echo "  - Nexus Repository:  http://nexus.duongbd.site"
echo "  - Test Page:         http://test.duongbd.site"
echo
print_info "Useful commands:"
echo "  - Test config:       nginx -t"
echo "  - Reload config:     systemctl reload nginx"
echo "  - Restart Nginx:     systemctl restart nginx"
echo "  - View logs:         tail -f /var/log/nginx/*.log"
echo "  - Check status:      systemctl status nginx"
echo
print_warning "Next steps:"
echo "  1. Update your docker-compose.yml with the provided version"
echo "  2. Restart Docker containers: docker-compose up -d"
echo "  3. Verify all services are accessible"
echo "  4. Configure Cloudflare Tunnel to route traffic to port 80"
echo

exit 0
