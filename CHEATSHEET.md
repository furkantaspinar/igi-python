# SAS → Python Cheatsheet für Migrationen

Dieses Cheatsheet ist für SAS-Programmierer:innen gedacht, die bestehende SAS-Skripte nach Python migrieren.

---

## 0. Setup & Grundregeln


```python
# Python Library imports, e.g.
import pandas as pd
import numpy as np

...
```

---

## 1. Makrovariablen / Konstanten

| SAS | Python |
|---|---|
| `%let _pagsakt = 2025;` | `PAGS_AKT = 2025` |
| `schema=variablen&_pagsakt.` | `schema_var = f"variablen{PAGS_AKT}"` |

```python
PAGS_AKT = 2025
schema_var = f"variablen{PAGS_AKT}"
```

---

## 2. Daten aus PostgreSQL laden

### Ganze Tabelle mit ausgewählten Spalten laden

| SAS | Python |
|---|---|
| `set pg_prod.ags8 (schema=variablen2025 keep=ags8 gemeindename);` | `pd.read_sql_table("ags8", engine, schema="variablen2025", columns=["ags8", "gemeindename"])` |

```python
gem1 = pd.read_sql_table(
    "ags8",
    con=engine,
    schema=schema_var,
    columns=["ags8", "gemeindename"],
)
```

### Tabellen via SQL-Query laden

```python
lage = pd.read_sql_query(
    
    text(
      "SELECT ags27, casa_dist_bhf, casa_dist_bush, casa_dist_ustrab
      FROM staging.casa_dist_opnv
      WHERE ags27 IS NOT NULL"
      ),
    con=engine,
)
```

---

## 3. Keep, Drop, Rename

| SAS | Python |
|---|---|
| `keep=ags8 gemeindename` | `df[["ags8", "gemeindename"]]` |
| `drop=job_title` | `df.drop(columns=["job_title"])` |
| `rename=(gemeindename=gem_name)` | `df.rename(columns={"gemeindename": "gem_name"})` |

```python
# keep
new = old[["ags8", "gemeindename"]].copy()

# drop
new = old.drop(columns=["job_title"])

# rename
new = old.rename(columns={"gemeindename": "gem_name"})
```

---

## 4. Filtern von Zeilen

| SAS | Python |
|---|---|
| `if year in (2010, 2011, 2012);` | `df[df["year"].isin([2010, 2011, 2012])]` |
| `if dob > "25APR1990"d;` | `df[df["dob"] > pd.Timestamp("1990-04-25")]` |
| `if x ne .;` | `df[df["x"].notna()]` |
| `if x = .;` | `df[df["x"].isna()]` |

```python
filtered = df.loc[df["year"].isin([2010, 2011, 2012])].copy()

# Datum vorher sauber konvertieren
df["dob"] = pd.to_datetime(df["dob"])
filtered = df.loc[df["dob"] > pd.Timestamp("1990-04-25")].copy()
```

**Tipp:** Nach dem Filtern oft `.copy()` verwenden, damit spätere Zuweisungen keine `SettingWithCopyWarning` auslösen.

---

## 5. Werte ändern / neue Spalten erzeugen

### Einfache Berechnung

| SAS | Python |
|---|---|
| `total_income = wages + benefits;` | `df["total_income"] = df["wages"] + df["benefits"]` |

```python
df["total_income"] = df["wages"] + df["benefits"]
```

### Obergrenze / Untergrenze setzen

| SAS | Python |
|---|---|
| `if CASA_DIST_BHF > 10000 then CASA_DIST_BHF = 10000;` | `df["casa_dist_bhf"] = df["casa_dist_bhf"].clip(upper=10000)` |

```python
dist_cols = ["casa_dist_bhf", "casa_dist_bush", "casa_dist_ustrab"]
df[dist_cols] = df[dist_cols].clip(upper=10000)
```

### IF / ELSE

| SAS | Python |
|---|---|
| `if hours > 30 then full_time="Y"; else full_time="N";` | `np.where(df["hours"] > 30, "Y", "N")` |

```python
df["full_time"] = np.where(df["hours"] > 30, "Y", "N")
```

---

## 6. Missing Values & SAS-ähnliche Summenlogik

pandas summiert standardmäßig mit `skipna=True`. Achtung: Wenn alle Werte missing sind, liefert pandas bei `sum()` oft `0`. SAS-Logik erwartet häufig wieder `missing`.

```python
def sas_sum(df: pd.DataFrame, columns: list[str]) -> pd.Series:
    numeric_df = df[columns].apply(pd.to_numeric, errors="raise")
    row_sum = numeric_df.sum(axis=1, skipna=True)
    all_missing = numeric_df.isna().all(axis=1)
    return row_sum.mask(all_missing, np.nan)
```

```python
df["dist_sum"] = sas_sum(df, ["casa_dist_bhf", "casa_dist_bush", "casa_dist_ustrab"])
```

---

## 7. Rundung: nicht Python `round()` verwenden

