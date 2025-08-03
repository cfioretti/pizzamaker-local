#!/bin/bash

# =============================================================================
# Kong Setup Script for PizzaMaker
# Configures Kong Gateway via Admin API
# =============================================================================

set -e

KONG_ADMIN_URL=${KONG_ADMIN_URL:-"http://localhost:8001"}
MAX_RETRIES=30
RETRY_INTERVAL=5

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🏗️  PizzaMaker Kong Gateway Setup${NC}"
echo "======================================"

# Function to clean existing Kong configuration
clean_kong() {
    echo -e "${YELLOW}🧹 Cleaning existing Kong configuration...${NC}"
    
    # Delete all plugins
    curl -s $KONG_ADMIN_URL/plugins | jq -r '.data[].id' 2>/dev/null | while read id; do
        [ ! -z "$id" ] && curl -s -X DELETE $KONG_ADMIN_URL/plugins/$id > /dev/null 2>&1
    done
    
    # Delete all routes
    curl -s $KONG_ADMIN_URL/routes | jq -r '.data[].id' 2>/dev/null | while read id; do
        [ ! -z "$id" ] && curl -s -X DELETE $KONG_ADMIN_URL/routes/$id > /dev/null 2>&1
    done
    
    # Delete all services
    curl -s $KONG_ADMIN_URL/services | jq -r '.data[].id' 2>/dev/null | while read id; do
        [ ! -z "$id" ] && curl -s -X DELETE $KONG_ADMIN_URL/services/$id > /dev/null 2>&1
    done
    
    echo -e "${GREEN}✅ Kong configuration cleaned${NC}"
}

# Function to wait for Kong Admin API
wait_for_kong() {
    echo -e "${YELLOW}⏳ Waiting for Kong Admin API to be ready...${NC}"
    
    for i in $(seq 1 $MAX_RETRIES); do
        if curl -f -s "$KONG_ADMIN_URL" > /dev/null 2>&1; then
            echo -e "${GREEN}✅ Kong Admin API is ready!${NC}"
            return 0
        fi
        
        echo -e "${YELLOW}   Attempt $i/$MAX_RETRIES: Kong not ready yet, waiting ${RETRY_INTERVAL}s...${NC}"
        sleep $RETRY_INTERVAL
    done
    
    echo -e "${RED}❌ Kong Admin API failed to start after $((MAX_RETRIES * RETRY_INTERVAL)) seconds${NC}"
    exit 1
}

# Function to create Kong service
create_service() {
    local name=$1
    local url=$2
    local connect_timeout=${3:-5000}
    local write_timeout=${4:-10000}
    local read_timeout=${5:-10000}
    
    echo -e "${BLUE}📦 Creating service: $name${NC}"
    
    curl -i -X POST $KONG_ADMIN_URL/services \
        --data "name=$name" \
        --data "url=$url" \
        --data "connect_timeout=$connect_timeout" \
        --data "write_timeout=$write_timeout" \
        --data "read_timeout=$read_timeout" \
        --data "retries=3" || true
}

# Function to create Kong route
create_route() {
    local name=$1
    local service=$2
    local paths=$3
    local methods=$4
    
    echo -e "${BLUE}🛣️  Creating route: $name${NC}"
    
    # Handle multiple methods by converting comma-separated string to multiple --data parameters
    local method_params=""
    IFS=',' read -ra METHOD_ARRAY <<< "$methods"
    for method in "${METHOD_ARRAY[@]}"; do
        method_params="$method_params --data methods[]=$method"
    done
    
    curl -i -X POST $KONG_ADMIN_URL/routes \
        --data "name=$name" \
        --data "service.name=$service" \
        --data "paths[]=$paths" \
        $method_params \
        --data "strip_path=false" || true
}

