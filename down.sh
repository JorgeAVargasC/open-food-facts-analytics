#!/usr/bin/env bash
# Borrar las 6 instancias, con confirmación. Se pierden los datos de HDFS.
set -euo pipefail
source "$(dirname "$0")/cluster/common.sh"

all=$(ids "$NODES" $EXISTING)
if [ -z "$all" ]; then
  echo "No hay instancias del clúster."
  exit 0
fi
echo "Se van a BORRAR: $all"
read -r -p "Escribe BORRAR para confirmar: " answer
if [ "$answer" != BORRAR ]; then
  echo "Cancelado."
  exit 1
fi
aws ec2 terminate-instances --instance-ids $all > /dev/null
aws ec2 wait instance-terminated --instance-ids $all
echo "Borradas."
