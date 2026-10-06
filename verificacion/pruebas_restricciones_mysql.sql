-- =====================================================================
-- Pruebas de restricciones · dialecto MySQL / MariaDB
-- TODAS las sentencias de modificación deben FALLAR. Cada una ataca una
-- restricción distinta y el comentario dice cuál debe dispararse.
-- Se corre con el cliente en modo --force (sigue tras cada error).
-- Al final los conteos deben ser los mismos de antes: nada entró.
-- =====================================================================

USE harrypotter;

-- P01 · ck_estudiantes_casa: casa inexistente
INSERT INTO estudiantes VALUES (99, 'Ginny Weasley', 'Grifindor');
-- P02 · ck_inscripciones_nota: nota fuera de la escala de Hogwarts
INSERT INTO inscripciones VALUES (1, 103, 'Z');
-- P03 · PRIMARY KEY (estudiante_id, curso_id): Harry ya está inscrito en Potions
INSERT INTO inscripciones VALUES (1, 101, 'O');
-- P04 · fk_cursos_profesor: el profesor 99 no existe
INSERT INTO cursos VALUES (199, 'Astronomy', 99);
-- P05 · UNIQUE profesores.nombre: Snape ya está registrado
INSERT INTO profesores VALUES (7, 'Severus Snape');
-- P06 · fk_cursos_profesor al borrar: Snape dicta Potions, no se puede borrar
DELETE FROM profesores WHERE profesor_id = 1;
-- P07 · NOT NULL cursos.profesor_id: curso sin profesor
INSERT INTO cursos VALUES (198, 'Muggle Studies', NULL);

USE marineros;

-- P08 · ck_sailors_rating: rating 11 fuera de 1..10
INSERT INTO sailors VALUES (99, 'Popeye', 11, 40.0);
-- P09 · ck_sailors_age: edad negativa
INSERT INTO sailors VALUES (98, 'Bluto', 5, -3.0);
-- P10 · PRIMARY KEY (sid, bid, day): Dustin ya reservó el 101 ese día
INSERT INTO reserves VALUES (22, 101, '2023-07-10');
-- P11 · fk_reserves_sailor: el marinero 99 no existe
INSERT INTO reserves VALUES (99, 101, '2024-01-01');
-- P12 · fk_reserves_boat: el bote 999 no existe
INSERT INTO reserves VALUES (22, 999, '2024-01-01');

-- Conteos finales: deben ser 8/6/5/16 y 10/4/11 (nada entró)
SELECT 'harrypotter.estudiantes' AS tabla, COUNT(*) AS filas FROM harrypotter.estudiantes
UNION ALL SELECT 'harrypotter.profesores',    COUNT(*) FROM harrypotter.profesores
UNION ALL SELECT 'harrypotter.cursos',        COUNT(*) FROM harrypotter.cursos
UNION ALL SELECT 'harrypotter.inscripciones', COUNT(*) FROM harrypotter.inscripciones
UNION ALL SELECT 'marineros.sailors',         COUNT(*) FROM marineros.sailors
UNION ALL SELECT 'marineros.boats',           COUNT(*) FROM marineros.boats
UNION ALL SELECT 'marineros.reserves',        COUNT(*) FROM marineros.reserves;
