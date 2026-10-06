"""Utilidades compartidas por los convertidores PostgreSQL -> MySQL."""
import re


def split_values(row):
    """Separa los campos de una tupla SQL '(a, 'b,c', NULL)' respetando comillas.
    Recibe el contenido SIN los paréntesis exteriores. Devuelve la lista de
    literales tal cual (con sus comillas)."""
    out, cur, in_q, i = [], [], False, 0
    while i < len(row):
        c = row[i]
        if in_q:
            cur.append(c)
            if c == "'":
                if i + 1 < len(row) and row[i + 1] == "'":   # '' = comilla escapada
                    cur.append("'"); i += 1
                else:
                    in_q = False
        elif c == "'":
            in_q = True; cur.append(c)
        elif c == ",":
            out.append("".join(cur).strip()); cur = []
        else:
            cur.append(c)
        i += 1
    out.append("".join(cur).strip())
    return out


def fix_comments(sql):
    """En MySQL un comentario '--' debe ir seguido de espacio: '---' es error de sintaxis."""
    return re.sub(r"(?m)^--(?=[^\s])", "-- ", sql)


def escape_backslashes(sql):
    """PostgreSQL (standard_conforming_strings=on) trata '\\' como un carácter
    normal; MySQL lo trata como escape. Duplicarlo conserva el mismo dato."""
    return sql.replace("\\", "\\\\")


def write(path, text):
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)
