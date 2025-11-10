#!/bin/bash

#####################################################################
# Nginx Installation Script for Ubuntu
# Purpose: Automated setup of nginx with backend proxy configurations
# Author: System Administrator
# Version: 1.0.0
#####################################################################

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="/root/nginx-backup-$(date +%Y%m%d-%H%M%S)"

#####################################################################
# Helper Functions
#####################################################################

print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
    print_success "Running as root"
}

#####################################################################
# Installation Functions
#####################################################################

install_nginx() {
    print_header "Installing Nginx"

    if command -v nginx &> /dev/null; then
        print_warning "Nginx is already installed"
        nginx -v
        read -p "Do you want to reinstall? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Skipping nginx installation"
            return 0
        fi
    fi

    print_info "Updating package lists..."
    apt-get update -qq

    print_info "Installing nginx..."
    apt-get install -y nginx

    print_success "Nginx installed successfully"
    nginx -v
}

backup_existing_config() {
    print_header "Backing Up Existing Configuration"

    if [ -d "/etc/nginx" ]; then
        print_info "Creating backup at $BACKUP_DIR"
        mkdir -p "$BACKUP_DIR"
        cp -r /etc/nginx/* "$BACKUP_DIR/"
        print_success "Backup created: $BACKUP_DIR"
    else
        print_info "No existing nginx configuration to backup"
    fi
}

create_directories() {
    print_header "Creating Directory Structure"

    directories=(
        "/etc/nginx/sites-available"
        "/etc/nginx/sites-enabled"
        "/etc/nginx/snippets"
        "/etc/nginx/conf.d"
        "/var/www/html"
        "/var/log/nginx"
    )

    for dir in "${directories[@]}"; do
        if [ ! -d "$dir" ]; then
            mkdir -p "$dir"
            print_success "Created: $dir"
        else
            print_info "Already exists: $dir"
        fi
    done
}

copy_configuration_files() {
    print_header "Copying Configuration Files"

    # Main nginx.conf
    if [ -f "$SCRIPT_DIR/nginx/nginx.conf" ]; then
        cp "$SCRIPT_DIR/nginx/nginx.conf" /etc/nginx/nginx.conf
        print_success "Copied: nginx.conf"
    fi

    # Upstreams
    if [ -f "$SCRIPT_DIR/nginx/conf.d/upstreams.conf" ]; then
        cp "$SCRIPT_DIR/nginx/conf.d/upstreams.conf" /etc/nginx/conf.d/
        print_success "Copied: upstreams.conf"
    fi

    # Snippets
    if [ -d "$SCRIPT_DIR/nginx/snippets" ]; then
        cp -r "$SCRIPT_DIR/nginx/snippets/"* /etc/nginx/snippets/
        print_success "Copied: snippets"
    fi

    # Sites
    if [ -d "$SCRIPT_DIR/nginx/sites-available" ]; then
        cp "$SCRIPT_DIR/nginx/sites-available/"*.conf /etc/nginx/sites-available/
        print_success "Copied: site configurations"
    fi
}

enable_sites() {
    print_header "Enabling Sites"

    # Remove default nginx site
    if [ -f "/etc/nginx/sites-enabled/default" ]; then
        rm -f /etc/nginx/sites-enabled/default
        print_info "Removed default nginx site"
    fi

    # Enable all sites
    for conf in /etc/nginx/sites-available/*.conf; do
        filename=$(basename "$conf")
        sitename="${filename%.conf}"

        if [ ! -L "/etc/nginx/sites-enabled/$filename" ]; then
            ln -s "/etc/nginx/sites-available/$filename" "/etc/nginx/sites-enabled/$filename"
            print_success "Enabled: $sitename"
        else
            print_info "Already enabled: $sitename"
        fi
    done
}

set_permissions() {
    print_header "Setting Permissions"

    chown -R www-data:www-data /var/www/html
    chmod -R 755 /var/www/html

    chown -R root:root /etc/nginx
    chmod -R 644 /etc/nginx
    find /etc/nginx -type d -exec chmod 755 {} \;

    print_success "Permissions set correctly"
}

test_configuration() {
    print_header "Testing Nginx Configuration"

    if nginx -t 2>&1; then
        print_success "Configuration test passed"
        return 0
    else
        print_error "Configuration test failed"
        print_warning "Check the error messages above"
        return 1
    fi
}

start_nginx() {
    print_header "Starting Nginx Service"

    systemctl enable nginx
    systemctl restart nginx

    if systemctl is-active --quiet nginx; then
        print_success "Nginx is running"
    else
        print_error "Nginx failed to start"
        print_info "Check logs: journalctl -xeu nginx.service"
        return 1
    fi
}

create_test_page() {
    print_header "Creating Test Page"

    cat > /var/www/html/index.html <<'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Nginx Setup Complete</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            max-width: 800px;
            margin: 50px auto;
            padding: 20px;
            background: #f5f5f5;
        }
        .container {
            background: white;
            padding: 30px;
            border-radius: 10px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
        h1 { color: #009639; }
        .status { color: #009639; font-weight: bold; }
        .service-list {
            list-style: none;
            padding: 0;
        }
        .service-list li {
            padding: 10px;
            margin: 5px 0;
            background: #f9f9f9;
            border-left: 3px solid #009639;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 Nginx Setup Complete!</h1>
        <p class="status">✅ Your nginx reverse proxy is running successfully</p>

        <h2>📋 Configured Services</h2>
        <ul class="service-list">
            <li><strong>Kafka UI:</strong> kafka.duongbd.site → localhost:8080</li>
            <li><strong>Kibana:</strong> kibana.duongbd.site → localhost:5601</li>
            <li><strong>Elasticsearch:</strong> es.duongbd.site → localhost:9200</li>
            <li><strong>MySQL Adminer:</strong> mysql.duongbd.site → localhost:8081</li>
            <li><strong>Redis Commander:</strong> redis.duongbd.site → localhost:8082</li>
            <li><strong>Nexus:</strong> nexus.duongbd.site → localhost:8083</li>
        </ul>

        <h2>🔍 Health Checks</h2>
        <p>Each service has a health endpoint: <code>/health</code></p>

        <h2>📊 Monitoring</h2>
        <p>Nginx status available at: <code>/nginx_status</code></p>

        <h2>📝 Logs</h2>
        <p>Check logs at: <code>/var/log/nginx/</code></p>
    </div>
</body>
</html>
EOF

    print_success "Test page created at /var/www/html/index.html"
}

display_summary() {
    print_header "Installation Summary"

    echo -e "${GREEN}✅ Nginx installation completed successfully!${NC}\n"

    echo "📁 Configuration files:"
    echo "   - Main config: /etc/nginx/nginx.conf"
    echo "   - Upstreams: /etc/nginx/conf.d/upstreams.conf"
    echo "   - Sites: /etc/nginx/sites-available/"
    echo "   - Snippets: /etc/nginx/snippets/"

    if [ -d "$BACKUP_DIR" ]; then
        echo -e "\n💾 Backup location: $BACKUP_DIR"
    fi

    echo -e "\n🌐 Configured domains:"
    echo "   - kafka.duongbd.site"
    echo "   - kibana.duongbd.site"
    echo "   - es.duongbd.site"
    echo "   - mysql.duongbd.site"
    echo "   - redis.duongbd.site"
    echo "   - nexus.duongbd.site"
    echo "   - test.duongbd.site"

    echo -e "\n🔧 Useful commands:"
    echo "   - Test config: sudo nginx -t"
    echo "   - Reload: sudo systemctl reload nginx"
    echo "   - Restart: sudo systemctl restart nginx"
    echo "   - Status: sudo systemctl status nginx"
    echo "   - Logs: tail -f /var/log/nginx/*.log"

    echo -e "\n📝 Next steps:"
    echo "   1. Ensure your Docker containers are running"
    echo "   2. Configure Cloudflare tunnel to point to this server"
    echo "   3. Test each service endpoint"
    echo "   4. Review logs for any issues"

    echo -e "\n${BLUE}Happy proxying! 🎉${NC}\n"
}

#####################################################################
# Main Installation Flow
#####################################################################

main() {
    print_header "Nginx Installation Script"
    echo "This script will install and configure nginx for backend services"
    echo "Press Ctrl+C to cancel, or wait 5 seconds to continue..."
    sleep 5

    check_root
    install_nginx
    backup_existing_config
    create_directories
    copy_configuration_files
    enable_sites
    set_permissions
    create_test_page

    if test_configuration; then
        start_nginx
        display_summary
        exit 0
    else
        print_error "Installation completed with errors"
        print_warning "Please fix the configuration errors and run: sudo nginx -t"
        exit 1
    fi
}

# Run main function
main "$@"
