#!/usr/bin/env bash

# Java configuration - detect JAVA_HOME if not set
[ -z "$JAVA_HOME" ] && { JAVA_CMD=$(which java 2>/dev/null); JAVA_HOME=$([ -n "$JAVA_CMD" ] && dirname $(dirname $(readlink -f "$JAVA_CMD" 2>/dev/null || echo "$JAVA_CMD")) || echo /opt/java/openjdk); }
[ -z "$JAVA_HOME" ] || [ ! -d "$JAVA_HOME" ] && { echo "ERROR: JAVA_HOME is not set or does not exist. Current value: $JAVA_HOME" >&2; echo "Please ensure Java is properly installed." >&2; exit 1; }
export JAVA_HOME

# Hadoop configuration
export HADOOP_HOME=/opt/hadoop
export HADOOP_CONF_DIR=$HADOOP_HOME/etc/hadoop
export HADOOP_LOG_DIR=$HADOOP_HOME/logs
export HADOOP_PID_DIR=$HADOOP_HOME/pids

# HDFS configuration
export HDFS_NAMENODE_USER=root
export HDFS_DATANODE_USER=root
export HDFS_SECONDARYNAMENODE_USER=root

# YARN configuration
export YARN_RESOURCEMANAGER_USER=root
export YARN_NODEMANAGER_USER=root

# Add Hadoop to PATH
export PATH=$PATH:$HADOOP_HOME/bin:$HADOOP_HOME/sbin

