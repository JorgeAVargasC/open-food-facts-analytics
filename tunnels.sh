#!/usr/bin/env bash
# Webs de HDFS y YARN en localhost. Uso: ./tunnels.sh [stop]
set -euo pipefail
source "$(dirname "$0")/cluster/common.sh"

if [ "${1:-}" = stop ]; then
  pkill -f "ssh .*-L 8088:" && echo "Túneles cerrados." || echo "No había túneles."
  exit 0
fi

# DNS público (para entrar) e IP privada (donde escuchan las webs) del master
dns=$(info hadoop-master PublicDnsName)
ip=$(info hadoop-master PrivateIpAddress)

# Puerto de la web de HDFS, tal como lo configuró Ansible
hdfs_port=$(ssh $SSH_OPTS ec2-user@$dns \
  "JAVA_HOME=/usr/lib/jvm/java ~/$HADOOP/bin/hdfs getconf -confKey dfs.namenode.http-address" | cut -d: -f2)

# Cerrar los de una sesión anterior (apuntan al DNS viejo del master) y abrir los nuevos:
# un solo SSH en segundo plano con los dos túneles
pkill -f "ssh .*-L 8088:" || true
ssh $SSH_OPTS -f -N -o ExitOnForwardFailure=yes -L $hdfs_port:$ip:$hdfs_port -L 8088:$ip:8088 ec2-user@$dns
echo "HDFS: http://localhost:$hdfs_port"
echo "YARN: http://localhost:8088/cluster/apps"
echo "Para cerrarlos: ./tunnels.sh stop"
