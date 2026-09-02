#!/usr/bin/env Rscript

# Prueba de regresión del flujo botón -> solicitud al mapa -> informe espacial.
.libPaths(c(file.path(getwd(), ".r-library"), .libPaths()))
invisible(try(Sys.setlocale("LC_CTYPE", "English_United States.utf8"), silent = TRUE))

suppressPackageStartupMessages({
  library(shiny)
  library(dplyr)
  library(sf)
  library(mapgl)
  library(geojsonsf)
  library(jsonlite)
})

source("R/utils_data.R", encoding = "UTF-8")
source("R/mod_delimitacion_poligono.R", encoding = "UTF-8")

datos <- load_app_data(refresh = TRUE)
stopifnot(nrow(datos$ocurrencias) == 67797)

# Área de 1 km alrededor de una ocurrencia conocida, convertida al mismo
# FeatureCollection que devuelve el control de dibujo de MapLibre.
centro <- datos$ocurrencias[1, ] |>
  st_transform(32718) |>
  st_buffer(1000) |>
  st_transform(4326)

payload <- st_sf(id = 1L, geometry = st_geometry(centro)) |>
  geojsonsf::sf_geojson() |>
  jsonlite::fromJSON(simplifyVector = FALSE)

shiny::testServer(
  mod_delimitacion_poligono_server,
  args = list(
    sf_ocurrencias = reactive(datos$ocurrencias),
    sf_ocurrencias_mapa = reactive(datos$ocurrencias_mapa),
    sf_distritos = reactive(datos$distritos)
  ),
  {
    # Completar el ciclo inicial de reactivos, como ocurre antes de que un
    # usuario pueda pulsar el botón en el navegador.
    session$flushReact()
    session$setInputs(btn_analizar_dibujo = 1)
    stopifnot(isTRUE(consulta_pendiente()))

    session$setInputs(mapa_ocurrencias_drawn_features = payload)
    session$flushReact()

    stopifnot(!isTRUE(consulta_pendiente()))
    stopifnot(!is.null(resultado_zona()), nrow(resultado_zona()) > 0)
    stopifnot(!is.null(area_zona_ha()), area_zona_ha() > 0)

    message(sprintf(
      "Módulo de delimitación correcto: %.2f ha, %d especies.",
      area_zona_ha(), nrow(resultado_zona())
    ))
  }
)
