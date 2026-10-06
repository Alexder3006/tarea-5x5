-- Conteos por tabla de chinook. Correr conectado a la base 'chinook'.
-- Dialecto PostgreSQL / YugabyteDB.
SELECT 'album' AS tabla, COUNT(*) AS filas FROM album
UNION ALL SELECT 'artist' AS tabla, COUNT(*) AS filas FROM artist
UNION ALL SELECT 'customer' AS tabla, COUNT(*) AS filas FROM customer
UNION ALL SELECT 'employee' AS tabla, COUNT(*) AS filas FROM employee
UNION ALL SELECT 'genre' AS tabla, COUNT(*) AS filas FROM genre
UNION ALL SELECT 'invoice' AS tabla, COUNT(*) AS filas FROM invoice
UNION ALL SELECT 'invoice_line' AS tabla, COUNT(*) AS filas FROM invoice_line
UNION ALL SELECT 'media_type' AS tabla, COUNT(*) AS filas FROM media_type
UNION ALL SELECT 'playlist' AS tabla, COUNT(*) AS filas FROM playlist
UNION ALL SELECT 'playlist_track' AS tabla, COUNT(*) AS filas FROM playlist_track
UNION ALL SELECT 'track' AS tabla, COUNT(*) AS filas FROM track
ORDER BY tabla;
