#!/usr/bin/env bash
# Levanta todo el clúster. Se puede relanzar: se salta lo ya hecho.
set -euo pipefail
cd "$(dirname "$0")"

KEY=~/.ssh/vockey.pem
OPTS="-i $KEY -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ServerAliveInterval=30"
CLIENTS="ingest query"
NODES="hadoop-master,hadoop-worker-1,hadoop-worker-2,hadoop-worker-3,hadoop-client-ingest,hadoop-client-query"
EXISTING="pending,running,stopping,stopped"

# IDs de las instancias por nombre y estado
ids() {
  aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=$1" "Name=instance-state-name,Values=$2" \
    --query "Reservations[].Instances[].InstanceId" --output text
}

# Un dato de una instancia encendida
info() {
  aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=$1" "Name=instance-state-name,Values=running" \
    --query "Reservations[0].Instances[0].$2" --output text
}

# Comprobar clave y credenciales
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

echo "== 1. Ansible"
if [ ! -x ~/ansible/bin/ansible-playbook ]; then
  python3 -m venv ~/ansible
  [ -d ~/hadoop-ansible-ec2 ] || git clone -q https://github.com/memaldi/hadoop-ansible-ec2 ~/hadoop-ansible-ec2
  ~/ansible/bin/pip install -q -r ~/hadoop-ansible-ec2/requirements.txt
fi

echo "== 2. Master y workers"
# Solo si no hay master: el playbook formatea HDFS
if [ -z "$(ids hadoop-master $EXISTING)" ]; then
  export ANSIBLE_SSH_ARGS="-o ServerAliveInterval=30 -o ControlMaster=auto -o ControlPersist=60s"   # que no se corte el SSH
  source ~/ansible/bin/activate
  (cd ~/hadoop-ansible-ec2 && ansible-playbook -i inventory.aws_ec2.yml --key-file $KEY --user ec2-user create-instances.yml)
fi

echo "== 3. SSH y clientes (ingest y query)"
aws ec2 authorize-security-group-ingress --group-name hadoop-master-sg \
  --protocol tcp --port 22 --cidr 0.0.0.0/0 > /dev/null 2>&1 || true   # SSH abierto a cualquier IP
for role in $CLIENTS; do
  if [ -z "$(ids hadoop-client-$role $EXISTING)" ]; then
    # Misma AMI que el master: mismo Java y mismo Python que en los workers
    aws ec2 run-instances \
      --image-id "$(info hadoop-master ImageId)" --instance-type t2.large --key-name vockey \
      --security-groups hadoop-sg hadoop-master-sg \
      --block-device-mappings "DeviceName=/dev/xvda,Ebs={VolumeSize=50,DeleteOnTermination=true}" \
      --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=hadoop-client-$role},{Key=Group,Value=hadoop-client}]" \
      > /dev/null
  fi
done

# Encender lo apagado y esperar a que todo acepte SSH
stopped=$(ids "$NODES" stopped)
[ -z "$stopped" ] || aws ec2 start-instances --instance-ids $stopped > /dev/null
echo "Esperando a que las 6 instancias estén listas..."
aws ec2 wait instance-status-ok --instance-ids $(ids "$NODES" pending,running)

echo "== 4. Configuración"
dns=$(info hadoop-master PublicDnsName)
master="ssh $OPTS ec2-user@$dns"
$master "rm -rf open-food-facts-analytics && mkdir open-food-facts-analytics"
tar -cf - run.sh cluster ingest query | $master "tar -C open-food-facts-analytics -xf -"

# IPs privadas de los clientes, para el /etc/hosts del master
for role in $CLIENTS; do
  echo "$(info hadoop-client-$role PrivateIpAddress)  hadoop-client-$role"
done | $master "cat > open-food-facts-analytics/clients-hosts.txt"

scp $OPTS -q $KEY ec2-user@"$dns":.ssh/vockey.pem   # el master entra en los demás nodos con ella
$master "cd open-food-facts-analytics && ./cluster/master.sh setup"

echo "== 5. Datos en HDFS (desde el cliente ingest)"
$master "ssh hadoop-client-ingest 'bash open-food-facts-analytics/ingest/load.sh'"

echo
echo "Listo. El DNS del master cambia en cada arranque."
echo "Master:  ssh -i $KEY ec2-user@$dns"
echo "HDFS:    ssh -i $KEY -N -L 50070:$dns:50070 ec2-user@$dns   -> http://localhost:50070"
echo "YARN:    ssh -i $KEY -N -L 8088:$dns:8088 ec2-user@$dns   -> http://localhost:8088/cluster/nodes"
echo "Clientes: desde el master, ssh hadoop-client-ingest o ssh hadoop-client-query"
