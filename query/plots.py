"""Gráficas de las preguntas. Uso, en el cliente query:
hdfs dfs -get -f /results ./results && python3 query/plots.py
"""
import glob
import os

import matplotlib
matplotlib.use("Agg")  # sin pantalla: solo guarda los PNG
import matplotlib.pyplot as plt
import pandas as pd

RESULTS = "results"
FIGURES = "figures"
os.makedirs(FIGURES, exist_ok=True)


def read(name):
    """El CSV que dejó Spark en results/<name>/part-*.csv"""
    return pd.read_csv(glob.glob(f"{RESULTS}/{name}/part-*.csv")[0])


def save(name):
    plt.tight_layout()
    plt.savefig(f"{FIGURES}/{name}.png", dpi=120)
    plt.close()
    print("Guardada", f"{FIGURES}/{name}.png")


# P5: un panel por nutriente, en el grupo donde ese nutriente pesa más
q5 = read("q05-brands-by-pnns-group")
panels = [("sugars_100g", "Sugary snacks", "Azúcar"),
          ("saturated_fat_100g", "Milk and dairy products", "Grasa saturada"),
          ("salt_100g", "Salty snacks", "Sal")]
fig, axes = plt.subplots(1, 3, figsize=(15, 5))
for ax, (nutrient, group, title) in zip(axes, panels):
    d = q5[(q5.nutrient == nutrient) & (q5.pnns_group == group)].sort_values("avg_100g")
    colors = ["#2e8b57" if k == "best" else "#c0392b" for k in d.kind]
    ax.barh(d.brand, d.avg_100g, color=colors)
    ax.invert_yaxis()
    ax.set_title(f"{title} · {group}")
    ax.set_xlabel("g por 100 g (media de la marca)")
fig.suptitle("P5 · Marcas con la media más baja (verde) y más alta (rojo)")
save("q05-brands-by-pnns-group")

# P6: barras con los productos añadidos por año y línea con el % que tiene energía y los tres macronutrientes
q6 = read("q06-yearly-data-quality")
fig, ax = plt.subplots(figsize=(11, 5))
ax.bar(q6.created_year.astype(str), q6.products / 1000, color="#c9ced6")
ax.set_xlabel("Año de alta (el último, incompleto)")
ax.set_ylabel("Productos añadidos (miles)")
ax2 = ax.twinx()
ax2.plot(q6.created_year.astype(str), q6.pct_all_four, color="black", marker="o")
ax2.set_ylim(0, 100)
ax2.set_ylabel("% con energía, grasa, carbohidratos y proteínas")
ax.set_title("P6 · Productos añadidos por año y % con los datos nutricionales básicos")
save("q06-yearly-data-quality")

# P7: los 30 países con más productos, ordenados por % de incoherentes
q7 = read("q07-energy-coherence-by-country").head(30).sort_values("pct_inconsistent")
fig, ax = plt.subplots(figsize=(9, 8))
ax.barh(q7.country, q7.pct_inconsistent, color="#b5651d")
ax.set_xlabel("% de productos con la energía declarada a más del 20 % (y 10 kcal) de la calculada")
ax.set_title("P7 · Energía declarada frente a calculada (30 países con más productos)")
save("q07-energy-coherence-by-country")

# P8: un panel por nutriente; barra oscura = alto contenido, barra completa = fuente o más
q8 = read("q08-protein-fiber-claims")
fig, axes = plt.subplots(1, 2, figsize=(14, 6))
for ax, nutrient, title in zip(axes, ["protein", "fiber"], ["Proteínas", "Fibra"]):
    d = q8.sort_values(f"pct_{nutrient}_source_or_high")
    ax.barh(d.pnns_group, d[f"pct_{nutrient}_source_or_high"], color="#8fbcd4", label="Fuente o más")
    ax.barh(d.pnns_group, d[f"pct_{nutrient}_high"], color="#1f5f8b", label="Alto contenido")
    ax.set_xlim(0, 100)
    ax.set_xlabel("% de productos con el dato")
    ax.set_title(title)
    ax.legend(frameon=False, loc="lower right")
fig.suptitle("P8 · Productos que cumplen las alegaciones del Reglamento UE 1924/2006, por grupo PNNS")
save("q08-protein-fiber-claims")
