#!/usr/bin/env bash
# Spark Environment Configuration

# Java Home - will be set by base image
# JAVA_HOME is already set in the base image

# Spark Master Host (for standalone mode)
# Use 0.0.0.0 to bind to all interfaces, allowing connections from other containers
# Can be overridden by environment variable SPARK_MASTER_HOST
# Only set default if not already set (allows docker-compose to override)
if [ -z "$SPARK_MASTER_HOST" ]; then
    export SPARK_MASTER_HOST=0.0.0.0
fi
export SPARK_MASTER_PORT=${SPARK_MASTER_PORT:-7077}

# Spark Worker Configuration
export SPARK_WORKER_CORES=2
export SPARK_WORKER_MEMORY=2g
# Worker Web UI host binding - use 0.0.0.0 to bind to all interfaces
export SPARK_WORKER_WEBUI_HOST=${SPARK_WORKER_WEBUI_HOST:-0.0.0.0}

# Spark History Server
# Bind UI to 0.0.0.0 to allow access from outside container
# SPARK_LOCAL_IP controls the bind address for History Server
export SPARK_LOCAL_IP=${SPARK_LOCAL_IP:-0.0.0.0}
export SPARK_HISTORY_OPTS="-Dspark.history.fs.logDirectory=hdfs://namenode:9000/spark-logs -Dspark.history.ui.port=18080 -Dspark.history.ui.bindAddress=0.0.0.0"

# PySpark Configuration
export PYSPARK_PYTHON=python3
export PYSPARK_DRIVER_PYTHON=python3

# HDFS Configuration (if using HDFS)
export HADOOP_CONF_DIR=${HADOOP_CONF_DIR:-/opt/hadoop/etc/hadoop}

