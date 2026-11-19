#!/usr/bin/env bash
# Paso 4: encender lo que esté apagado y esperar a que las 6 instancias estén listas.
set -euo pipefail
source "$(dirname "$0")/common.sh"
echo "== 4. Encender y esperar"

stopped=$(ids "$NODES" stopped)
[ -z "$stopped" ] || aws ec2 start-instances --instance-ids $stopped > /dev/null
aws ec2 wait instance-status-ok --instance-ids $(ids "$NODES" pending,running)
echo "Las 6 instancias, listas"
