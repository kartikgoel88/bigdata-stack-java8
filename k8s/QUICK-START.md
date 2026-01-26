# Kubernetes Quick Start Guide

This is a quick reference guide for deploying the big data stack to Kubernetes.

## Prerequisites Check

```bash
# Check kubectl is installed
kubectl version --client

# Check cluster connection
kubectl cluster-info

# Check available nodes
kubectl get nodes
```

## Step 1: Build Docker Images

```bash
# From project root
docker build -f Dockerfile.base -t bigdata-stack-base:latest .
docker build -f Dockerfile.hadoop-spark-base -t bigdata-runtime:hadoop .
```

## Step 2: Load Images to Cluster

### For minikube:
```bash
minikube image load bigdata-runtime:hadoop
```

### For kind:
```bash
kind load docker-image bigdata-runtime:hadoop
```

### For remote clusters:
```bash
# Tag and push to your registry
docker tag bigdata-runtime:hadoop your-registry/bigdata-runtime:hadoop
docker push your-registry/bigdata-runtime:hadoop

# Update image references in YAML files
sed -i 's|bigdata-runtime:hadoop|your-registry/bigdata-runtime:hadoop|g' k8s/*.yaml
```

## Step 3: Deploy

```bash
cd k8s
./deploy.sh
```

Or manually:
```bash
kubectl apply -k k8s/  # Using kustomize
# OR
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/configmaps.yaml
kubectl apply -f k8s/secrets.yaml
kubectl apply -f k8s/persistent-volumes.yaml
kubectl apply -f k8s/postgres.yaml
kubectl apply -f k8s/hadoop.yaml
kubectl apply -f k8s/hive.yaml
kubectl apply -f k8s/spark.yaml
```

## Step 4: Verify Deployment

```bash
# Check all pods are running
kubectl get pods -n bigdata-stack

# Watch pod status
kubectl get pods -n bigdata-stack -w

# Check services
kubectl get svc -n bigdata-stack

# Check persistent volumes
kubectl get pvc -n bigdata-stack
```

## Step 5: Access Services

### Port Forwarding (Recommended for local access)

```bash
# NameNode Web UI
kubectl port-forward -n bigdata-stack svc/namenode 9870:9870 &
# Access at http://localhost:9870

# ResourceManager Web UI
kubectl port-forward -n bigdata-stack svc/resourcemanager 8088:8088 &
# Access at http://localhost:8088

# Spark Master Web UI
kubectl port-forward -n bigdata-stack svc/spark-master 8080:8080 &
# Access at http://localhost:8080

# Spark History Server
kubectl port-forward -n bigdata-stack svc/spark-history-server 18080:18080 &
# Access at http://localhost:18080

# HiveServer2 (for JDBC)
kubectl port-forward -n bigdata-stack svc/hive-server 10000:10000 &
```

### Using Ingress (if ingress controller is installed)

```bash
kubectl apply -f k8s/ingress.yaml
# Update /etc/hosts: <ingress-ip> bigdata.local
# Access at http://bigdata.local/namenode, etc.
```

## Common Commands

### View Logs
```bash
# Specific pod
kubectl logs -n bigdata-stack <pod-name>

# Follow logs
kubectl logs -f -n bigdata-stack <pod-name>

# All pods of a service
kubectl logs -n bigdata-stack -l app=namenode
```

### Scale Services
```bash
# Scale DataNodes
kubectl scale deployment datanode -n bigdata-stack --replicas=3

# Scale NodeManagers
kubectl scale deployment nodemanager -n bigdata-stack --replicas=3

# Scale Spark Workers
kubectl scale deployment spark-worker -n bigdata-stack --replicas=5
```

### Execute Commands in Pods
```bash
# Get pod name
kubectl get pods -n bigdata-stack -l app=namenode

# Execute command
kubectl exec -it -n bigdata-stack <pod-name> -- bash

# Run HDFS command
kubectl exec -n bigdata-stack <namenode-pod> -- hdfs dfs -ls /
```

### Restart Services
```bash
# Restart deployment
kubectl rollout restart deployment <deployment-name> -n bigdata-stack

# Restart all Hadoop services
kubectl rollout restart deployment datanode resourcemanager nodemanager -n bigdata-stack
```

## Troubleshooting

### Pods Not Starting
```bash
# Describe pod for details
kubectl describe pod <pod-name> -n bigdata-stack

# Check events
kubectl get events -n bigdata-stack --sort-by='.lastTimestamp'
```

### PVC Not Binding
```bash
# Check storage classes
kubectl get storageclass

# Update storageClassName in persistent-volumes.yaml if needed
```

### Services Not Accessible
```bash
# Check service endpoints
kubectl get endpoints -n bigdata-stack

# Check pod labels match service selectors
kubectl get pods -n bigdata-stack --show-labels
```

## Cleanup

```bash
# Delete everything
kubectl delete namespace bigdata-stack

# Or delete specific components
kubectl delete -f k8s/spark.yaml
kubectl delete -f k8s/hive.yaml
kubectl delete -f k8s/hadoop.yaml
kubectl delete -f k8s/postgres.yaml
```

## Next Steps

- Read [KUBERNETES-BENEFITS.md](../KUBERNETES-BENEFITS.md) to understand the benefits
- Check [k8s/README.md](README.md) for detailed documentation
- Configure monitoring and logging
- Set up CI/CD pipelines
- Implement backup strategies for persistent volumes



