#!/usr/bin/env bash

# Java configuration - use JAVA_HOME from environment if set, otherwise detect
# eclipse-temurin base image sets JAVA_HOME, so we use that if available
if [ -z "$JAVA_HOME" ] || [ ! -d "$JAVA_HOME" ]; then
    # Try to source from profile script first
    if [ -f /etc/profile.d/java-home.sh ]; then
        source /etc/profile.d/java-home.sh
    fi
    
    # If still not set, try common eclipse-temurin paths
    if [ -z "$JAVA_HOME" ] || [ ! -d "$JAVA_HOME" ]; then
        if [ -d /opt/java/openjdk ]; then
            export JAVA_HOME=/opt/java/openjdk
        elif [ -d /usr/local/openjdk-8 ]; then
            export JAVA_HOME=/usr/local/openjdk-8
        elif [ -d /usr/lib/jvm/java-8-openjdk-amd64 ]; then
            export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
        elif [ -d /usr/lib/jvm/java-8-openjdk-arm64 ]; then
            export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-arm64
        else
            # Last resort: detect from java command
            JAVA_CMD=$(which java 2>/dev/null)
            if [ -n "$JAVA_CMD" ]; then
                JAVA_HOME=$(dirname $(dirname $(readlink -f "$JAVA_CMD" 2>/dev/null || echo "$JAVA_CMD")))
                export JAVA_HOME
            fi
        fi
    fi
fi

# Verify JAVA_HOME is set and valid
if [ -z "$JAVA_HOME" ] || [ ! -d "$JAVA_HOME" ]; then
    echo "ERROR: JAVA_HOME is not set or does not exist. Current value: $JAVA_HOME" >&2
    echo "Please ensure Java is properly installed." >&2
    exit 1
fi

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

