"""P7: % de productos cuya energía declarada se aleja de la calculada (4·carbohidratos + 4·proteínas + 9·grasa), por país."""
from pyspark.sql import SparkSession
from pyspark.sql import functions as F

MAX_DIFF = 0.20       # diferencia máxima: 20 % de la energía declarada
MIN_DIFF_KCAL = 10    # y al menos 10 kcal, para no marcar agua o refrescos zero por 1 o 2 kcal
MIN_PRODUCTS = 1000   # países con menos productos no entran

spark = SparkSession.builder.appName("q07-energy-coherence-by-country").getOrCreate()
df = spark.read.parquet("hdfs:///data/clean/products")

# Productos con energía (> 0) y los tres macronutrientes.
# No se quitan las filas marcadas como incoherentes: casi todas lo son por la energía, que es lo que se mide
base = df.where(F.col("energy_kcal_100g").isNotNull() & (F.col("energy_kcal_100g") > 0)
                & F.col("carbohydrates_100g").isNotNull() & F.col("proteins_100g").isNotNull()
                & F.col("fat_100g").isNotNull())

# Energía calculada y diferencia con la declarada
computed = 4 * F.col("carbohydrates_100g") + 4 * F.col("proteins_100g") + 9 * F.col("fat_100g")
diff = F.abs(F.col("energy_kcal_100g") - computed)
base = base.withColumn("inconsistent", (diff > MAX_DIFF * F.col("energy_kcal_100g")) & (diff > MIN_DIFF_KCAL))

# % global: cada producto una sola vez, antes de repartirlo por países
total = base.agg(F.round(100 * F.avg(F.col("inconsistent").cast("int")), 1)).first()[0]
print(f"Productos en la base: {base.count()} · incoherentes en total: {total} %")

# Por país: un producto cuenta en cada país donde se vende (explode)
result = (base.select(F.explode("countries").alias("country"), "inconsistent")
              .groupBy("country")
              .agg(F.count("*").alias("products"),
                   F.sum(F.col("inconsistent").cast("int")).alias("inconsistent_products"))
              .where(F.col("products") >= MIN_PRODUCTS)
              .withColumn("pct_inconsistent", F.round(100 * F.col("inconsistent_products") / F.col("products"), 1))
              .orderBy(F.desc("products")))

# Mostrar y guardar en un CSV
result.show(30, truncate=False)
result.coalesce(1).write.mode("overwrite").option("header", True).csv("hdfs:///results/q07-energy-coherence-by-country")

spark.stop()
