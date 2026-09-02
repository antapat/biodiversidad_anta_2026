# Verificación de sintaxis y carga de módulos Shiny
.libPaths(c(file.path(getwd(), ".r-library"), .libPaths()))

suppressPackageStartupMessages({
  library(shiny)
  library(bslib)
  library(reactable)
  library(mapgl)
  library(plotly)
  library(dplyr)
  library(sf)
  library(htmltools)
})

invisible(try(Sys.setlocale("LC_CTYPE", "English_United States.utf8"), silent = TRUE))

message("Cargando funciones y módulos...")
source("R/utils_data.R", encoding = "UTF-8")
source("R/mod_resumen_ejecutivo.R", encoding = "UTF-8")
source("R/mod_explorador_distrital.R", encoding = "UTF-8")
source("R/mod_delimitacion_poligono.R", encoding = "UTF-8")
source("R/mod_ebird_aves.R", encoding = "UTF-8")
source("R/mod_mapa_cobertura.R", encoding = "UTF-8")
source("R/mod_recambio_ecologico.R", encoding = "UTF-8")
source("R/mod_metodologia_descarga.R", encoding = "UTF-8")

message("Probando caché de datos compartido...")
datos <- load_app_data()
stopifnot(identical(datos, load_app_data()))

message(sprintf("Especies Totales: %d | Ocurrencias sf: %d | Aves eBird: %d en %d hotspots | Distritos: %d", 
                nrow(datos$especies), ifelse(is.null(datos$ocurrencias), 0, nrow(datos$ocurrencias)),
                nrow(datos$ebird_especies), nrow(datos$ebird_resumen), nrow(datos$resumen)))
message("¡Todos los módulos y funciones auxiliares cargaron exitosamente!")
