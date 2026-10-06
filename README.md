# Tarea 5 × 5 — cinco bases en cinco plataformas

**CMP 4002 Base de Datos · USFQ · Alexis Camargo**

Cinco bases de datos (Harry Potter, Marineros, Northwind, Chinook, SportsDB) desplegadas en cinco
plataformas (MySQL local, PostgreSQL local, YugabyteDB Aeon, MariaDB en Docker, MariaDB en GitHub
Codespace): 25 despliegues.

## Matriz de despliegues

| | MySQL local | PG local | YugabyteDB Aeon | MariaDB Docker | MariaDB Codespace |
|---|:---:|:---:|:---:|:---:|:---:|
| Harry Potter | ✅ | ✅ | ✅ | ✅ | ⏳ |
| Marineros    | ✅ | ✅ | ✅ | ✅ | ⏳ |
| Northwind    | ✅ | ✅ | ✅ | ✅ | ⏳ |
| Chinook      | ✅ | ✅ | ✅ | ✅ | ⏳ |
| SportsDB     | ✅ | ✅ | ✅ | ✅ | ⏳ |

✅ = el script corrió de punta a punta, los conteos coinciden con las demás plataformas y la salida
quedó en `evidencias/<plataforma>/`. ⏳ = pendiente.

**Validación previa del dialecto PostgreSQL.** Antes de desplegar en PostgreSQL local y en Aeon, los
5 scripts PostgreSQL se probaron en dos contenedores de prueba: `postgres:18` (la misma versión que
el instalador local) y `yugabytedb/yugabyte` (el mismo motor YSQL de Aeon). También se cargaron desde
el `psql` de Windows, para cubrir la codificación de la consola. Pasaron todos: ver
`evidencias/pg_docker_prueba/` y `evidencias/yb_docker_prueba/`. Esos contenedores no cuentan como
plataformas de la matriz.

## Idea clave: 25 despliegues, 10 scripts

Las 5 plataformas hablan solo dos dialectos de SQL, así que cada base se escribe dos veces y el mismo
archivo se corre en todas las plataformas de su familia.

| Dialecto | Carpeta | Plataformas |
|---|---|---|
| MySQL | `mysql/` | MySQL local · MariaDB Docker · MariaDB Codespace |
| PostgreSQL | `postgres/` | PostgreSQL local · YugabyteDB Aeon (YSQL es compatible con PostgreSQL) |

Cada script corre **de punta a punta sobre una base recién creada**: borra la base, la crea, ejecuta el
DDL, carga los datos y termina con las consultas de verificación.

## Las bases

