# ==============================================================================
# DESPLEGAR_SHINYAPPS.PS1: Ejecutor de despliegue a shinyapps.io en PowerShell
# ==============================================================================

$Rscript = "C:\Program Files\R\R-4.6.1\bin\Rscript.exe"
if (-not (Test-Path $Rscript)) {
    $Rscript = "Rscript"
}

Write-Host "==============================================================================" -ForegroundColor Green
Write-Host "  Iniciando proceso de publicacion en shinyapps.io - Anta 2026" -ForegroundColor Cyan
Write-Host "==============================================================================" -ForegroundColor Green

& $Rscript "desplegar_shinyapps.R"
