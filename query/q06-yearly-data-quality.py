"""P6: productos añadidos por año, % con energía y macronutrientes y crecimiento respecto al año anterior."""

from pyspark.sql import SparkSession, Window
from pyspark.sql import functions as F

NUTRIENTS = ["energy_kcal_100g", "fat_100g", "carbohydrates_100g", "proteins_100g"]

spark = SparkSession.builder.appName("q06-yearly-data-quality").getOrCreate()
df = spark.read.parquet("hdfs:///data/clean/products")


def pct(condition):
    """% de filas del grupo que cumplen la condición"""
    return F.round(100 * F.avg(condition.cast("int")), 1)


# Cuentan también las incoherentes: se mide si el dato está, no si es correcto
all_four = F.col(NUTRIENTS[0]).isNotNull()
for n in NUTRIENTS[1:]:
    all_four = all_four & F.col(n).isNotNull()

by_year = (
    df.where(F.col("created_year").isNotNull())
    .groupBy("created_year")
    .agg(
        F.count("*").alias("products"),
        *[pct(F.col(n).isNotNull()).alias(f"pct_{n}") for n in NUTRIENTS],
        pct(all_four).alias("pct_all_four"),
    )
)

# Crecimiento: lag trae los productos del año anterior. La ventana no tiene partición
# porque la tabla ya está agregada (una fila por año, unas 15 filas)
w = Window.orderBy("created_year")
last_year = by_year.agg(F.max("created_year")).first()[0]
result = (
    by_year.withColumn("previous_products", F.lag("products").over(w))
    .withColumn(
        "growth_pct",
        F.round(100 * (F.col("products") / F.col("previous_products") - 1), 1),
    )
    .withColumn(
        "complete_year", F.col("created_year") != last_year
    )  # el último año va a medias
    .orderBy("created_year")
)

# Mostrar y guardar en un CSV
result.show(30, truncate=False)
result.coalesce(1).write.mode("overwrite").option("header", True).csv(
    "hdfs:///results/q06-yearly-data-quality"
)

spark.stop()
