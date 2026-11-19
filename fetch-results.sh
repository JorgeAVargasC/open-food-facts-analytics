#!/usr/bin/env bash
# Tu equipo: trae los resultados de las preguntas (CSV de HDFS) a results/. Uso: ./fetch-results.sh
# Deja un CSV por pregunta: results/q05-brands-by-pnns-group.csv, etc.
set -euo pipefail
cd "$(dirname "$0")"
OPTS="-i ~/.ssh/vockey.pem -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR"

dns=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=hadoop-client-query" "Name=instance-state-name,Values=running" \
  --query "Reservations[0].Instances[0].PublicDnsName" --output text)

# En el cliente: cada carpeta de /results (un part-*.csv dentro) pasa a un solo CSV con el nombre de la pregunta
ssh $OPTS ec2-user@$dns 'bash -l -s' <<'REMOTE'
cd open-food-facts-analytics
rm -rf csv && mkdir csv
for d in $(hdfs dfs -ls /results | awk '/^d/ {print $NF}'); do
  hdfs dfs -getmerge "$d/part-*.csv" "csv/$(basename "$d").csv"
done
REMOTE

# Las comillas hacen que el * lo expanda el cliente, no tu equipo
mkdir -p results
scp $OPTS "ec2-user@$dns:open-food-facts-analytics/csv/*.csv" results/
ls -l results/
