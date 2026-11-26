# Arrancar NANA para la demo: revisa todo, prende el agente y lo prueba.
# Se abre con doble clic en «Arrancar NANA.bat» (en la carpeta del repo).
# Para detenerlo: Ctrl+C en esta ventana.

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$Host.UI.RawUI.WindowTitle = 'NANA - agente para la demo'
$aqui = $PSScriptRoot
$puerto = 8787

function Paso($n, $texto) { Write-Host "`n[$n/5] $texto" -ForegroundColor Cyan }
function Bien($texto) { Write-Host "  OK  $texto" -ForegroundColor Green }
function Ojo($texto) { Write-Host "  !!  $texto" -ForegroundColor Yellow }
function Mal($texto) {
    Write-Host "`n  XX  $texto" -ForegroundColor Red
    Read-Host "`nPresiona Enter para cerrar"
    exit 1
}

Write-Host '==============================================' -ForegroundColor Magenta
Write-Host '          NANA - arranque para la demo        ' -ForegroundColor Magenta
Write-Host '==============================================' -ForegroundColor Magenta

# 1. Corriente: con batería la tarjeta de video va 4 veces más lenta y
#    las respuestas se pasan de 5 segundos.
Paso 1 'Corriente'
function Conectada {
    try {
        $b = Get-CimInstance -Namespace root/WMI -ClassName BatteryStatus -ErrorAction Stop | Select-Object -First 1
        return [bool]$b.PowerOnline
    } catch { return $true }  # sin batería (de escritorio): siempre conectada
}
while (-not (Conectada)) {
    Write-Host ''
    Write-Host '  ####################################################' -ForegroundColor Red
    Write-Host '  ##   CONECTA EL CARGADOR DE LA LAPTOP             ##' -ForegroundColor Red
    Write-Host '  ##   Con bateria NANA contesta 4 veces mas lento  ##' -ForegroundColor Red
    Write-Host '  ####################################################' -ForegroundColor Red
    $r = Read-Host '  Conectalo y presiona Enter (o escribe "seguir" para seguir sin corriente)'
    if ($r -eq 'seguir') { Ojo 'Sigues con bateria: puede tardar mas de 5 s.'; break }
}
if (Conectada) { Bien 'La laptop esta conectada a la corriente.' }

# 2. Ollama con Qwen.
Paso 2 'Ollama'
function OllamaVivo {
    try { return Invoke-RestMethod "http://127.0.0.1:11434/api/tags" -TimeoutSec 3 } catch { return $null }
}
$tags = OllamaVivo
if (-not $tags) {
    $app = Join-Path $env:LOCALAPPDATA 'Programs\Ollama\ollama app.exe'
    if (-not (Test-Path $app)) { Mal "No encuentro Ollama en $app. Instalalo desde ollama.com." }
    Ojo 'Ollama estaba cerrado: lo abro...'
    Start-Process $app
    for ($i = 0; $i -lt 30 -and -not $tags; $i++) { Start-Sleep -Seconds 1; $tags = OllamaVivo }
    if (-not $tags) { Mal 'Ollama no contesto en 30 s. Abrelo a mano (menu Inicio > Ollama) y vuelve a correr esto.' }
}
if (-not ($tags.models | Where-Object { $_.name -eq 'qwen3:8b' })) {
    Mal 'Ollama no tiene qwen3:8b. En una terminal corre: ollama pull qwen3:8b'
}
Bien 'Ollama prendido y con qwen3:8b.'

# 3. Clave de la demo: se guarda en clave_demo.txt (no va al repo).
Paso 3 'Clave de la demo'
$archivoClave = Join-Path $aqui 'clave_demo.txt'
if (-not (Test-Path $archivoClave)) {
    (Get-Random -Minimum 100000 -Maximum 999999).ToString() | Set-Content -Path $archivoClave -Encoding ascii
    Ojo 'Hice una clave nueva: escribela en los dos celulares.'
}
$clave = (Get-Content $archivoClave -Raw).Trim()
$env:NANA_CLAVE_DEMO = $clave
Bien 'Clave lista.'
# La llave de Claude no se guarda en el repo: Cris la pone como variable de
# usuario de Windows (setx ANTHROPIC_API_KEY ...). Sin ella platica Qwen.
if (-not $env:ANTHROPIC_API_KEY) {
    $env:ANTHROPIC_API_KEY = [Environment]::GetEnvironmentVariable('ANTHROPIC_API_KEY', 'User')
}
if ($env:ANTHROPIC_API_KEY) { Bien 'Llave de Claude encontrada: la platica usa Haiku 5.5.' }
else { Ojo 'No hay llave de Claude: la platica la hace Qwen en esta laptop.' }

# 4. El servidor del agente (en esta misma ventana).
Paso 4 'Agente'
$ocupado = $null
try { $ocupado = Invoke-RestMethod "http://127.0.0.1:$puerto/salud" -TimeoutSec 2 } catch { }
if ($ocupado) { Mal "Ya hay un agente corriendo en el puerto $puerto. Cierra la otra ventana del agente y vuelve a correr esto." }
$env:PYTHONUTF8 = '1'
$servidor = Start-Process python -ArgumentList 'servidor_local.py' -WorkingDirectory $aqui -NoNewWindow -PassThru
$salud = $null
for ($i = 0; $i -lt 90 -and -not $salud; $i++) {
    Start-Sleep -Seconds 1
    if ($servidor.HasExited) { Mal 'El agente se cerro al arrancar. Revisa el mensaje de arriba.' }
    try { $salud = Invoke-RestMethod "http://127.0.0.1:$puerto/salud" -TimeoutSec 2 -Headers @{ 'X-Nana-Demo' = $clave } } catch { }
}
if (-not $salud) { Mal 'El agente no contesto en 90 s.' }
Bien "Agente prendido: $($salud.proveedores)"