| Base | Fuente | Tablas | Filas |
|---|---|---:|---:|
| Harry Potter | Guía de laboratorio del D2L (SQLite), normalizada: `profesores`, `estudiantes`, `cursos`, `inscripciones` | 4 | 35 |
| Marineros | Laboratorio del D2L (SQLite) + marineros clásicos del libro de Ramakrishnan | 3 | 25 |
| Northwind | Northwind clásica de YugabyteDB: [`sample/northwind_*.sql`](https://github.com/yugabyte/yugabyte-db/tree/master/sample) | 14 | 3.362 |
| Chinook | Chinook 1.4.5 oficial: [`lerocha/chinook-database`](https://github.com/lerocha/chinook-database) | 11 | 15.607 |
| SportsDB | SportsDB de YugabyteDB: [`sample/sportsdb_*.sql`](https://github.com/yugabyte/yugabyte-db/tree/master/sample) (5 archivos) | 107 | 79.138 |

Los archivos originales están **sin modificar** en `fuentes/`. Los scripts de Northwind, Chinook y
SportsDB se **generan** desde esas fuentes con los programas de `herramientas/`: ninguna conversión se
hizo a mano, así que cualquiera puede repetirla.

```
py herramientas/construir_northwind.py
py herramientas/construir_chinook.py
py herramientas/construir_sportsdb.py
py herramientas/generar_verificacion.py
```

## Estructura

```
tarea-5x5/
├── mysql/            5 scripts dialecto MySQL/MariaDB
├── postgres/         5 scripts dialecto PostgreSQL/YugabyteDB
├── verificacion/     conteos por tabla de cada base + pruebas de restricciones
├── evidencias/       salida de cada script en cada plataforma (+ capturas)
├── fuentes/          archivos originales descargados, sin modificar
├── herramientas/     generadores de scripts y comparador de conteos (Python)
├── ejecutar/         un ejecutor por plataforma
└── .devcontainer/    configuración del Codespace
```

## Cómo correr cada plataforma

En Windows, desde la carpeta `tarea-5x5`:

| Plataforma | Comando |
|---|---|
| MariaDB Docker | `powershell -ExecutionPolicy Bypass -File ejecutar\mariadb_docker.ps1` |
| MySQL local | `powershell -ExecutionPolicy Bypass -File ejecutar\mysql_local.ps1` |
| PostgreSQL local | `powershell -ExecutionPolicy Bypass -File ejecutar\postgres_cliente.ps1 -Plataforma local` |
| YugabyteDB Aeon | `powershell -ExecutionPolicy Bypass -File ejecutar\postgres_cliente.ps1 -Plataforma aeon -Servidor <host> -CertRaiz <root.crt>` |
| MariaDB Codespace | en la terminal del Codespace: `./ejecutar/mariadb_codespace.sh` |

Las pruebas de restricciones se corren agregando
`-Archivo verificacion\pruebas_restricciones_mysql.sql` (o `..._postgres.sql`). Para comparar los
conteos de todas las plataformas: `py herramientas/comparar_conteos.py`.

El contenedor MariaDB se creó así (contraseña en `.env`, que no se sube al repositorio):

```
docker run -d --name mariadb-tarea -p 127.0.0.1:3307:3306 --env-file .env ^
  -v mariadb_tarea_data:/var/lib/mysql --restart unless-stopped mariadb:11
```

## Verificación

1. **Conteos idénticos.** `herramientas/comparar_conteos.py` lee los logs de todas las plataformas y
   compara tabla por tabla. Si algún conteo difiere, algo falló en silencio.
2. **Contenido idéntico, no solo conteos.** Se compararon huellas MD5 de todos los nombres de canciones
   y artistas de Chinook (con acentos y barras invertidas), sumas de columnas decimales, fracciones de
   segundo en timestamps y el próximo `id` autogenerado de SportsDB. Coinciden entre MariaDB,
   PostgreSQL 18 y YugabyteDB.
3. **Las restricciones funcionan, no solo están escritas.** `verificacion/pruebas_restricciones_*.sql`
   intenta 12 operaciones inválidas en Harry Potter y Marineros (casa inexistente, nota fuera de
   escala, inscripción duplicada, profesor inexistente, borrar un profesor con cursos, rating 11, edad
   negativa, reserva duplicada, marinero o bote inexistente, etc.). Las 12 son rechazadas por la
   restricción esperada y los conteos no cambian.
4. **Regla de oro.** Se volvieron a correr todos los scripts sobre bases ya existentes: el `DROP` →
   `CREATE` deja todo igual que la primera vez.

## Decisiones técnicas

**Diseño (Harry Potter y Marineros)**
- Cada restricción evita un problema concreto, y está comentado junto a ella en el script. Por
  ejemplo: el `CHECK` de `casa` evita casas inexistentes, la PK compuesta de `inscripciones` evita
  inscribir dos veces al mismo estudiante en el mismo curso, y `nota` admite `NULL` porque alguien
  inscrito puede no tener nota todavía.
- Solo restricciones declarativas (`PRIMARY KEY`, `FOREIGN KEY`, `UNIQUE`, `CHECK`, `NOT NULL`), sin
  triggers. MySQL 8.0.45 aplica los `CHECK` (lo hace desde la versión 8.0.16).
- IDs explícitos en vez de `AUTO_INCREMENT`/`IDENTITY`: los datos quedan idénticos en los dos dialectos.
- `DECIMAL(4,1)` para la edad (en vez de `REAL`): se guarda exacta, sin redondeo de punto flotante.

**Que el mismo dato quede igual en las 5 plataformas**
- **Intercalación `utf8mb4_bin` en MySQL**: compara exacto, igual que PostgreSQL. Con `*_ci`, MySQL
  consideraría iguales `'Snape'` y `'snape'`, y un `UNIQUE` se comportaría distinto según la plataforma.
- **Barra invertida**: en PostgreSQL `'\'` es un carácter normal; en MySQL es un escape. El script
  oficial de Chinook para MySQL perdía en silencio la barra en 4 títulos de canciones (`'Rusticana \ Act'`).
  Se duplica (`\\`) en todo el dialecto MySQL.
- **Codificación del cliente**: la consola de Windows no usa UTF-8. Cada script declara la suya
  (`SET NAMES utf8mb4` en MySQL; `SET client_encoding = 'UTF8'` después de cada `\c` en PostgreSQL,
  porque `\c` abre una conexión nueva y el `SET` anterior se pierde).

**Conversiones de PostgreSQL a MySQL**
- Northwind: `bpchar` → `CHAR(n)` con los largos de la Northwind original de Microsoft; `bytea` →
  `LONGBLOB`; `real` → `FLOAT` (4 bytes en los dos motores); las FK abreviadas (`REFERENCES t`) se
  completan con la columna.
- Northwind: `employees.reports_to` es una FK a la misma tabla. PostgreSQL la revisa al final de la
  sentencia y MySQL fila por fila, así que las filas se reordenan (cada jefe antes que sus
  subordinados) en vez de desactivar `FOREIGN_KEY_CHECKS`.
- SportsDB: `serial` → `INT AUTO_INCREMENT` (con su `UNIQUE (id)` dentro del `CREATE TABLE`, porque
  MySQL lo exige); `setval()` → `ALTER TABLE ... AUTO_INCREMENT` (mismo próximo id); el `DOMAIN
  primary_id` → `INT`; `timestamp` → `DATETIME(6)`, porque hay 414 valores con microsegundos;
  `numeric` sin precisión → `DECIMAL(p,s)` calculado con los datos reales, porque `DECIMAL` a secas en
  MySQL es `DECIMAL(10,0)` y cortaría los decimales.

**PostgreSQL y YugabyteDB con un mismo script**
- Los índices de SportsDB usan `USING lsm`, que solo existe en YugabyteDB. Se quita el `USING`: sin
  método explícito, PostgreSQL usa `btree` y YugabyteDB usa `lsm`, su método por defecto.
- `DROP DATABASE ... WITH (FORCE)`: el monitoreo de YugabyteDB deja sesiones abiertas en cada base, y
  sin `FORCE` volver a correr un script falla con "database is being accessed by other users".
- Los 79.138 `INSERT` de una fila de SportsDB se agrupan en `INSERT` de 500 filas: son los mismos
  datos, pero se pasa de unos 80.000 viajes de red a Aeon a unos 170.
- **SportsDB en Aeon va colocada** (`-v colocado=1`; en el ejecutor, `-Colocado`). El clúster Sandbox
  gratis admite como máximo 180 *tablets*, y en YugabyteDB cada tabla e índice ocupa al menos uno. SportsDB
  (107 tablas + 96 UNIQUE + 98 índices) sumada a las otras 4 bases supera ese límite. Aeon lo rechazó
  con *"would cause the total running tablet replica count (181) to exceed the safe system maximum (180)"*.
  Con `COLOCATION = true` todas las tablas de `sports` comparten un solo tablet. El esquema y los datos
  son los mismos; solo cambia cómo se reparten físicamente. En PostgreSQL la opción no aplica y no se usa.
- `\set ON_ERROR_STOP on`: sin esto, `psql` sigue de largo después de un error y el script "termina"
  aunque haya fallado a la mitad.

**Plataformas**
- Puertos: MySQL 3306, MariaDB Docker 3307 (no 3306, que lo usa MySQL), PostgreSQL 5432. Los
  contenedores solo escuchan en `127.0.0.1`, así que no son visibles desde la red.
- MariaDB en Docker y en Codespace usan la misma imagen, `mariadb:11`, para que las dos plataformas
  MariaDB corran la misma versión.
- Docker Desktop corre sobre WSL 2.

## Versiones

| Componente | Versión |
|---|---|
| Windows | 11 Pro 64 bits (build 26200) |
| MySQL Community Server | 8.0.45 |
| MariaDB (imagen `mariadb:11`) | 11.8.9 |
| PostgreSQL | 18.6 |
| YugabyteDB (YSQL) | 2026.1.2 (compatible con PostgreSQL 15.12) |
| Docker Desktop / Engine | 4.94.0 / 29.8.2 |
| Git for Windows (portable) | 2.56.0 |
