#!/usr/bin/env bash
# Variables comunes de los scripts que se ejecutan en tu equipo (WSL o Mac). Se carga con source, no se ejecuta solo.

# Activar el entorno con aws y ansible (lo crea el paso 0)
source ~/ansible/bin/activate

# Región del Learner Lab
export AWS_DEFAULT_REGION=us-east-1

# Clave para entrar en las instancias
KEY=~/.ssh/vockey.pem

# Opciones de ssh/scp: usar la clave y no preguntar por la huella del servidor
SSH_OPTS="-i $KEY -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR"

# Dato de una instancia encendida por su nombre. Ejemplo: instance_info hadoop-master PublicDnsName
instance_info() {
  aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=$1" \
              "Name=instance-state-name,Values=running" \
    --query "Reservations[0].Instances[0].$2" \
    --output text
}
