#!/bin/bash
set -x

ROLE="$1"
echo "Starting BigData container with role: $ROLE"

# ---------- Signal handling ----------
child_pid=""

term_handler() {
  echo "Received termination signal"
  [ -n "$child_pid" ] && kill -0 "$child_pid" 2>/dev/null && kill -TERM "$child_pid" && wait "$child_pid"
  exit 0
}

trap term_handler SIGTERM SIGINT

# ---------- Environment ----------
export HADOOP_HOME=${HADOOP_HOME}
export HIVE_HOME=${HIVE_HOME}
export SPARK_HOME=${SPARK_HOME}
export HADOOP_CONF_DIR=${HADOOP_CONF_DIR}
export HIVE_CONF_DIR=${HIVE_CONF_DIR}
export SPARK_CONF_DIR=${SPARK_CONF_DIR}

# Normalize HIVE_HOME and SPARK_HOME paths if binaries are in versioned subdirectories
normalize_hive_home() {
  [ ! -d "$HIVE_HOME/bin" ] && [ -d "$HIVE_HOME/apache-hive-${HIVE_VERSION}-bin/bin" ] && \
    export HIVE_HOME="$HIVE_HOME/apache-hive-${HIVE_VERSION}-bin"
}

normalize_spark_home() {
  [ ! -d "$SPARK_HOME/sbin" ] && [ -d "$SPARK_HOME/spark-${SPARK_VERSION}-bin-hadoop3/sbin" ] && \
    export SPARK_HOME="$SPARK_HOME/spark-${SPARK_VERSION}-bin-hadoop3"
}

normalize_hive_home
normalize_spark_home

export PATH=$PATH:$HADOOP_HOME/bin:$HADOOP_HOME/sbin:$HIVE_HOME/bin:$SPARK_HOME/bin:$SPARK_HOME/sbin

# ---------- Create local filesystem directories ----------
mkdir -p "$HADOOP_HOME/data/namenode" \
         "$HADOOP_HOME/data/datanode" \
         "$HADOOP_HOME/data/tmp" \
         "$HADOOP_HOME/logs" \
         "$SPARK_HOME/work" \
         "$SPARK_HOME/logs" \
         /var/run/sshd

chmod -R 755 "$HADOOP_HOME/data" "$HADOOP_HOME/logs" "$SPARK_HOME/work" "$SPARK_HOME/logs" 2>/dev/null || true

# ---------- SSH ----------
[ ! -f /root/.ssh/id_rsa ] && ssh-keygen -t rsa -P '' -f /root/.ssh/id_rsa && \
  cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys && \
  chmod 600 /root/.ssh/authorized_keys

service ssh start

# ---------- Helpers ----------

format_namenode() {
  [ ! -d "$HADOOP_HOME/data/namenode/current" ] && echo "Formatting NameNode..." && hdfs namenode -format -force
}

wait_for_port() {
  local host=$1 port=$2 retries=${3:-${WAIT_RETRIES}}
  for ((i=1;i<=retries;i++)); do
    nc -z "$host" "$port" 2>/dev/null && echo "$host:$port is reachable" && return 0
    echo "Waiting for $host:$port ($i/$retries)"
    sleep 2
  done
  return 1
}

init_hive_schema() {
  sleep 3
  
  SCHEMATOOL="$HIVE_HOME/bin/schematool"
  echo "Using schematool: $SCHEMATOOL"
  
  "$SCHEMATOOL" -dbType postgres -info >/dev/null 2>&1 && echo "Hive schema already initialized" && return 0
  
  echo "Initializing Hive schema..."
  "$SCHEMATOOL" -dbType postgres -initSchema 2>&1 || true
}

ensure_hdfs_directories() {
  sleep 5
  
  echo "Creating HDFS directories..."
  hdfs dfs -mkdir -p /tmp /user/${HIVE_USER}/warehouse /spark-logs 2>/dev/null || true
  hdfs dfs -chmod -R 755 /tmp /user/${HIVE_USER}/warehouse /spark-logs 2>/dev/null || true
  hdfs dfs -chown -R ${HIVE_USER}:${HIVE_USER} /user/${HIVE_USER}/warehouse 2>/dev/null || true
}

# ---------- Dispatcher ----------

case "$ROLE" in
  namenode)
    format_namenode
    hdfs namenode &
    child_pid=$!
    #ensure_hdfs_directories
    wait $child_pid
    ;;

  datanode)
    hdfs datanode &
    child_pid=$!
    wait $child_pid
    ;;

  resourcemanager)
    yarn resourcemanager &
    child_pid=$!
    wait $child_pid
    ;;

  nodemanager)
    yarn nodemanager &
    child_pid=$!
    wait $child_pid
    ;;

  metastore)
    init_hive_schema || true
    
    echo "Starting Hive Metastore..."
    "$HIVE_HOME/bin/hive" --service metastore &
    child_pid=$!
    wait $child_pid
    ;;

  hiveserver2)
    ensure_hdfs_directories
    
    echo "Starting HiveServer2..."
    "$HIVE_HOME/bin/hiveserver2" &
    child_pid=$!
    wait $child_pid
    ;;

  spark-master)
    ensure_hdfs_directories
    
    echo "Starting Spark Master..."
    "$SPARK_HOME/bin/spark-class" org.apache.spark.deploy.master.Master \
      --host ${SPARK_MASTER_HOST:-0.0.0.0} \
      --port ${SPARK_MASTER_PORT_CONTAINER:-7077} \
      --webui-port ${SPARK_MASTER_WEB_PORT_CONTAINER:-8080} &
    child_pid=$!
    wait $child_pid
    ;;

  spark-worker)
    ensure_hdfs_directories
    
    echo "Starting Spark Worker..."
    "$SPARK_HOME/bin/spark-class" org.apache.spark.deploy.worker.Worker \
      --webui-port ${SPARK_WORKER_PORT_CONTAINER:-8081} \
      "$SPARK_MASTER" &
    child_pid=$!
    wait $child_pid
    ;;

  spark-history)
    ensure_hdfs_directories
    
    echo "Starting Spark History Server..."
    "$SPARK_HOME/bin/spark-class" org.apache.spark.deploy.history.HistoryServer &
    child_pid=$!
    wait $child_pid
    ;;

  *)
    exec "$@"
    ;;
esac
