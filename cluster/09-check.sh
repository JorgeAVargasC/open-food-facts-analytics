#!/usr/bin/env bash
# Paso 9: comprobar el clúster. También se puede lanzar suelto: bash cluster/09-check.sh
set -euo pipefail
source "$(dirname "$0")/common.sh"
echo "== 9. Comprobación"

# SparkPi en YARN, lanzado desde cada cliente
on_client ingest "bash -lc 'spark-submit $SPARK/examples/src/main/python/pi.py 10 2> /dev/null'"
on_client query "bash -lc 'spark-submit $SPARK/examples/src/main/python/pi.py 10 2> /dev/null'"
echo "Esperado: dos veces Pi is roughly 3.14"
echo

on_master "HADOOP=$HADOOP bash -s" <<'EOF2'
export JAVA_HOME=/usr/lib/jvm/java
hdfs=~/$HADOOP/bin/hdfs
for node in hadoop-master hadoop-worker-1 hadoop-worker-2 hadoop-worker-3; do
  echo "$node: $(ssh -n $node /usr/lib/jvm/java/bin/jps | grep -v Jps | awk '{print $2}' | xargs)"
done
echo "Esperado: master con NameNode y ResourceManager; workers con DataNode y NodeManager"
echo
$hdfs dfsadmin -report 2> /dev/null | grep "Live datanodes"
~/$HADOOP/bin/yarn node -list -showDetails 2> /dev/null | grep -E "Total Nodes|Configured Resources"
echo "Esperado: Live datanodes (3), Total Nodes:3 y 3 veces <memory:6144, vCores:2>"
echo
$hdfs dfs -ls / /data
echo "Esperado: /data de ingest y /results de query"
echo
HADOOP_USER_NAME=query $hdfs dfs -touchz /data/test 2>&1 | grep -o "Permission denied" || true
echo "Esperado: Permission denied (query no puede escribir en /data)"
EOF2
