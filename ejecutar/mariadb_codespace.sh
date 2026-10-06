#!/usr/bin/env bash
# Plataforma 5: MariaDB en GitHub Codespace.
# Levanta mariadb:11 (la misma imagen que en Docker local) dentro del Codespace,
# corre los 5 scripts del dialecto MySQL y las pruebas de restricciones.
# Uso (en la terminal del Codespace):   ./ejecutar/mariadb_codespace.sh
# Las salidas quedan en evidencias/mariadb_codespace/
set -euo pipefail
cd "$(dirname "$0")/.."

CONT=mariadb-codespace
SALIDA=evidencias/mariadb_codespace
mkdir -p "$SALIDA"

# Contraseña aleatoria solo para este contenedor (no se sube: está en .gitignore).
if [ ! -f .env.codespace ]; then
  echo "MARIADB_ROOT_PASSWORD=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 20)" > .env.codespace
fi

if ! docker ps -a --format '{{.Names}}' | grep -qx "$CONT"; then
  docker run -d --name "$CONT" -p 127.0.0.1:3307:3306 --env-file .env.codespace \
    -v mariadb_codespace_data:/var/lib/mysql mariadb:11 >/dev/null
fi
docker start "$CONT" >/dev/null

echo -n "Esperando a MariaDB"
for i in $(seq 1 60); do
  if docker exec "$CONT" healthcheck.sh --connect --innodb_initialized >/dev/null 2>&1; then echo " listo"; break; fi
  echo -n "."; sleep 2
done
docker exec "$CONT" sh -c 'exec mariadb -uroot -p$MARIADB_ROOT_PASSWORD -e "SELECT VERSION() AS version"'

correr() {   # $1 = archivo .sql, $2 = opciones extra del cliente
  local archivo=$1 nombre extra=${2:-}
  nombre=$(basename "$archivo" .sql)
  docker cp "$archivo" "$CONT:/tmp/script.sql"
  local inicio=$SECONDS codigo=0
  salida=$(docker exec "$CONT" sh -c "exec mariadb -uroot -p\$MARIADB_ROOT_PASSWORD --default-character-set=utf8mb4 --table $extra < /tmp/script.sql 2>&1") || codigo=$?
  printf '# %s  |  MariaDB Codespace  |  %s  |  %ss  |  codigo %s\n%s\n' \
    "$nombre" "$(date -Iseconds)" "$((SECONDS - inicio))" "$codigo" "$salida" > "$SALIDA/$nombre.log"
  echo "$nombre: codigo $codigo -> $SALIDA/$nombre.log"
  return $codigo
}

fallos=0
for s in mysql/*.sql; do correr "$s" || fallos=$((fallos + 1)); done
correr verificacion/pruebas_restricciones_mysql.sql "--force -v -n" || true
echo "Pruebas rechazadas: $(grep -c '^ERROR ' "$SALIDA/pruebas_restricciones_mysql.log") de 12"

python3 herramientas/comparar_conteos.py || fallos=$((fallos + 1))
echo "Scripts con falla: $fallos"
exit $fallos
