$ErrorActionPreference = "Stop"
$env:LANG = "English_United States.utf8"
$env:LC_ALL = "English_United States.utf8"
$env:LC_CTYPE = "English_United States.utf8"
$projectRoot = Split-Path -Parent $PSScriptRoot
$rscript = "C:\Program Files\R\R-4.6.1\bin\Rscript.exe"

if (-not (Test-Path -LiteralPath $rscript)) {
    throw "No se encontro Rscript en $rscript"
}

Push-Location $projectRoot
try {
    & $rscript "scripts/homologar_datos_biodiversidad.R"
    if ($LASTEXITCODE -ne 0) { throw "La homologacion termino con codigo $LASTEXITCODE" }

    & $rscript "scripts/02_analisis_biodiversidad_mapgl.R"
    if ($LASTEXITCODE -ne 0) { throw "El analisis termino con codigo $LASTEXITCODE" }

    & $rscript "scripts/preparar_datos_shiny.R"
    if ($LASTEXITCODE -ne 0) { throw "La preparacion de datos termino con codigo $LASTEXITCODE" }

    & $rscript "scripts/enriquecer_especies_iucn.R"
    if ($LASTEXITCODE -ne 0) { throw "El enriquecimiento UICN termino con codigo $LASTEXITCODE" }
}
finally {
    Pop-Location
}
