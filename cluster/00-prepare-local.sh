#!/usr/bin/env bash
# Paso 0 (local, una sola vez): crea el entorno de Ansible, clona el playbook e instala AWS CLI.
# Uso: ./cluster/00-prepare-local.sh
set -euo pipefail

# Comprobar que la clave ya está donde la espera el playbook
if [ ! -f ~/.ssh/vockey.pem ]; then
  echo "Falta ~/.ssh/vockey.pem: cp ~/Downloads/labsuser.pem ~/.ssh/vockey.pem && chmod og-rwx ~/.ssh/vockey.pem"
  exit 1
fi

# Entorno de Ansible con el playbook de clase
python3 -m venv ~/ansible
source ~/ansible/bin/activate
[ -d ~/hadoop-ansible-ec2 ] || git clone https://github.com/memaldi/hadoop-ansible-ec2 ~/hadoop-ansible-ec2
pip install -r ~/hadoop-ansible-ec2/requirements.txt

# AWS CLI para nuestros scripts (versión compatible con el playbook)
pip install awscli==1.29.36

echo
echo "Falta: pegar las credenciales del Learner Lab en ~/.aws/credentials"
echo "Siguiente: ./cluster/01-create-cluster.sh"
