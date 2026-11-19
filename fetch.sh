#!/usr/bin/env bash
# Tu equipo: trae las gráficas del cliente query a figures/. Uso: ./fetch.sh
set -euo pipefail
cd "$(dirname "$0")"
OPTS="-i ~/.ssh/vockey.pem -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR"

dns=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=hadoop-client-query" "Name=instance-state-name,Values=running" \
  --query "Reservations[0].Instances[0].PublicDnsName" --output text)

mkdir -p figures
# Las comillas hacen que el * lo expanda el cliente, no tu equipo
scp $OPTS "ec2-user@$dns:open-food-facts-analytics/figures/*.png" figures/
ls -l figures/
