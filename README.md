# Big Data Stack with Hadoop and Hive (Java 8)

A complete big data stack setup with Apache Hadoop and Apache Hive, built on Java 8 base image.

## Architecture

This project uses a multi-stage Docker build approach:

1. **Base Image** (`Dockerfile.base`): Contains Java 8 and common dependencies
   - OpenJDK 8
   - System packages (wget, curl, ssh, etc.)
   - SSH configuration for Hadoop

2. **Application Image** (`dockerfiles/Dockerfile.hadoop`): Built on top of the base image
   - Adds Hadoop 3.3.4
   - Adds Hive 3.1.3
   - Includes all configuration files and scripts

This project provides a containerized big data stack with the following components:

- **Hadoop 3.3.4**: Distributed storage and processing framework
  - NameNode: Manages the file system namespace
  - DataNode: Stores actual data blocks
  - ResourceManager: Manages cluster resources
  - NodeManager: Manages containers on nodes
- **Hive 3.1.3**: Data warehouse software for querying and managing large datasets
  - Hive Metastore: Stores metadata
  - HiveServer2: Provides JDBC/ODBC interface
- **PostgreSQL 13**: Database for Hive Metastore

## Prerequisites

### For Docker Compose:
- Docker (version 20.10 or higher)
- Docker Compose (version 1.29 or higher)
- At least 4GB of available RAM
- At least 10GB of free disk space

### For Kubernetes:
- Kubernetes cluster (minikube, kind, GKE, EKS, AKS, etc.)
- kubectl configured to access your cluster
- At least 8GB of available RAM (for the entire cluster)
- At least 100GB of free disk space (for persistent volumes)

## Deployment Options

### Option 1: Docker Compose (Recommended for Development)

Quick Start:

1. **Clone or navigate to the project directory:**
   ```bash
   cd bigdata-stack-java8
   ```

2. **Build and start all services:**
   ```bash
   docker-compose up -d --build
   ```
   
   This will:
   - First build the base image (`bigdata-stack-base:latest`)
   - Then build all service images using the base image
   - Start all containers

3. **Wait for services to be ready** (this may take a few minutes):
   ```bash
   docker-compose ps
   ```
   
   Note: HDFS directories (`/tmp`, `/user/hive/warehouse`, `/spark-logs`) are automatically created during NameNode startup.

## Service URLs

Once all services are running, you can access:

- **NameNode Web UI**: http://localhost:9870
- **ResourceManager Web UI**: http://localhost:8088
- **DataNode Web UI**: http://localhost:9864
- **HiveServer2**: localhost:10000 (JDBC connection)

## Usage Examples

### Access Hive via Beeline (CLI)

```bash
# Connect to HiveServer2
docker-compose exec hive-server $HIVE_HOME/bin/beeline -u jdbc:hive2://localhost:10000

# Or from your local machine (if you have beeline installed)
beeline -u jdbc:hive2://localhost:10000
```

### Example Hive Queries

Once connected via Beeline:

```sql
-- Create a database
CREATE DATABASE test_db;
USE test_db;

-- Create a table
CREATE TABLE employees (
    id INT,
    name STRING,
    department STRING,
    salary DOUBLE
) ROW FORMAT DELIMITED
FIELDS TERMINATED BY ','
STORED AS TEXTFILE;

-- Insert sample data
INSERT INTO employees VALUES
(1, 'John Doe', 'Engineering', 75000.0),
(2, 'Jane Smith', 'Marketing', 65000.0),
(3, 'Bob Johnson', 'Engineering', 80000.0);

-- Query data
SELECT * FROM employees;
SELECT department, AVG(salary) FROM employees GROUP BY department;
```

### Using HDFS Commands

```bash
# List files in HDFS
docker-compose exec namenode $HADOOP_HOME/bin/hdfs dfs -ls /

# Create a directory
docker-compose exec namenode $HADOOP_HOME/bin/hdfs dfs -mkdir /data

# Copy file from local to HDFS
docker-compose exec namenode $HADOOP_HOME/bin/hdfs dfs -put /path/to/local/file /data/

# View file content
docker-compose exec namenode $HADOOP_HOME/bin/hdfs dfs -cat /data/file.txt
```

### Running MapReduce Jobs

```bash
# Example: Word count
docker-compose exec namenode $HADOOP_HOME/bin/hadoop jar \
  $HADOOP_HOME/share/hadoop/mapreduce/hadoop-mapreduce-examples-*.jar \
  wordcount /input /output
```

## Configuration

### Hadoop Configuration

Configuration files are located in `config/hadoop/`:
- `core-site.xml`: Core Hadoop configuration
- `hdfs-site.xml`: HDFS configuration
- `mapred-site.xml`: MapReduce configuration
- `yarn-site.xml`: YARN configuration
- `workers`: List of worker nodes

