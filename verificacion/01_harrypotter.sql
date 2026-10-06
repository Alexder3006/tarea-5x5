-- Conteos por tabla de harrypotter. Correr conectado a la base 'harrypotter'.
-- Igual en ambos dialectos.
SELECT 'estudiantes' AS tabla, COUNT(*) AS filas FROM estudiantes
UNION ALL SELECT 'profesores',    COUNT(*) FROM profesores
UNION ALL SELECT 'cursos',        COUNT(*) FROM cursos
UNION ALL SELECT 'inscripciones', COUNT(*) FROM inscripciones;
