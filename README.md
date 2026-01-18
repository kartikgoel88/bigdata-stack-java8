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

- Docker (version 20.10 or higher)
- Docker Compose (version 1.29 or higher)
- At least 4GB of available RAM
- At least 10GB of free disk space

## Quick Start

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

4. **Initialize HDFS directories for Hive:**
   ```bash
   docker-compose exec namenode /opt/scripts/init-hdfs.sh
   ```

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
│   └── init-hdfs.sh         # HDFS initialization script
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

## Versions

- **Base Image**: OpenJDK 8
- **Hadoop**: 3.3.4
- **Hive**: 3.1.3
- **PostgreSQL**: 13

## License

This project is provided as-is for educational and development purposes.
