#!/usr/bin/env bash
# Copiar el código a los clientes: ingest/ al de ingesta y query/ al de consulta.
# No borra nada de lo que haya en el cliente. Repetirlo cada vez que cambies código.
set -euo pipefail
source "$(dirname "$0")/cluster/common.sh"

tar -cf - ingest | on_client ingest "mkdir -p open-food-facts-analytics && tar -C open-food-facts-analytics -xf -"
tar -cf - query | on_client query "mkdir -p open-food-facts-analytics && tar -C open-food-facts-analytics -xf -"
echo "Código copiado: ingest/ al cliente ingest, query/ al cliente query"
