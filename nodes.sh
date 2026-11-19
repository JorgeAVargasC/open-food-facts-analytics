#!/usr/bin/env bash
# Los nodos encendidos, su IP privada y cómo entrar por SSH a cada uno.
set -euo pipefail
source "$(dirname "$0")/cluster/common.sh"

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
