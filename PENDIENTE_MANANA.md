# Lo que queda para mañana (lo haces tú, ~40 min)

> **Estado 2026-10-06, 10:30:** los pasos 1 (MySQL local), 2 (PostgreSQL local) y 3 (YugabyteDB Aeon)
> ya están hechos y verificados: 20 de 25 despliegues. En Aeon, SportsDB va con `-Colocado` por el
> límite de 180 tablets del Sandbox. El paso 4 (Codespace) también: **25 de 25 completos**. Solo quedan las capturas para `evidencias/` (sección 5).

Ya está hecho: los 10 scripts, MariaDB Docker completa (5/5) y los scripts PostgreSQL probados en
PostgreSQL 18 y YugabyteDB, también desde el `psql` de Windows. Lo que sigue necesita **tu**
contraseña, **tu** cuenta o una ventana de administrador.

Abre **PowerShell** y entra a la carpeta:

```powershell
cd C:\BaseDeDatos\tarea-5x5
```

Si algún paso falla, copia el mensaje completo y pásaselo a Claude.

---

## 1. MySQL local (5 min)

Necesitas la contraseña de `root` de tu MySQL (la que pusiste al instalarlo; con ella entras a Workbench).

```powershell
powershell -ExecutionPolicy Bypass -File ejecutar\mysql_local.ps1
powershell -ExecutionPolicy Bypass -File ejecutar\mysql_local.ps1 -Archivo verificacion\pruebas_restricciones_mysql.sql
```

Debes ver 5 veces `OK` y luego `Pruebas: 12 sentencias rechazadas`. Cada comando pide la contraseña.

## 2. PostgreSQL local (10 min)

1. Doble clic en `Descargas\postgresql-18.6-1-windows-x64.exe` → **Sí** en la ventana de UAC.
2. Componentes: **PostgreSQL Server** ✅, **Command Line Tools** ✅ (trae `psql`, imprescindible),
   **pgAdmin 4** ✅ (opcional, sirve para las capturas), **Stack Builder** ❌.
3. Carpeta de datos: la que propone.
4. **Contraseña del superusuario `postgres`**: invéntala y anótala.
5. Puerto: **5432**. Locale: el que propone.
6. Al terminar, desmarca "Launch Stack Builder".

```powershell
powershell -ExecutionPolicy Bypass -File ejecutar\postgres_cliente.ps1 -Plataforma local
powershell -ExecutionPolicy Bypass -File ejecutar\postgres_cliente.ps1 -Plataforma local -Archivo verificacion\pruebas_restricciones_postgres.sql
```

## 3. YugabyteDB Aeon (15 min)

1. Entra a <https://cloud.yugabyte.com> y crea la cuenta.
2. **Create a Free cluster** (Sandbox). Elige la región más cercana a Ecuador que ofrezca.
3. Credenciales: usuario **admin** y una contraseña. **Descárgalas o anótalas.**
4. Cuando el clúster esté listo (unos minutos), ve a **Connect** → *Connect to your application*.
   Ahí aparecen:
   - el **host** (algo como `us-east-1.xxxxxxxx.aws.yugabyte.cloud`), y
   - el botón **Download CA Cert**. Guarda el archivo `root.crt` en `C:\BaseDeDatos\tarea-5x5\`.
5. **IP Allow List**: agrega **tu IP actual** (botón *Add Current IP Address*). Sin eso, Aeon
   rechaza la conexión.

```powershell
powershell -ExecutionPolicy Bypass -File ejecutar\postgres_cliente.ps1 -Plataforma aeon -Servidor TU-HOST-DE-AEON -CertRaiz .\root.crt
powershell -ExecutionPolicy Bypass -File ejecutar\postgres_cliente.ps1 -Plataforma aeon -Servidor TU-HOST-DE-AEON -CertRaiz .\root.crt -Archivo verificacion\pruebas_restricciones_postgres.sql
```

SportsDB tarda algunos minutos (79.138 filas viajando por internet). Si falla con un mensaje de
**tablets** o de límite de recursos, repítelo solo para SportsDB con la opción de colocación:

```powershell
powershell -ExecutionPolicy Bypass -File ejecutar\postgres_cliente.ps1 -Plataforma aeon -Servidor TU-HOST-DE-AEON -CertRaiz .\root.crt -Colocado 05_sports
```

`root.crt` no es secreto (es el certificado público de Aeon), pero no hace falta subirlo al repositorio.

## 4. GitHub + Codespace (10 min)

Git ya está instalado en modo portable. Primero define tu nombre y correo para los commits. El correo
queda **público** en GitHub; puedes usar el correo `noreply` que te da GitHub en
*Settings → Emails*.

```powershell
$git = "$env:LOCALAPPDATA\Programs\PortableGit\cmd\git.exe"
& $git config --global user.name  "Alexis Camargo"
& $git config --global user.email "TU-CORREO"
& $git add .
& $git status
```

En `git status` **no** debe aparecer `.env`: tiene contraseñas y `.gitignore` lo excluye.

```powershell
& $git commit -m "Tarea 5x5: 10 scripts, ejecutores y evidencias"
```

1. En GitHub: **New repository** → nombre `tarea-5x5` → **sin** README ni .gitignore → *Create*.
2. Conecta y sube (la primera vez se abre el navegador para que inicies sesión en GitHub):

```powershell
& $git remote add origin https://github.com/TU-USUARIO/tarea-5x5.git
& $git push -u origin main
```

3. En la página del repo: **Code → Codespaces → Create codespace on main**. Espera a que abra
   (la primera vez tarda unos minutos porque instala Docker).
4. En la terminal del Codespace:

```bash
./ejecutar/mariadb_codespace.sh
git add evidencias/mariadb_codespace
git commit -m "Evidencias MariaDB Codespace"
git push
```

5. **Detén el Codespace** (Code → Codespaces → ⋯ → *Stop codespace*) para no gastar horas gratis.
6. De vuelta en Windows, trae las evidencias del Codespace:

```powershell
& $git pull
```

## 5. Cierre

```powershell
py herramientas\comparar_conteos.py
```

Debe decir **IGUALES** en las 5 bases y listar todas las plataformas. Después, Claude actualiza la
matriz del README con los ✅.

**Capturas para `evidencias/`** (el plan pide "cliente conectado + conteos"): para cada plataforma,
una captura del cliente (Workbench, pgAdmin, la consola de Aeon o la terminal del Codespace)
mostrando el resultado de `verificacion\0X_base.sql`. Los logs de `evidencias/` ya tienen la salida
completa de cada script.
