"""Genera verificacion/<base>.sql: la consulta de conteos por tabla de cada base,
extraída de los propios scripts (así nunca queda desincronizada).

Si la consulta es igual en ambos dialectos se genera un solo archivo; si no
(Chinook usa nombres distintos en MySQL y PostgreSQL) se generan dos.

Uso:  py herramientas/generar_verificacion.py
"""
import os
import re

from sqlutil import write

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def consulta_conteos(ruta):
    texto = open(ruta, encoding="utf-8").read()
    m = re.search(r"(?ms)^SELECT '\w+' AS tabla, COUNT\(\*\) AS filas FROM .*?;", texto)
    assert m, ruta
    return m.group(0) + "\n"


for archivo in sorted(os.listdir(os.path.join(RAIZ, "mysql"))):
    base = archivo[:-4]
    q_my = consulta_conteos(os.path.join(RAIZ, "mysql", archivo))
    q_pg = consulta_conteos(os.path.join(RAIZ, "postgres", archivo))
    nombre = re.sub(r"^\d+_", "", base)
    cab = f"-- Conteos por tabla de {nombre}. Correr conectado a la base '{nombre}'.\n"
    if q_my == q_pg:
        write(os.path.join(RAIZ, "verificacion", f"{base}.sql"), cab + "-- Igual en ambos dialectos.\n" + q_my)
        print(f"{base}.sql")
    else:
        write(os.path.join(RAIZ, "verificacion", f"{base}_mysql.sql"), cab + "-- Dialecto MySQL / MariaDB.\n" + q_my)
        write(os.path.join(RAIZ, "verificacion", f"{base}_postgres.sql"), cab + "-- Dialecto PostgreSQL / YugabyteDB.\n" + q_pg)
        print(f"{base}_mysql.sql + {base}_postgres.sql")
