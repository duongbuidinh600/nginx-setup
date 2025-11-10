#!/bin/bash

#####################################################################
# Nginx Configuration Validation Script
# Purpose: Verify no duplicate directives and validate configuration
# Usage: ./validate-config.sh
#####################################################################

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

# Track validation status
validation_passed=true

print_header "Nginx Configuration Validation"

# Check 1: Verify no proxy directives in snippets
print_info "Check 1: Verifying snippet files contain no proxy settings..."
snippet_proxy_count=$(grep -r "proxy_connect_timeout\|proxy_read_timeout\|proxy_send_timeout\|proxy_buffering" "$SCRIPT_DIR/nginx/snippets/" 2>/dev/null | wc -l)

if [ "$snippet_proxy_count" -eq 0 ]; then
    print_success "Snippet files are clean (no proxy settings)"
else
    print_error "Found proxy directives in snippet files!"
    grep -rn "proxy_connect_timeout\|proxy_read_timeout\|proxy_send_timeout\|proxy_buffering" "$SCRIPT_DIR/nginx/snippets/"
    validation_passed=false
fi

# Check 2: Verify all site configs have complete settings
print_info "Check 2: Verifying all site configs have required proxy settings..."

required_sites=("kafka.conf" "elasticsearch.conf" "kibana.conf" "mysql.conf" "redis.conf" "nexus.conf")

for site in "${required_sites[@]}"; do
    site_path="$SCRIPT_DIR/nginx/sites-available/$site"

    if [ ! -f "$site_path" ]; then
        print_warning "Site config not found: $site"
        continue
    fi

    # Check for required directives
    has_connect=$(grep -c "proxy_connect_timeout" "$site_path" || echo "0")
    has_send=$(grep -c "proxy_send_timeout" "$site_path" || echo "0")
    has_read=$(grep -c "proxy_read_timeout" "$site_path" || echo "0")
    has_buffering=$(grep -c "proxy_buffering" "$site_path" || echo "0")

    if [ "$has_connect" -gt 0 ] && [ "$has_send" -gt 0 ] && [ "$has_read" -gt 0 ] && [ "$has_buffering" -gt 0 ]; then
        print_success "$site has complete settings"
    else
        print_error "$site missing required directives:"
        [ "$has_connect" -eq 0 ] && echo "  - proxy_connect_timeout"
        [ "$has_send" -eq 0 ] && echo "  - proxy_send_timeout"
        [ "$has_read" -eq 0 ] && echo "  - proxy_read_timeout"
        [ "$has_buffering" -eq 0 ] && echo "  - proxy_buffering"
        validation_passed=false
    fi
done

# Check 3: Verify no duplicate directives
print_info "Check 3: Checking for duplicate directives..."

duplicate_issues=0
for site in "${required_sites[@]}"; do
    site_path="$SCRIPT_DIR/nginx/sites-available/$site"

    if [ ! -f "$site_path" ]; then
        continue
    fi

    # Count occurrences of each directive
    connect_count=$(grep -c "proxy_connect_timeout" "$site_path" || echo "0")
    send_count=$(grep -c "proxy_send_timeout" "$site_path" || echo "0")
    read_count=$(grep -c "proxy_read_timeout" "$site_path" || echo "0")
    buffering_count=$(grep -c "proxy_buffering" "$site_path" || echo "0")

    if [ "$connect_count" -gt 1 ] || [ "$send_count" -gt 1 ] || [ "$read_count" -gt 1 ] || [ "$buffering_count" -gt 1 ]; then
        print_error "Duplicate directives found in $site"
        [ "$connect_count" -gt 1 ] && echo "  - proxy_connect_timeout appears $connect_count times"
        [ "$send_count" -gt 1 ] && echo "  - proxy_send_timeout appears $send_count times"
        [ "$read_count" -gt 1 ] && echo "  - proxy_read_timeout appears $read_count times"
        [ "$buffering_count" -gt 1 ] && echo "  - proxy_buffering appears $buffering_count times"
        duplicate_issues=$((duplicate_issues + 1))
        validation_passed=false
    fi
done

if [ "$duplicate_issues" -eq 0 ]; then
    print_success "No duplicate directives found"
fi

# Check 4: File structure
print_info "Check 4: Verifying file structure..."

expected_files=(
    "nginx/nginx.conf"
    "nginx/conf.d/upstreams.conf"
    "nginx/snippets/proxy-headers.conf"
    "nginx/snippets/security-headers.conf"
    "nginx/sites-available/kafka.conf"
    "nginx/sites-available/elasticsearch.conf"
    "nginx/sites-available/kibana.conf"
    "nginx/sites-available/mysql.conf"
    "nginx/sites-available/redis.conf"
    "nginx/sites-available/nexus.conf"
    "nginx/sites-available/default.conf"
)

missing_files=0
for file in "${expected_files[@]}"; do
    if [ -f "$SCRIPT_DIR/$file" ]; then
        print_success "Found: $file"
    else
        print_error "Missing: $file"
        missing_files=$((missing_files + 1))
        validation_passed=false
    fi
done

# Check 5: Obsolete files
print_info "Check 5: Checking for obsolete files..."

if [ -f "$SCRIPT_DIR/nginx/snippets/proxy-headers-no-timeout.conf" ]; then
    print_warning "Obsolete file found: nginx/snippets/proxy-headers-no-timeout.conf"
    print_info "This file should be deleted"
    validation_passed=false
else
    print_success "No obsolete files found"
fi

# Summary
print_header "Validation Summary"

if [ "$validation_passed" = true ]; then
    print_success "All validation checks passed!"
    echo ""
    print_info "Configuration is ready for deployment"
    echo ""
    echo "Next steps:"
    echo "  1. Deploy to server: scp -r nginx/ user@server:/path/to/nginx-setup/"
    echo "  2. Run installation: sudo ./install-nginx.sh"
    echo "  3. Test configuration: ./test-nginx-config.sh"
    exit 0
else
    print_error "Validation failed - please fix the issues above"
    echo ""
    print_info "Common fixes:"
    echo "  • Run git pull to get latest configuration"
    echo "  • Ensure all files are present"
    echo "  • Check for manual modifications that may have introduced duplicates"
    exit 1
fi
