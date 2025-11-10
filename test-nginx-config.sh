#!/bin/bash

#####################################################################
# Nginx Configuration Testing Script
# Purpose: Test nginx configuration and optionally reload/restart
# Usage: ./test-nginx-config.sh [--reload|--restart]
#####################################################################

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

echo -e "\n${BLUE}🔍 Testing Nginx Configuration Syntax...${NC}\n"

# Test nginx configuration syntax
if sudo nginx -t 2>&1; then
    print_success "Nginx configuration syntax is valid"
    echo ""

    # Show configuration summary
    print_info "Configuration Summary:"
    echo "  📄 Main config: /etc/nginx/nginx.conf"
    echo "  🔄 Upstreams: /etc/nginx/conf.d/upstreams.conf"

    if [ -d "/etc/nginx/sites-enabled" ]; then
        site_count=$(find /etc/nginx/sites-enabled -type l | wc -l)
        echo "  🌐 Sites enabled: $site_count"
        echo ""
        echo "  Enabled sites:"
        for site in /etc/nginx/sites-enabled/*; do
            if [ -L "$site" ]; then
                basename "$site" .conf | sed 's/^/    - /'
            fi
        done
    fi

    echo ""

    # Check nginx status
    if sudo systemctl is-active --quiet nginx; then
        print_success "Nginx service is running"

        # Handle command line arguments
        case "${1:-}" in
            --reload)
                print_info "Reloading nginx (zero-downtime)..."
                sudo systemctl reload nginx
                print_success "Nginx reloaded successfully"
                ;;
            --restart)
                print_info "Restarting nginx..."
                sudo systemctl restart nginx
                print_success "Nginx restarted successfully"
                ;;
            *)
                # Interactive mode
                echo ""
                echo "Choose an action:"
                echo "  1) Reload nginx (recommended, zero-downtime)"
                echo "  2) Restart nginx (full restart)"
                echo "  3) Skip (just test)"
                read -p "Enter choice [1-3]: " -n 1 -r
                echo ""

                case $REPLY in
                    1)
                        print_info "Reloading nginx..."
                        sudo systemctl reload nginx
                        print_success "Nginx reloaded successfully"
                        ;;
                    2)
                        print_info "Restarting nginx..."
                        sudo systemctl restart nginx
                        print_success "Nginx restarted successfully"
                        ;;
                    3)
                        print_info "Skipping reload/restart"
                        ;;
                    *)
                        print_warning "Invalid choice, skipping"
                        ;;
                esac
                ;;
        esac

        # Final status check
        if sudo systemctl is-active --quiet nginx; then
            print_success "Nginx is running successfully"
            echo ""
            print_info "Quick Commands:"
            echo "  • Check status: sudo systemctl status nginx"
            echo "  • View logs: sudo tail -f /var/log/nginx/*.log"
            echo "  • Test config: sudo nginx -t"
        else
            print_error "Nginx is not running"
            print_warning "Check logs with: sudo journalctl -xeu nginx.service"
            exit 1
        fi
    else
        print_warning "Nginx service is not running"
        read -p "Do you want to start nginx now? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_info "Starting nginx..."
            sudo systemctl start nginx
            if sudo systemctl is-active --quiet nginx; then
                print_success "Nginx started successfully"
            else
                print_error "Failed to start nginx"
                sudo systemctl status nginx
                exit 1
            fi
        fi
    fi

    echo ""
    print_success "Configuration test completed!"

else
    echo ""
    print_error "Nginx configuration has errors"
    print_warning "Please review the error messages above"
    echo ""
    print_info "Common issues:"
    echo "  • Duplicate directives (check included files)"
    echo "  • Missing semicolons"
    echo "  • Invalid file paths"
    echo "  • Port conflicts"
    echo ""
    print_info "Debug tips:"
    echo "  • Check main config: cat /etc/nginx/nginx.conf"
    echo "  • List includes: grep -r 'include' /etc/nginx/"
    echo "  • Check port usage: sudo netstat -tulpn | grep nginx"
    exit 1
fi