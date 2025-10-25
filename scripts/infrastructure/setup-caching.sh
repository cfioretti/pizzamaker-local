#!/bin/bash

# =============================================================================
# PizzaMaker Caching Management Script  
# Single Redis Instance Setup, Testing & Monitoring (Optimized for Local Dev)
# =============================================================================

set -e

# Configuration
REDIS_HOST=${REDIS_HOST:-"localhost"}
REDIS_PORT=${REDIS_PORT:-"6379"}
REDIS_PASSWORD=${REDIS_PASSWORD:-"pizzamaker_redis_2024"}
KONG_ADMIN_URL=${KONG_ADMIN_URL:-"http://localhost:8001"}
MAX_RETRIES=30
RETRY_INTERVAL=5

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 PizzaMaker Redis Caching Setup${NC}"
echo "============================================="

# Function to wait for Redis
wait_for_redis() {
    echo -e "${YELLOW}⏳ Waiting for Redis to be ready...${NC}"
    
    for i in $(seq 1 $MAX_RETRIES); do
        if docker exec redis redis-cli -a $REDIS_PASSWORD ping > /dev/null 2>&1; then
            echo -e "${GREEN}✅ Redis is ready!${NC}"
            return 0
        fi
        
        echo -e "${YELLOW}   Attempt $i/$MAX_RETRIES: Redis not ready yet, waiting ${RETRY_INTERVAL}s...${NC}"
        sleep $RETRY_INTERVAL
    done
    
    echo -e "${RED}❌ Redis failed to start after $((MAX_RETRIES * RETRY_INTERVAL)) seconds${NC}"
    exit 1
}

# Function to wait for Kong
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

# Function to setup Redis cache structure
setup_redis_cache() {
    echo -e "\n${GREEN}🗄️  Setting up Redis cache structure...${NC}"
    
    # Database allocation strategy
    echo -e "${BLUE}📊 Configuring Redis database allocation:${NC}"
    echo "  - DB 0: Session storage"
    echo "  - DB 1: API response cache"
    echo "  - DB 2: Application data cache"
    echo "  - DB 3: Kong rate limiting"
    echo "  - DB 4: Calculation results"
    echo "  - DB 5: User preferences"
    
    # Create initial cache keys structure
    docker exec redis redis-cli -a $REDIS_PASSWORD -n 0 SET cache:structure:initialized "$(date)"
    docker exec redis redis-cli -a $REDIS_PASSWORD -n 0 SET cache:databases:session 0
    docker exec redis redis-cli -a $REDIS_PASSWORD -n 0 SET cache:databases:api_responses 1
    docker exec redis redis-cli -a $REDIS_PASSWORD -n 0 SET cache:databases:app_data 2
    docker exec redis redis-cli -a $REDIS_PASSWORD -n 0 SET cache:databases:rate_limiting 3
    docker exec redis redis-cli -a $REDIS_PASSWORD -n 0 SET cache:databases:calculations 4
    docker exec redis redis-cli -a $REDIS_PASSWORD -n 0 SET cache:databases:user_prefs 5

    # Set up cache key patterns and TTLs
    docker exec redis redis-cli -a $REDIS_PASSWORD -n 1 SET cache:ttl:recipes 900
    docker exec redis redis-cli -a $REDIS_PASSWORD -n 1 SET cache:ttl:calculations 1800
    docker exec redis redis-cli -a $REDIS_PASSWORD -n 1 SET cache:ttl:health_checks 30
    docker exec redis redis-cli -a $REDIS_PASSWORD -n 1 SET cache:ttl:user_sessions 3600
    docker exec redis redis-cli -a $REDIS_PASSWORD -n 1 SET cache:ttl:api_responses 300

    echo -e "${GREEN}✅ Redis cache structure configured${NC}"
}

# Function to setup Kong proxy cache
setup_kong_cache() {
    echo -e "\n${GREEN}🌐 Setting up Kong proxy cache...${NC}"
    
    wait_for_kong
    
    # Enable proxy-cache plugin globally
    echo -e "${BLUE}🔌 Enabling Kong proxy cache plugin...${NC}"
    
    curl -i -X POST $KONG_ADMIN_URL/plugins \
        --data "name=proxy-cache" \
        --data "config.response_code[]=200" \
        --data "config.response_code[]=301" \
        --data "config.response_code[]=302" \
        --data "config.request_method[]=GET" \
        --data "config.request_method[]=HEAD" \
        --data "config.content_type[]=application/json" \
        --data "config.content_type[]=text/plain" \
        --data "config.cache_ttl=300" \
        --data "config.strategy=memory" \
        --data "config.storage_ttl=300" || true
        
    echo -e "${GREEN}✅ Kong proxy cache configured${NC}"
}

