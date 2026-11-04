#!/usr/bin/env bash
# Paso 3 (local): crea la instancia hadoop-client, la que lanza los trabajos de Spark.
# Uso: ./cluster/03-create-client.sh
set -euo pipefail
cd "$(dirname "$0")"
source env.sh

# Buscar si ya existe un client, encendido o apagado
CLIENT_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=hadoop-client" \
            "Name=instance-state-name,Values=pending,running,stopping,stopped" \
  --query "Reservations[].Instances[].InstanceId" \
  --output text)

# Si existe, no crear otro
if [ -n "$CLIENT_ID" ]; then
  echo "Ya existe hadoop-client ($CLIENT_ID)."
  exit 1
fi

# Crear la instancia con la misma AMI (Amazon Linux 2023), clave y grupos que el resto
CLIENT_ID=$(aws ec2 run-instances \
  --image-id ami-066784287e358dad1 \
  --instance-type t2.large \
  --key-name vockey \
  --security-groups hadoop-sg hadoop-master-sg \
  --block-device-mappings "DeviceName=/dev/xvda,Ebs={VolumeSize=50,DeleteOnTermination=true}" \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=hadoop-client},{Key=Group,Value=hadoop-client}]" \
  --query "Instances[0].InstanceId" \
  --output text)

# Esperar a que arranque y acepte SSH (2 a 3 minutos)
echo "Creado $CLIENT_ID. Esperando a que esté listo..."
aws ec2 wait instance-status-ok --instance-ids "$CLIENT_ID"

# Guardar su IP privada para añadirla a /etc/hosts en el paso 5
instance_info hadoop-client PrivateIpAddress > client-ip.txt
echo "IP privada del client: $(cat client-ip.txt)"

echo
echo "Siguiente: ./cluster/04-copy-to-master.sh"
