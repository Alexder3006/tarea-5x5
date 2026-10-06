"""Construye mysql/03_northwind.sql y postgres/03_northwind.sql a partir de la
Northwind clásica publicada por YugabyteDB (fuentes/northwind_ddl.sql y
fuentes/northwind_data.sql, descargadas de github.com/yugabyte/yugabyte-db/sample).

PostgreSQL: el DDL y los datos van SIN CAMBIOS; solo se envuelven con
            DROP/CREATE DATABASE, \\c y los conteos de verificación.
MySQL:      conversión automática, explicada paso a paso abajo.

Uso:  py herramientas/construir_northwind.py
"""
import os
import re

from sqlutil import split_values, fix_comments, escape_backslashes, write

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FUENTES = os.path.join(RAIZ, "fuentes")

ddl = open(os.path.join(FUENTES, "northwind_ddl.sql"), encoding="utf-8").read()
data = open(os.path.join(FUENTES, "northwind_data.sql"), encoding="utf-8").read()

tablas = sorted(re.findall(r"(?m)^CREATE TABLE (\w+) \(", ddl))
assert len(tablas) == 14, tablas


def conteos():
    filas = [f"SELECT '{t}' AS tabla, COUNT(*) AS filas FROM {t}" for t in tablas]
    return "\nUNION ALL ".join(filas) + "\nORDER BY tabla;\n"


# ---------------------------------------------------------------------------
# PostgreSQL / YugabyteDB: fuente original intacta
# ---------------------------------------------------------------------------
pg = f"""-- =====================================================================
-- 03_northwind.sql  ·  dialecto PostgreSQL
-- Plataformas: PostgreSQL local · YugabyteDB (YSQL)
-- Fuente: Northwind clásica de YugabyteDB (docs.yugabyte.com/stable/develop/
--         sample-data/northwind) = sample/northwind_ddl.sql + northwind_data.sql
--         del repo yugabyte/yugabyte-db. Ambos van SIN CAMBIOS más abajo.
-- GENERADO por herramientas/construir_northwind.py — no editar a mano.
-- Ejecutar conectado a OTRA base (postgres o yugabyte):
--   psql -d postgres -f postgres/03_northwind.sql
-- =====================================================================

\\set ON_ERROR_STOP on

-- WITH (FORCE): cierra sesiones abiertas (p. ej. monitoreo de YugabyteDB).
DROP DATABASE IF EXISTS northwind WITH (FORCE);
CREATE DATABASE northwind ENCODING 'UTF8' TEMPLATE template0;
\\c northwind
-- Los DROP TABLE del DDL original avisan (NOTICE) que las tablas no existen:
-- es normal en una base recién creada.
SET client_min_messages = warning;

-- ======================== northwind_ddl.sql (original) ========================
{ddl.strip()}

-- ======================== northwind_data.sql (original) =======================
{data.strip()}

-- ======================== Verificación =========================================
{conteos()}"""

# ---------------------------------------------------------------------------
# MySQL / MariaDB: conversión
# ---------------------------------------------------------------------------

# 1) Largo de cada columna bpchar (CHAR sin largo de PostgreSQL; MySQL exige
#    largo). Se usan los de la Northwind original de Microsoft (nchar(n)).
#    CHAR ignora los espacios finales, igual que bpchar.
BPCHAR = {
    ("customer_demographics", "customer_type_id"): 10,
    ("customers", "customer_id"): 5,
    ("customer_customer_demo", "customer_id"): 5,
    ("customer_customer_demo", "customer_type_id"): 10,
    ("orders", "customer_id"): 5,
    ("region", "region_description"): 50,
    ("territories", "territory_description"): 50,
}

# PK de cada tabla (para completar las FK abreviadas "REFERENCES tabla").
pk = {}
for t, cuerpo in re.findall(r"(?ms)^CREATE TABLE (\w+) \((.*?)^\);", ddl):
    m = re.search(r"(?m)^\s*(\w+) [^,\n]*PRIMARY KEY", cuerpo)
    if m:
        pk[t] = m.group(1)


def convertir_tabla(m):
    t, cuerpo = m.group(1), m.group(2)

    def tipo_bpchar(mc):
        col = mc.group(1)
        n = BPCHAR[(t, col)]                       # KeyError = bpchar sin mapear
        return f"{col} CHAR({n})"

    cuerpo = re.sub(r"(\w+) bpchar\b", tipo_bpchar, cuerpo)
    # 2) FK abreviada: MySQL exige la columna referenciada.
    cuerpo = re.sub(r"REFERENCES (\w+)(?!\s*\()",
                    lambda r: f"REFERENCES {r.group(1)} ({pk[r.group(1)]})", cuerpo)
    return f"CREATE TABLE {t} ({cuerpo});"


