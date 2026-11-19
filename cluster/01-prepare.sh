#!/usr/bin/env bash
# Paso 1: comprobar clave y credenciales, y preparar el Ansible de clase.
set -euo pipefail
source "$(dirname "$0")/common.sh"
echo "== 1. Preparar"

if [ ! -f $KEY ]; then
  echo "Falta $KEY: cp ~/Downloads/labsuser.pem $KEY && chmod 600 $KEY"
  exit 1
fi
aws configure set region us-east-1
aws configure set cli_pager ""
if ! aws sts get-caller-identity > /dev/null; then
  echo "Pega en ~/.aws/credentials las credenciales del Learner Lab (AWS Details, AWS CLI, Show)"
  exit 1
fi

# Playbook de clase con dos ajustes de descarga (repetirlos no hace nada):
# Hadoop desde archive.apache.org (no borra versiones) y Spark desde dlcdn (el CDN rápido)
if [ ! -d ~/hadoop-ansible-ec2 ]; then
  git clone -q https://github.com/memaldi/hadoop-ansible-ec2 ~/hadoop-ansible-ec2
fi
sed -i -E -e 's|https://dlcdn.apache.org/hadoop/common/|https://archive.apache.org/dist/hadoop/common/|' \
          -e 's|https://archive.apache.org/dist/spark/|https://dlcdn.apache.org/spark/|' \
          -e "s|spark-3\.5\.[0-9]+|spark-$SPARK_VERSION|g" ~/hadoop-ansible-ec2/create-instances.yml

# Entorno de Python con Ansible
if [ ! -x ~/ansible/bin/ansible-playbook ]; then
  python3 -m venv ~/ansible
  ~/ansible/bin/pip install -q -r ~/hadoop-ansible-ec2/requirements.txt
fi
