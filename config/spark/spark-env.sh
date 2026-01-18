#!/usr/bin/env bash
# Spark Environment Configuration

# Java Home - will be set by base image
# JAVA_HOME is already set in the base image

# Spark Master Host (for standalone mode)
export SPARK_MASTER_HOST=localhost
export SPARK_MASTER_PORT=7077

# Spark Worker Configuration
export SPARK_WORKER_CORES=2
export SPARK_WORKER_MEMORY=2g

# Spark History Server
export SPARK_HISTORY_OPTS="-Dspark.history.fs.logDirectory=hdfs://namenode:9000/spark-logs"

# PySpark Configuration
export PYSPARK_PYTHON=python3
export PYSPARK_DRIVER_PYTHON=python3

# HDFS Configuration (if using HDFS)
export HADOOP_CONF_DIR=${HADOOP_CONF_DIR:-/opt/hadoop/etc/hadoop}

