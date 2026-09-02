# ==============================================================================
# INICIAR_APP.PS1: Lanzador de la Aplicación Shiny de Biodiversidad de Anta
# Municipalidad Provincial de Anta - Gerencia de Desarrollo Urbano y Rural
# ==============================================================================

$ErrorActionPreference = "Stop"
$projectRoot = $PSScriptRoot
if (-not $projectRoot) { $projectRoot = Get-Location }

$rscript = "C:\Program Files\R\R-4.6.1\bin\Rscript.exe"

if (-not (Test-Path -LiteralPath $rscript)) {
    # Buscar en otras ubicaciones estándar de R
    $altR = Get-ChildItem "C:\Program Files\R" -Filter "Rscript.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($altR) {
        $rscript = $altR.FullName
    } else {
        throw "No se encontro Rscript.exe en el sistema."
    }
}

Write-Host "=================================================================" -ForegroundColor DarkGreen
Write-Host "  MUNICIPALIDAD PROVINCIAL DE ANTA" -ForegroundColor Green
Write-Host "  Gerencia de Desarrollo Urbano y Rural" -ForegroundColor Green
Write-Host "  Iniciando Sistema de Informacion de Biodiversidad..." -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor DarkGreen

Set-Location $projectRoot

& $rscript -e "invisible(Sys.setlocale('LC_CTYPE', 'English_United States.utf8')); shiny::runApp('.', port = 3838, launch.browser = TRUE)"
