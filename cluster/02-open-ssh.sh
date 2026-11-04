#!/usr/bin/env bash
# Paso 2 (local): abre el SSH del master y del client a cualquier IP (Ansible solo deja tu IP inicial).
# Uso: ./cluster/02-open-ssh.sh
set -euo pipefail
source "$(dirname "$0")/env.sh"

# Abrir el puerto 22 a todo internet en el grupo del master y el client
aws ec2 authorize-security-group-ingress \
  --group-name hadoop-master-sg \
  --protocol tcp \
  --port 22 \
  --cidr 0.0.0.0/0 \
  || echo "La regla ya existía"

# Mostrar las IPs que pueden entrar por SSH
aws ec2 describe-security-groups \
  --group-names hadoop-master-sg \
  --query "SecurityGroups[0].IpPermissions[].IpRanges[].CidrIp" \
  --output text

echo "Esperado: aparece 0.0.0.0/0"
echo
echo "Siguiente: ./cluster/03-create-client.sh"
