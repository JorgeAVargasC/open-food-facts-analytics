#!/usr/bin/env bash
# Paso 5: que el master entre en todos los nodos por nombre, y que los clientes conozcan al resto.
set -euo pipefail
source "$(dirname "$0")/common.sh"
echo "== 5. SSH y nombres"

# La clave, para que el master entre en los demás nodos
scp $SSH_OPTS -q $KEY ec2-user@"$(info hadoop-master PublicDnsName)":.ssh/vockey.pem

# En el master: SSH por nombre y los clientes en /etc/hosts (Ansible solo puso master y workers).
# A cada cliente, el /etc/hosts del master sin los clientes: si conociera su propio alias, Spark
# se anunciaría con él y los workers fallarían con UnknownHostException
on_master "INGEST=$(info hadoop-client-ingest PrivateIpAddress) QUERY=$(info hadoop-client-query PrivateIpAddress) bash -s" <<'EOF2'
chmod 600 ~/.ssh/vockey.pem
printf 'Host hadoop-*\n  User ec2-user\n  IdentityFile ~/.ssh/vockey.pem\n  StrictHostKeyChecking no\n  UserKnownHostsFile /dev/null\n  LogLevel ERROR\n' > ~/.ssh/config
chmod 600 ~/.ssh/config
if ! grep -q hadoop-client /etc/hosts; then
  printf '\n%s  hadoop-client-ingest\n%s  hadoop-client-query\n' $INGEST $QUERY | sudo tee -a /etc/hosts
fi
grep -v hadoop-client /etc/hosts | ssh hadoop-client-ingest "sudo tee /etc/hosts > /dev/null"
grep -v hadoop-client /etc/hosts | ssh hadoop-client-query "sudo tee /etc/hosts > /dev/null"
EOF2
