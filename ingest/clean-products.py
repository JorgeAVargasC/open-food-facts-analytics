"""Limpieza: CSV en bruto a Parquet limpio. Uso: spark-submit ingest/clean-products.py [hdfs:///data/raw/sample.csv]"""

import sys

from pyspark.sql import SparkSession, Window
from pyspark.sql import functions as F

INPUT = sys.argv[1] if len(sys.argv) > 1 else "hdfs:///data/raw/openfoodfacts.csv"
OUTPUT = "hdfs:///data/clean/products"

spark = SparkSession.builder.appName("clean-products").getOrCreate()
spark.conf.set("spark.sql.session.timeZone", "UTC")  # años de alta en UTC

# Leer el CSV (tabuladores, todo texto, sin comillas)
raw = spark.read.csv(INPUT, sep="\t", header=True, quote="")


def col(name):
    """Columna por nombre; las comillas invertidas permiten guiones (energy-kcal_100g)"""
    return F.col(f"`{name}`")


def tag_list(name):
    """'en:france,en:spain' -> ['france', 'spain']; vacío -> nulo"""
    tags = F.split(F.regexp_replace(F.lower(col(name)), "(^|,)[a-z]{2}:", "$1"), ",")
    tags = F.array_distinct(F.filter(tags, lambda t: t != ""))
    return F.when(F.size(tags) > 0, tags)


def number(name, low, high):
    """Número entre low y high; si no, nulo"""
    x = col(name).cast("double")
    return F.when(x.between(low, high), x)


# Un producto = un código: quedarse con la versión modificada más recientemente
latest = Window.partitionBy("code").orderBy(col("last_modified_t").cast("long").desc())
products = (raw.where(col("code").isNotNull())
               .withColumn("rn", F.row_number().over(latest))
               .where("rn = 1"))

# Columnas limpias
clean = products.select(
    col("code"),
    F.year(F.from_unixtime(col("created_t").cast("long"))).alias("created_year"),  # fecha Unix a año
    F.when(~col("pnns_groups_1").isin("unknown", ""), col("pnns_groups_1")).alias("pnns_group"),
    F.array_remove(tag_list("countries_tags"), "world").alias("countries"),  # 'world' no es un país
    tag_list("brands_tags").alias("brands"),
    number("energy-kcal_100g", 0, 900).alias("energy_kcal_100g"),
    number("fat_100g", 0, 100).alias("fat_100g"),
    number("saturated-fat_100g", 0, 100).alias("saturated_fat_100g"),
    number("carbohydrates_100g", 0, 100).alias("carbohydrates_100g"),
    number("sugars_100g", 0, 100).alias("sugars_100g"),
    number("fiber_100g", 0, 100).alias("fiber_100g"),
    number("proteins_100g", 0, 100).alias("proteins_100g"),
    number("salt_100g", 0, 100).alias("salt_100g"),
    col("data_quality_errors_tags").isNotNull().alias("off_error"),  # Open Food Facts marcó un error
)

# Incoherente: saturada > grasa, azúcar > carbohidratos, macros > 105 g o error marcado por Open Food Facts.
# No se borra: cada pregunta decide si la excluye
inconsistent = (
    F.coalesce(F.col("saturated_fat_100g") > F.col("fat_100g"), F.lit(False))
    | F.coalesce(F.col("sugars_100g") > F.col("carbohydrates_100g"), F.lit(False))
    | F.coalesce(F.col("fat_100g") + F.col("carbohydrates_100g") + F.col("proteins_100g") > 105, F.lit(False))
    | F.col("off_error")
)
clean = clean.withColumn("nutrients_inconsistent", inconsistent).drop("off_error")

# Guardar en Parquet
clean.write.mode("overwrite").parquet(OUTPUT)

# Comprobar: filas y datos no nulos por columna
clean = spark.read.parquet(OUTPUT)
print("Filas del CSV:      ", raw.count())
print("Productos limpios:  ", clean.count())
print("Incoherentes:       ", clean.where("nutrients_inconsistent").count())
clean.select([F.count(c).alias(c) for c in clean.columns]).show(vertical=True)

spark.stop()
