#!/usr/bin/env bash
# Paso 7 (master): copia el proyecto al client y ejecuta allí la instalación de Spark.
# Uso: ./cluster/07-setup-client.sh
set -euo pipefail

# Borrar la copia anterior del proyecto en el client
ssh hadoop-client "rm -rf open-food-facts-analytics"

# Copiar el proyecto al client
scp -r -q ~/open-food-facts-analytics hadoop-client:

# Instalar y configurar Spark en el client
ssh hadoop-client "bash open-food-facts-analytics/cluster/client-install-spark.sh"

echo
echo "Siguiente, si el CSV aún no está en HDFS: ./cluster/08-upload-data.sh"
