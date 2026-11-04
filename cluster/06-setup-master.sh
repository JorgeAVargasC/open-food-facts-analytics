#!/usr/bin/env bash
# Paso 6 (master): permite entrar a los nodos con "ssh hadoop-worker-1" y añade el client a /etc/hosts.
# Uso: ./cluster/06-setup-master.sh
set -euo pipefail
cd "$(dirname "$0")"

# Dejar la clave legible solo por ti (si no, ssh no la usa)
chmod 600 ~/.ssh/vockey.pem

# Instalar ~/.ssh/config: usuario ec2-user y clave vockey.pem para todos los hadoop-*
cp ssh-config ~/.ssh/config
chmod 600 ~/.ssh/config

# Añadir el client al /etc/hosts del master con la IP de client-ip.txt
if ! grep -q hadoop-client /etc/hosts; then
  # El /etc/hosts de Ansible no acaba en salto de línea: añadirlo para no pegar el client a la última línea
  [ -z "$(tail -c 1 /etc/hosts)" ] || echo | sudo tee -a /etc/hosts > /dev/null
  echo "$(cat client-ip.txt)  hadoop-client" | sudo tee -a /etc/hosts
fi

# Copiar ese /etc/hosts al client para que encuentre al master y a los workers por su nombre
scp /etc/hosts hadoop-client:/tmp/hosts
ssh hadoop-client "sudo cp /tmp/hosts /etc/hosts"

# Comprobar que el master entra en cada nodo
for node in hadoop-worker-1 hadoop-worker-2 hadoop-worker-3 hadoop-client; do
  echo "$node: $(ssh "$node" hostname)"
done

echo "Esperado: 4 líneas con ip-172-..."
echo
echo "Siguiente: ./cluster/07-apply-config.sh"
