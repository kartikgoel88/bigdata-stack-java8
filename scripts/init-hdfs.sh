#!/bin/bash

# Initialize HDFS directories for Hive

set -e

echo "Waiting for NameNode to be ready..."
until $HADOOP_HOME/bin/hdfs dfsadmin -report 2>/dev/null; do
    echo "Waiting for NameNode..."
    sleep 2
done

echo "Creating HDFS directories for Hive..."
$HADOOP_HOME/bin/hdfs dfs -mkdir -p /tmp
$HADOOP_HOME/bin/hdfs dfs -mkdir -p /user/hive/warehouse
$HADOOP_HOME/bin/hdfs dfs -chmod -R 777 /tmp
$HADOOP_HOME/bin/hdfs dfs -chmod -R 777 /user/hive/warehouse

echo "HDFS directories created successfully!"