# 5. Prueba rápida: una frase de Rosa y una del encargado, con la clave.
Paso 5 'Prueba rapida'
function Pedir($ruta, $cuerpo) {
    $bytes = [Text.Encoding]::UTF8.GetBytes(($cuerpo | ConvertTo-Json -Depth 6 -Compress))
    $t = [Diagnostics.Stopwatch]::StartNew()
    $r = Invoke-RestMethod "http://127.0.0.1:$puerto$ruta" -Method Post -Body $bytes `
        -ContentType 'application/json; charset=utf-8' -Headers @{ 'X-Nana-Demo' = $clave } -TimeoutSec 20
    return @{ r = $r; s = [math]::Round($t.Elapsed.TotalSeconds, 1) }
}
$lento = $false
try {
    $a = Pedir '/agente' @{ texto = 'Hola NANA, me siento un poco sola'; nombre = 'Rosa' }
    Bien ("Rosa: {0} s  -> {1}" -f $a.s, $a.r.texto)
    $e = Pedir '/encargado' @{ pregunta = 'Que dias no se marco el Losartan?'; nombre = 'Rosa'; datos = @{
        medicinas = @(@{ nombre = 'Losartan'; hora = '8:00' })
        totales_7_dias = @{ dias_sin_marcar_por_medicina = @{ Losartan = @('martes 18') } } } }
    Bien ("Encargado: {0} s  -> {1}" -f $e.s, $e.r.texto)
    $lento = ($a.s -gt 5) -or ($e.s -gt 5)
} catch { Mal "La prueba rapida fallo: $($_.Exception.Message)" }
if ($lento) { Ojo 'Tardo mas de 5 s: revisa que la laptop este conectada a la corriente.' }

# Túnel de Cloudflare (opcional): una dirección https que funciona desde
# cualquier red, aunque la escuela bloquee la IP de la laptop. Sin cuenta.
$tunel = $null; $urlTunel = $null
$cf = Get-Command cloudflared -ErrorAction SilentlyContinue
$exe = if ($cf) { $cf.Source } else { @("$env:ProgramFiles\cloudflared\cloudflared.exe", "${env:ProgramFiles(x86)}\cloudflared\cloudflared.exe") | Where-Object { Test-Path $_ } | Select-Object -First 1 }
if ($exe) {
    $log = Join-Path $aqui 'tunel.log'
    Remove-Item $log -ErrorAction SilentlyContinue
    $tunel = Start-Process $exe -ArgumentList "tunnel --no-autoupdate --url http://127.0.0.1:$puerto" `
        -RedirectStandardError $log -WindowStyle Hidden -PassThru
    for ($i = 0; $i -lt 30 -and -not $urlTunel; $i++) {
        Start-Sleep -Seconds 1
        if (Test-Path $log) {
            $m = Select-String -Path $log -Pattern 'https://[a-z0-9-]+\.trycloudflare\.com' | Select-Object -First 1
            if ($m) { $urlTunel = $m.Matches[0].Value }
        }
    }
    if ($urlTunel) { Bien "Tunel listo: $urlTunel" } else { Ojo 'El tunel no arranco en 30 s: usa la IP.' }
} else {
    Ojo 'Sin tunel (cloudflared no esta instalado): solo funciona en la misma red.'
}

# Lo que hay que escribir en los dos celulares.
$ip = (Get-NetIPConfiguration | Where-Object { $_.IPv4DefaultGateway -and $_.NetAdapter.Status -eq 'Up' } |
    Select-Object -First 1).IPv4Address.IPAddress
Write-Host ''
Write-Host '==============================================' -ForegroundColor Green
Write-Host '   LISTO PARA LA DEMO' -ForegroundColor Green
Write-Host '   En los dos celulares: Mas opciones >' -ForegroundColor Green
Write-Host '   Servidor de NANA (pruebas)' -ForegroundColor Green
Write-Host ''
if ($urlTunel) { Write-Host "      Internet: $urlTunel" -ForegroundColor White }
Write-Host "      IP:     $ip" -ForegroundColor White
Write-Host "      Clave:  $clave" -ForegroundColor White
Write-Host ''
Write-Host '   y toca "Guardar y probar".' -ForegroundColor Green
Write-Host '==============================================' -ForegroundColor Green
if (-not $ip) { Ojo 'No encontre la IP: conecta la laptop al hotspot o al Wi-Fi.' }
Write-Host "`nAqui abajo sale cada frase (solo el tema). Ctrl+C para detenerlo.`n"

try { $servidor.WaitForExit() } finally {
    if (-not $servidor.HasExited) { Stop-Process -Id $servidor.Id -Force }
    if ($tunel -and -not $tunel.HasExited) { Stop-Process -Id $tunel.Id -Force }
}
