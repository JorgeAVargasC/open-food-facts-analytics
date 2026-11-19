#!/usr/bin/env bash
# Tu equipo: copia el código a cada cliente (ingest/ al de ingesta, query/ al de consulta).
# Después entras por SSH y lanzas tú los comandos. Uso: ./sync.sh
set -euo pipefail
cd "$(dirname "$0")"
OPTS="-i ~/.ssh/vockey.pem -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR"

for role in ingest query; do
  dns=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=hadoop-client-$role" "Name=instance-state-name,Values=running" \
    --query "Reservations[0].Instances[0].PublicDnsName" --output text)
  # Sin borrar: se conserva lo generado en el cliente (figures/, results/)
  tar -cf - $role | ssh $OPTS ec2-user@$dns \
    "mkdir -p open-food-facts-analytics && tar -C open-food-facts-analytics -xf -"
  echo "hadoop-client-$role: $role/ copiado"
done