### Hive Configuration

Configuration files are located in `config/hive/`:
- `hive-site.xml`: Hive configuration including metastore connection

## Troubleshooting

### Check service logs

```bash
# View logs for a specific service
docker-compose logs -f namenode
docker-compose logs -f datanode
docker-compose logs -f hive-server
docker-compose logs -f hive-metastore
```

### Restart services

```bash
# Restart all services
docker-compose restart

# Restart a specific service
docker-compose restart namenode
```

### Reset everything

```bash
# Stop and remove all containers, networks, and volumes
docker-compose down -v

# Rebuild and start
docker-compose up -d --build
```

### Build base image separately

If you want to build just the base image:

```bash
docker build -f Dockerfile.base -t bigdata-stack-base:latest .
```

This is useful for:
- Testing the base image independently
- Reusing the base image for other projects
- Faster iteration when only base dependencies change

### Common Issues

1. **Port conflicts**: Make sure ports 9870, 8088, 9864, 10000, 9083, and 5432 are not in use
2. **Memory issues**: Increase Docker memory allocation in Docker Desktop settings
3. **Hive connection errors**: Ensure Hive Metastore is running and initialized before starting HiveServer2

## Project Structure

```
bigdata-stack-java8/
├── Dockerfile.base           # Base image with Java 8 and dependencies
├── dockerfiles/
│   └── Dockerfile.hadoop     # Application image with Hadoop and Hive
├── docker-compose.yml        # Service orchestration
├── config/
│   ├── hadoop/              # Hadoop configuration files
│   └── hive/                # Hive configuration files
├── scripts/
│   ├── entrypoint.sh        # Service entrypoint script
│   └── utils/
│       └── error-handling.sh  # Error handling utilities
├── downloads/               # Pre-downloaded binaries (optional)
└── README.md                # This file
```

## Docker Image Structure

The project uses a layered approach:

1. **Base Image** (`bigdata-stack-base:latest`): 
   - Built from `Dockerfile.base`
   - Contains Java 8 runtime and system dependencies
   - Can be reused for other Java-based services

2. **Application Image**: 
   - Built from `dockerfiles/Dockerfile.hadoop`
   - Extends the base image
   - Adds Hadoop and Hive installations
   - Includes all configurations and scripts

This structure allows for:
- Faster rebuilds (base image is cached)
- Reusability of the base image
- Easier maintenance and updates

## Kubernetes Deployment

This stack is also available as Kubernetes manifests for production deployments.

### Quick Start with Kubernetes

1. **Build Docker images** (if not already built):
   ```bash
   docker build -f Dockerfile.base -t bigdata-stack-base:latest .
   docker build -f Dockerfile.hadoop-spark-base -t bigdata-runtime:hadoop .
   ```

2. **Make images available to your Kubernetes cluster:**
   ```bash
   # For minikube
   minikube image load bigdata-runtime:hadoop
   
   # For kind
   kind load docker-image bigdata-runtime:hadoop
   
   # For remote clusters, push to a registry and update image references
   ```

3. **Deploy to Kubernetes:**
   ```bash
   cd k8s
   ./deploy.sh
   ```

4. **Access services via port-forwarding:**
   ```bash
   kubectl port-forward -n bigdata-stack svc/namenode 9870:9870
   kubectl port-forward -n bigdata-stack svc/resourcemanager 8088:8088
   kubectl port-forward -n bigdata-stack svc/spark-master 8080:8080
   ```

### Kubernetes Benefits

Running on Kubernetes provides:
- ✅ **High Availability** - Automatic pod restarts and self-healing
- ✅ **Horizontal Scaling** - Scale DataNodes, NodeManagers, Spark Workers independently
- ✅ **Resource Management** - CPU and memory limits with QoS guarantees
- ✅ **Persistent Storage** - Data survives pod restarts and migrations
- ✅ **Service Discovery** - Built-in DNS for service communication
- ✅ **Rolling Updates** - Zero-downtime deployments
- ✅ **Multi-Environment** - Isolated namespaces for dev/staging/prod
- ✅ **Cloud Portability** - Run on any Kubernetes cluster (GKE, EKS, AKS, on-prem)

See [KUBERNETES-BENEFITS.md](KUBERNETES-BENEFITS.md) for detailed benefits and comparison.

For detailed Kubernetes deployment instructions, see [k8s/README.md](k8s/README.md).

## Versions

- **Base Image**: OpenJDK 8
- **Hadoop**: 3.3.6
- **Hive**: 3.1.3
- **Spark**: 3.5.8
- **PostgreSQL**: 13

## License

This project is provided as-is for educational and development purposes.
