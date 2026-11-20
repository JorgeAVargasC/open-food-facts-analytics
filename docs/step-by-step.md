# Paso a paso, desde cero

Ejecución completa del 20/11/2026: clúster nuevo, carga, limpieza y preguntas. Resumen en el [README](../README.md).

## 0. Preparar tu equipo

Learner Lab → **Start Lab** → AWS Details → AWS CLI **Show** → pegar en `~/.aws/credentials` (cambian en cada sesión).

![Credenciales del Learner Lab](assets/learner-lab-credentials.png)
![~/.aws/credentials](assets/aws-credentials-file.png)

## 1. Levantar el clúster (tu equipo)

```bash
./up.sh
```

Llama uno a uno a `cluster/01…09`. Ansible (paso 02) es lo más largo; no interrumpirlo:

![Ansible creando el master y los workers](assets/up-ansible-running.png)

Al terminar, 6 instancias `running` con los status checks en verde:

![6 instancias en EC2](assets/steps/01-ec2-instances.png)

`./nodes.sh` da el SSH de cada nodo (el DNS cambia en cada arranque). Los workers solo son accesibles desde el master:

![nodes.sh](assets/steps/06-nodes-sh.png)

### Comprobar en las webs (`./tunnels.sh`)

HDFS: 3 DataNodes vivos.

![HDFS Datanodes](assets/steps/02-hdfs-datanodes.png)

HDFS: `/data` de `ingest`, `/results` de `query`, `/user` de `ec2-user` (paso 07).

![HDFS /](assets/steps/03-hdfs-root.png)

YARN: 3 NodeManagers de 6 GB → 18 GB y 6 vCores en total (paso 06).

![YARN nodes](assets/steps/04-yarn-nodes.png)

YARN: el SparkPi del paso 09, lanzado desde un cliente, `SUCCEEDED`.

![SparkPi](assets/steps/05-yarn-sparkpi.png)

## 2. Cargar los datos (cliente ingest)

```bash
curl -sL https://static.openfoodfacts.org/data/en.openfoodfacts.org.products.csv.gz \
  | gunzip | hdfs dfs -put -f - /data/raw/openfoodfacts.csv
hdfs dfs -cat /data/raw/openfoodfacts.csv \
  | awk 'NR == 1 || rand() < 0.02' | hdfs dfs -put -f - /data/raw/sample.csv
hdfs dfs -ls -h /data/raw
```

Mientras sube, HDFS muestra el archivo como `._COPYING_` y va creciendo (~3 min para 13 GB):

![Subiendo 3.88 GB](assets/steps/07-load-copying-1.png)
![Subiendo 5.75 GB](assets/steps/08-load-copying-2.png)
![CSV completo: 13.06 GB](assets/steps/09-load-csv-done.png)

Después, la muestra del 2 %:

![Muestra subiendo](assets/steps/10-load-sample-copying.png)
![Muestra: 269.54 MB](assets/steps/11-load-sample-done.png)

En la terminal: dueño `ingest`, replicación 3.

![Carga en la terminal](assets/steps/12-load-terminal.png)

## 3. Limpiar (cliente ingest)

El cliente tiene Hadoop, Spark 3.5.9 y el código copiado por `push.sh`:

![Home del cliente ingest](assets/steps/13-ingest-client-home.png)

Primero la muestra:

```bash
cd open-food-facts-analytics
spark-submit ingest/clean-products.py hdfs:///data/raw/sample.csv
```

![spark-submit con la muestra](assets/steps/14-clean-sample-submit.png)

En YARN, `clean-products` de `ingest` en `RUNNING`, usando 13 GB y 4 vCores: 3 executors × 4 GB (3 GB + 512 MB de overhead, redondeado) + 1 GB del application master. Es el 72 % del clúster: por eso limpieza y preguntas nunca a la vez. En modo client, el progreso de YARN se queda en 10 % hasta el final.

![YARN: limpieza en ejecución](assets/steps/15-yarn-clean-running.png)
![YARN: 72 % del clúster](assets/steps/16-yarn-clean-resources.png)

Resultado de la muestra: 99 289 productos, 3 816 incoherentes.

![Salida de la muestra](assets/steps/17-clean-sample-output.png)

Después, el CSV completo en segundo plano:

```bash
nohup spark-submit ingest/clean-products.py > clean.out 2>&1 &
tail -f clean.out
```

![nohup](assets/steps/18-clean-full-nohup.png)
![YARN: limpieza completa en ejecución](assets/steps/19-yarn-clean-full-running.png)

Resultado (2 min 28 s): 4 922 927 filas → 4 922 870 productos (57 duplicados), 189 753 incoherentes.

![Salida de la limpieza completa](assets/steps/20-clean-full-output.png)

13 GB de CSV → 118,6 MB de Parquet (355,8 MB con las 3 réplicas):

![du del Parquet](assets/steps/21-clean-full-du.png)
![Parquet en HDFS](assets/steps/22-hdfs-clean-products.png)

## 4. Preguntas (cliente query)

Una pregunta paso a paso (la 5):

```bash
cd open-food-facts-analytics
spark-submit query/q05-brands-by-pnns-group.py
```

![spark-submit q05](assets/steps/23-q05-submit.png)
![YARN: q05 de query](assets/steps/24-yarn-q05.png)

Imprime la base (924 329 productos) y el ranking de dulces:

![Salida de q05](assets/steps/25-q05-output.png)

Comprobar el resultado en HDFS:

```bash
hdfs dfs -cat /results/q05-brands-by-pnns-group/part-*.csv | head
```

![CSV de q05](assets/steps/26-q05-csv-head.png)
![q05 en HDFS](assets/steps/27-hdfs-q05.png)

Las otras tres, igual cambiando el archivo. Al final, todo `SUCCEEDED`, cada job con su usuario:

![YARN: todos los jobs](assets/steps/28-yarn-all-finished.png)
![/results con las 4 preguntas](assets/steps/29-hdfs-results.png)

| Job | Usuario | Duración |
|---|---|---|
| clean-products (muestra) | ingest | 43 s |
| clean-products (13 GB) | ingest | 2 min 28 s |
| q05 · q06 · q07 · q08 | query | 46 s · 37 s · 39 s · 37 s |

## 5. Resultados y apagar (tu equipo)

```bash
./pull.sh                  # HDFS → results/*.csv
python3 plot-results.py    # results/*.png
./stop.sh                  # o ./down.sh para borrar
```
