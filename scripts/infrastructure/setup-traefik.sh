#!/bin/bash

# Traefik Setup and Management Script for PizzaMaker Local Development
set -e

TRAEFIK_DASHBOARD_URL="http://localhost:8080"
TRAEFIK_API_URL="http://localhost:8080/api"
API_GATEWAY_URL="http://localhost:8000"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Wait for Traefik to be ready
wait_for_traefik() {
    log_info "Waiting for Traefik to be ready..."
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -s -o /dev/null -w "%{http_code}" "$TRAEFIK_DASHBOARD_URL" | grep -q "200\|301\|302"; then
            log_success "Traefik is ready!"
            return 0
        fi
        
        log_info "Attempt $attempt/$max_attempts - Traefik not ready yet..."
        sleep 2
        ((attempt++))
    done
    
    log_error "Traefik failed to start within expected time"
    return 1
}

# Show Traefik configuration
show_configuration() {
    log_info "=== TRAEFIK CONFIGURATION ==="
    echo ""
    
    log_info "📊 Dashboard: $TRAEFIK_DASHBOARD_URL"
    log_info "🔗 API Gateway: $API_GATEWAY_URL"
    log_info "📈 Metrics: $TRAEFIK_DASHBOARD_URL/metrics"
    echo ""
    
    log_info "🚀 Discovered Routes:"
    if curl -s "$TRAEFIK_API_URL/http/routers" | jq -r '.[] | select(.provider == "docker") | "  - \(.name): \(.rule) [\(.status)]"' 2>/dev/null; then
        echo ""
    else
        log_warning "Could not fetch routes (jq not available or API not responding)"
        curl -s "$TRAEFIK_API_URL/http/routers" 2>/dev/null || log_error "API not responding"
    fi
    
    log_info "🎯 Discovered Services:"
    if curl -s "$TRAEFIK_API_URL/http/services" | jq -r '.[] | select(.provider == "docker") | "  - \(.name): \(.loadBalancer.servers[0].url // "No servers")"' 2>/dev/null; then
        echo ""
    else
        log_warning "Could not fetch services"
    fi
    
    log_info "🛡️ Active Middlewares:"
    if curl -s "$TRAEFIK_API_URL/http/middlewares" | jq -r '.[] | select(.provider == "docker") | "  - \(.name): \(.type)"' 2>/dev/null; then
        echo ""
    else
        log_warning "Could not fetch middlewares"
    fi
}

# Test Traefik functionality
test_traefik() {
    log_info "=== TESTING TRAEFIK FUNCTIONALITY ==="
    echo ""
    
    # Test Dashboard
    log_info "Testing Traefik Dashboard..."
    if curl -s -o /dev/null -w "%{http_code}" "$TRAEFIK_DASHBOARD_URL" | grep -q "200\|301\|302"; then
        log_success "✅ Dashboard: OK"
    else
        log_error "❌ Dashboard: FAILED"
    fi
    
    # Test API
    log_info "Testing Traefik API..."
    if curl -s -o /dev/null -w "%{http_code}" "$TRAEFIK_API_URL/version" | grep -q "200"; then
        log_success "✅ API: OK"
    else
        log_error "❌ API: FAILED"
    fi
    
    # Test Metrics
    log_info "Testing Prometheus Metrics..."
    if curl -s -o /dev/null -w "%{http_code}" "$TRAEFIK_DASHBOARD_URL/metrics" | grep -q "200"; then
        log_success "✅ Metrics: OK"
    else
        log_error "❌ Metrics: FAILED"
    fi
    
    # Test Health Endpoint (through API Gateway)
    log_info "Testing Health Endpoint (via API Gateway)..."
    local health_status=$(curl -s -o /dev/null -w "%{http_code}" "$API_GATEWAY_URL/health")
    if [ "$health_status" = "200" ]; then
        log_success "✅ Health Endpoint: OK ($health_status)"
    else
        log_warning "⚠️  Health Endpoint: $health_status (may be expected if recipe-manager not ready)"
    fi
    
    # Test CORS Headers
    log_info "Testing CORS Headers..."
    local cors_headers=$(curl -s -I "$API_GATEWAY_URL/health" | grep -i "access-control" | wc -l)
    if [ "$cors_headers" -gt 0 ]; then
        log_success "✅ CORS Headers: Present"
    else
        log_warning "⚠️  CORS Headers: Not detected"
    fi
    
    echo ""
    log_info "🎯 Quick Access URLs:"
    echo "  - Dashboard: $TRAEFIK_DASHBOARD_URL"
    echo "  - API Gateway: $API_GATEWAY_URL"
    echo "  - Health Check: $API_GATEWAY_URL/health"
    echo "  - Metrics: $TRAEFIK_DASHBOARD_URL/metrics"
}

# Setup Traefik (mainly validation since it's auto-configured)
setup_traefik() {
    log_info "=== TRAEFIK SETUP ==="
    echo ""
    
    log_info "Traefik uses auto-discovery via Docker labels"
    log_info "No manual configuration required!"
    echo ""
    
    wait_for_traefik
    show_configuration
}

# Clean Traefik (remove containers and configs)
clean_traefik() {
    log_info "=== CLEANING TRAEFIK ==="
    echo ""
    
    log_warning "This will stop and remove Traefik container"
    read -p "Are you sure? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "Stopping Traefik..."
        docker-compose stop traefik 2>/dev/null || true
        
        log_info "Removing Traefik container..."
        docker-compose rm -f traefik 2>/dev/null || true
        
        log_success "Traefik cleaned successfully"
    else
        log_info "Clean operation cancelled"
    fi
}

# Monitor Traefik performance
monitor_traefik() {
    log_info "=== TRAEFIK PERFORMANCE MONITOR ==="
    echo ""
    
    log_info "📊 Container Stats:"
    docker stats traefik --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}" 2>/dev/null || log_error "Traefik container not running"
    
    echo ""
    log_info "🔄 Recent Access Logs (last 10):"
    docker logs traefik --tail 10 2>/dev/null | grep -E '"level":"info".*"msg":""' | tail -5 || log_warning "No recent access logs"
    
    echo ""
    log_info "⚡ Route Performance:"
    if curl -s "$TRAEFIK_API_URL/http/routers" | jq -r '.[] | select(.provider == "docker" and .status == "enabled") | "  ✅ \(.name)"' 2>/dev/null; then
        echo ""
    else
        log_warning "Could not fetch route status"
    fi
}

# Main script logic
case "${1:-help}" in
    "setup")
        setup_traefik
        ;;
    "test")
        wait_for_traefik
        test_traefik
        ;;
    "show")
        wait_for_traefik
        show_configuration
        ;;
    "monitor")
        monitor_traefik
        ;;
    "clean")
        clean_traefik
        ;;
    "clean-setup")
        clean_traefik
        echo ""
        setup_traefik
        ;;
    "help"|*)
        echo "Traefik Management Script for PizzaMaker"
        echo ""
        echo "Usage: $0 <command>"
        echo ""
        echo "Commands:"
        echo "  setup        - Setup and validate Traefik configuration"
        echo "  test         - Test all Traefik functionality"
        echo "  show         - Show current Traefik configuration"
        echo "  monitor      - Monitor Traefik performance"
        echo "  clean        - Clean Traefik containers"
        echo "  clean-setup  - Clean and setup Traefik"
        echo "  help         - Show this help message"
        echo ""
        echo "Examples:"
        echo "  $0 setup     # Setup Traefik"
        echo "  $0 test      # Test functionality"
        echo "  $0 show      # Show configuration"
        ;;
esac
