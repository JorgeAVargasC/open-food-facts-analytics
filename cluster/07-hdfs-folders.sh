#!/usr/bin/env bash
# Paso 7: carpetas de HDFS y sus dueños: ingest escribe /data, query escribe /results.
# Se hace en el master, que es el superusuario de HDFS (ec2-user).
set -euo pipefail
source "$(dirname "$0")/common.sh"
echo "== 7. Carpetas de HDFS"

on_master "HADOOP=$HADOOP bash -s" <<'EOF2'
export JAVA_HOME=/usr/lib/jvm/java
hdfs=~/$HADOOP/bin/hdfs
$hdfs dfs -mkdir -p /data/raw /data/clean /results /user/ingest /user/query
$hdfs dfs -chown -R ingest /data /user/ingest
$hdfs dfs -chown -R query /results /user/query
$hdfs dfs -chmod -R 755 /data /results
$hdfs dfs -chmod 700 /user/ingest /user/query   # /user/<usuario>: Spark deja ahí lo que necesita cada job
$hdfs dfs -ls /
EOF2
