#!/bin/bash

# Big Data Stack Startup Script
# This script brings down containers, rebuilds images, and starts all services

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=========================================="
echo "Big Data Stack - Startup Script"
echo "=========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Step 1: Stop and remove containers
print_info "Step 1: Stopping and removing existing containers..."
docker-compose down -v
if [ $? -eq 0 ]; then
    print_info "Containers stopped and removed successfully"
else
    print_warn "Some containers may not have been running"
fi

echo ""

# Step 2: Remove old network if it exists (with underscore)
print_info "Step 2: Cleaning up old network (if exists)..."
docker network rm bigdata-stack-java8_hadoop-network 2>/dev/null || \
docker network rm bigdata-stack-java8-hadoop-network 2>/dev/null || \
print_info "Old network cleanup completed (or didn't exist)"

echo ""

# Step 3: Build base image
print_info "Step 3: Building base image..."
docker-compose build --no-cache base
if [ $? -eq 0 ]; then
    print_info "Base image built successfully"
else
    print_error "Failed to build base image"
    exit 1
fi

echo ""

# Step 4: Build all service images
print_info "Step 4: Building all service images..."
docker-compose build 
#--no-cache
if [ $? -eq 0 ]; then
    print_info "All service images built successfully"
else
    print_error "Failed to build service images"
    exit 1
fi

echo ""

# Step 5: Start all services
print_info "Step 5: Starting all services..."
docker-compose up -d
if [ $? -eq 0 ]; then
    print_info "Services started successfully"
else
    print_error "Failed to start services"
    exit 1
fi

echo ""

# Step 6: Wait for services to be ready
print_info "Step 6: Waiting for services to be ready..."
print_info "This may take 30-60 seconds..."

# Wait for PostgreSQL
print_info "Waiting for PostgreSQL..."
for i in {1..30}; do
    if docker-compose exec -T postgres pg_isready -U hive -d metastore > /dev/null 2>&1; then
        print_info "PostgreSQL is ready"
        break
    fi
    if [ $i -eq 30 ]; then
        print_warn "PostgreSQL may not be ready yet"
    else
        echo -n "."
        sleep 2
    fi
done
echo ""

# Wait for NameNode
print_info "Waiting for HDFS NameNode..."
for i in {1..30}; do
    if docker-compose exec -T namenode nc -z localhost 9000 > /dev/null 2>&1; then
        print_info "NameNode is ready"
        break
    fi
    if [ $i -eq 30 ]; then
        print_warn "NameNode may not be ready yet"
    else
        echo -n "."
        sleep 2
    fi
done
echo ""

# Wait for Hive Metastore
print_info "Waiting for Hive Metastore..."
for i in {1..60}; do
    if docker-compose exec -T hive-metastore nc -z localhost 9083 > /dev/null 2>&1; then
        print_info "Hive Metastore is ready"
        break
    fi
    if [ $i -eq 60 ]; then
        print_warn "Hive Metastore may not be ready yet"
    else
        echo -n "."
        sleep 2
    fi
done
echo ""

# Wait for Spark Master
print_info "Waiting for Spark Master..."
for i in {1..30}; do
    if docker-compose exec -T spark-master nc -z localhost 7077 > /dev/null 2>&1; then
        print_info "Spark Master is ready"
        break
    fi
    if [ $i -eq 30 ]; then
        print_warn "Spark Master may not be ready yet"
    else
        echo -n "."
        sleep 2
    fi
done
echo ""

# Wait for Spark Worker
print_info "Waiting for Spark Worker..."
for i in {1..30}; do
    if docker-compose exec -T spark-worker nc -z localhost 8081 > /dev/null 2>&1; then
        print_info "Spark Worker is ready"
        break
    fi
    if [ $i -eq 30 ]; then
        print_warn "Spark Worker may not be ready yet"
    else
        echo -n "."
        sleep 2
    fi
done
echo ""

# Wait for Spark History Server
print_info "Waiting for Spark History Server..."
for i in {1..30}; do
    if docker-compose exec -T spark-history-server nc -z localhost 18080 > /dev/null 2>&1; then
        print_info "Spark History Server is ready"
        break
    fi
    if [ $i -eq 30 ]; then
        print_warn "Spark History Server may not be ready yet"
    else
        echo -n "."
        sleep 2
    fi
done
echo ""

# Step 7: Show service status
echo ""
print_info "Step 7: Service Status"
echo "=========================================="
docker-compose ps

echo ""
print_info "Startup complete!"
echo ""
print_info "Service URLs:"
echo "  - HDFS NameNode Web UI: http://localhost:9870"
echo "  - YARN ResourceManager: http://localhost:8088"
echo "  - HiveServer2: localhost:10000"
echo "  - Spark Master Web UI: http://localhost:8080"
echo "  - Spark Worker Web UI: http://localhost:8081"
echo "  - Spark History Server: http://localhost:18080"
echo ""
print_info "To view logs: docker-compose logs -f [service-name]"
print_info "To validate connections: ./validate-connections.sh"
echo ""

