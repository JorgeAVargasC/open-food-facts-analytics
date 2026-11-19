#!/usr/bin/env bash
# En el cliente ingest: descarga el CSV de Open Food Facts y lo sube a HDFS.
source ~/.bashrc   # hdfs y HADOOP_USER_NAME=ingest
set -euo pipefail

# La muestra se crea la última: si existe, ya está todo
if hdfs dfs -test -e /data/raw/sample.csv; then
  echo "Los datos ya están en HDFS"
  exit 0
fi

echo "== Descargar y subir a HDFS sin pasar por el disco (~15 min)"
curl -sL https://static.openfoodfacts.org/data/en.openfoodfacts.org.products.csv.gz \
  | gunzip | hdfs dfs -put -f - /data/raw/openfoodfacts.csv

echo "== Muestra al azar del 2 %, para probar la limpieza"
hdfs dfs -cat /data/raw/openfoodfacts.csv \
  | awk 'NR == 1 || rand() < 0.02' | hdfs dfs -put -f - /data/raw/sample.csv

hdfs dfs -ls -h /data/raw
echo "Esperado: openfoodfacts.csv unos 13 G y sample.csv unos 270 M, de ingest"
