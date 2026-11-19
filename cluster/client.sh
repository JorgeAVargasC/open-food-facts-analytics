#!/usr/bin/env bash
# En un cliente. Uso: bash cluster/client.sh ingest | query
# Instala Java, Hadoop y Spark, y fija el usuario de HDFS del cliente.
set -euo pipefail
ROLE=$1

if [ -x ~/spark-3.5.5-bin-hadoop3/bin/spark-submit ]; then
  echo "Hadoop y Spark ya instalados"
  exit 0
fi

# Java 8, el mismo que en el master y los workers
sudo dnf install -y -q java-1.8.0-amazon-corretto-devel python3-pip

# El cliente query dibuja las gráficas
if [ "$ROLE" = query ]; then
  pip3 install -q --user pandas matplotlib
fi

# Descomprimir lo que copió el master
tar -xzf ~/hadoop-3.3.6.tar.gz -C ~
tar -xzf ~/spark-3.5.5-bin-hadoop3.tgz -C ~

# Spark en YARN: 3 executors (uno por worker) de 2 núcleos y 3 GB
cat > ~/spark-3.5.5-bin-hadoop3/conf/spark-defaults.conf <<'CONF'
spark.master                   yarn
spark.submit.deployMode        client
spark.driver.memory            2g
spark.executor.instances       3
spark.executor.cores           2
spark.executor.memory          3g
spark.executor.memoryOverhead  512m
CONF

# Variables de entorno. HADOOP_USER_NAME es el usuario con el que el cliente entra a HDFS
cat >> ~/.bashrc <<VARS
export JAVA_HOME=/usr/lib/jvm/java
export HADOOP_HOME=\$HOME/hadoop-3.3.6
export HADOOP_CONF_DIR=\$HADOOP_HOME/etc/hadoop
export SPARK_HOME=\$HOME/spark-3.5.5-bin-hadoop3
export PATH=\$PATH:\$HADOOP_HOME/bin:\$SPARK_HOME/bin
export HADOOP_USER_NAME=$ROLE
VARS
echo "Cliente $ROLE instalado"