Python `round()` nutzt eine andere Rundungslogik als viele SAS-Migrationen erwarten. Für reproduzierbare Migrationen besser eine Projektfunktion verwenden.

| SAS | Python |
|---|---|
| `round(x)` | `sas_round(x)` |
| `round(x, 0.00001)` | `sas_round(x, ndigits=5)` |

```python
df["idx"] = sas_round(df["idx_raw"], ndigits=5)
```

---

## 8. Sortieren, Deduplizieren, FIRST./LAST.-Logik

### Sortieren

| SAS | Python |
|---|---|
| `proc sort data=X; by ags5; run;` | `df.sort_values("ags5")` |
| `by id descending income;` | `df.sort_values(["id", "income"], ascending=[True, False])` |

```python
df = df.sort_values(["id", "income"], ascending=[True, False])
```

### Deduplizieren

| SAS | Python |
|---|---|
| `proc sort nodupkey; by id;` | `df.sort_values("id").drop_duplicates("id", keep="first")` |

```python
deduped = df.sort_values("id").drop_duplicates(subset=["id"], keep="first")
```

### Erste / letzte Zeile je Gruppe

| SAS | Python |
|---|---|
| `by id; if first.id;` | `df.sort_values("id").groupby("id").head(1)` |
| `by id; if last.id;` | `df.sort_values("id").groupby("id").tail(1)` |

```python
first_per_id = df.sort_values("id").groupby("id", as_index=False).head(1)
```

---

## 9. Joins / Merges

### Left Join

| SAS | Python |
|---|---|
| `proc sql; create table X as select a.*, b.* from A left join B on a.ags8=b.ags8; quit;` | `A.merge(B, on="ags8", how="left")` |

```python
bbsr = gem1.merge(gem2, on="ags8", how="left")
```

---

## 10. Gruppierungen

### Gruppiertes Maximum wieder an jede Zeile hängen

Das entspricht häufig SAS-Patterns wie `select *, max(x) ... group by ...`.

| SAS | Python |
|---|---|
| `max(CASA_DIST_BUSH) as max_bush ... group by gem_bbsr_typ` | `df.groupby("gem_bbsr_typ")["casa_dist_bush"].transform("max")` |

```python
df["max_bush"] = df.groupby("gem_bbsr_typ")["casa_dist_bush"].transform("max")
```

---

## 11. Normierung / Index-Berechnung

Beispiel aus OPNV-Logik:

| SAS | Python |
|---|---|
| `round(100000 - ((x - min) * 100000) / (max - min), 0.00001)` | `sas_round(100000 - ((df[col] - min_col) * 100000) / (max_col - min_col), ndigits=5)` |

```python
raw = 100000 - ((df[col] - min_col) * 100000) / (max_col - min_col)
df["idx"] = sas_round(raw, ndigits=5)
```


---

## 12. Text, Substrings, Typ-Konvertierung

### Textsuche

| SAS | Python |
|---|---|
| `if find(job_title, "Health");` | `df[df["job_title"].str.contains("Health", case=False, na=False)]` |

```python
health = df.loc[df["job_title"].str.contains("Health", case=False, na=False)].copy()
```

### Substring

Achtung: SAS zählt ab **1**, Python ab **0**. Das Ende ist in Python exklusiv.

| SAS | Python |
|---|---|
| `substr(big_string, 3, 4)` | `df["big_string"].str[2:6]` |

```python
df["substring"] = df["big_string"].str[2:6]
```

### Character → Numeric

| SAS | Python |
|---|---|
| `num_var = input(text_var, 8.);` | `pd.to_numeric(df["text_var"], errors="raise")` |

```python
df["num_var"] = pd.to_numeric(df["text_var"], errors="raise")
```

### Numeric → Character

| SAS | Python |
|---|---|
| `text_var = put(num_var, best.);` | `df["num_var"].astype("string")` |

```python
df["text_var"] = df["num_var"].astype("string")
```

---

## 13. Datasets kombinieren: SET / Append

| SAS | Python |
|---|---|
| `data new; set data_1 data_2; run;` | `pd.concat([data_1, data_2], ignore_index=True)` |

```python
new = pd.concat([data_1, data_2], ignore_index=True)
```

---

## 14. DataFrames im Speicher: `.copy()` gezielt einsetzen

SAS erzeugt bei jedem `data new; set old; ...; run;` automatisch einen neuen,
unabhängigen Datensatz. In Python entsteht bei `new_df = old_df` **keine**
Kopie, sondern nur ein zweiter Name für dasselbe Objekt im Speicher -
Änderungen an `new_df` würden dann auch `old_df` verändern.

Trotzdem sollte man nicht bei jedem SAS-Zwischenschritt automatisch
`.copy()` schreiben. Faustregel:

