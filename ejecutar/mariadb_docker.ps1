# Corre los scripts del dialecto MySQL en el contenedor MariaDB (puerto 3307).
# Uso:  .\ejecutar\mariadb_docker.ps1                 (los 5)
#       .\ejecutar\mariadb_docker.ps1 01_harrypotter  (solo uno)
#       .\ejecutar\mariadb_docker.ps1 -Archivo verificacion\pruebas_restricciones_mysql.sql
#           (modo pruebas: --force, sigue tras cada error esperado)
# La salida de cada script queda en evidencias\mariadb_docker\<script>.log
[CmdletBinding(PositionalBinding=$false)]
param(
    [Parameter(ValueFromRemainingArguments)][string[]]$Scripts,
    [string]$Archivo
)

$ErrorActionPreference = 'Stop'
# Leer la salida de docker como UTF-8 (si no, los acentos de Chinook salen rotos en el log).
[Console]::OutputEncoding = New-Object Text.UTF8Encoding $false
$raiz       = Split-Path $PSScriptRoot -Parent
$docker     = 'C:\Program Files\Docker\Docker\resources\bin\docker.exe'
$contenedor = 'mariadb-tarea'
$salida     = Join-Path $raiz 'evidencias\mariadb_docker'
New-Item -ItemType Directory -Force $salida | Out-Null

$opciones = '--default-character-set=utf8mb4 --table'
if ($Archivo) { $lista = @(Join-Path $raiz $Archivo); $opciones += ' --force -v -n' }
elseif ($Scripts) { $lista = $Scripts | ForEach-Object { Join-Path $raiz "mysql\$_.sql" } }
else { $lista = Get-ChildItem (Join-Path $raiz 'mysql') -Filter '*.sql' | Sort-Object Name | ForEach-Object FullName }

$fallos = 0
foreach ($archivoSql in $lista) {
    $nombre = [IO.Path]::GetFileNameWithoutExtension($archivoSql)
    $log    = Join-Path $salida "$nombre.log"
    Write-Host "== $nombre @ MariaDB Docker ==" -ForegroundColor Cyan
    # Se copia el archivo al contenedor para que los bytes UTF-8 lleguen intactos.
    & $docker cp $archivoSql "${contenedor}:/tmp/script.sql" | Out-Null
    if ($LASTEXITCODE -ne 0) { $fallos++; Write-Host "No se pudo copiar $archivoSql" -ForegroundColor Red; continue }
    $inicio = Get-Date
    # 2>&1 dentro del contenedor: errores y resultados quedan juntos en el log.
    $out = & $docker exec $contenedor sh -c "exec mariadb -uroot -p`$MARIADB_ROOT_PASSWORD $opciones < /tmp/script.sql 2>&1"
    $codigo = $LASTEXITCODE
    $seg = [math]::Round(((Get-Date) - $inicio).TotalSeconds, 1)
    $texto = ($out | ForEach-Object { "$_" }) -join "`n"
    [IO.File]::WriteAllText($log, "# $nombre  |  MariaDB Docker  |  $(Get-Date -Format s)  |  ${seg}s  |  codigo $codigo`n$texto`n", (New-Object Text.UTF8Encoding $false))
    if ($Archivo) { $n = ([regex]::Matches($texto, '(?m)^ERROR ')).Count; Write-Host "Pruebas: $n sentencias rechazadas -> $log" -ForegroundColor Yellow }
    elseif ($codigo -eq 0) { Write-Host "OK (${seg}s) -> $log" -ForegroundColor Green }
    else { $fallos++; Write-Host "FALLO (codigo $codigo) -> $log" -ForegroundColor Red; Write-Host $texto }
}
exit $fallos
