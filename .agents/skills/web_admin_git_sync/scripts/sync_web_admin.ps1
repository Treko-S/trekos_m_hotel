# Script de sincronización automática de Git para web_admin
# Hotel 3 Vagos - UTCD
param(
    [string]$CommitMessage = "chore(web_admin): sincronizacion automatica de cambios en panel administrativo"
)

$ErrorActionPreference = "Stop"
$repoPath = "C:\Users\Trekos\AndroidStudioProjects\trekos_m_hotel\web_admin"

if (-not (Test-Path "$repoPath\.git")) {
    Write-Error "No se encontro repositorio Git en: $repoPath"
    exit 1
}

Write-Host "Iniciando sincronizacion de Git para web_admin..." -ForegroundColor Cyan

# 1. Verificar si hay cambios
$status = git -C $repoPath status --porcelain
if (-not $status) {
    # Verificar si hay commits locales pendientes de push
    $ahead = git -C $repoPath log origin/main..main --oneline 2>$null
    if (-not $ahead) {
        Write-Host "web_admin ya esta completamente sincronizado y al dia con origin/main." -ForegroundColor Green
        exit 0
    }
    Write-Host "Hay commits locales pendientes de push. Procediendo al envio..." -ForegroundColor Yellow
} else {
    Write-Host "Cambios detectados en web_admin:" -ForegroundColor Yellow
    Write-Host $status

    # 2. Agregar cambios
    git -C $repoPath add -A

    # 3. Commitear
    git -C $repoPath commit -m $CommitMessage
    Write-Host "Commit creado exitosamente." -ForegroundColor Green
}

# 4. Pull para evitar desincronizaciones si hubo cambios en remoto
Write-Host "Verificando actualizaciones remotas (pull --rebase)..." -ForegroundColor Cyan
git -C $repoPath pull --rebase origin main

# 5. Push a origin main
Write-Host "Subiendo cambios a origin/main en GitHub..." -ForegroundColor Cyan
git -C $repoPath push origin main

Write-Host "Sincronizacion de web_admin completada con exito." -ForegroundColor Green
git -C $repoPath status -s