| Situation | `.copy()` nötig? |
|---|---|
| Variable wird nur einmal weiterverwendet, die alte Variable danach nicht mehr gebraucht | Nein - `neu = alt` reicht, `neu` ist einfach der neue Name |
| Ergebnis kommt frisch aus `merge()`, `groupby().agg()`, `read_sql_table()` o.ä. | Nein - diese Funktionen liefern bereits ein neues Objekt zurück |
| Dieselbe Variable wird noch **zusätzlich** für einen zweiten, unabhängigen Zweig gebraucht (z.B. `alt` liefert sowohl `zweig_a` als auch `zweig_b`) | Ja, mindestens für einen der beiden Zweige |
| Direkt nach dem Filtern (`df[bedingung]`) wird die Teilmenge weiter verändert | Ja - sonst kann eine `SettingWithCopyWarning` auftreten |

```python
# Kein .copy(): "firmen" wird einfach Schritt für Schritt umgebaut,
# die Rohtabelle wird nicht mehr gebraucht und kann aus dem Speicher fallen.
firmen = firmen.groupby(["ags5", "ags8", "ags11"], as_index=False)[
    "mitarbeiter_real"
].sum()

# .copy() nötig: "ao2" wird weiter unten noch einmal separat gefiltert (ao4),
# eine Änderung an ao3 darf ao2 nicht mit verändern.
ao3 = ao2.copy()
ao3["neue_spalte"] = ...

# .copy() direkt beim Filtern, weil die Teilmenge gleich mutiert wird:
ao4 = ao2[ao2["gem_be_ao_ges"].isna()].copy()
ao4["weitere_spalte"] = ...
```

**Hintergrund:** Bei kleinen/mittleren Tabellen (Kreis-, Gemeinde-,
Ortsteilebene) spielt die Anzahl an `.copy()`-Aufrufen für den
Speicherverbrauch praktisch keine Rolle - Lesbarkeit und 1:1-Vergleichbarkeit
mit den SAS-Zwischentabellen wiegen mehr. Bei großen Rohtabellen
(Millionen Zeilen, z.B. Firmendaten) lohnt es sich dagegen, den Variablen-
namen wiederzuverwenden statt für jeden Aggregationsschritt eine neue
Variable zu vergeben, damit Python die große Rohtabelle so früh wie möglich
aus dem Speicher räumen kann.

---


## 15. SAS Makros → Python Funktionen

| SAS | Python |
|---|---|
| `%macro ... %mend;` | `def function_name(...): ...` |
| `%add_variable(my_data);` | `my_data = add_variable(my_data)` |

```python
def add_variable(df: pd.DataFrame) -> pd.DataFrame:
    df = df.copy()
    df["new_variable"] = 1
    return df


my_data = add_variable(my_data)
```

**Tipp:** Funktionen sollten möglichst einen DataFrame annehmen und einen DataFrame zurückgeben. Das macht Tests einfacher.

---

## 16. Daten schreiben

| SAS | Python |
|---|---|
| `%sas_to_pg(from=X, to=tabelle, schema=sas_dbupdate)` | `df.to_sql("tabelle", engine, schema="sas_dbupdate", if_exists="replace", index=False)` |

```python
output_cols = ["ags27", "casa_opnv_idx", "casa_opnv_idx_kl"]

result[output_cols].to_sql(
    "_ags27_p26_260611_opnv_idx",
    con=engine,
    schema="sas_dbupdate",
    if_exists="replace",
    index=False,
)
```

**Achtung:** `if_exists="replace"` löscht und erstellt die Tabelle neu. Für produktive Jobs bewusst entscheiden zwischen `replace`, `append` und `fail`.

---

## 17. Mini-Beispiel: OPNV-Migration als pandas-Flow

```python
PAGS_AKT = 2025
schema_var = f"variablen{PAGS_AKT}"

# 1) Daten laden
gem1 = pd.read_sql_table(
    "ags8",
    con=engine,
    schema=schema_var,
    columns=["ags8", "gemeindename"],
)

gem2 = pd.read_sql_table(
    "ags8_gem_lage",
    con=engine,
    schema=schema_var,
    columns=["ags8", "gem_bbsr_typ"],
)

bbsr = gem1.merge(gem2, on="ags8", how="left", validate="1:1")

lage = pd.read_sql_table(
    "casa_dist_opnv",
    con=engine,
    schema="staging",
    columns=["ags27", "casa_dist_bhf", "casa_dist_bush", "casa_dist_ustrab"],
)

# 2) Werte begrenzen
dist_cols = ["casa_dist_bhf", "casa_dist_bush", "casa_dist_ustrab"]
lage[dist_cols] = lage[dist_cols].clip(upper=10000)

# 3) Qualitätscheck ähnlich PROC MEANS
summary = lage[dist_cols].agg(["count", lambda s: s.isna().sum(), "max"])
summary.index = ["n", "nmiss", "max"]
print(summary)

# 4) Weitere Joins / Berechnungen folgen ...
```

---

## 18. Migrations-Checkliste

Vor dem Schreiben der Zieltabelle immer kurz prüfen:

```python
print(df.shape)
print(df.dtypes)
print(df.head())
print(df.isna().sum())
```