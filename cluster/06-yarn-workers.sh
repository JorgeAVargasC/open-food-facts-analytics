#!/usr/bin/env bash
# Paso 6: YARN de los workers a 6 GB y 2 vCores (cluster/worker-yarn-site.xml), desde el master.
set -euo pipefail
source "$(dirname "$0")/common.sh"
echo "== 6. YARN de los workers"

scp $SSH_OPTS -q cluster/worker-yarn-site.xml ec2-user@"$(info hadoop-master PublicDnsName)":
on_master "HADOOP=$HADOOP bash -s" <<'EOF2'
scp -q worker-yarn-site.xml hadoop-worker-1:$HADOOP/etc/hadoop/yarn-site.xml && ssh -n hadoop-worker-1 "sudo systemctl restart nodemanager"
scp -q worker-yarn-site.xml hadoop-worker-2:$HADOOP/etc/hadoop/yarn-site.xml && ssh -n hadoop-worker-2 "sudo systemctl restart nodemanager"
scp -q worker-yarn-site.xml hadoop-worker-3:$HADOOP/etc/hadoop/yarn-site.xml && ssh -n hadoop-worker-3 "sudo systemctl restart nodemanager"
EOF2
echo "3 NodeManager reiniciados"
