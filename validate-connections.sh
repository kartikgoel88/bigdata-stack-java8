#!/bin/bash

# Big Data Stack Connection Validation Script
# This script validates connections between hive-server, metastore, and postgres

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_section() {
    echo ""
    echo -e "${BLUE}=========================================="
    echo "$1"
    echo -e "==========================================${NC}"
}

# Track validation results
PASSED=0
FAILED=0

# Function to check service
check_service() {
    local service=$1
    local description=$2
    
    if docker-compose ps | grep -q "$service.*Up"; then
        print_success "$description is running"
        ((PASSED++))
        return 0
    else
        print_error "$description is NOT running"
        ((FAILED++))
        return 1
    fi
}

# Function to check port
check_port() {
    local service=$1
    local port=$2
    local description=$3
    
    if docker-compose exec -T "$service" nc -z localhost "$port" > /dev/null 2>&1; then
        print_success "$description is listening on port $port"
        ((PASSED++))
        return 0
    else
        print_error "$description is NOT listening on port $port"
        ((FAILED++))
        return 1
    fi
}

# Function to check network connectivity
check_network_connectivity() {
    local from_service=$1
    local to_service=$2
    local port=$3
    local description=$4
    
    if docker-compose exec -T "$from_service" nc -z "$to_service" "$port" > /dev/null 2>&1; then
        print_success "$description: $from_service -> $to_service:$port"
        ((PASSED++))
        return 0
    else
        print_error "$description: $from_service -> $to_service:$port (FAILED)"
        ((FAILED++))
        return 1
    fi
}

# Function to check PostgreSQL connection
check_postgres_connection() {
    local user=$1
    local database=$2
    local description=$3
    
    if docker-compose exec -T postgres psql -U "$user" -d "$database" -c "SELECT 1;" > /dev/null 2>&1; then
        print_success "$description: PostgreSQL connection successful"
        ((PASSED++))
        return 0
    else
        print_error "$description: PostgreSQL connection failed"
        ((FAILED++))
        return 1
    fi
}

# Function to check Hive schema
check_hive_schema() {
    local table=$1
    local description=$2
    
    if docker-compose exec -T postgres psql -U hive -d metastore -c "SELECT 1 FROM information_schema.tables WHERE table_name = '$table';" 2>/dev/null | grep -q "1 row"; then
        print_success "$description: Table '$table' exists"
        ((PASSED++))
        return 0
    else
        print_error "$description: Table '$table' does NOT exist"
        ((FAILED++))
        return 1
    fi
}

# Function to check Hive Metastore connection
check_hive_metastore_connection() {
    print_info "Testing Hive Metastore connection from hive-server..."
    
    # Try to connect using Hive CLI (HIVE_HOME should be set in container)
    if docker-compose exec -T hive-server bash -c '${HIVE_HOME:-/opt/hive}/bin/hive -e "SHOW DATABASES;"' > /dev/null 2>&1; then
        print_success "Hive Metastore: Hive CLI connection successful"
        ((PASSED++))
        return 0
    else
        # Check if it's just a connection issue or schema issue
        local error=$(docker-compose exec -T hive-server bash -c '${HIVE_HOME:-/opt/hive}/bin/hive -e "SHOW DATABASES;"' 2>&1 | grep -i "SessionHiveMetaStoreClient\|URISyntaxException" || echo "")
        if [ -n "$error" ]; then
            print_error "Hive Metastore: Connection failed - URI/Configuration issue"
            print_info "Error details: $error"
        else
            print_error "Hive Metastore: Connection failed - Unknown error"
        fi
        ((FAILED++))
        return 1
    fi
}

echo "=========================================="
echo "Big Data Stack - Connection Validation"
echo "=========================================="
echo ""

# 1. Check if containers are running
print_section "1. Container Status"
check_service "hive-postgres" "PostgreSQL"
check_service "hive-metastore" "Hive Metastore"
check_service "hive-server" "HiveServer2"
check_service "hadoop-namenode" "HDFS NameNode"
check_service "hadoop-datanode" "HDFS DataNode"

# 2. Check PostgreSQL
print_section "2. PostgreSQL Validation"
check_port "postgres" "5432" "PostgreSQL"
check_postgres_connection "hive" "metastore" "Hive user connection"
check_postgres_connection "hive" "hive" "Hive user default database"

