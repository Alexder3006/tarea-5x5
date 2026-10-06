"""Compara los conteos por tabla de cada base entre todas las plataformas.

Lee los logs de evidencias/<plataforma>/<script>.log (la salida de cada script
incluye una tabla 'tabla | filas') y verifica que los conteos sean idénticos.
Los nombres de tabla se normalizan (Chinook usa InvoiceLine en MySQL e
invoice_line en PostgreSQL, tal como los publica su autor).

Uso:  py herramientas/comparar_conteos.py
Sale con código 1 si hay alguna diferencia.
"""
import os
import re
import sys

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EVID = os.path.join(RAIZ, "evidencias")
SCRIPTS = ["01_harrypotter", "02_marineros", "03_northwind", "04_chinook", "05_sports"]


def normalizar(nombre):
    return nombre.lower().replace("_", "")


def leer_conteos(log):
    """Devuelve {tabla_normalizada: filas} del primer bloque 'tabla | filas'."""
    lineas = open(log, encoding="utf-8").read().splitlines()
    for i, l in enumerate(lineas):
        if re.search(r"\btabla\b\s*\|\s*filas\b", l):
            res = {}
            for l2 in lineas[i + 1:]:
                if re.match(r"^[\s|+-]*$", l2):          # separadores ----+---- / +---+
                    if res:
                        break
                    continue
                m = re.match(r"^\|?\s*(\w+)\s*\|\s*(\d+)\s*\|?\s*$", l2)
                if not m:
                    break
                res[normalizar(m.group(1))] = int(m.group(2))
            return res
    return None


def main():
    plataformas = sorted(d for d in os.listdir(EVID) if os.path.isdir(os.path.join(EVID, d)))
    ok = True
    for s in SCRIPTS:
        datos = {}
        for p in plataformas:
            log = os.path.join(EVID, p, f"{s}.log")
            if os.path.exists(log):
                c = leer_conteos(log)
                if c is None:
                    print(f"  ! {p}/{s}.log no tiene tabla de conteos (¿falló?)")
                    ok = False
                else:
                    datos[p] = c
        if not datos:
            print(f"{s}: sin evidencias todavía")
            continue
        ref_p, ref = next(iter(datos.items()))
        difs = []
        for p, c in datos.items():
            for t in sorted(set(ref) | set(c)):
                if ref.get(t) != c.get(t):
                    difs.append(f"{t}: {ref_p}={ref.get(t)} vs {p}={c.get(t)}")
        estado = "IGUALES" if not difs else "DIFERENTES"
        print(f"{s}: {len(ref)} tablas, {sum(ref.values()):,} filas - {estado} en {len(datos)} plataformas ({', '.join(datos)})")
        for d in difs:
            print("    ", d)
        ok &= not difs
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
