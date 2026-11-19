#!/usr/bin/env bash
# Levantar el clúster, paso a paso. Uso: ./up.sh
# Se puede relanzar: cada paso se salta lo que ya está hecho.
set -euo pipefail
cd "$(dirname "$0")"

bash cluster/01-prepare.sh           # clave, credenciales y Ansible de clase
bash cluster/02-master-workers.sh    # master y 3 workers con HDFS y YARN (Ansible)
bash cluster/03-clients.sh           # crear los clientes ingest y query
bash cluster/04-start.sh             # encender lo apagado y esperar a las 6 instancias
bash cluster/05-ssh.sh               # el master entra a todos por nombre; /etc/hosts
bash cluster/06-yarn-workers.sh      # YARN de los workers: 6 GB y 2 vCores
bash cluster/07-hdfs-folders.sh      # /data de ingest, /results de query
bash cluster/08-install-clients.sh   # Java, Hadoop y Spark en los clientes
bash cluster/09-check.sh             # SparkPi y estado del clúster
bash push.sh                         # código a los clientes
bash nodes.sh                        # cómo entrar a cada nodo
bash tunnels.sh                      # webs de HDFS y YARN en localhost

echo
echo "Siguiente, a mano: cargar los datos en el cliente ingest (README, paso 2)"
