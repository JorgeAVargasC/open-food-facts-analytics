#!/usr/bin/env bash
# Apagar las instancias encendidas. HDFS conserva los datos; ./up.sh las vuelve a encender.
set -euo pipefail
source "$(dirname "$0")/cluster/common.sh"

running=$(ids "$NODES" running)
[ -z "$running" ] || aws ec2 stop-instances --instance-ids $running > /dev/null
echo "Apagando: $running"
