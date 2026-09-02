# Diagnosticar errores de KPI y mapgl::cluster_options
.libPaths(c(file.path(getwd(), ".r-library"), .libPaths()))
suppressPackageStartupMessages({
  library(mapgl)
  library(dplyr)
})

cat("=== Argumentos de mapgl::cluster_options ===\n")
print(args(mapgl::cluster_options))

cat("\n=== Columnas de especies_por_distrito.rds ===\n")
esp <- readRDS("outputs/analisis_biodiversidad/especies_por_distrito.rds")
print(names(esp))
print(head(esp, 2))

cat("\n=== Columnas de resumen_distritos.csv ===\n")
res <- read.csv("outputs/analisis_biodiversidad/resumen_distritos.csv")
print(names(res))
print(head(res, 2))
