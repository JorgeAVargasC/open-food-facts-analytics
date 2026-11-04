#!/usr/bin/env bash
# Local: muestra nombre, estado, IP privada y DNS público de cada instancia. El DNS cambia en cada arranque.
# Uso: ./cluster/status.sh
set -euo pipefail
source "$(dirname "$0")/env.sh"

aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=hadoop-master,hadoop-worker-1,hadoop-worker-2,hadoop-worker-3,hadoop-client" \
            "Name=instance-state-name,Values=pending,running,stopping,stopped" \
  --query 'Reservations[].Instances[].[Tags[?Key==`Name`]|[0].Value, State.Name, PrivateIpAddress, PublicDnsName]' \
  --output table
