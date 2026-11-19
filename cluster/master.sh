#!/usr/bin/env bash
# En el master. Uso: ./cluster/master.sh setup | check
set -euo pipefail
cd "$(dirname "$0")/.."
export JAVA_HOME=/usr/lib/jvm/java
HADOOP=~/hadoop-3.3.6
HDFS=$HADOOP/bin/hdfs
WORKERS="hadoop-worker-1 hadoop-worker-2 hadoop-worker-3"
CLIENTS="ingest query"

setup() {
  echo "== SSH a los nodos por nombre"
  chmod 600 ~/.ssh/vockey.pem
  printf 'Host hadoop-*\n  User ec2-user\n  IdentityFile ~/.ssh/vockey.pem\n  StrictHostKeyChecking no\n  UserKnownHostsFile /dev/null\n  LogLevel ERROR\n' > ~/.ssh/config
  chmod 600 ~/.ssh/config

  echo "== /etc/hosts del master con los dos clientes"
  if ! grep -q hadoop-client /etc/hosts; then
    (echo; cat clients-hosts.txt) | sudo tee -a /etc/hosts   # echo: el archivo no termina en salto de línea
  fi

  echo "== YARN de los workers: 6 GB por nodo"
  for w in $WORKERS; do
    scp -q cluster/worker-yarn-site.xml "$w:hadoop-3.3.6/etc/hadoop/yarn-site.xml"
    ssh "$w" "sudo systemctl restart nodemanager"
  done

  echo "== Carpetas de HDFS: ingest escribe /data, query escribe /results"
  $HDFS dfs -mkdir -p /data/raw /data/clean /results /user/ingest /user/query
  $HDFS dfs -chown -R ingest /data /user/ingest
  $HDFS dfs -chown -R query /results /user/query
  $HDFS dfs -chmod -R 755 /data /results
  $HDFS dfs -chmod 700 /user/ingest /user/query

  for role in $CLIENTS; do
    client=hadoop-client-$role
    echo "== $client"

    # El cliente conoce al master y los workers, pero no su propio nombre.
    # Así Spark se anuncia con el nombre interno de EC2, que los workers sí resuelven;
    # con su alias, los workers fallarían con UnknownHostException.
    grep -v hadoop-client /etc/hosts | ssh $client "sudo tee /etc/hosts > /dev/null"

    # Los mismos Hadoop y Spark que instaló Ansible en el master, y su configuración
    ssh $client "test -f spark-3.5.9-bin-hadoop3.tgz" || scp -q ~/hadoop-3.3.6.tar.gz ~/spark-3.5.9-bin-hadoop3.tgz $client:
    ssh $client "rm -rf open-food-facts-analytics && mkdir open-food-facts-analytics"
    tar -cf - cluster/client.sh $role | ssh $client "tar -C open-food-facts-analytics -xf -"
    ssh $client "bash open-food-facts-analytics/cluster/client.sh $role"
    scp -q $HADOOP/etc/hadoop/core-site.xml $HADOOP/etc/hadoop/yarn-site.xml $client:hadoop-3.3.6/etc/hadoop/

    # Prueba: SparkPi en YARN lanzado desde el cliente
    ssh $client "bash -lc 'spark-submit spark-3.5.9-bin-hadoop3/examples/src/main/python/pi.py 10 2> /dev/null'"
  done
  echo "Esperado: dos veces Pi is roughly 3.14"

  echo
  check
}

check() {
  for node in hadoop-master $WORKERS; do
    echo "== $node"
    ssh "$node" /usr/lib/jvm/java/bin/jps
  done
  echo "Esperado: master con NameNode y ResourceManager; workers con DataNode y NodeManager"
  echo
  $HDFS dfsadmin -report 2> /dev/null | grep "Live datanodes"
  $HADOOP/bin/yarn node -list -showDetails 2> /dev/null | grep -E "Total Nodes|Configured Resources"
  echo "Esperado: Live datanodes (3), Total Nodes:3 y 3 veces <memory:6144, vCores:2>"
  echo
  $HDFS dfs -ls / /data
  echo "Esperado: /data de ingest y /results de query"
  echo
  # query solo puede leer /data
  HADOOP_USER_NAME=query $HDFS dfs -touchz /data/test 2>&1 | grep -o "Permission denied" || true
  echo "Esperado: Permission denied"
}

case "${1:-}" in
  setup | check) "$1" ;;
  *) echo "Uso: ./cluster/master.sh setup | check"; exit 1 ;;
esac