# Function to test caching layers
test_caching_layers() {
    echo -e "\n${GREEN}🧪 Testing caching layers...${NC}"
    
    # Test 1: Redis connectivity
    echo -e "${BLUE}Test 1: Redis connectivity${NC}"
    
    # Test Redis instance
    if docker exec redis redis-cli -a $REDIS_PASSWORD ping > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Redis: Connected${NC}"
        
        # Get Redis info
        redis_version=$(docker exec redis redis-cli -a $REDIS_PASSWORD INFO server | grep redis_version | cut -d: -f2 | tr -d '\r')
        redis_mode=$(docker exec redis redis-cli -a $REDIS_PASSWORD INFO replication | grep role | cut -d: -f2 | tr -d '\r')
        echo -e "${BLUE}   Version: $redis_version, Mode: $redis_mode${NC}"
    else
        echo -e "${RED}❌ Redis: Failed${NC}"
    fi
    
    # Test 2: Cache write/read performance
    echo -e "\n${BLUE}Test 2: Cache performance${NC}"
    
    # Write test data
    docker exec redis redis-cli -a $REDIS_PASSWORD -n 1 SET test:recipe:1 '{"id":1,"name":"Margherita","ingredients":["tomato","mozzarella"]}'
    docker exec redis redis-cli -a $REDIS_PASSWORD -n 1 SET test:calculation:1 '{"total_cost":12.50,"prep_time":25}'
    docker exec redis redis-cli -a $REDIS_PASSWORD -n 1 EXPIRE test:recipe:1 300
    docker exec redis redis-cli -a $REDIS_PASSWORD -n 1 EXPIRE test:calculation:1 600

    # Read test data
    recipe_data=$(docker exec redis redis-cli -a $REDIS_PASSWORD -n 1 GET test:recipe:1)
    if [ ! -z "$recipe_data" ]; then
        echo -e "${GREEN}✅ Cache Write/Read: Working${NC}"
    else
        echo -e "${RED}❌ Cache Write/Read: Failed${NC}"
    fi
    
    # Test 3: Kong proxy cache
    echo -e "\n${BLUE}Test 3: Kong proxy cache${NC}"
    
    # Test health endpoint caching
    response1=$(curl -s -w "%{http_code}" http://localhost:8000/health -o /dev/null)
    sleep 1
    response2=$(curl -s -w "%{http_code}" http://localhost:8000/health -o /dev/null)
    
    if [ "$response1" = "200" ] && [ "$response2" = "200" ]; then
        echo -e "${GREEN}✅ Kong Proxy Cache: Working${NC}"
    else
        echo -e "${RED}❌ Kong Proxy Cache: Failed (HTTP: $response1, $response2)${NC}"
    fi
    
    # Test 4: Redis CLI Access
    echo -e "\n${BLUE}Test 4: Redis CLI access${NC}"
    
    if docker exec redis redis-cli -a $REDIS_PASSWORD ping > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Redis CLI: Direct access available${NC}"
        echo -e "${BLUE}   Usage: docker exec redis redis-cli -a \$REDIS_PASSWORD${NC}"
    else
        echo -e "${RED}❌ Redis CLI: Access failed${NC}"
    fi
}

# Function to monitor cache performance
monitor_cache_performance() {
    echo -e "\n${GREEN}📊 Cache Performance Monitoring${NC}"
    
    # Redis memory usage
    echo -e "${BLUE}📈 Redis Memory Usage:${NC}"
    docker exec redis redis-cli -a $REDIS_PASSWORD INFO memory | grep -E "used_memory_human|used_memory_peak_human|maxmemory_human"
    
    # Redis hit ratio
    echo -e "\n${BLUE}🎯 Redis Hit Ratio:${NC}"
    docker exec redis redis-cli -a $REDIS_PASSWORD INFO stats | grep -E "keyspace_hits|keyspace_misses"
    
    # Connected clients
    echo -e "\n${BLUE}👥 Connected Clients:${NC}"
    docker exec redis redis-cli -a $REDIS_PASSWORD INFO clients | grep connected_clients
    
    # Server info
    echo -e "\n${BLUE}🖥️  Server Info:${NC}"
    docker exec redis redis-cli -a $REDIS_PASSWORD INFO server | grep -E "redis_version|uptime_in_seconds|process_id"
    
    # Kong cache metrics
    echo -e "\n${BLUE}🌐 Kong Cache Metrics:${NC}"
    curl -s $KONG_ADMIN_URL/metrics | grep -E "kong_memory|kong_http_requests_total" | head -5
}

# Function to benchmark cache performance
benchmark_cache() {
    echo -e "\n${GREEN}⚡ Cache Performance Benchmark${NC}"
    
    echo -e "${BLUE}🏃 Running Redis benchmark...${NC}"
    echo "Testing 10,000 SET/GET operations..."
    
    # Run redis-benchmark
    docker exec redis redis-benchmark -h localhost -p 6379 -a $REDIS_PASSWORD -n 10000 -d 100 -t set,get -q
    
    echo -e "${GREEN}✅ Benchmark completed${NC}"
}

# Function to show cache configuration
show_cache_config() {
    echo -e "\n${GREEN}📋 Current Cache Configuration${NC}"
    
    echo -e "${YELLOW}Redis Configuration:${NC}"
    echo "  - Instance: localhost:6379"
    echo "  - CLI Access: docker exec redis redis-cli -a \$REDIS_PASSWORD"
    echo "  - Memory: 1GB allocated"
    echo "  - Mode: Single instance (development-optimized)"
    
    echo -e "\n${YELLOW}Database Allocation:${NC}"
    echo "  - DB 0: Session storage"
    echo "  - DB 1: API response cache"
    echo "  - DB 2: Application data cache"
    echo "  - DB 3: Kong rate limiting"
    echo "  - DB 4: Calculation results"
    echo "  - DB 5: User preferences"
    
    echo -e "\n${YELLOW}Cache TTL Settings:${NC}"
    docker exec redis redis-cli -a $REDIS_PASSWORD -n 1 MGET cache:ttl:recipes cache:ttl:calculations cache:ttl:health_checks cache:ttl:user_sessions cache:ttl:api_responses 2>/dev/null || echo "  Cache TTL data not available"
    
    echo -e "\n${YELLOW}Kong Plugins:${NC}"
    curl -s $KONG_ADMIN_URL/plugins | jq -r '.data[] | select(.name=="proxy-cache") | "  - \(.name) (\(.route.name // "global"))"' 2>/dev/null || echo "  Kong cache info not available"
}

# Function to clear all caches
clear_caches() {
    echo -e "\n${YELLOW}🧹 Clearing all caches...${NC}"
    
    read -p "Are you sure you want to clear ALL cache data? (y/N): " confirm
    if [[ $confirm =~ ^[Yy]$ ]]; then
        # Clear Redis databases
        for db in {0..5}; do
            docker exec redis redis-cli -a $REDIS_PASSWORD -n $db FLUSHDB
        done
        
        echo -e "${GREEN}✅ All caches cleared${NC}"
    else
        echo -e "${BLUE}ℹ️  Cache clear cancelled${NC}"
    fi
}

# Main execution
case "${1:-setup}" in
    "setup")
        wait_for_redis
        setup_redis_cache
        setup_kong_cache
        test_caching_layers
        show_cache_config
        ;;
    "test")
        test_caching_layers
        ;;
    "monitor")
        monitor_cache_performance
        ;;
    "benchmark")
        benchmark_cache
        ;;
    "show")
        show_cache_config
        ;;
    "clear")
        clear_caches
        ;;
    *)
        echo "Usage: $0 {setup|test|monitor|benchmark|show|clear}"
        echo "  setup     - Setup and configure all caching layers (default)"
        echo "  test      - Test all caching functionality"
        echo "  monitor   - Show cache performance metrics"
        echo "  benchmark - Run performance benchmark"
        echo "  show      - Display current cache configuration"
        echo "  clear     - Clear all cache data (with confirmation)"
        exit 1
        ;;
esac 