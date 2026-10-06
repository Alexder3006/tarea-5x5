# Corre los scripts del dialecto PostgreSQL en los contenedores DE PRUEBA:
#   -Destino pg  -> contenedor pg-prueba  (postgres:18, puerto 5434)
#   -Destino yb  -> contenedor yb-prueba  (yugabytedb/yugabyte, YSQL, puerto 5433)
# Sirven para validar los scripts antes de PostgreSQL local y YugabyteDB Aeon.
# Uso:  .\ejecutar\postgres_docker.ps1 -Destino pg
#       .\ejecutar\postgres_docker.ps1 -Destino yb 01_harrypotter
#       .\ejecutar\postgres_docker.ps1 -Destino pg -Archivo verificacion\pruebas_restricciones_postgres.sql
[CmdletBinding(PositionalBinding=$false)]
param(
    [Parameter(Mandatory)][ValidateSet('pg','yb')][string]$Destino,
    [Parameter(ValueFromRemainingArguments)][string[]]$Scripts,
    [string]$Archivo
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = New-Object Text.UTF8Encoding $false
$raiz   = Split-Path $PSScriptRoot -Parent
$docker = 'C:\Program Files\Docker\Docker\resources\bin\docker.exe'

if ($Destino -eq 'pg') {
    $contenedor = 'pg-prueba'; $etiqueta = 'PostgreSQL 18 (Docker, prueba)'; $carpeta = 'pg_docker_prueba'
    $cmd = 'psql -U postgres -d postgres -X -q -f /tmp/script.sql'
} else {
    $contenedor = 'yb-prueba'; $etiqueta = 'YugabyteDB YSQL (Docker, prueba)'; $carpeta = 'yb_docker_prueba'
    $cmd = 'bin/ysqlsh -h $(hostname) -U yugabyte -d yugabyte -X -q -f /tmp/script.sql'
}
$salida = Join-Path $raiz "evidencias\$carpeta"
New-Item -ItemType Directory -Force $salida | Out-Null

if ($Archivo) { $lista = @(Join-Path $raiz $Archivo) }
elseif ($Scripts) { $lista = $Scripts | ForEach-Object { Join-Path $raiz "postgres\$_.sql" } }
else { $lista = Get-ChildItem (Join-Path $raiz 'postgres') -Filter '*.sql' | Sort-Object Name | ForEach-Object FullName }

$fallos = 0
foreach ($archivoSql in $lista) {
    $nombre = [IO.Path]::GetFileNameWithoutExtension($archivoSql)
    $log    = Join-Path $salida "$nombre.log"
    Write-Host "== $nombre @ $etiqueta ==" -ForegroundColor Cyan
    & $docker cp $archivoSql "${contenedor}:/tmp/script.sql" | Out-Null
    if ($LASTEXITCODE -ne 0) { $fallos++; Write-Host "No se pudo copiar $archivoSql" -ForegroundColor Red; continue }
    $inicio = Get-Date
    $out = & $docker exec $contenedor bash -c "$cmd 2>&1"
    $codigo = $LASTEXITCODE
    $seg = [math]::Round(((Get-Date) - $inicio).TotalSeconds, 1)
    $texto = ($out | ForEach-Object { "$_" }) -join "`n"
    [IO.File]::WriteAllText($log, "# $nombre  |  $etiqueta  |  $(Get-Date -Format s)  |  ${seg}s  |  codigo $codigo`n$texto`n", (New-Object Text.UTF8Encoding $false))
    if ($Archivo) { $n = ([regex]::Matches($texto, 'ERROR:')).Count; Write-Host "Pruebas: $n sentencias rechazadas -> $log" -ForegroundColor Yellow }
    elseif ($codigo -eq 0) { Write-Host "OK (${seg}s) -> $log" -ForegroundColor Green }
    else { $fallos++; Write-Host "FALLO (codigo $codigo) -> $log" -ForegroundColor Red; Write-Host $texto }
}
exit $fallos
