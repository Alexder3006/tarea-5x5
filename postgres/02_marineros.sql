-- =====================================================================
-- 02_marineros.sql  ·  dialecto PostgreSQL
-- Plataformas: PostgreSQL local · YugabyteDB (YSQL)
-- Fuente: laboratorio del D2L (Sailors, Boats, Reserves en SQLite) — esquema
--         clásico del libro; solo se cambian los tipos de SQLite (TEXT, REAL)
--         por tipos reales (VARCHAR, DECIMAL, DATE).
-- Ejecutar conectado a OTRA base (postgres o yugabyte), nunca a marineros:
--   psql -d postgres -f postgres/02_marineros.sql
-- =====================================================================

\set ON_ERROR_STOP on

-- WITH (FORCE): cierra sesiones abiertas en la base (p. ej. el monitoreo de
-- YugabyteDB); sin esto, volver a correr el script falla con 'being accessed'.
DROP DATABASE IF EXISTS marineros WITH (FORCE);
CREATE DATABASE marineros ENCODING 'UTF8' TEMPLATE template0;
\c marineros
-- client_encoding es por conexion y \c abre una nueva: va DESPUES de \c.
SET client_encoding = 'UTF8';

CREATE TABLE sailors (
    sid     INTEGER      PRIMARY KEY,
    sname   VARCHAR(50)  NOT NULL,
    -- CHECK: evita ratings fuera de la escala 1..10.
    rating  INTEGER,
    -- DECIMAL(4,1) en vez de REAL: la edad se guarda exacta (45.0, 55.5), sin
    -- errores de redondeo de punto flotante al comparar.
    -- CHECK: evita edades cero o negativas.
    age     DECIMAL(4,1),
    CONSTRAINT ck_sailors_rating CHECK (rating BETWEEN 1 AND 10),
    CONSTRAINT ck_sailors_age    CHECK (age > 0)
);

CREATE TABLE boats (
    bid    INTEGER      PRIMARY KEY,
    bname  VARCHAR(50)  NOT NULL,
    color  VARCHAR(20)
);

CREATE TABLE reserves (
    sid  INTEGER  NOT NULL,
    bid  INTEGER  NOT NULL,
    day  DATE     NOT NULL,
    -- PK (sid, bid, day): evita reservar el mismo bote el mismo día dos veces
    -- para el mismo marinero.
    PRIMARY KEY (sid, bid, day),
    -- FKs: evitan reservas de marineros o botes que no existen.
    CONSTRAINT fk_reserves_sailor FOREIGN KEY (sid) REFERENCES sailors (sid),
    CONSTRAINT fk_reserves_boat   FOREIGN KEY (bid) REFERENCES boats (bid)
);

-- ---------------------------------------------------------------------
-- Datos: los del laboratorio + marineros clásicos del libro (Ramakrishnan)
-- ---------------------------------------------------------------------

INSERT INTO sailors (sid, sname, rating, age) VALUES
    (22, 'Dustin',  7, 45.0),
    (29, 'Brutus',  1, 33.0),
    (31, 'Lubber',  8, 55.5),
    (32, 'Andy',    8, 25.5),
    (58, 'Rusty',  10, 35.0),
    (64, 'Horatio', 7, 35.0),
    (71, 'Zorba',  10, 16.0),
    (74, 'Horatio', 9, 35.0),
    (85, 'Art',     3, 25.5),
    (95, 'Bob',     3, 63.5);

INSERT INTO boats (bid, bname, color) VALUES
    (101, 'Interlake', 'blue'),
    (102, 'Clipper',   'red'),
    (103, 'Marine',    'green'),
    (104, 'Interlake', 'red');

INSERT INTO reserves (sid, bid, day) VALUES
    -- las 4 del laboratorio
    (22, 101, '2023-07-10'),
    (22, 102, '2023-08-15'),
    (31, 103, '2023-09-10'),
    (58, 101, '2023-10-05'),
    -- adicionales
    (22, 103, '2023-10-08'),
    (22, 104, '2023-10-07'),
    (31, 102, '2023-11-10'),
    (31, 104, '2023-11-12'),
    (64, 101, '2023-09-05'),
    (64, 102, '2023-09-08'),
    (74, 103, '2023-09-08');

-- ---------------------------------------------------------------------
-- Verificación
-- ---------------------------------------------------------------------

SELECT 'sailors' AS tabla, COUNT(*) AS filas FROM sailors
UNION ALL SELECT 'boats',    COUNT(*) FROM boats
UNION ALL SELECT 'reserves', COUNT(*) FROM reserves;

-- Marineros que reservaron algún bote rojo
SELECT DISTINCT s.sname
FROM sailors s
JOIN reserves r ON r.sid = s.sid
JOIN boats    b ON b.bid = r.bid
WHERE b.color = 'red'
ORDER BY s.sname;

-- División relacional: marineros que reservaron TODOS los botes (debe salir Dustin)
SELECT s.sname
FROM sailors s
WHERE NOT EXISTS (
    SELECT b.bid FROM boats b
    WHERE NOT EXISTS (
        SELECT 1 FROM reserves r WHERE r.sid = s.sid AND r.bid = b.bid
    )
);
