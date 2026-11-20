#!/usr/bin/env bash
# Paso 8: Java, Hadoop y Spark en los dos clientes, Spark configurado para YARN y su usuario de HDFS.
set -euo pipefail
source "$(dirname "$0")/common.sh"
echo "== 8. Instalar los clientes"

# Del master a cada cliente, por la red interna: los mismos Hadoop y Spark que instaló Ansible y la
# configuración de Hadoop (dónde están HDFS y YARN)
on_master "HADOOP=$HADOOP SPARK=$SPARK bash -s" <<'EOF2'
conf=~/$HADOOP/etc/hadoop
ssh -n hadoop-client-ingest "test -f $SPARK.tgz" || scp -q ~/$HADOOP.tar.gz ~/$SPARK.tgz $conf/core-site.xml $conf/yarn-site.xml hadoop-client-ingest:
ssh -n hadoop-client-query "test -f $SPARK.tgz" || scp -q ~/$HADOOP.tar.gz ~/$SPARK.tgz $conf/core-site.xml $conf/yarn-site.xml hadoop-client-query:
EOF2

install_client() {
  on_client $1 "ROLE=$1 HADOOP=$HADOOP SPARK=$SPARK bash -s" <<'EOF2'
if [ -x ~/$SPARK/bin/spark-submit ] && grep -q SPARK_HOME ~/.bashrc; then
  echo "hadoop-client-$ROLE: ya instalado"
  exit 0
fi
sudo dnf install -y -q java-1.8.0-amazon-corretto-devel   # Java 8, el mismo que en el resto de nodos
tar -xzf ~/$HADOOP.tar.gz -C ~
tar -xzf ~/$SPARK.tgz -C ~
mv ~/core-site.xml ~/yarn-site.xml ~/$HADOOP/etc/hadoop/

# Spark en YARN: 3 executors (uno por worker) de 2 núcleos y 3 GB
cat > ~/$SPARK/conf/spark-defaults.conf <<'CONF'
spark.master                   yarn
spark.submit.deployMode        client
spark.driver.memory            2g
spark.executor.instances       3
spark.executor.cores           2
spark.executor.memory          3g
spark.executor.memoryOverhead  512m
CONF

# Solo avisos y errores en pantalla (por defecto Spark imprime mucho INFO)
sed 's/rootLogger.level = info/rootLogger.level = warn/' \
  ~/$SPARK/conf/log4j2.properties.template > ~/$SPARK/conf/log4j2.properties

# Variables de entorno. HADOOP_USER_NAME es el usuario con el que el cliente entra a HDFS
cat >> ~/.bashrc <<VARS
export JAVA_HOME=/usr/lib/jvm/java
export HADOOP_HOME=\$HOME/$HADOOP
export HADOOP_CONF_DIR=\$HADOOP_HOME/etc/hadoop
export SPARK_HOME=\$HOME/$SPARK
export PATH=\$PATH:\$HADOOP_HOME/bin:\$SPARK_HOME/bin
export HADOOP_USER_NAME=$ROLE
VARS
echo "hadoop-client-$ROLE: instalado"
EOF2
}

install_client ingest
install_client query
