# Lo que comparten los scripts: versiones, clave, opciones de SSH, nodos y atajos.
# Deja el directorio de trabajo en la raíz del repo.
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source cluster/versions.sh

KEY=~/.ssh/vockey.pem
SSH_OPTS="-i $KEY -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ServerAliveInterval=30"
NODES="hadoop-master,hadoop-worker-1,hadoop-worker-2,hadoop-worker-3,hadoop-client-ingest,hadoop-client-query"
EXISTING="pending,running,stopping,stopped"

# IDs de instancias por nombre y estado. Ej.: ids hadoop-master running
ids() {
  aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=$1" "Name=instance-state-name,Values=$2" \
    --query "Reservations[].Instances[].InstanceId" --output text
}

# Un dato de una instancia encendida. Ej.: info hadoop-master PublicDnsName
info() {
  aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=$1" "Name=instance-state-name,Values=running" \
    --query "Reservations[0].Instances[0].$2" --output text
}

# Ejecutar en el master o en un cliente. Ej.: on_master "hostname"   on_client ingest "hostname"
on_master() {
  ssh $SSH_OPTS ec2-user@"$(info hadoop-master PublicDnsName)" "$@"
}
on_client() {
  local role=$1
  shift
  ssh $SSH_OPTS ec2-user@"$(info hadoop-client-$role PublicDnsName)" "$@"
}
