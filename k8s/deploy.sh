#!/bin/bash

# Big Data Stack Kubernetes Deployment Script
# This script deploys the entire big data stack to Kubernetes

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=========================================="
echo "Big Data Stack - Kubernetes Deployment"
echo "=========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed or not in PATH"
    exit 1
fi

# Check if we can connect to cluster
if ! kubectl cluster-info &> /dev/null; then
    print_error "Cannot connect to Kubernetes cluster"
    exit 1
fi

print_info "Connected to cluster: $(kubectl config current-context)"

# Step 1: Create namespace
print_info "Step 1: Creating namespace..."
kubectl apply -f namespace.yaml

# Step 2: Create ConfigMaps
print_info "Step 2: Creating ConfigMaps..."
kubectl apply -f configmaps.yaml

# Step 3: Create Secrets
print_info "Step 3: Creating Secrets..."
kubectl apply -f secrets.yaml

# Step 4: Create PersistentVolumeClaims
print_info "Step 4: Creating PersistentVolumeClaims..."
kubectl apply -f persistent-volumes.yaml

# Wait for PVCs to be bound
print_info "Waiting for PersistentVolumeClaims to be bound..."
kubectl wait --for=condition=Bound pvc --all -n bigdata-stack --timeout=300s || print_warn "Some PVCs may not be bound yet"

# Step 5: Deploy PostgreSQL
print_info "Step 5: Deploying PostgreSQL..."
kubectl apply -f postgres.yaml

# Step 6: Wait for PostgreSQL to be ready
print_info "Waiting for PostgreSQL to be ready..."
kubectl wait --for=condition=ready pod -l app=postgres -n bigdata-stack --timeout=300s || print_warn "PostgreSQL may not be ready yet"

# Step 7: Deploy Hadoop components
print_info "Step 7: Deploying Hadoop components..."
kubectl apply -f hadoop.yaml

# Step 8: Wait for NameNode to be ready
print_info "Waiting for NameNode to be ready..."
kubectl wait --for=condition=ready pod -l app=namenode -n bigdata-stack --timeout=300s || print_warn "NameNode may not be ready yet"

# Step 9: Deploy Hive
print_info "Step 9: Deploying Hive..."
kubectl apply -f hive.yaml

# Step 10: Deploy Spark
print_info "Step 10: Deploying Spark..."
kubectl apply -f spark.yaml

# Step 11: Optional - Deploy Ingress (commented out by default)
# print_info "Step 11: Deploying Ingress..."
# kubectl apply -f ingress.yaml

echo ""
print_info "Deployment complete!"
echo ""
print_info "Checking pod status..."
kubectl get pods -n bigdata-stack

echo ""
print_info "To access services, use port-forward:"
echo "  kubectl port-forward -n bigdata-stack svc/namenode 9870:9870"
echo "  kubectl port-forward -n bigdata-stack svc/resourcemanager 8088:8088"
echo "  kubectl port-forward -n bigdata-stack svc/spark-master 8080:8080"
echo "  kubectl port-forward -n bigdata-stack svc/hive-server 10000:10000"
echo ""
print_info "To view logs: kubectl logs -n bigdata-stack <pod-name>"
print_info "To delete everything: kubectl delete namespace bigdata-stack"
echo ""



