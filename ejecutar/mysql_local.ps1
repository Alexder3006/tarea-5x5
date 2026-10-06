# Plataforma 1: MySQL local (servicio MySQL80, puerto 3306).
# Corre los 5 scripts del dialecto MySQL con el cliente mysql.exe de Windows.
# Te pide la contraseña de root de TU MySQL (no se guarda en ningún archivo).
# Uso:  .\ejecutar\mysql_local.ps1
#       .\ejecutar\mysql_local.ps1 01_harrypotter
#       .\ejecutar\mysql_local.ps1 -Archivo verificacion\pruebas_restricciones_mysql.sql
# Salida: evidencias\mysql_local\<script>.log
[CmdletBinding(PositionalBinding=$false)]
param(
    [Parameter(ValueFromRemainingArguments)][string[]]$Scripts,
    [string]$Archivo,
    [string]$Servidor = '127.0.0.1',
    [int]$Puerto = 3306,
    [string]$Usuario = 'root',
    [string]$Carpeta = 'mysql_local',
    [string]$Etiqueta = 'MySQL local',
    [switch]$SinContrasena    # root sin contraseña (instalación por defecto)
)

$ErrorActionPreference = 'Stop'
$raiz  = Split-Path $PSScriptRoot -Parent
$mysql = 'C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe'
if (-not (Test-Path $mysql)) { throw "No encuentro $mysql" }
$salida = Join-Path $raiz "evidencias\$Carpeta"
New-Item -ItemType Directory -Force $salida | Out-Null

# Contraseña: se pide una vez y solo vive en la variable de entorno de este proceso.
$pwdPrevia = $env:MYSQL_PWD
if (-not $env:MYSQL_PWD -and -not $SinContrasena) {
    $seg = Read-Host "Contraseña de '$Usuario' en $Etiqueta" -AsSecureString
    $env:MYSQL_PWD = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($seg))
}

$opciones = @('-h', $Servidor, '-P', $Puerto, '-u', $Usuario, '--default-character-set=utf8mb4', '--table')
if ($SinContrasena) { $opciones += '--skip-password' }
if ($Archivo) { $lista = @(Join-Path $raiz $Archivo); $opciones += @('--force', '-v', '-n') }
elseif ($Scripts) { $lista = $Scripts | ForEach-Object { Join-Path $raiz "mysql\$_.sql" } }
else { $lista = Get-ChildItem (Join-Path $raiz 'mysql') -Filter '*.sql' | Sort-Object Name | ForEach-Object FullName }

$tmpOut = Join-Path $env:TEMP 'tarea5x5_out.txt'
$tmpErr = Join-Path $env:TEMP 'tarea5x5_err.txt'
$fallos = 0
try {
    foreach ($archivoSql in $lista) {
        $nombre = [IO.Path]::GetFileNameWithoutExtension($archivoSql)
        $log    = Join-Path $salida "$nombre.log"
        Write-Host "== $nombre @ $Etiqueta ==" -ForegroundColor Cyan
        $inicio = Get-Date
        # El archivo entra por stdin byte a byte (sin pasar por PowerShell): los acentos llegan intactos.
        $p = Start-Process -FilePath $mysql -ArgumentList $opciones -RedirectStandardInput $archivoSql `
             -RedirectStandardOutput $tmpOut -RedirectStandardError $tmpErr -NoNewWindow -Wait -PassThru
        $seg = [math]::Round(((Get-Date) - $inicio).TotalSeconds, 1)
        $texto = [IO.File]::ReadAllText($tmpOut, [Text.Encoding]::UTF8) + [IO.File]::ReadAllText($tmpErr, [Text.Encoding]::UTF8)
        [IO.File]::WriteAllText($log, "# $nombre  |  $Etiqueta  |  $(Get-Date -Format s)  |  ${seg}s  |  codigo $($p.ExitCode)`n$texto", (New-Object Text.UTF8Encoding $false))
        if ($Archivo) { $n = ([regex]::Matches($texto, '(?m)^ERROR ')).Count; Write-Host "Pruebas: $n sentencias rechazadas -> $log" -ForegroundColor Yellow }
        elseif ($p.ExitCode -eq 0) { Write-Host "OK (${seg}s) -> $log" -ForegroundColor Green }
        else { $fallos++; Write-Host "FALLO (codigo $($p.ExitCode)) -> $log" -ForegroundColor Red; Write-Host $texto }
    }
} finally {
    $env:MYSQL_PWD = $pwdPrevia
    Remove-Item $tmpOut, $tmpErr -ErrorAction SilentlyContinue
}
exit $fallos
