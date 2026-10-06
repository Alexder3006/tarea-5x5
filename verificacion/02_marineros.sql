-- Conteos por tabla de marineros. Correr conectado a la base 'marineros'.
-- Igual en ambos dialectos.
SELECT 'sailors' AS tabla, COUNT(*) AS filas FROM sailors
UNION ALL SELECT 'boats',    COUNT(*) FROM boats
UNION ALL SELECT 'reserves', COUNT(*) FROM reserves;
