"""Construye postgres/05_sports.sql y mysql/05_sports.sql a partir de SportsDB
publicada por YugabyteDB (github.com/yugabyte/yugabyte-db/sample):
  1. sportsdb_tables.sql       (tablas y secuencias)
  2. sportsdb_inserts.sql      (datos)
  3. sportsdb_constraints.sql  (UNIQUE)
  4. sportsdb_fks.sql          (claves foráneas)
  5. sportsdb_indexes.sql      (índices)
Se unen en ese orden en un único script por dialecto (regla del plan: un script
que corre de punta a punta sobre una base recién creada).

Uso:  py herramientas/construir_sportsdb.py
"""
import os
import re
from collections import defaultdict, OrderedDict

from sqlutil import split_values, fix_comments, write

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
F = os.path.join(RAIZ, "fuentes")
LOTE = 500   # filas por INSERT agrupado


def leer(nombre):
    return open(os.path.join(F, nombre), encoding="utf-8").read()


tables_src = leer("sportsdb_tables.sql")
inserts_src = leer("sportsdb_inserts.sql")
constraints_src = leer("sportsdb_constraints.sql")
fks_src = leer("sportsdb_fks.sql")
indexes_src = leer("sportsdb_indexes.sql")

# ---------------------------------------------------------------------------
# Análisis del esquema
# ---------------------------------------------------------------------------
bloques = re.findall(r"(?ms)^CREATE TABLE (\w+) \((.*?)^\);", tables_src)
tablas = [t for t, _ in bloques]
assert len(tablas) == 107, len(tablas)

columnas = {}        # tabla -> [(col_sin_comillas, tipo_pg_resto_de_linea)]
for t, cuerpo in bloques:
    cols = []
    for linea in cuerpo.strip().splitlines():
        m = re.match(r'\s*("?)(\w+)\1 (.+?),?$', linea)
        assert m, (t, linea)
        cols.append((m.group(2), m.group(3)))
    columnas[t] = cols

seriales = {t for t, cols in columnas.items() for c, ty in cols if c == "id" and ty.startswith("serial")}
assert len(seriales) == 96, len(seriales)

# Las 96 restricciones del archivo de constraints son UNIQUE (id) de las tablas con serial.
uniques = re.findall(r"ALTER TABLE ONLY (\w+)\s+ADD CONSTRAINT (\w+) UNIQUE \(id\);", constraints_src)
assert len(uniques) == 96 and {t for t, _ in uniques} == seriales
unique_de = dict(uniques)

# setval: valor y si ya fue "llamado" (true -> el próximo será n+1).
setvals = {t: (int(n), llamado == "true") for t, n, llamado in re.findall(
    r"setval\(pg_catalog\.pg_get_serial_sequence\('(\w+)', 'id'\), (\d+), (true|false)\);", tables_src)}
assert set(setvals) == seriales

# ---------------------------------------------------------------------------
# Datos: parseo de los 79.138 INSERT (uno por línea)
# ---------------------------------------------------------------------------
patron_ins = re.compile(r"^INSERT INTO (\w+) \(([^)]*)\) VALUES \((.*)\);$")
filas = []           # (tabla, lista_columnas_texto, valores_texto)
for linea in inserts_src.splitlines():
    if not linea.startswith("INSERT INTO"):
        continue
    m = patron_ins.match(linea)
    assert m, linea[:120]
    filas.append((m.group(1), m.group(2), m.group(3)))
assert len(filas) == 79138, len(filas)

# Precisión real de las columnas numeric sin (p,s), y fracciones de segundo.
numericas = {(t, c) for t, cols in columnas.items() for c, ty in cols if ty.startswith("numeric")}
ent, dec = defaultdict(int), defaultdict(int)
fraccion_seg = False
for t, cols_txt, vals_txt in filas:
    cols = [c.strip().strip('"') for c in cols_txt.split(",")]
    vals = split_values(vals_txt)
    assert len(cols) == len(vals), (t, cols_txt)
    for c, v in zip(cols, vals):
        if (t, c) in numericas and v != "NULL":
            v = v.strip("'").lstrip("-")
            e, _, d = v.partition(".")
            ent[(t, c)] = max(ent[(t, c)], len(e.lstrip("0")) or 1)
            dec[(t, c)] = max(dec[(t, c)], len(d))
        elif re.fullmatch(r"'\d{4}-\d\d-\d\d \d\d:\d\d:\d\d\.\d+'", v):
            fraccion_seg = True


