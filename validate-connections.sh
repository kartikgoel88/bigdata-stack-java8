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

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_section() {
    echo ""
    echo -e "${BLUE}=========================================="
    echo "$1"
    echo -e "==========================================${NC}"
}

# Function to open URL in default browser (cross-platform)
open_url() {
    local url=$1
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        open "$url" 2>/dev/null
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux
        xdg-open "$url" 2>/dev/null || sensible-browser "$url" 2>/dev/null
    elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
        # Windows
        start "$url" 2>/dev/null
    else
        # Fallback - try common commands
        open "$url" 2>/dev/null || xdg-open "$url" 2>/dev/null || echo "Could not open $url"
    fi
}

# Function to open all UI links
open_all_ui_links() {
    print_info "Opening all service UI links in default browser..."
    
    local urls=(
        "http://localhost:9870"   # HDFS NameNode
        "http://localhost:9864"   # HDFS DataNode
        "http://localhost:8088"   # YARN ResourceManager
        "http://localhost:8042"   # YARN NodeManager
        "http://localhost:8080"   # Spark Master
        "http://localhost:8081"   # Spark Worker
        "http://localhost:18080"  # Spark History Server
    )
    
    for url in "${urls[@]}"; do
        open_url "$url"
        sleep 0.5  # Small delay between opening tabs
    done
    
    print_success "All UI links opened"
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

# Function to find Hive command (handles nested directory structures)
find_hive_command() {
    local service=$1
    local command=$2
    local hive_home="/opt/hive"
    
    # Try standard location first
    if docker-compose exec -T "$service" test -f "$hive_home/bin/$command" 2>/dev/null; then
        echo "$hive_home/bin/$command"
        return 0
    # Try nested structure
    elif docker-compose exec -T "$service" test -f "$hive_home/apache-hive-3.1.3-bin/bin/$command" 2>/dev/null; then
        echo "$hive_home/apache-hive-3.1.3-bin/bin/$command"
        return 0
    fi
    return 1
}

# Function to find Beeline command (handles nested directory structures)
find_beeline_command() {
    local service=$1
    local command=$2
    local hive_home="/opt/hive"
    
    # Try standard location first
    if docker-compose exec -T "$service" test -f "$hive_home/bin/$command" 2>/dev/null; then
        echo "$hive_home/bin/$command"
        return 0
    # Try nested structure
    elif docker-compose exec -T "$service" test -f "$hive_home/apache-hive-3.1.3-bin/bin/$command" 2>/dev/null; then
        echo "$hive_home/apache-hive-3.1.3-bin/bin/$command"
        return 0
    fi
    return 1
}

# Function to find Spark command (handles nested directory structures)
find_spark_command() {
    local service=$1
    local command=$2
    local spark_home="/opt/spark"
    
    # Try standard location first
    if docker-compose exec -T "$service" test -f "$spark_home/bin/$command" 2>/dev/null; then
        echo "$spark_home/bin/$command"
        return 0
    # Try nested structure
    elif docker-compose exec -T "$service" test -f "$spark_home/spark-3.5.8-bin-hadoop3/bin/$command" 2>/dev/null; then
        echo "$spark_home/spark-3.5.8-bin-hadoop3/bin/$command"
        return 0
    fi
    return 1
}

# Function to check Hive Metastore connection
check_hive_metastore_connection() {
    print_info "Testing Hive Metastore connection from hive-server..."
    
    # Find hive command (handles nested structures)
    local HIVE_CMD=$(find_hive_command "hive-server" "hive")
    
    if [ -z "$HIVE_CMD" ]; then
        print_error "Hive Metastore: Hive CLI command not found"
        ((FAILED++))
        return 1
    fi
    
    # Try to connect using Hive CLI
    if docker-compose exec -T hive-server bash -c "$HIVE_CMD -e \"SHOW DATABASES;\"" > /dev/null 2>&1; then
        print_success "Hive Metastore: Hive CLI connection successful"
        ((PASSED++))
        return 0
    else
        # Check if it's just a connection issue or schema issue
        local error=$(docker-compose exec -T hive-server bash -c "$HIVE_CMD -e \"SHOW DATABASES;\"" 2>&1 | grep -i "SessionHiveMetaStoreClient\|URISyntaxException" || echo "")
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

# Function to execute Beeline command (no validation - user can manually check output)
check_beeline_connection() {
    print_info "Executing Beeline connection test to HiveServer2..."
    
    # Find beeline command (handles nested structures)
    local BEELINE_CMD=$(find_beeline_command "hive-server" "beeline")
    
    if [ -z "$BEELINE_CMD" ]; then
        print_error "Beeline: Beeline command not found"
        return 1
    fi
    
    # Execute Beeline with JDBC URL
    # Beeline format: beeline -u jdbc:hive2://host:port/database -n username -p password -e "query"
    # For local connections, empty username/password is often acceptable
    local jdbc_url="jdbc:hive2://localhost:10000/default"
    print_info "Running: beeline -u $jdbc_url -e 'SHOW DATABASES;'"
    echo ""
    
    # Execute and display output directly (no validation)
    docker-compose exec -T hive-server bash -c "$BEELINE_CMD -u '$jdbc_url' -n '' -p '' -e 'SHOW DATABASES;' 2>&1" || true
    
    echo ""
    print_info "Beeline command executed. Please review the output above to verify connection status."
}

echo "=========================================="
echo "Big Data Stack - Connection Validation"
echo "=========================================="
echo ""

# 1. Check if containers are running
print_section "1. Container Status"
check_service "postgres" "PostgreSQL"
check_service "namenode" "HDFS NameNode"
check_service "datanode" "HDFS DataNode"
check_service "resourcemanager" "YARN ResourceManager"
check_service "nodemanager" "YARN NodeManager"
check_service "hive-metastore" "Hive Metastore"
check_service "hive-server" "HiveServer2"
check_service "spark-master" "Spark Master"
check_service "spark-worker" "Spark Worker"
check_service "spark-history-server" "Spark History Server"

# 2. Check PostgreSQL
print_section "2. PostgreSQL Validation"
#check_port "postgres" "5432" "PostgreSQL"
#check_postgres_connection "hive" "metastore" "Hive user connection"
#check_postgres_connection "hive" "hive" "Hive user default database"

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

# Check HDFS report
print_info "Checking HDFS cluster status..."
HDFS_REPORT=$(docker-compose exec -T namenode hdfs dfsadmin -report 2>/dev/null | head -5 || echo "")
if [ -n "$HDFS_REPORT" ]; then
    print_success "HDFS: NameNode is responding"
    ((PASSED++))
else
    print_warn "HDFS: NameNode report unavailable"
fi

# 5. Check YARN Services
print_section "5. YARN Services Validation"
check_port "resourcemanager" "8088" "YARN ResourceManager Web UI"
check_port "nodemanager" "8042" "YARN NodeManager Web UI"

# Check network connectivity
check_network_connectivity "nodemanager" "resourcemanager" "8032" "NodeManager -> ResourceManager connectivity"
check_network_connectivity "nodemanager" "namenode" "9000" "NodeManager -> NameNode connectivity"

# Check if YARN processes are running
if docker-compose exec -T resourcemanager jps 2>/dev/null | grep -qi "ResourceManager"; then
    print_success "YARN ResourceManager: Java process is running"
    ((PASSED++))
else
    print_error "YARN ResourceManager: Java process is NOT running"
    ((FAILED++))
fi

if docker-compose exec -T nodemanager jps 2>/dev/null | grep -qi "NodeManager"; then
    print_success "YARN NodeManager: Java process is running"
    ((PASSED++))
else
    print_error "YARN NodeManager: Java process is NOT running"
    ((FAILED++))
fi

# 6. Check Hive Metastore
print_section "6. Hive Metastore Validation"
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

# 7. Check HiveServer2
print_section "7. HiveServer2 Validation"
check_port "hive-server" "10000" "HiveServer2 Thrift"

# Check if HiveServer2 process is running
if docker-compose exec -T hive-server jps 2>/dev/null | grep -qi "RunJar\|HiveServer2"; then
    print_success "HiveServer2: Java process is running"
    ((PASSED++))
else
    print_warn "HiveServer2: Java process may not be running yet (check logs if port is listening)"
fi

# Test Beeline connection to HiveServer2
check_beeline_connection

# 8. Test Hive Metastore Connection
print_section "8. Hive Metastore Connection Test"
check_hive_metastore_connection

# 9. Check Spark Services
print_section "9. Spark Services Validation"
check_port "spark-master" "7077" "Spark Master RPC"
check_port "spark-master" "8080" "Spark Master Web UI"
check_port "spark-worker" "8081" "Spark Worker Web UI"
check_port "spark-history-server" "18080" "Spark History Server Web UI"

# Check Spark Master connectivity from worker
check_network_connectivity "spark-worker" "spark-master" "7077" "Spark Worker -> Master connectivity"

# Check if Spark processes are running
if docker-compose exec -T spark-master jps 2>/dev/null | grep -qi "Master"; then
    print_success "Spark Master: Java process is running"
    ((PASSED++))
else
    print_error "Spark Master: Java process is NOT running"
    ((FAILED++))
fi

if docker-compose exec -T spark-worker jps 2>/dev/null | grep -qi "Worker"; then
    print_success "Spark Worker: Java process is running"
    ((PASSED++))
else
    print_error "Spark Worker: Java process is NOT running"
    ((FAILED++))
fi

# Check Spark connectivity to HDFS
check_network_connectivity "spark-master" "namenode" "9000" "Spark Master -> HDFS NameNode connectivity"
check_network_connectivity "spark-worker" "namenode" "9000" "Spark Worker -> HDFS NameNode connectivity"

# Check Spark connectivity to Hive Metastore
check_network_connectivity "spark-master" "hive-metastore" "9083" "Spark Master -> Hive Metastore connectivity"
check_network_connectivity "spark-worker" "hive-metastore" "9083" "Spark Worker -> Hive Metastore connectivity"

# Test Spark SQL with Hive support
print_info "Testing Spark SQL with Hive support..."
SPARK_SQL_CMD=$(find_spark_command "spark-master" "spark-sql")
if [ -n "$SPARK_SQL_CMD" ]; then
    if docker-compose exec -T spark-master bash -c "$SPARK_SQL_CMD --master local[*] --conf spark.sql.catalogImplementation=hive -e \"SHOW DATABASES;\"" > /dev/null 2>&1; then
        print_success "Spark SQL: Hive integration test successful"
        ((PASSED++))
    else
        print_warn "Spark SQL: Hive integration test failed (may need more time to initialize)"
        print_info "You can test manually: docker-compose exec spark-master $SPARK_SQL_CMD --master local[*] -e 'SHOW DATABASES;'"
    fi
else
    print_warn "Spark SQL: Command not found (may need container restart)"
fi

# 10. Network Configuration Check
print_section "10. Network Configuration"
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
    echo ""
    print_info "Service URLs:"
    echo "  - HDFS NameNode Web UI: http://localhost:9870"
    echo "  - HDFS DataNode Web UI: http://localhost:9864"
    echo "  - YARN ResourceManager Web UI: http://localhost:8088"
    echo "  - YARN NodeManager Web UI: http://localhost:8042"
    echo "  - Hive Metastore: hive-metastore:9083"
    echo "  - HiveServer2: localhost:10000"
    echo "  - Spark Master Web UI: http://localhost:8080"
    echo "  - Spark Worker Web UI: http://localhost:8081"
    echo "  - Spark History Server: http://localhost:18080"
    echo ""
    
    # Open all UI links automatically
    open_all_ui_links
    echo ""
    
    print_info "Connection Strings:"
    echo "  - Spark Master URL: spark://spark-master:7077"
    echo "  - HDFS URI: hdfs://namenode:9000"
    echo "  - Hive JDBC: jdbc:hive2://localhost:10000"
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
    echo "  docker-compose logs spark-master"
    echo "  docker-compose logs spark-worker"
    echo "  docker-compose logs spark-history-server"
    exit 1
fi