# Function to create Kong plugin
create_plugin() {
    local plugin_name=$1
    local route_name=$2
    shift 2
    local config_params="$@"
    
    echo -e "${BLUE}🔌 Creating plugin: $plugin_name${NC}"
    
    local url="$KONG_ADMIN_URL/plugins"
    local base_data="name=$plugin_name"
    
    # Build curl command with proper data parameters
    local curl_cmd="curl -i -X POST $url --data \"$base_data\""
    
    if [ ! -z "$route_name" ]; then
        curl_cmd="$curl_cmd --data \"route.name=$route_name\""
    fi
    
    # Add each config parameter as separate --data argument
    for param in $config_params; do
        curl_cmd="$curl_cmd --data \"$param\""
    done
    
    # Execute the curl command
    eval "$curl_cmd" || true
}

# Main setup function
setup_kong() {
    echo -e "${GREEN}🚀 Starting Kong configuration...${NC}"
    
    # Wait for Kong to be ready
    wait_for_kong
    
    # =============================================================================
    # SERVICES CONFIGURATION
    # =============================================================================
    
    echo -e "\n${GREEN}📦 Setting up Services...${NC}"
    
    # Recipe Manager Service
    create_service "recipe-service" "http://recipe-manager:8080" 5000 10000 10000
    
    # Calculator Metrics Service  
    create_service "calculator-metrics" "http://calculator:8080" 5000 5000 5000
    
    # Ingredients Balancer Metrics Service
    create_service "balancer-metrics" "http://ingredients-balancer:8081" 5000 5000 5000
    
    # =============================================================================
    # ROUTES CONFIGURATION
    # =============================================================================
    
    echo -e "\n${GREEN}🛣️  Setting up Routes...${NC}"
    
    # Recipe API Routes
    create_route "recipes-api" "recipe-service" "/api/v1/recipes" "GET,POST,PUT,DELETE,PATCH"
    
    # Health Check Route
    create_route "health-check" "recipe-service" "/health" "GET"
    
    # Metrics Routes (Protected)
    create_route "calculator-metrics-route" "calculator-metrics" "/metrics/calculator" "GET"
    create_route "balancer-metrics-route" "balancer-metrics" "/metrics/balancer" "GET"
    
    # =============================================================================
    # PLUGINS CONFIGURATION
    # =============================================================================
    
    echo -e "\n${GREEN}🔌 Setting up Plugins...${NC}"
    
    # Global Prometheus Plugin
    create_plugin "prometheus" "" \
        "config.per_consumer=false" \
        "config.status_code_metrics=true" \
        "config.latency_metrics=true" \
        "config.bandwidth_metrics=true"
    
    # Global CORS Plugin
    create_plugin "cors" "" \
        "config.origins[]=http://localhost:3000" \
        "config.origins[]=http://localhost:3001" \
        "config.methods[]=GET" \
        "config.methods[]=POST" \
        "config.methods[]=PUT" \
        "config.methods[]=DELETE" \
        "config.methods[]=PATCH" \
        "config.methods[]=OPTIONS" \
        "config.headers[]=Accept" \
        "config.headers[]=Authorization" \
        "config.headers[]=Content-Type" \
        "config.headers[]=X-Request-ID" \
        "config.headers[]=X-Correlation-ID" \
        "config.credentials=true" \
        "config.max_age=3600"
    
    # Note: request-id plugin not available in Kong Gateway CE
    # Will be implemented via custom headers in application layer
    
    # Rate Limiting for Recipe API
    create_plugin "rate-limiting" "recipes-api" \
        "config.minute=1000" \
        "config.hour=10000" \
        "config.day=100000" \
        "config.policy=local" \
        "config.fault_tolerant=true"
    
    # Request Size Limiting for Recipe API
    create_plugin "request-size-limiting" "recipes-api" \
        "config.allowed_payload_size=10"
    
    # Response Transformer for Recipe API
    create_plugin "response-transformer" "recipes-api" \
        "config.add.headers=X-API-Version:1.0,X-Service:PizzaMaker"
    
    # IP Restriction for Metrics Routes (Docker networks + localhost)
    create_plugin "ip-restriction" "calculator-metrics-route" \
        "config.allow[]=172.18.0.0/16" \
        "config.allow[]=10.0.0.0/8" \
        "config.allow[]=192.168.0.0/16" \
        "config.allow[]=127.0.0.1"
    
    create_plugin "ip-restriction" "balancer-metrics-route" \
        "config.allow[]=172.18.0.0/16" \
        "config.allow[]=10.0.0.0/8" \
        "config.allow[]=192.168.0.0/16" \
        "config.allow[]=127.0.0.1"
    
    echo -e "\n${GREEN}✅ Kong configuration completed successfully!${NC}"
    echo -e "${BLUE}📊 Kong Admin GUI: http://localhost:8002${NC}"
    echo -e "${BLUE}🔗 Kong Proxy: http://localhost:8000${NC}"
    echo -e "${BLUE}⚙️  Kong Admin API: http://localhost:8001${NC}"
}