def agrupar(lista, comillas_columnas):
    """Une INSERT consecutivos de la misma tabla y columnas en lotes de LOTE filas."""
    salida, i = [], 0
    while i < len(lista):
        t, cols_txt, _ = lista[i]
        j = i
        while j < len(lista) and lista[j][0] == t and lista[j][1] == cols_txt and j - i < LOTE:
            j += 1
        cols = comillas_columnas(cols_txt)
        valores = ",\n  ".join(f"({v})" for _, _, v in lista[i:j])
        salida.append(f"INSERT INTO {t} ({cols}) VALUES\n  {valores};")
        i = j
    return salida


def conteos(cita):
    return ("\nUNION ALL ".join(f"SELECT '{t}' AS tabla, COUNT(*) AS filas FROM {cita(t)}" for t in sorted(tablas))
            + "\nORDER BY tabla;\n")


resumen = (f"-- Contenido: 107 tablas, {len(filas):,} filas en 56 tablas con datos, "
           f"96 UNIQUE, {len(re.findall('FOREIGN KEY', fks_src))} FK, {len(re.findall('CREATE INDEX', indexes_src))} índices.")

# ---------------------------------------------------------------------------
# PostgreSQL / YugabyteDB
# ---------------------------------------------------------------------------
ins_pg = agrupar(filas, lambda c: c)
idx_pg, n_lsm = re.subn(r" USING lsm", "", indexes_src)
assert n_lsm == 98

pg = f"""-- =====================================================================
-- 05_sports.sql  ·  dialecto PostgreSQL
-- Plataformas: PostgreSQL local · YugabyteDB (YSQL)
-- Fuente: SportsDB de YugabyteDB (docs.yugabyte.com/stable/develop/sample-data/
--         sportsdb) = los 5 archivos sample/sportsdb_*.sql del repo
--         yugabyte/yugabyte-db, unidos en el orden oficial.
-- GENERADO por herramientas/construir_sportsdb.py — no editar a mano.
{resumen}
-- Adaptaciones a los archivos oficiales:
--   · los 79.138 INSERT de una fila se agrupan en INSERT de {LOTE} filas
--     (mismos datos; ~80.000 viajes de red pasan a ~170: clave para Aeon)
--   · índices: se quita "USING lsm". lsm solo existe en YugabyteDB; sin método
--     explícito PostgreSQL usa btree y YugabyteDB usa lsm (su default).
-- Opcional en YugabyteDB:  ysqlsh -v colocado=1 ...  crea la base con
--   COLOCATION = true (todas las tablas en un solo tablet; útil si el clúster
--   sandbox de Aeon limita la cantidad de tablets).
-- Ejecutar conectado a OTRA base (postgres o yugabyte):
--   psql -d postgres -f postgres/05_sports.sql
-- =====================================================================

\\set ON_ERROR_STOP on

-- WITH (FORCE): cierra sesiones abiertas (p. ej. monitoreo de YugabyteDB).
DROP DATABASE IF EXISTS sports WITH (FORCE);
\\if :{{?colocado}}
CREATE DATABASE sports ENCODING 'UTF8' TEMPLATE template0 COLOCATION = true;
\\else
CREATE DATABASE sports ENCODING 'UTF8' TEMPLATE template0;
\\endif
\\c sports
-- client_encoding es por conexion y \\c abre una nueva: va DESPUES de \\c.
SET client_encoding = 'UTF8';
SET client_min_messages = warning;

-- ============ 1/5 sportsdb_tables.sql (original) ============
{tables_src.strip()}

-- ============ 2/5 sportsdb_inserts.sql (agrupado en lotes de {LOTE}) ============
BEGIN;
{chr(10).join(ins_pg)}
COMMIT;

-- ============ 3/5 sportsdb_constraints.sql (original) ============
{constraints_src.strip()}

-- ============ 4/5 sportsdb_fks.sql (original) ============
{fks_src.strip()}

-- ============ 5/5 sportsdb_indexes.sql (sin "USING lsm") ============
{idx_pg.strip()}

-- ============ Verificación ============
{conteos(lambda t: t)}"""

