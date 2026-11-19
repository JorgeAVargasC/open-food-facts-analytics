#!/usr/bin/env bash
# Paso 3: crear los clientes ingest y query (si no existen), con la misma AMI que el master.
set -euo pipefail
source "$(dirname "$0")/common.sh"
echo "== 3. Clientes"

create_client() {
  if [ -n "$(ids hadoop-client-$1 $EXISTING)" ]; then
    echo "hadoop-client-$1 ya existe"
    return
  fi
  aws ec2 run-instances \
    --image-id "$(info hadoop-master ImageId)" --instance-type t2.large --key-name vockey \
    --security-groups hadoop-sg hadoop-master-sg \
    --block-device-mappings "DeviceName=/dev/xvda,Ebs={VolumeSize=50,DeleteOnTermination=true}" \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=hadoop-client-$1},{Key=Group,Value=hadoop-client}]" \
    > /dev/null
  echo "hadoop-client-$1 creado"
}

# SSH abierto a cualquier IP en el grupo del master y los clientes
aws ec2 authorize-security-group-ingress --group-name hadoop-master-sg \
  --protocol tcp --port 22 --cidr 0.0.0.0/0 > /dev/null 2>&1 || true
create_client ingest
create_client query
