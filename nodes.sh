#!/usr/bin/env bash
# Tu equipo: lista los nodos encendidos y cómo entrar por SSH a cada uno.
set -euo pipefail
KEY=~/.ssh/vockey.pem
NODES="hadoop-master,hadoop-worker-1,hadoop-worker-2,hadoop-worker-3,hadoop-client-ingest,hadoop-client-query"

# Nombre, IP privada y DNS público de cada nodo encendido
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=$NODES" "Name=instance-state-name,Values=running" \
  --query "Reservations[].Instances[].[Tags[?Key=='Name']|[0].Value,PrivateIpAddress,PublicDnsName]" \
  --output text | sort | while read -r name ip dns; do
  case $name in
    hadoop-worker-*) how="solo desde el master: ssh $name" ;;   # sin SSH desde fuera
    *)               how="ssh -i $KEY ec2-user@$dns" ;;
  esac
  printf '%-20s %-15s %s\n' "$name" "$ip" "$how"
done
