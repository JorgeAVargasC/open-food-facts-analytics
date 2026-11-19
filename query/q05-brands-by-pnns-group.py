"""P5: en cada grupo PNNS, las 5 marcas con la media más baja y más alta de azúcar, grasa saturada y sal."""
from functools import reduce

from pyspark.sql import SparkSession, Window
from pyspark.sql import functions as F

MIN_PRODUCTS = 20   # productos de la marca dentro del grupo; con 20, todos los grupos tienen 10 marcas o más
TOP = 5
NUTRIENTS = ["sugars_100g", "saturated_fat_100g", "salt_100g"]

spark = SparkSession.builder.appName("off-q05").getOrCreate()
df = spark.read.parquet("hdfs:///data/clean/products")

# Productos con grupo, marca y los tres nutrientes, sin incoherencias
base = df.where(F.col("pnns_group").isNotNull() & F.col("brands").isNotNull() & ~F.col("nutrients_inconsistent"))
for n in NUTRIENTS:
    base = base.where(F.col(n).isNotNull())

# Media de cada nutriente por grupo y marca. Un producto con varias marcas cuenta en cada una (explode)
by_brand = (base.select("pnns_group", F.explode("brands").alias("brand"), *NUTRIENTS)
                .groupBy("pnns_group", "brand")
                .agg(F.count("*").alias("products"), *[F.avg(n).alias(n) for n in NUTRIENTS])
                .where(F.col("products") >= MIN_PRODUCTS))

# Un ranking por nutriente y sentido: numerar las marcas dentro de cada grupo y quedarse con las 5 primeras.
# Empates: más productos primero y después por nombre, para que el resultado no cambie entre ejecuciones
rankings = []
for n in NUTRIENTS:
    for kind, order in [("best", F.asc(n)), ("worst", F.desc(n))]:
        w = Window.partitionBy("pnns_group").orderBy(order, F.desc("products"), "brand")
        rankings.append(by_brand.withColumn("rank", F.row_number().over(w))
                                .where(F.col("rank") <= TOP)
                                .select("pnns_group", F.lit(n).alias("nutrient"), F.lit(kind).alias("kind"),
                                        "rank", "brand", "products", F.round(n, 3).alias("avg_100g")))
result = reduce(lambda a, b: a.unionByName(b), rankings).orderBy("pnns_group", "nutrient", "kind", "rank")

# Mostrar y guardar en un CSV
print("Productos en la base:", base.count())
result.where(F.col("pnns_group") == "Sugary snacks").show(30, truncate=False)
result.coalesce(1).write.mode("overwrite").option("header", True).csv("hdfs:///results/q05-brands-by-pnns-group")

spark.stop()
