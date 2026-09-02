# ==============================================================================
# DESPLEGAR_SHINYAPPS.R: Publicación Optimizada en shinyapps.io
# Municipalidad Provincial de Anta - Gerencia de Desarrollo Urbano y Rural (GDUR)
# ==============================================================================

if (dir.exists(".r-library")) {
  .libPaths(c(file.path(getwd(), ".r-library"), .libPaths()))
}

# Configurar Posit Package Manager con binarios para Ubuntu 22.04 (Jammy)
options(repos = c(CRAN = "https://packagemanager.posit.co/cran/__linux__/jammy/latest"))

suppressPackageStartupMessages({
  library(rsconnect)
})

cat("==============================================================================\n")
cat("🚀 PUBLICACIÓN EN SHINYAPPS.IO - BIODIVERSIDAD ANTA 2026\n")
cat("==============================================================================\n\n")

archivos_despliegue <- c(
  "app.R",
  "DESCRIPTION",
  list.files("R", pattern = "\\.R$", full.names = TRUE),
  c("www/custom.css", "www/logo_anta.jpg"),
  # RDS para carga rápida; los CSV voluminosos se generan al descargarlos.
  list.files("outputs/analisis_biodiversidad", pattern = "\\.(rds|geojson)$", full.names = TRUE),
  c(
    "outputs/analisis_biodiversidad/resumen_distritos.csv",
    "outputs/analisis_biodiversidad/singularidad_distritos.csv",
    "outputs/analisis_biodiversidad/recambio_jaccard_distritos.csv",
    "outputs/analisis_biodiversidad/cobertura_cuadricula_5km.csv"
  )
)

archivos_despliegue <- gsub("^\\./", "", archivos_despliegue)
archivos_faltantes <- archivos_despliegue[!file.exists(archivos_despliegue)]
if (length(archivos_faltantes) > 0) {
  stop("No se puede publicar: faltan archivos requeridos: ", paste(archivos_faltantes, collapse = ", "))
}

tamanio_mb <- sum(file.info(archivos_despliegue)$size) / 1024^2
cat(sprintf("Tamaño del paquete: %.2f MiB\n", tamanio_mb))
cat("Archivos incluidos en el paquete (", length(archivos_despliegue), " archivos):\n", sep = "")

cuentas <- rsconnect::accounts()
if (nrow(cuentas) == 0) {
  cat("\n⚠️ No se encontró ninguna cuenta de shinyapps.io configurada.\n")
} else {
  cat("\nDesplegando en la cuenta:", cuentas$name[1], "...\n")
  
  rsconnect::deployApp(
    appDir = getwd(),
    appFiles = archivos_despliegue,
    appName = "biodiversidad_anta_2026",
    appTitle = "Sistema de Biodiversidad Provincial de Anta (GDUR)",
    forceUpdate = TRUE,
    lint = FALSE
  )
  
  cat("\n🎉 ¡Despliegue completado exitosamente!\n")
}
