# Big Data Stack - Kubernetes Deployment

This directory contains Kubernetes manifests to deploy the big data stack (Hadoop, Hive, Spark, PostgreSQL) to a Kubernetes cluster.

## Prerequisites

1. **Kubernetes Cluster**: A running Kubernetes cluster (minikube, kind, GKE, EKS, AKS, or any other)
2. **kubectl**: Kubernetes command-line tool installed and configured
3. **Docker Images**: The Docker images must be built and available:
   - `bigdata-runtime:hadoop` - Main runtime image with Hadoop, Hive, and Spark
   - `postgres:13` - PostgreSQL database

### Building Docker Images

Before deploying to Kubernetes, you need to build the Docker images:

```bash
# From the project root
docker build -f Dockerfile.base -t bigdata-stack-base:latest .
docker build -f Dockerfile.hadoop-spark-base -t bigdata-runtime:hadoop .
```

### Making Images Available to Kubernetes

**For local clusters (minikube, kind):**
```bash
# Load images into minikube
minikube image load bigdata-runtime:hadoop

# Or for kind
kind load docker-image bigdata-runtime:hadoop
```

**For remote clusters:**
- Push images to a container registry (Docker Hub, GCR, ECR, etc.)
- Update image references in the YAML files to use the registry path

## Quick Start

1. **Deploy everything:**
   ```bash
   chmod +x deploy.sh
   ./deploy.sh
   ```

2. **Or deploy manually:**
   ```bash
   kubectl apply -f namespace.yaml
   kubectl apply -f configmaps.yaml
   kubectl apply -f secrets.yaml
   kubectl apply -f persistent-volumes.yaml
   kubectl apply -f postgres.yaml
   kubectl apply -f hadoop.yaml
   kubectl apply -f hive.yaml
   kubectl apply -f spark.yaml
   ```

## Accessing Services

### Port Forwarding

Access services from your local machine using port forwarding:

```bash
# NameNode Web UI
kubectl port-forward -n bigdata-stack svc/namenode 9870:9870

# ResourceManager Web UI
kubectl port-forward -n bigdata-stack svc/resourcemanager 8088:8088

# Spark Master Web UI
kubectl port-forward -n bigdata-stack svc/spark-master 8080:8080

# Spark History Server
kubectl port-forward -n bigdata-stack svc/spark-history-server 18080:18080

# HiveServer2 (for JDBC connections)
kubectl port-forward -n bigdata-stack svc/hive-server 10000:10000
```

Then access:
- NameNode: http://localhost:9870
- ResourceManager: http://localhost:8088
- Spark Master: http://localhost:8080
- Spark History: http://localhost:18080

### Using Ingress

If you have an ingress controller installed, you can use the provided `ingress.yaml`:

```bash
kubectl apply -f ingress.yaml
```

Update the host in `ingress.yaml` to match your domain or add an entry to `/etc/hosts`.

### Exec into Pods

Execute commands directly in pods:

```bash
# Access NameNode
kubectl exec -it -n bigdata-stack $(kubectl get pod -n bigdata-stack -l app=namenode -o jsonpath='{.items[0].metadata.name}') -- bash

# Access HiveServer2
kubectl exec -it -n bigdata-stack $(kubectl get pod -n bigdata-stack -l app=hive-server -o jsonpath='{.items[0].metadata.name}') -- bash
```

## Monitoring

### Check Pod Status

```bash
kubectl get pods -n bigdata-stack
kubectl get pods -n bigdata-stack -w  # Watch mode
```

### View Logs

```bash
# View logs for a specific pod
kubectl logs -n bigdata-stack <pod-name>

# Follow logs
kubectl logs -f -n bigdata-stack <pod-name>

# View logs for all pods of a service
kubectl logs -n bigdata-stack -l app=namenode
```

### Check Services

```bash
kubectl get svc -n bigdata-stack
```

### Check PersistentVolumes

```bash
kubectl get pvc -n bigdata-stack
kubectl get pv
```

## Scaling

### Scale DataNodes

```bash
kubectl scale deployment datanode -n bigdata-stack --replicas=3
```

### Scale NodeManagers

```bash
kubectl scale deployment nodemanager -n bigdata-stack --replicas=3
```

### Scale Spark Workers

```bash
kubectl scale deployment spark-worker -n bigdata-stack --replicas=3
```

## Configuration

### Updating Configurations

1. Edit the ConfigMaps in `configmaps.yaml`
2. Apply the changes:
   ```bash
   kubectl apply -f configmaps.yaml
   ```
3. Restart the affected pods:
   ```bash
   kubectl rollout restart deployment <deployment-name> -n bigdata-stack
   ```

### Updating Secrets

1. Edit `secrets.yaml` (or use `kubectl create secret` for better security)
2. Apply:
   ```bash
   kubectl apply -f secrets.yaml
   ```
3. Restart pods that use the secret

## Troubleshooting

### Pods Not Starting

1. Check pod status:
   ```bash
   kubectl describe pod <pod-name> -n bigdata-stack
   ```

2. Check events:
   ```bash
   kubectl get events -n bigdata-stack --sort-by='.lastTimestamp'
   ```

### PVC Not Binding

1. Check storage class:
   ```bash
   kubectl get storageclass
   ```

2. Update `persistent-volumes.yaml` with the correct `storageClassName` for your cluster

### Services Not Accessible

1. Check service endpoints:
   ```bash
   kubectl get endpoints -n bigdata-stack
   ```

2. Verify pods are running and ready:
   ```bash
   kubectl get pods -n bigdata-stack
   ```

## Cleanup

### Delete Everything

```bash
kubectl delete namespace bigdata-stack
```

This will delete all resources including PersistentVolumeClaims (data will be lost unless you have a retention policy).

### Delete Specific Components

```bash
kubectl delete -f spark.yaml
kubectl delete -f hive.yaml
kubectl delete -f hadoop.yaml
kubectl delete -f postgres.yaml
```

## Resource Requirements

Minimum recommended resources for the entire stack:

- **CPU**: 8 cores
- **Memory**: 16 GB
- **Storage**: 100 GB (for persistent volumes)

Adjust resource requests/limits in the YAML files based on your cluster capacity.

## File Structure

```
k8s/
├── namespace.yaml              # Namespace definition
├── configmaps.yaml             # All configuration files
├── secrets.yaml                # Sensitive data (passwords)
├── persistent-volumes.yaml     # Storage claims
├── postgres.yaml               # PostgreSQL StatefulSet and Service
├── hadoop.yaml                 # Hadoop components (NameNode, DataNode, etc.)
├── hive.yaml                   # Hive Metastore and HiveServer2
├── spark.yaml                  # Spark Master, Workers, and History Server
├── ingress.yaml                # Optional ingress for external access
├── deploy.sh                   # Deployment script
└── README.md                   # This file
```

