#!/bin/bash

###############################################################################
# Nginx Management Script
# Author: Claude
# Description: Helper script for common Nginx operations
###############################################################################

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "Please run this script as root or with sudo"
        exit 1
    fi
}

###############################################################################
# Functions
###############################################################################

test_config() {
    print_info "Testing Nginx configuration..."
    if nginx -t; then
        print_success "Configuration is valid!"
        return 0
    else
        print_error "Configuration has errors!"
        return 1
    fi
}

reload_nginx() {
    if test_config; then
        print_info "Reloading Nginx..."
        systemctl reload nginx
        print_success "Nginx reloaded successfully!"
    else
        print_error "Cannot reload - configuration has errors!"
        return 1
    fi
}

restart_nginx() {
    if test_config; then
        print_info "Restarting Nginx..."
        systemctl restart nginx
        print_success "Nginx restarted successfully!"
    else
        print_error "Cannot restart - configuration has errors!"
        return 1
    fi
}

status_nginx() {
    print_info "Nginx status:"
    systemctl status nginx --no-pager
}

view_logs() {
    local log_type=${1:-access}
    local lines=${2:-50}
    
    case $log_type in
        access)
            print_info "Showing last $lines lines of access log..."
            tail -n $lines /var/log/nginx/access.log
            ;;
        error)
            print_info "Showing last $lines lines of error log..."
            tail -n $lines /var/log/nginx/error.log
            ;;
        kafka)
            print_info "Showing last $lines lines of Kafka UI log..."
            tail -n $lines /var/log/nginx/kafka-ui.access.log
            ;;
        kibana)
            print_info "Showing last $lines lines of Kibana log..."
            tail -n $lines /var/log/nginx/kibana.access.log
            ;;
        es)
            print_info "Showing last $lines lines of Elasticsearch log..."
            tail -n $lines /var/log/nginx/elasticsearch.access.log
            ;;
        all)
            print_info "Following all access logs..."
            tail -f /var/log/nginx/*.access.log
            ;;
        *)
            print_error "Unknown log type: $log_type"
            print_info "Available types: access, error, kafka, kibana, es, all"
            return 1
            ;;
    esac
}

enable_site() {
    local site=$1
    if [ -z "$site" ]; then
        print_error "Please specify a site to enable"
        return 1
    fi
    
    if [ ! -f "/etc/nginx/sites-available/$site.conf" ]; then
        print_error "Site configuration not found: $site.conf"
        return 1
    fi
    
    print_info "Enabling site: $site"
    ln -sf "/etc/nginx/sites-available/$site.conf" "/etc/nginx/sites-enabled/$site.conf"
    
    if test_config; then
        reload_nginx
        print_success "Site $site enabled!"
    else
        print_error "Failed to enable site due to configuration errors"
        return 1
    fi
}

disable_site() {
    local site=$1
    if [ -z "$site" ]; then
        print_error "Please specify a site to disable"
        return 1
    fi
    
    if [ ! -L "/etc/nginx/sites-enabled/$site.conf" ]; then
        print_warning "Site is not enabled: $site"
        return 1
    fi
    
    print_info "Disabling site: $site"
    rm "/etc/nginx/sites-enabled/$site.conf"
    
    if test_config; then
        reload_nginx
        print_success "Site $site disabled!"
    else
        print_error "Failed to disable site due to configuration errors"
        return 1
    fi
}

list_sites() {
    print_info "Available sites:"
    ls -1 /etc/nginx/sites-available/*.conf 2>/dev/null | xargs -n 1 basename | sed 's/.conf$//' | while read site; do
        if [ -L "/etc/nginx/sites-enabled/$site.conf" ]; then
            echo "  ✓ $site (enabled)"
        else
            echo "  ✗ $site (disabled)"
        fi
    done
}

show_connections() {
    print_info "Active connections:"
    ss -tn | grep :80 | wc -l
    echo
    print_info "Connection details:"
    ss -tn | grep :80 | head -10
}

check_upstreams() {
    print_info "Checking upstream services..."
    
    local services=(
        "Kafka UI:localhost:8080"
        "Kibana:localhost:5601"
        "Elasticsearch:localhost:9200"
        "Adminer:localhost:8081"
        "Redis Commander:localhost:8082"
        "Nexus:localhost:8083"
    )
    
    for service in "${services[@]}"; do
        IFS=':' read -r name host port <<< "$service"
        if nc -z "$host" "$port" 2>/dev/null; then
            print_success "$name ($host:$port) is reachable"
        else
            print_error "$name ($host:$port) is not reachable"
        fi
    done
}

show_help() {
    cat << EOF
Nginx Management Script

Usage: $0 [command] [options]

Commands:
    test            Test Nginx configuration
    reload          Reload Nginx (graceful restart)
    restart         Restart Nginx service
    status          Show Nginx service status
    logs [type]     View logs (access|error|kafka|kibana|es|all)
    enable [site]   Enable a site configuration
    disable [site]  Disable a site configuration
    list            List all available sites
    connections     Show active connections
    check           Check if upstream services are reachable
    help            Show this help message

Examples:
    $0 test                 # Test configuration
    $0 reload               # Reload Nginx
    $0 logs error           # View error logs
    $0 enable kafka         # Enable Kafka site
    $0 disable nexus        # Disable Nexus site
    $0 check                # Check upstream services

EOF
}

###############################################################################
# Main
###############################################################################

check_root

case "${1:-help}" in
    test)
        test_config
        ;;
    reload)
        reload_nginx
        ;;
    restart)
        restart_nginx
        ;;
    status)
        status_nginx
        ;;
    logs)
        view_logs "${2:-access}" "${3:-50}"
        ;;
    enable)
        enable_site "$2"
        ;;
    disable)
        disable_site "$2"
        ;;
    list)
        list_sites
        ;;
    connections)
        show_connections
        ;;
    check)
        check_upstreams
        ;;
    help|*)
        show_help
        ;;
esac

exit 0
