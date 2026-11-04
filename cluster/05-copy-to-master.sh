#!/usr/bin/env bash
# Paso 4 (local): copia el proyecto y la clave al master. Repetir cada vez que cambie el proyecto.
# Uso: ./cluster/04-copy-to-master.sh
set -euo pipefail
source "$(dirname "$0")/env.sh"
REPO="$(cd "$(dirname "$0")/.." && pwd)"
MASTER=$(instance_info hadoop-master PublicDnsName)

# Borrar la copia anterior del proyecto en el master
ssh $SSH_OPTS ec2-user@"$MASTER" "rm -rf open-food-facts-analytics && mkdir open-food-facts-analytics"

# En Mac, que tar no añada archivos ocultos ._* (no afecta en WSL)
export COPYFILE_DISABLE=1

# Copiar el proyecto sin el CSV completo ni las carpetas de pruebas locales
tar -C "$REPO" \
    --exclude="*.gz" \
    --exclude="local" \
    --exclude="logs" \
    -cf - . \
  | ssh $SSH_OPTS ec2-user@"$MASTER" "tar -C open-food-facts-analytics -xf -"

# Copiar la clave para que el master pueda entrar en los demás nodos
scp $SSH_OPTS -q "$KEY" ec2-user@"$MASTER":.ssh/vockey.pem

echo "Copiado. Entra al master con:"
echo
echo "  ssh -i ~/.ssh/vockey.pem ec2-user@$MASTER"
echo
echo "Siguiente, en el master: cd open-food-facts-analytics && ./cluster/05-setup-master.sh"
