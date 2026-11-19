#!/usr/bin/env bash
# Traer los resultados de HDFS a results/, un CSV por pregunta. Después: python3 plot-results.py
set -euo pipefail
source "$(dirname "$0")/cluster/common.sh"

# En el cliente query: cada carpeta de /results (Spark deja un part-*.csv dentro) pasa a un CSV con su nombre
on_client query "bash -l -s" <<'EOF2'
rm -rf ~/results-csv && mkdir ~/results-csv
for d in $(hdfs dfs -ls /results | awk '/^d/ {print $NF}'); do
  hdfs dfs -getmerge "$d/part-*.csv" ~/results-csv/$(basename "$d").csv
done
EOF2

# Las comillas hacen que el * lo expanda el cliente, no tu equipo
mkdir -p results
scp $SSH_OPTS "ec2-user@$(info hadoop-client-query PublicDnsName):results-csv/*.csv" results/
ls -l results/*.csv
echo "Gráficas: python3 plot-results.py"
