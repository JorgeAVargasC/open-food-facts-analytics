#!/usr/bin/env bash
# Tu equipo: abre los túneles a las webs de HDFS y YARN. Uso: ./tunnels.sh [stop]
set -euo pipefail
KEY=~/.ssh/vockey.pem

if [ "${1:-}" = stop ]; then
  pkill -f "ssh .*-L 8088:" && echo "Túneles cerrados." || echo "No había túneles."
  exit 0
fi

# DNS público (para entrar) e IP privada (donde escuchan las webs) del master
master() {
  aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=hadoop-master" "Name=instance-state-name,Values=running" \
    --query "Reservations[0].Instances[0].$1" --output text
}
dns=$(master PublicDnsName)
ip=$(master PrivateIpAddress)
SSH="ssh -i $KEY -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR"

# Puerto de la web de HDFS, tal como lo configuró Ansible
hdfs_port=$($SSH ec2-user@$dns "JAVA_HOME=/usr/lib/jvm/java ~/hadoop-3.3.6/bin/hdfs getconf -confKey dfs.namenode.http-address" | cut -d: -f2)

# Un solo SSH en segundo plano con los dos túneles
$SSH -f -N -o ExitOnForwardFailure=yes -L $hdfs_port:$ip:$hdfs_port -L 8088:$ip:8088 ec2-user@$dns
echo "HDFS: http://localhost:$hdfs_port"
echo "YARN: http://localhost:8088/cluster/nodes"
echo "Para cerrarlos: ./tunnels.sh stop"