ddl_my = re.sub(r"(?m)^SET .*\n", "", ddl)                     # SET de PostgreSQL
ddl_my = re.sub(r"(?ms)^CREATE TABLE (\w+) \((.*?)^\);", convertir_tabla, ddl_my)
ddl_my = re.sub(r"\bcharacter varying\(", "VARCHAR(", ddl_my)  # 3) tipos
ddl_my = re.sub(r"\bbytea\b", "LONGBLOB", ddl_my)               #    bytea -> LONGBLOB
ddl_my = re.sub(r"\breal\b", "FLOAT", ddl_my)                   #    real (4 bytes) -> FLOAT (4 bytes)
ddl_my = fix_comments(ddl_my)
assert "bpchar" not in ddl_my and "character varying" not in ddl_my

data_my = re.sub(r"(?m)^SET .*\n", "", data)
data_my = data_my.replace("INSERT INTO public.", "INSERT INTO ")
# 4) bytea vacío '\x' -> X'' (literal binario de MySQL); antes de escapar '\'.
data_my = re.sub(r"'\\x([0-9a-fA-F]*)'", r"X'\1'", data_my)
# 5) '\' es un carácter normal en PostgreSQL y un escape en MySQL.
data_my = escape_backslashes(data_my)
data_my = fix_comments(data_my)


# 6) employees.reports_to es FK a la misma tabla. PostgreSQL revisa la FK al
#    final de la sentencia; MySQL fila por fila. Se reordenan las filas para que
#    cada jefe entre antes que sus subordinados (mismos datos, FK verificada).
def reordenar_empleados(m):
    filas = [l for l in m.group(1).split("\n") if l.strip()]
    tuplas = []
    for l in filas:
        s = l.strip().rstrip(",;")
        assert s.startswith("(") and s.endswith(")"), s[:60]
        campos = split_values(s[1:-1])
        assert len(campos) == 18, len(campos)
        tuplas.append((campos[0], campos[16], s))       # employee_id, reports_to
    orden, puestos = [], set()
    while tuplas:
        listos = [t for t in tuplas if t[1] == "NULL" or t[1] in puestos]
        assert listos, "ciclo en reports_to"
        for t in listos:
            orden.append(t[2]); puestos.add(t[0]); tuplas.remove(t)
    return ("INSERT INTO employees VALUES\n"
            "-- filas reordenadas: cada jefe antes que sus subordinados (FK reports_to)\n\t"
            + ",\n\t".join(orden) + ";\n")


data_my, n = re.subn(r"(?s)INSERT INTO employees VALUES\n(.*?);\n", reordenar_empleados, data_my)
assert n == 1

my = f"""-- =====================================================================
-- 03_northwind.sql  ·  dialecto MySQL / MariaDB
-- Plataformas: MySQL local · MariaDB Docker · MariaDB Codespace
-- Fuente: Northwind clásica de YugabyteDB (la misma de postgres/03_northwind.sql)
--         convertida a MySQL. GENERADO por herramientas/construir_northwind.py.
-- Conversiones aplicadas:
--   · bpchar -> CHAR(n) con los largos de la Northwind original de Microsoft
--   · character varying -> VARCHAR · bytea -> LONGBLOB · real -> FLOAT
--   · FK abreviadas "REFERENCES t" -> "REFERENCES t (pk)"
--   · SET NAMES utf8mb4 (el archivo es UTF-8 aunque el cliente esté en Windows)
--   · sin SET de PostgreSQL · sin prefijo "public." · '\\x' -> X''
--   · '\\' duplicada (en MySQL es escape; en PostgreSQL no)
--   · employees reordenado para que la FK reports_to se cumpla fila a fila
-- =====================================================================

SET NAMES utf8mb4;
DROP DATABASE IF EXISTS northwind;
CREATE DATABASE northwind CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;
USE northwind;

-- ======================== DDL (convertido) =====================================
{ddl_my.strip()}

-- ======================== Datos (convertidos) ==================================
{data_my.strip()}

-- ======================== Verificación =========================================
{conteos()}"""

write(os.path.join(RAIZ, "postgres", "03_northwind.sql"), pg)
write(os.path.join(RAIZ, "mysql", "03_northwind.sql"), my)
print("OK: 14 tablas;", ", ".join(f"{t}->{c}" for t, c in pk.items()))
