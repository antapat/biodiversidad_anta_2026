# ============================================================
# 1. LIBRERÍAS
# ============================================================
library(peruocc)
library(tidyverse)
library(sf)
library(readr)

# ============================================================
# 2. CONFIGURACIÓN
# ============================================================

# Carpeta de salida
ruta <- "D:/biodiversidad_2026"
if (!dir.exists(ruta)) dir.create(ruta, recursive = TRUE)

provincia    <- "Anta"
departamento <- "Cusco"

# Distritos que se buscan por nombre (API distrital)
# Actualización PDM Cusco Sector II - Subsector 2 Huarocondo / Subsector 3 Zurite
distritos <- c(
  "Anta", "Zurite", "Ancahuasi", "Huarocondo",
  "Cachimayo", "Pucyura", "Limatambo", "Chinchaypujio"
)

# Mollepata se busca por polígono (no está bien resuelto por nombre en la API)
mollepata <- sf::read_sf("data\\spatial\\DISTRITOS_PROV_ANTA.shp") |>
  dplyr::filter(NOMBDIST == "MOLLEPATA")

grupos <- c("flora", "fauna")

# ============================================================
# 3. BÚSQUEDA DE ESPECIES POR DISTRITO (flora y fauna)
# ============================================================
# Se guarda un resultado por distrito y grupo, para poder revisar
# cada búsqueda individualmente si hace falta.

resultados_distritos <- purrr::map(
  distritos,
  function(d) {
    purrr::map(
      grupos,
      function(g) {
        buscar_especies_distrito(
          distrito       = d,
          provincia      = provincia,
          departamento   = departamento,
          grupo          = g,
          limite_por_api = NULL
        )
      }
    ) |> purrr::set_names(grupos)
  }
) |> purrr::set_names(distritos)

# ============================================================
# 4. BÚSQUEDA DE ESPECIES EN MOLLEPATA (por polígono)
# ============================================================

resultados_mollepata <- purrr::map(
  grupos,
  function(g) {
    buscar_especies_poligono(
      poligono       = mollepata,
      nombre         = "Mollepata",
      grupo          = g,
      limite_por_api = NULL
    )
  }
) |> purrr::set_names(grupos)

# ============================================================
# 5. CONSOLIDACIÓN EN UNA SOLA BASE DE DATOS
# ============================================================

# 5.1 Ocurrencias de todos los distritos (nombre), por grupo
ocurrencias_distritos <- purrr::map_dfr(
  grupos,
  function(g) {
    purrr::map_dfr(
      distritos,
      function(d) {
        resultados_distritos[[d]][[g]]$ocurrencias |> tibble::as_tibble()
      }
    ) |> dplyr::mutate(grupo = g)
  }
)

# 5.2 Ocurrencias de Mollepata (polígono), por grupo
ocurrencias_mollepata <- purrr::map_dfr(
  grupos,
  function(g) {
    resultados_mollepata[[g]]$ocurrencias |>
      tibble::as_tibble() |>
      dplyr::mutate(grupo = g)
  }
)

# 5.3 Base de datos consolidada ÚNICA: los 8 distritos + Mollepata,
#     flora y fauna juntos en una sola tabla
ocurrencias_totales <- dplyr::bind_rows(
  ocurrencias_distritos,
  ocurrencias_mollepata
)

ocurrencias_totales

# ============================================================
# 6. LISTAS DE ESPECIES (a partir de la base consolidada)
# ============================================================

lista_especies_flora <- ocurrencias_totales |>
  dplyr::filter(grupo == "flora") |>
  dplyr::select(scientificName, taxonRank, kingdom, order, family, genus, species) |>
  dplyr::filter(taxonRank %in% c("SPECIES", "SUBSPECIES")) |>
  dplyr::distinct()

lista_especies_fauna <- ocurrencias_totales |>
  dplyr::filter(grupo == "fauna") |>
  dplyr::select(scientificName, taxonRank, kingdom, order, family, genus, species) |>
  dplyr::filter(taxonRank %in% c("SPECIES", "SUBSPECIES")) |>
  dplyr::distinct()

lista_especies_flora
lista_especies_fauna

# ============================================================
# 7. LIMPIEZA DE COORDENADAS
# ============================================================

ocurrencias_validas <- ocurrencias_totales |>
  dplyr::filter(!is.na(decimalLongitude), !is.na(decimalLatitude))

n_descartados <- nrow(ocurrencias_totales) - nrow(ocurrencias_validas)
if (n_descartados > 0) {
  message(n_descartados, " registro(s) sin coordenadas fueron excluidos del shapefile.")
}

# ============================================================
# 8. EXPORTACIÓN
# ============================================================

# 8.1 Listas de especies (CSV)
readr::write_csv(lista_especies_flora, file.path(ruta, "lista_especies_flora.csv"))
readr::write_csv(lista_especies_fauna, file.path(ruta, "lista_especies_fauna.csv"))

# 8.2 Base de datos consolidada completa (CSV, sin geometría)
readr::write_csv(ocurrencias_totales, file.path(ruta, "ocurrencias_totales_consolidado.csv"))

# 8.3 Shapefile único con TODAS las ocurrencias (flora + fauna, todos los distritos)
ocurrencias_sf <- sf::st_as_sf(
  ocurrencias_validas,
  coords = c("decimalLongitude", "decimalLatitude"),
  crs    = 4326  # WGS84
)

sf::st_write(
  ocurrencias_sf,
  file.path(ruta, "ocurrencias_flora_fauna_consolidado.shp"),
  delete_dsn = TRUE
)

# 8.4 (Opcional) Shapefiles separados por grupo, a partir de la misma base consolidada
flora_sf <- ocurrencias_sf |> dplyr::filter(grupo == "flora")
fauna_sf <- ocurrencias_sf |> dplyr::filter(grupo == "fauna")

sf::st_write(flora_sf, file.path(ruta, "ocurrencias_flora_consolidado.shp"), delete_dsn = TRUE)
sf::st_write(fauna_sf, file.path(ruta, "ocurrencias_fauna_consolidado.shp"), delete_dsn = TRUE)