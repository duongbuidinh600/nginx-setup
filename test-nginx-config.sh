#!/bin/bash

echo "🔍 Testing Nginx Configuration Syntax..."

# Test nginx configuration syntax
if sudo nginx -t; then
    echo "✅ Nginx configuration syntax is valid"
    echo ""
    echo "📋 Configuration Summary:"
    echo "  - Main config: /etc/nginx/nginx.conf"
    echo "  - Upstreams: /etc/nginx/conf.d/upstreams.conf"
    echo "  - Sites: $(ls /etc/nginx/sites-enabled/ | wc -l) sites enabled"
    echo ""
    echo "🚀 Ready to restart nginx service!"

    # Optional: restart nginx
    read -p "Do you want to restart nginx now? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "🔄 Restarting nginx..."
        sudo systemctl restart nginx
        if sudo systemctl is-active --quiet nginx; then
            echo "✅ Nginx is running successfully"
            echo "📊 Status: $(sudo systemctl is-active nginx)"
        else
            echo "❌ Nginx failed to start"
            sudo systemctl status nginx
        fi
    fi
else
    echo "❌ Nginx configuration has errors"
    echo "🔧 Please check the configuration files and try again"
    exit 1
fi