# Function to show current Kong configuration
show_configuration() {
    echo -e "\n${GREEN}📋 Current Kong Configuration:${NC}"
    echo -e "${YELLOW}Services:${NC}"
    curl -s $KONG_ADMIN_URL/services | jq -r '.data[] | "  - \(.name): \(.host):\(.port)"' 2>/dev/null || echo "  Unable to fetch services"
    
    echo -e "${YELLOW}Routes:${NC}"
    curl -s $KONG_ADMIN_URL/routes | jq -r '.data[] | "  - \(.name): \(.paths[])"' 2>/dev/null || echo "  Unable to fetch routes"
    
    echo -e "${YELLOW}Plugins:${NC}"
    curl -s $KONG_ADMIN_URL/plugins | jq -r '.data[] | "  - \(.name) (\(.route.name // "global"))"' 2>/dev/null || echo "  Unable to fetch plugins"
}

# Function to test Kong configuration
test_kong() {
    echo -e "\n${GREEN}🧪 Testing Kong Configuration...${NC}"
    
    # Test health endpoint
    echo -e "${BLUE}Testing health endpoint...${NC}"
    if curl -f -s "http://localhost:8000/health" > /dev/null; then
        echo -e "${GREEN}✅ Health endpoint working${NC}"
    else
        echo -e "${RED}❌ Health endpoint failed${NC}"
    fi
    
    # Test Kong status
    echo -e "${BLUE}Testing Kong status...${NC}"
    if curl -f -s "$KONG_ADMIN_URL/status" > /dev/null; then
        echo -e "${GREEN}✅ Kong Admin API working${NC}"
    else
        echo -e "${RED}❌ Kong Admin API failed${NC}"
    fi
    
    # Test Prometheus metrics
    echo -e "${BLUE}Testing Prometheus metrics...${NC}"
    if curl -f -s "$KONG_ADMIN_URL/metrics" > /dev/null; then
        echo -e "${GREEN}✅ Prometheus metrics working${NC}"
    else
        echo -e "${RED}❌ Prometheus metrics failed${NC}"
    fi
}

# Main script execution
case "${1:-setup}" in
    "setup")
        setup_kong
        show_configuration
        test_kong
        ;;
    "clean")
        wait_for_kong
        clean_kong
        ;;
    "clean-setup")
        wait_for_kong
        clean_kong
        setup_kong
        show_configuration
        test_kong
        ;;
    "show")
        show_configuration
        ;;
    "test")
        test_kong
        ;;
    "wait")
        wait_for_kong
        ;;
    *)
        echo "Usage: $0 {setup|clean|clean-setup|show|test|wait}"
        echo "  setup       - Configure Kong with PizzaMaker services (default)"
        echo "  clean       - Remove all Kong configuration"
        echo "  clean-setup - Clean and reconfigure Kong from scratch"
        echo "  show        - Display current Kong configuration"
        echo "  test        - Test Kong endpoints"
        echo "  wait        - Wait for Kong to be ready"
        exit 1
        ;;
esac 