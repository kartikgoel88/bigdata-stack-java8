#!/bin/bash

# Entrypoint script for Hadoop/Hive services

set -e

# Source environment variables
if [ -f /etc/profile.d/java-home.sh ]; then
    source /etc/profile.d/java-home.sh
fi

# Set HADOOP_HOME if not already set (from Dockerfile ENV)
export HADOOP_HOME=${HADOOP_HOME:-/opt/hadoop}
export HIVE_HOME=${HIVE_HOME:-/opt/hive}

# Source Hadoop environment if available
if [ -f "$HADOOP_HOME/etc/hadoop/hadoop-env.sh" ]; then
    source "$HADOOP_HOME/etc/hadoop/hadoop-env.sh"
fi

# Function to format NameNode (only on first run)
format_namenode() {
    if [ ! -d "$HADOOP_HOME/data/namenode/current" ]; then
        echo "Formatting NameNode..."
        $HADOOP_HOME/bin/hdfs namenode -format -force
    fi
}

# Function to initialize Hive schema
init_hive_schema() {
    echo "Checking Hive schema..."
    MAX_SCHEMA_RETRIES=5
    SCHEMA_RETRY=0
    
    # Wait for PostgreSQL to be fully ready
    echo "Waiting for PostgreSQL connection..."
    until PGPASSWORD=hive psql -h postgres -U hive -d metastore -c "SELECT 1" > /dev/null 2>&1; do
        echo "Waiting for PostgreSQL to accept connections..."
        sleep 2
    done
    
    # Check if schema is already initialized
    if $HIVE_HOME/bin/schematool -dbType postgres -info 2>/dev/null; then
        echo "Hive schema already initialized."
        return 0
    fi
    
    # Initialize schema with retries
    while [ $SCHEMA_RETRY -lt $MAX_SCHEMA_RETRIES ]; do
        echo "Initializing Hive schema (attempt $((SCHEMA_RETRY + 1))/$MAX_SCHEMA_RETRIES)..."
        if $HIVE_HOME/bin/schematool -dbType postgres -initSchema; then
            echo "Hive schema initialized successfully."
            # Verify schema was created
            if $HIVE_HOME/bin/schematool -dbType postgres -info 2>/dev/null; then
                echo "Schema verification successful."
                return 0
            else
                echo "WARNING: Schema initialization reported success but verification failed"
            fi
        else
            SCHEMA_RETRY=$((SCHEMA_RETRY + 1))
            if [ $SCHEMA_RETRY -lt $MAX_SCHEMA_RETRIES ]; then
                echo "Schema initialization failed, retrying in 5 seconds..."
                sleep 5
            else
                echo "ERROR: Failed to initialize Hive schema after $MAX_SCHEMA_RETRIES attempts"
                echo "Please check PostgreSQL connection and permissions"
                return 1
            fi
        fi
    done
}

# Function to wait for log file and tail it
wait_and_tail_log() {
    local log_pattern=$1
    local max_wait=30
    local wait_count=0
    
    echo "Waiting for log file matching pattern: $log_pattern"
    while [ $wait_count -lt $max_wait ]; do
        if ls $log_pattern 1> /dev/null 2>&1; then
            echo "Log file found, starting to tail..."
            tail -f $log_pattern
            return 0
        fi
        echo "Waiting for log file... ($wait_count/$max_wait)"
        sleep 1
        wait_count=$((wait_count + 1))
    done
    
    echo "WARNING: Log file not found after $max_wait seconds. Showing available logs:"
    ls -la $HADOOP_HOME/logs/ 2>/dev/null || echo "Log directory is empty or doesn't exist"
    # Keep container running even if log file not found
    tail -f /dev/null
}

# Start SSH service
service ssh start

# Determine which service to start based on command
case "$1" in
    namenode)
        format_namenode
        echo "Starting NameNode..."
        $HADOOP_HOME/sbin/hadoop-daemon.sh start namenode
        wait_and_tail_log "$HADOOP_HOME/logs/hadoop-*-namenode-*.log"
        ;;
    datanode)
        echo "Starting DataNode..."
        $HADOOP_HOME/sbin/hadoop-daemon.sh start datanode
        wait_and_tail_log "$HADOOP_HOME/logs/hadoop-*-datanode-*.log"
        ;;
    resourcemanager)
        echo "Starting ResourceManager..."
        $HADOOP_HOME/sbin/yarn-daemon.sh start resourcemanager
        wait_and_tail_log "$HADOOP_HOME/logs/yarn-*-resourcemanager-*.log"
        ;;
    nodemanager)
        echo "Starting NodeManager..."
        $HADOOP_HOME/sbin/yarn-daemon.sh start nodemanager
        wait_and_tail_log "$HADOOP_HOME/logs/yarn-*-nodemanager-*.log"
        ;;
    metastore)
        echo "Waiting for PostgreSQL to be ready..."
        until nc -z postgres 5432; do
            echo "Waiting for postgres..."
            sleep 2
        done
        echo "PostgreSQL is ready!"
        init_hive_schema
        echo "Starting Hive Metastore..."
        $HIVE_HOME/bin/hive --service metastore
        ;;
    hiveserver2)
        echo "Starting HiveServer2..."
        
        # Wait for HDFS NameNode to be ready
        echo "Waiting for HDFS NameNode to be ready..."
        MAX_RETRIES=60
        RETRY_COUNT=0
        until nc -z namenode 9000; do
            RETRY_COUNT=$((RETRY_COUNT + 1))
            if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
                echo "ERROR: NameNode not ready after $MAX_RETRIES attempts"
                exit 1
            fi
            echo "Waiting for NameNode... ($RETRY_COUNT/$MAX_RETRIES)"
            sleep 2
        done
        echo "NameNode is ready!"
        
        # Wait for Hive Metastore to be ready
        echo "Waiting for Hive Metastore to be ready..."
        RETRY_COUNT=0
        until nc -z hive-metastore 9083; do
            RETRY_COUNT=$((RETRY_COUNT + 1))
            if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
                echo "ERROR: Hive Metastore not ready after $MAX_RETRIES attempts"
                echo "Please check hive-metastore container logs"
                exit 1
            fi
            echo "Waiting for hive-metastore... ($RETRY_COUNT/$MAX_RETRIES)"
            sleep 2
        done
        echo "Hive Metastore is ready!"
        
        # Wait a bit more to ensure metastore is fully initialized
        sleep 5
        
        # Ensure Hive warehouse directory exists in HDFS
        echo "Ensuring Hive warehouse directory exists in HDFS..."
        if $HADOOP_HOME/bin/hdfs dfs -test -d /user/hive/warehouse 2>/dev/null; then
            echo "Hive warehouse directory already exists in HDFS"
        else
            echo "Creating Hive warehouse directory in HDFS..."
            $HADOOP_HOME/bin/hdfs dfs -mkdir -p /user/hive/warehouse 2>/dev/null || echo "WARNING: Could not create warehouse directory, HiveServer2 will try during startup"
            $HADOOP_HOME/bin/hdfs dfs -chmod -R 777 /user/hive/warehouse 2>/dev/null || true
        fi
        
        # Create logs directory
        mkdir -p $HIVE_HOME/logs
        
        echo "Starting HiveServer2 (this may take 30-90 seconds to fully initialize)..."
        # Start HiveServer2 in foreground so logs are visible
        exec $HIVE_HOME/bin/hiveserver2
        ;;
    *)
        exec "$@"
        ;;
esac