# 3. Check Hive Schema
print_section "3. Hive Schema Validation"
check_hive_schema "VERSION" "Hive schema"
check_hive_schema "DBS" "Hive databases table"
check_hive_schema "TBLS" "Hive tables table"

# Count total tables
TABLE_COUNT=$(docker-compose exec -T postgres psql -U hive -d metastore -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';" 2>/dev/null | tr -d ' ')
if [ -n "$TABLE_COUNT" ] && [ "$TABLE_COUNT" -gt 0 ]; then
    print_success "Hive schema: Found $TABLE_COUNT tables in metastore database"
    ((PASSED++))
else
    print_error "Hive schema: No tables found in metastore database"
    ((FAILED++))
fi

# 4. Check HDFS
print_section "4. HDFS Validation"
check_port "namenode" "9000" "NameNode RPC"
check_port "namenode" "9870" "NameNode Web UI"
check_port "datanode" "9864" "DataNode Web UI"

# Check HDFS connectivity from hive-server
check_network_connectivity "hive-server" "namenode" "9000" "HDFS connectivity"

# 5. Check Hive Metastore
print_section "5. Hive Metastore Validation"
check_port "hive-metastore" "9083" "Hive Metastore Thrift"

# Check network connectivity from hive-server to metastore
check_network_connectivity "hive-server" "hive-metastore" "9083" "Hive Metastore connectivity"

# Check if metastore process is running
if docker-compose exec -T hive-metastore jps 2>/dev/null | grep -qi "RunJar\|Metastore"; then
    print_success "Hive Metastore: Java process is running"
    ((PASSED++))
else
    print_error "Hive Metastore: Java process is NOT running"
    ((FAILED++))
fi

# 6. Check HiveServer2
print_section "6. HiveServer2 Validation"
check_port "hive-server" "10000" "HiveServer2 Thrift"

# Check if HiveServer2 process is running
if docker-compose exec -T hive-server jps 2>/dev/null | grep -qi "RunJar\|HiveServer2"; then
    print_success "HiveServer2: Java process is running"
    ((PASSED++))
else
    print_warn "HiveServer2: Java process may not be running yet (check logs if port is listening)"
fi

# 7. Test Hive Metastore Connection
print_section "7. Hive Metastore Connection Test"
check_hive_metastore_connection

# 8. Network Configuration Check
print_section "8. Network Configuration"
NETWORK_NAME=$(docker network ls | grep "bigdata" | awk '{print $2}' | head -1)
if [ -n "$NETWORK_NAME" ]; then
    if echo "$NETWORK_NAME" | grep -q "_"; then
        print_error "Network name contains underscore: $NETWORK_NAME (may cause URI parsing issues)"
        ((FAILED++))
    else
        print_success "Network name is valid: $NETWORK_NAME"
        ((PASSED++))
    fi
else
    print_error "Network not found"
    ((FAILED++))
fi

# Check hostname resolution
print_info "Checking hostname resolution..."
HOSTNAME_RESOLUTION=$(docker-compose exec -T hive-server getent hosts hive-metastore 2>/dev/null | awk '{print $2}' | head -1)
if [ -n "$HOSTNAME_RESOLUTION" ]; then
    if echo "$HOSTNAME_RESOLUTION" | grep -q "_"; then
        print_error "Hostname resolution contains underscore: $HOSTNAME_RESOLUTION (may cause URI parsing issues)"
        ((FAILED++))
    else
        print_success "Hostname resolution: hive-metastore -> $HOSTNAME_RESOLUTION"
        ((PASSED++))
    fi
else
    print_error "Hostname resolution failed"
    ((FAILED++))
fi

# Summary
echo ""
print_section "Validation Summary"
echo -e "${GREEN}Passed: $PASSED${NC}"
echo -e "${RED}Failed: $FAILED${NC}"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}=========================================="
    echo "All validations passed! ✓"
    echo -e "==========================================${NC}"
    exit 0
else
    echo -e "${RED}=========================================="
    echo "Some validations failed. Please check the errors above."
    echo -e "==========================================${NC}"
    echo ""
    print_info "To view logs:"
    echo "  docker-compose logs hive-metastore"
    echo "  docker-compose logs hive-server"
    echo "  docker-compose logs postgres"
    exit 1
fi

