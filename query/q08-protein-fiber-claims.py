"""P8: % de productos que cumplen 'fuente de' y 'alto contenido de' proteínas y fibra (Reglamento UE 1924/2006), por grupo PNNS."""
from pyspark.sql import SparkSession
from pyspark.sql import functions as F

spark = SparkSession.builder.appName("off-q08").getOrCreate()
df = spark.read.parquet("hdfs:///data/clean/products").where(~F.col("nutrients_inconsistent"))

energy = F.col("energy_kcal_100g")
fiber = F.col("fiber_100g")
has_energy = energy.isNotNull() & (energy > 0)

# Proteínas: % de la energía que aportan (4 kcal por gramo). Fuente: >= 12 %. Alto: >= 20 %.
# Si pasa del 100 % el dato es imposible y el producto no entra
protein_share = 4 * F.col("proteins_100g") / energy
protein_level = (F.when(~has_energy | F.col("proteins_100g").isNull() | (protein_share > 1), None)
                  .when(protein_share >= 0.20, "high")
                  .when(protein_share >= 0.12, "source")
                  .otherwise("none"))

# Fibra. Fuente: >= 3 g/100 g o >= 1,5 g/100 kcal. Alto: >= 6 g/100 g o >= 3 g/100 kcal
fiber_per_100kcal = 100 * fiber / energy
fiber_level = (F.when(fiber.isNull(), None)
                .when((fiber >= 6) | (has_energy & (fiber_per_100kcal >= 3)), "high")
                .when((fiber >= 3) | (has_energy & (fiber_per_100kcal >= 1.5)), "source")
                .otherwise("none"))

levels = df.select("pnns_group", protein_level.alias("protein"), fiber_level.alias("fiber"))


def summary(nutrient):
    """Base (productos con el dato) y % 'fuente o más' y 'alto' de un nutriente"""
    base = F.count(nutrient)   # count no cuenta los nulos
    return [base.alias(f"{nutrient}_base"),
            F.round(100 * F.sum(F.col(nutrient).isin("source", "high").cast("int")) / base, 1).alias(f"pct_{nutrient}_source_or_high"),
            F.round(100 * F.sum((F.col(nutrient) == "high").cast("int")) / base, 1).alias(f"pct_{nutrient}_high")]


# Total y por grupo
levels.agg(*summary("protein"), *summary("fiber")).show(vertical=True)
result = (levels.where(F.col("pnns_group").isNotNull())
                .groupBy("pnns_group")
                .agg(*summary("protein"), *summary("fiber"))
                .orderBy("pnns_group"))

# Mostrar y guardar en un CSV
result.show(truncate=False)
result.coalesce(1).write.mode("overwrite").option("header", True).csv("hdfs:///results/q08-protein-fiber-claims")

spark.stop()
