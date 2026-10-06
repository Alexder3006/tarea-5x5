-- Conteos por tabla de chinook. Correr conectado a la base 'chinook'.
-- Dialecto MySQL / MariaDB.
SELECT 'Album' AS tabla, COUNT(*) AS filas FROM `Album`
UNION ALL SELECT 'Artist' AS tabla, COUNT(*) AS filas FROM `Artist`
UNION ALL SELECT 'Customer' AS tabla, COUNT(*) AS filas FROM `Customer`
UNION ALL SELECT 'Employee' AS tabla, COUNT(*) AS filas FROM `Employee`
UNION ALL SELECT 'Genre' AS tabla, COUNT(*) AS filas FROM `Genre`
UNION ALL SELECT 'Invoice' AS tabla, COUNT(*) AS filas FROM `Invoice`
UNION ALL SELECT 'InvoiceLine' AS tabla, COUNT(*) AS filas FROM `InvoiceLine`
UNION ALL SELECT 'MediaType' AS tabla, COUNT(*) AS filas FROM `MediaType`
UNION ALL SELECT 'Playlist' AS tabla, COUNT(*) AS filas FROM `Playlist`
UNION ALL SELECT 'PlaylistTrack' AS tabla, COUNT(*) AS filas FROM `PlaylistTrack`
UNION ALL SELECT 'Track' AS tabla, COUNT(*) AS filas FROM `Track`
ORDER BY tabla;
