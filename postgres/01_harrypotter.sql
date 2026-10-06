-- =====================================================================
-- 01_harrypotter.sql  ·  dialecto PostgreSQL
-- Plataformas: PostgreSQL local · YugabyteDB (YSQL)
-- Fuente: guía de laboratorio del D2L (Students, Courses, Grades en SQLite),
--         normalizada: el profesor deja de ser texto dentro de Courses.
-- Ejecutar con psql/ysqlsh conectado a OTRA base (postgres o yugabyte),
-- nunca a harrypotter: no se puede borrar la base en la que uno está.
--   psql -d postgres -f postgres/01_harrypotter.sql
-- =====================================================================

-- Si algo falla, psql se detiene (por defecto seguiría de largo).
\set ON_ERROR_STOP on

-- WITH (FORCE): cierra sesiones abiertas en la base (p. ej. el monitoreo de
-- YugabyteDB); sin esto, volver a correr el script falla con 'being accessed'.
DROP DATABASE IF EXISTS harrypotter WITH (FORCE);
CREATE DATABASE harrypotter ENCODING 'UTF8' TEMPLATE template0;
\c harrypotter
-- client_encoding es por conexion y \c abre una nueva: va DESPUES de \c.
SET client_encoding = 'UTF8';

-- ---------------------------------------------------------------------
-- DDL
-- ---------------------------------------------------------------------

CREATE TABLE profesores (
    profesor_id  INTEGER      PRIMARY KEY,
    -- UNIQUE: evita registrar dos veces al mismo profesor con IDs distintos,
    -- que es justo la duplicación que esta tabla vino a eliminar.
    nombre       VARCHAR(80)  NOT NULL UNIQUE
);

CREATE TABLE estudiantes (
    estudiante_id INTEGER      PRIMARY KEY,
    nombre        VARCHAR(80)  NOT NULL,
    -- CHECK: evita casas que no existen en Hogwarts (p. ej. 'Grifindor').
    casa          VARCHAR(20)  NOT NULL,
    CONSTRAINT ck_estudiantes_casa
        CHECK (casa IN ('Gryffindor','Slytherin','Hufflepuff','Ravenclaw'))
);

CREATE TABLE cursos (
    curso_id     INTEGER      PRIMARY KEY,
    -- UNIQUE: evita dos cursos con el mismo nombre (dos 'Potions').
    nombre       VARCHAR(80)  NOT NULL UNIQUE,
    -- NOT NULL + FK: evita cursos sin profesor o con un profesor inexistente.
    profesor_id  INTEGER      NOT NULL,
    CONSTRAINT fk_cursos_profesor
        FOREIGN KEY (profesor_id) REFERENCES profesores (profesor_id)
);

CREATE TABLE inscripciones (
    estudiante_id INTEGER  NOT NULL,
    curso_id      INTEGER  NOT NULL,
    -- nota admite NULL: alguien inscrito puede no tener calificación todavía.
    nota          CHAR(1),
    -- PK compuesta: evita inscribir dos veces al mismo estudiante en el mismo curso.
    PRIMARY KEY (estudiante_id, curso_id),
    -- CHECK: evita notas fuera de la escala de Hogwarts (O, E, A, P, D, T).
    CONSTRAINT ck_inscripciones_nota
        CHECK (nota IN ('O','E','A','P','D','T')),
    -- FKs: evitan inscripciones de estudiantes o cursos que no existen.
    CONSTRAINT fk_inscripciones_estudiante
        FOREIGN KEY (estudiante_id) REFERENCES estudiantes (estudiante_id),
    CONSTRAINT fk_inscripciones_curso
        FOREIGN KEY (curso_id) REFERENCES cursos (curso_id)
);

-- ---------------------------------------------------------------------
-- Datos (los de la guía + algunos más para que las consultas digan algo)
-- ---------------------------------------------------------------------

INSERT INTO profesores (profesor_id, nombre) VALUES
    (1, 'Severus Snape'),
    (2, 'Remus Lupin'),
    (3, 'Pomona Sprout'),
    (4, 'Minerva McGonagall'),
    (5, 'Filius Flitwick'),
    (6, 'Sybill Trelawney');          -- sin curso asignado: sirve para probar LEFT JOIN

INSERT INTO estudiantes (estudiante_id, nombre, casa) VALUES
    (1, 'Harry Potter',     'Gryffindor'),
    (2, 'Hermione Granger', 'Gryffindor'),
    (3, 'Draco Malfoy',     'Slytherin'),
    (4, 'Ron Weasley',      'Gryffindor'),
    (5, 'Luna Lovegood',    'Ravenclaw'),
    (6, 'Cedric Diggory',   'Hufflepuff'),
    (7, 'Neville Longbottom','Gryffindor'),
    (8, 'Cho Chang',        'Ravenclaw');

INSERT INTO cursos (curso_id, nombre, profesor_id) VALUES
    (101, 'Potions',                       1),
    (102, 'Defense Against the Dark Arts', 2),
    (103, 'Herbology',                     3),
    (104, 'Transfiguration',               4),
    (105, 'Charms',                        5);

INSERT INTO inscripciones (estudiante_id, curso_id, nota) VALUES
    -- las 6 de la guía original
    (1, 101, 'A'), (1, 102, 'E'),
    (2, 101, 'O'), (2, 103, 'O'),
    (3, 101, 'E'), (3, 102, 'A'),
    -- adicionales
    (2, 104, 'O'), (3, 104, 'E'),
    (4, 101, 'P'), (4, 104, 'A'),
    (5, 103, 'E'), (5, 105, NULL),    -- Luna aún sin nota en Charms
    (6, 103, 'O'),
    (7, 101, 'T'), (7, 103, 'O'),
    (8, 105, 'E');

-- ---------------------------------------------------------------------
-- Verificación
-- ---------------------------------------------------------------------

SELECT 'estudiantes' AS tabla, COUNT(*) AS filas FROM estudiantes
UNION ALL SELECT 'profesores',    COUNT(*) FROM profesores
UNION ALL SELECT 'cursos',        COUNT(*) FROM cursos
UNION ALL SELECT 'inscripciones', COUNT(*) FROM inscripciones;

-- Boletín: quién está en qué curso, con qué profesor y qué nota
SELECT e.nombre AS estudiante, e.casa, c.nombre AS curso, p.nombre AS profesor, i.nota
FROM inscripciones i
JOIN estudiantes e ON e.estudiante_id = i.estudiante_id
JOIN cursos      c ON c.curso_id      = i.curso_id
JOIN profesores  p ON p.profesor_id   = c.profesor_id
ORDER BY e.estudiante_id, c.curso_id;

-- Profesores sin curso (debe salir Sybill Trelawney)
SELECT p.nombre AS profesor_sin_curso
FROM profesores p
LEFT JOIN cursos c ON c.profesor_id = p.profesor_id
WHERE c.curso_id IS NULL;
