# Plataformas 2 y 3: PostgreSQL local y YugabyteDB Aeon, con psql de Windows.
#
#   PostgreSQL local:
#     .\ejecutar\postgres_cliente.ps1 -Plataforma local
#   YugabyteDB Aeon (datos de la pestaña "Connect" del clúster en Aeon):
#     .\ejecutar\postgres_cliente.ps1 -Plataforma aeon -Servidor <host-del-cluster> -CertRaiz C:\ruta\root.crt
#     agregar -Colocado si Aeon se queja del límite de tablets al crear SportsDB
#
#   Un solo script:   ... 01_harrypotter
#   Pruebas:          ... -Archivo verificacion\pruebas_restricciones_postgres.sql
#
# Pide la contraseña (no se guarda en ningún archivo).
# Salida: evidencias\pg_local\  o  evidencias\yugabyte_aeon\
[CmdletBinding(PositionalBinding=$false)]
param(
    [Parameter(Mandatory)][ValidateSet('local','aeon')][string]$Plataforma,
    [Parameter(ValueFromRemainingArguments)][string[]]$Scripts,
    [string]$Archivo,
    [string]$Servidor,
    [int]$Puerto,
    [string]$Usuario,
    [string]$BaseInicial,
    [string]$SslMode,
    [string]$CertRaiz,
    [switch]$Colocado,
    [string]$Psql = 'C:\Program Files\PostgreSQL\18\bin\psql.exe',
    [string]$Carpeta,
    [string]$Etiqueta
)

$ErrorActionPreference = 'Stop'
$raiz = Split-Path $PSScriptRoot -Parent

# Valores por defecto de cada plataforma (cualquiera se puede sobrescribir).
if ($Plataforma -eq 'local') {
    # 127.0.0.1 y no 'localhost': localhost puede resolverse a IPv6 (::1) y \c falla.
    $def = @{ Servidor='127.0.0.1'; Puerto=5432; Usuario='postgres'; BaseInicial='postgres'; SslMode='prefer'; Carpeta='pg_local'; Etiqueta='PostgreSQL local' }
} else {
    $def = @{ Servidor=''; Puerto=5433; Usuario='admin'; BaseInicial='yugabyte'; SslMode='verify-full'; Carpeta='yugabyte_aeon'; Etiqueta='YugabyteDB Aeon' }
}
foreach ($k in $def.Keys) { if (-not $PSBoundParameters.ContainsKey($k)) { Set-Variable -Name $k -Value $def[$k] } }
if (-not $Servidor) { throw "Falta -Servidor (el host del clúster que muestra Aeon en 'Connect')." }
if ($SslMode -eq 'verify-full' -and -not ($CertRaiz -and (Test-Path $CertRaiz))) { throw "Falta -CertRaiz con el root.crt que se descarga desde Aeon." }
if (-not (Test-Path $Psql)) { throw "No encuentro psql en $Psql" }

$salida = Join-Path $raiz "evidencias\$Carpeta"
New-Item -ItemType Directory -Force $salida | Out-Null

# Conexión por variables de entorno: \c (que usan los scripts) las reutiliza.
$previas = @{}
foreach ($v in 'PGHOST','PGPORT','PGUSER','PGPASSWORD','PGSSLMODE','PGSSLROOTCERT','PGCLIENTENCODING') { $previas[$v] = [Environment]::GetEnvironmentVariable($v) }
$env:PGHOST = $Servidor; $env:PGPORT = "$Puerto"; $env:PGUSER = $Usuario; $env:PGSSLMODE = $SslMode
if ($CertRaiz) { $env:PGSSLROOTCERT = (Resolve-Path $CertRaiz).Path }
# El archivo es UTF-8 aunque la consola de Windows use otra codificación.
$env:PGCLIENTENCODING = 'UTF8'
if (-not $env:PGPASSWORD) {
    $seg = Read-Host "Contraseña de '$Usuario' en $Etiqueta ($Servidor)" -AsSecureString
    $env:PGPASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($seg))
}

if ($Archivo) { $lista = @(Join-Path $raiz $Archivo) }
elseif ($Scripts) { $lista = $Scripts | ForEach-Object { Join-Path $raiz "postgres\$_.sql" } }
else { $lista = Get-ChildItem (Join-Path $raiz 'postgres') -Filter '*.sql' | Sort-Object Name | ForEach-Object FullName }

$tmpOut = Join-Path $env:TEMP 'tarea5x5_out.txt'
$tmpErr = Join-Path $env:TEMP 'tarea5x5_err.txt'
$fallos = 0
try {
    foreach ($archivoSql in $lista) {
        $nombre = [IO.Path]::GetFileNameWithoutExtension($archivoSql)
        $log    = Join-Path $salida "$nombre.log"
        Write-Host "== $nombre @ $Etiqueta ==" -ForegroundColor Cyan
        $argumentos = @('-d', $BaseInicial, '-X', '-q', '-f', "`"$archivoSql`"")
        if ($Colocado) { $argumentos += @('-v', 'colocado=1') }
        $inicio = Get-Date
        $p = Start-Process -FilePath $Psql -ArgumentList $argumentos -RedirectStandardOutput $tmpOut `
             -RedirectStandardError $tmpErr -NoNewWindow -Wait -PassThru
        $seg = [math]::Round(((Get-Date) - $inicio).TotalSeconds, 1)
        $texto = [IO.File]::ReadAllText($tmpErr, [Text.Encoding]::UTF8) + [IO.File]::ReadAllText($tmpOut, [Text.Encoding]::UTF8)
        [IO.File]::WriteAllText($log, "# $nombre  |  $Etiqueta  |  $(Get-Date -Format s)  |  ${seg}s  |  codigo $($p.ExitCode)`n$texto", (New-Object Text.UTF8Encoding $false))
        if ($Archivo) { $n = ([regex]::Matches($texto, 'ERROR:')).Count; Write-Host "Pruebas: $n sentencias rechazadas -> $log" -ForegroundColor Yellow }
        elseif ($p.ExitCode -eq 0) { Write-Host "OK (${seg}s) -> $log" -ForegroundColor Green }
        else { $fallos++; Write-Host "FALLO (codigo $($p.ExitCode)) -> $log" -ForegroundColor Red; Write-Host $texto }
    }
} finally {
    foreach ($v in $previas.Keys) { [Environment]::SetEnvironmentVariable($v, $previas[$v]) }
    Remove-Item $tmpOut, $tmpErr -ErrorAction SilentlyContinue
}
exit $fallos
