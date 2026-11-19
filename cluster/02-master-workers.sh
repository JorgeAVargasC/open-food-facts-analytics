#!/usr/bin/env bash
# Paso 2: master y 3 workers con HDFS y YARN, con el Ansible de clase.
# Solo si no hay master: el playbook formatea HDFS.
set -euo pipefail
source "$(dirname "$0")/common.sh"
echo "== 2. Master y workers (Ansible)"

if [ -n "$(ids hadoop-master $EXISTING)" ]; then
  echo "Ya existen"
  exit 0
fi
export ANSIBLE_SSH_ARGS="-o ServerAliveInterval=30 -o ControlMaster=auto -o ControlPersist=60s"   # que no se corte el SSH
source ~/ansible/bin/activate

# El inventario de clase toma TODAS las instancias de la cuenta; limitarlo a los nodos de este proyecto
cat > ~/hadoop-ansible-ec2/inventory.aws_ec2.yml <<'INV'
plugin: amazon.aws.aws_ec2
regions: [us-east-1]
filters:
  tag:Group: [hadoop-master, hadoop-worker]
  instance-state-name: running
keyed_groups:
  - prefix: tag
    key: tags
INV
cd ~/hadoop-ansible-ec2
ansible-playbook -i inventory.aws_ec2.yml --key-file $KEY --user ec2-user create-instances.yml
