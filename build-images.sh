#!/bin/bash

# Build script that ensures proper build order
# This script builds base image first, then runtime image

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=========================================="
echo "Building Big Data Stack Images"
echo "=========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Step 1: Build base image
print_info "Step 1: Building base image..."
if docker-compose build base --no-cache; then
    print_info "Base image built successfully"
else
    print_error "Failed to build base image"
    exit 1
fi

echo ""

# Step 2: Verify base image exists
print_info "Step 2: Verifying base image exists..."
if docker images bigdata-stack-base:latest --format "{{.Repository}}:{{.Tag}}" | grep -q "bigdata-stack-base:latest"; then
    print_info "Base image verified: bigdata-stack-base:latest"
else
    print_error "Base image not found after build!"
    exit 1
fi

echo ""

# Step 3: Build runtime image (will use local base image)
print_info "Step 3: Building runtime image..."
if docker-compose build runtime; then
    print_info "Runtime image built successfully"
else
    print_error "Failed to build runtime image"
    exit 1
fi

echo ""

# Step 4: Verify runtime image exists
print_info "Step 4: Verifying runtime image exists..."
if docker images bigdata-runtime:hadoop --format "{{.Repository}}:{{.Tag}}" | grep -q "bigdata-runtime:hadoop"; then
    print_info "Runtime image verified: bigdata-runtime:hadoop"
else
    print_error "Runtime image not found after build!"
    exit 1
fi

echo ""
print_info "=========================================="
print_info "All images built successfully!"
print_info "=========================================="
echo ""
print_info "Available images:"
docker images | grep -E "bigdata-stack-base|bigdata-runtime" || true
echo ""