# ---------------------------------------------------------------------------
# MySQL / MariaDB
# ---------------------------------------------------------------------------
def tipo_mysql(t, c, ty):
    r = ty
    if c == "id" and ty.startswith("serial"):
        return re.sub(r"^serial", "INT", r) + " AUTO_INCREMENT"
    r = re.sub(r"^primary_id\b", "INT", r)
    r = re.sub(r"^character varying\(", "VARCHAR(", r)
    r = re.sub(r"^timestamp without time zone\b", "DATETIME(6)" if fraccion_seg else "DATETIME", r)
    if r.startswith("numeric"):
        e, d = ent.get((t, c), 1), dec.get((t, c), 0)
        e, d = max(e, 1) + 4, max(d, 3)            # margen: 4 dígitos enteros más, mínimo 3 decimales
        r = re.sub(r"^numeric\b", f"DECIMAL({e + d},{d})", r)
    assert re.match(r"^(INT|VARCHAR|DATETIME|DECIMAL|integer|smallint|date|text)\b", r), (t, c, ty)
    return r


ddl_my = []
for t, cols in columnas.items():
    defs = [f"    `{c}` {tipo_mysql(t, c, ty)}" for c, ty in cols]
    if t in seriales:
        # MySQL exige índice en la columna AUTO_INCREMENT al crear la tabla:
        # el UNIQUE (id) de sportsdb_constraints.sql se declara aquí mismo.
        defs.append(f"    CONSTRAINT {unique_de[t]} UNIQUE (id)")
    ddl_my.append(f"CREATE TABLE {t} (\n" + ",\n".join(defs) + "\n);")

ins_my = agrupar(filas, lambda c: ", ".join(f"`{x.strip().strip(chr(34))}`" for x in c.split(",")))

autoinc = [f"ALTER TABLE {t} AUTO_INCREMENT = {n + 1 if llamado else n};"
           for t, (n, llamado) in setvals.items()]

fks_my = re.sub(r"ALTER TABLE ONLY ", "ALTER TABLE ", fks_src)
fks_my = re.sub(r'"(\w+)"', r"`\1`", fks_my)
assert all(len(n) <= 64 for n in re.findall(r"ADD CONSTRAINT (\w+)", fks_my))
idx_my = re.sub(r'"(\w+)"', r"`\1`", idx_pg)

my = f"""-- =====================================================================
-- 05_sports.sql  ·  dialecto MySQL / MariaDB
-- Plataformas: MySQL local · MariaDB Docker · MariaDB Codespace
-- Fuente: SportsDB de YugabyteDB (los mismos 5 archivos de postgres/05_sports.sql)
--         convertida a MySQL. GENERADO por herramientas/construir_sportsdb.py.
{resumen}
-- Conversiones aplicadas:
--   · serial -> INT AUTO_INCREMENT; su UNIQUE (id) (archivo 3/5) se declara
--     dentro del CREATE TABLE porque MySQL exige índice en AUTO_INCREMENT
--   · setval(secuencia, n) -> ALTER TABLE ... AUTO_INCREMENT (mismo próximo id)
--   · DOMAIN primary_id -> INT (MySQL no tiene dominios)
--   · character varying -> VARCHAR · timestamp without time zone -> DATETIME
--   · numeric sin precisión -> DECIMAL(p,s) calculado con los datos reales
--     (DECIMAL a secas en MySQL es DECIMAL(10,0) y cortaría decimales)
--   · identificadores "entre comillas dobles" -> `comillas invertidas`
--   · INSERT agrupados en lotes de {LOTE} filas (mismos datos)
--   · ALTER TABLE ONLY -> ALTER TABLE · índices sin "USING lsm"
-- =====================================================================

SET NAMES utf8mb4;
DROP DATABASE IF EXISTS sports;
CREATE DATABASE sports CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;
USE sports;

-- ============ 1/5 tablas (+ los UNIQUE (id) de 3/5) ============
{chr(10).join(ddl_my)}

-- ============ 2/5 datos (agrupados en lotes de {LOTE}) ============
START TRANSACTION;
{chr(10).join(ins_my)}
COMMIT;

-- Secuencias: equivalente de los setval() de PostgreSQL
{chr(10).join(autoinc)}

-- ============ 3/5 constraints: ya declarados en 1/5 ============

-- ============ 4/5 claves foráneas ============
{fix_comments(fks_my).strip()}

-- ============ 5/5 índices ============
{fix_comments(idx_my).strip()}

-- ============ Verificación ============
{conteos(lambda t: t)}"""

write(os.path.join(RAIZ, "postgres", "05_sports.sql"), pg)
write(os.path.join(RAIZ, "mysql", "05_sports.sql"), my)
print(f"OK: {len(tablas)} tablas, {len(filas)} filas -> {len(ins_pg)} INSERT agrupados")
print("numeric -> ", {f"{t}.{c}": f"({ent.get((t,c),0)} ent, {dec.get((t,c),0)} dec)" for t, c in sorted(numericas)})
print("fracciones de segundo en timestamps:", fraccion_seg)
