#!/usr/bin/env bash
# Local: muestra, ya listos para copiar y pegar, los comandos ssh para entrar al master y abrir las webs de YARN y HDFS.
# El DNS del master cambia en cada arranque: volver a ejecutarlo después de ./cluster/start.sh.
# Uso: ./cluster/ssh-commands.sh
set -euo pipefail
source "$(dirname "$0")/env.sh"

# DNS público del master encendido
MASTER_DNS=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=$ENV_MASTER" \
            "Name=instance-state-name,Values=running" \
  --query "Reservations[0].Instances[0].PublicDnsName" \
  --output text)

# aws devuelve "None" si no encuentra la instancia
if [ "$MASTER_DNS" = "None" ]; then
  echo "No hay $ENV_MASTER encendido. Enciéndelo con ./cluster/start.sh"
  exit 1
fi

echo "Entrar al master:"
echo
echo "  ssh -i $ENV_KEY ec2-user@$MASTER_DNS"
echo
echo "Túnel a las webs de YARN y HDFS (en otra terminal, dejarla abierta):"
echo
echo "  ssh -i $ENV_KEY -N -L 8088:$MASTER_DNS:8088 -L 50070:$MASTER_DNS:50070 ec2-user@$MASTER_DNS"
echo
echo "  YARN: http://localhost:8088/cluster"
echo "  HDFS: http://localhost:50070"
