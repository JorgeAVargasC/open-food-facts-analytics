# Versiones de Hadoop y Spark: el único sitio donde cambiarlas.
# Hadoop tiene que coincidir con el del playbook de clase.
# Spark se baja de dlcdn.apache.org, que solo guarda las versiones vigentes: si desaparece,
# ver cuál hay con  curl -s https://dlcdn.apache.org/spark/  y cambiar el número aquí.
HADOOP_VERSION=3.3.6
SPARK_VERSION=3.5.9
HADOOP=hadoop-$HADOOP_VERSION
SPARK=spark-$SPARK_VERSION-bin-hadoop3
