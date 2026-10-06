"""Construye mysql/04_chinook.sql y postgres/04_chinook.sql a partir de los
scripts oficiales de Chinook 1.4.5 (github.com/lerocha/chinook-database,
ChinookDatabase/DataSources/Chinook_MySql.sql y Chinook_PostgreSql.sql).

No se convierte de un dialecto a otro: cada versión sale de su script oficial.
Solo se aplican adaptaciones mínimas (listadas en el encabezado de cada salida).

Uso:  py herramientas/construir_chinook.py
"""
import os
import re

from sqlutil import escape_backslashes, write

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FUENTES = os.path.join(RAIZ, "fuentes")

src_my = open(os.path.join(FUENTES, "Chinook_MySql.sql"), encoding="utf-8").read()
src_pg = open(os.path.join(FUENTES, "Chinook_PostgreSql.sql"), encoding="utf-8").read()


def reemplazar(texto, viejo, nuevo, veces=1):
    assert texto.count(viejo) == veces, (viejo, texto.count(viejo))
    return texto.replace(viejo, nuevo)


# ---------------------------------------------------------------------------
# MySQL / MariaDB
# ---------------------------------------------------------------------------
tablas_my = sorted(re.findall(r"(?m)^CREATE TABLE `(\w+)`", src_my))
assert len(tablas_my) == 11, tablas_my

my = src_my
# 1) Base en minúsculas (como las otras 4) y con utf8mb4_bin.
my = reemplazar(my, "DROP DATABASE IF EXISTS `Chinook`;", "DROP DATABASE IF EXISTS chinook;")
my = reemplazar(my, "CREATE DATABASE `Chinook`;",
                "CREATE DATABASE chinook CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;")
my = reemplazar(my, "USE `Chinook`;", "USE chinook;")
# 2) NVARCHAR = utf8mb3 (obsoleto) en MySQL 8 -> VARCHAR hereda utf8mb4 de la base.
my = re.sub(r"\bNVARCHAR\(", "VARCHAR(", my)
# 3) '\ ' en MySQL es un escape desconocido: se pierde la barra. Duplicarla
#    conserva el dato igual que en PostgreSQL (4 títulos de canciones).
my = escape_backslashes(my)

conteos_my = ("\nUNION ALL ".join(f"SELECT '{t}' AS tabla, COUNT(*) AS filas FROM `{t}`" for t in tablas_my)
              + "\nORDER BY tabla;\n")

my = f"""-- =====================================================================
-- 04_chinook.sql  ·  dialecto MySQL / MariaDB
-- Plataformas: MySQL local · MariaDB Docker · MariaDB Codespace
-- Fuente: Chinook 1.4.5 oficial (github.com/lerocha/chinook-database,
--         ChinookDatabase/DataSources/Chinook_MySql.sql).
-- GENERADO por herramientas/construir_chinook.py — no editar a mano.
-- Adaptaciones al script oficial:
--   · SET NAMES utf8mb4: el cliente lee el archivo como UTF-8 (Windows usa otra
--     codificación por defecto y rompería los 772 caracteres con acento)
--   · base `Chinook` -> chinook, con utf8mb4 / utf8mb4_bin
--   · NVARCHAR -> VARCHAR (NVARCHAR es utf8mb3, obsoleto en MySQL 8)
--   · '\\' duplicada: el original pierde la barra en 4 títulos ('\\ ' no es un
--     escape válido en MySQL y se descarta en silencio)
-- =====================================================================

SET NAMES utf8mb4;
{my.strip()}

/*******************************************************************************
   Verificación (agregado)
********************************************************************************/
{conteos_my}"""

# ---------------------------------------------------------------------------
# PostgreSQL / YugabyteDB
# ---------------------------------------------------------------------------
tablas_pg = sorted(re.findall(r"(?m)^CREATE TABLE (\w+)", src_pg))
assert len(tablas_pg) == 11, tablas_pg

pg = src_pg
# WITH (FORCE): cierra sesiones abiertas (p. ej. monitoreo de YugabyteDB);
# sin esto, volver a correr el script falla con "being accessed by other users".
pg = reemplazar(pg, "DROP DATABASE IF EXISTS chinook;", "DROP DATABASE IF EXISTS chinook WITH (FORCE);")
pg = reemplazar(pg, "CREATE DATABASE chinook;",
                "CREATE DATABASE chinook ENCODING 'UTF8' TEMPLATE template0;")
# \c es un comando de psql, no SQL: no lleva punto y coma.
pg = reemplazar(pg, "\\c chinook;",
                "\\c chinook\n-- client_encoding es por conexion y \\c abre una nueva: va DESPUES de \\c.\nSET client_encoding = 'UTF8';")

conteos_pg = ("\nUNION ALL ".join(f"SELECT '{t}' AS tabla, COUNT(*) AS filas FROM {t}" for t in tablas_pg)
              + "\nORDER BY tabla;\n")

pg = f"""-- =====================================================================
-- 04_chinook.sql  ·  dialecto PostgreSQL
-- Plataformas: PostgreSQL local · YugabyteDB (YSQL)
-- Fuente: Chinook 1.4.5 oficial (github.com/lerocha/chinook-database,
--         ChinookDatabase/DataSources/Chinook_PostgreSql.sql).
-- GENERADO por herramientas/construir_chinook.py — no editar a mano.
-- Adaptaciones al script oficial:
--   · ON_ERROR_STOP: psql se detiene ante el primer error
--   · client_encoding UTF8: el archivo es UTF-8 aunque la consola de Windows no
--   · DROP DATABASE ... WITH (FORCE): cierra sesiones abiertas (monitoreo de YugabyteDB)
--   · CREATE DATABASE con ENCODING 'UTF8' TEMPLATE template0
--   · "\\c chinook;" -> "\\c chinook" (meta-comando de psql, sin punto y coma)
-- Ejecutar conectado a OTRA base (postgres o yugabyte):
--   psql -d postgres -f postgres/04_chinook.sql
-- =====================================================================

\\set ON_ERROR_STOP on
{pg.strip()}

/*******************************************************************************
   Verificación (agregado)
********************************************************************************/
{conteos_pg}"""

write(os.path.join(RAIZ, "mysql", "04_chinook.sql"), my)
write(os.path.join(RAIZ, "postgres", "04_chinook.sql"), pg)
print("OK: tablas MySQL", tablas_my)
print("OK: tablas PG   ", tablas_pg)
