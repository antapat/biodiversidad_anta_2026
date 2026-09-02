#!/usr/bin/env Rscript

# Preparación de datos optimizados para Shiny App
.libPaths(c(file.path(getwd(), ".r-library"), .libPaths()))

suppressPackageStartupMessages({
  library(sf)
  library(dplyr)
  library(jsonlite)
})

source("R/utils_homologacion.R")

options(scipen = 999)
sf_use_s2(FALSE)

dir.create("outputs/analisis_biodiversidad", recursive = TRUE, showWarnings = FALSE)

occ_path <- "data/spatial/ocurrencias_homologadas.gpkg"
dist_path <- "data/spatial/DISTRITOS_PROV_ANTA.shp"

if (!file.exists(occ_path)) {
  stop("No se encontró la capa homologada. Ejecute 'scripts/homologar_datos_biodiversidad.R'.")
}

message("Leyendo capas espaciales...")
occ <- st_read(occ_path, quiet = TRUE) |>
  st_transform(4326) |>
  mutate(
    species = trimws(as.character(species)),
    grupo = tolower(as.character(grupo)),
    source = normalizar_fuente_descarga(fuente_descarga),
    plataforma = as.character(plataforma_origen),
    coordinate_uncertainty_m = suppressWarnings(as.numeric(crdnUIM)),
    event_date = as.Date(substr(as.character(eventDt), 1, 10)),
    year = as.integer(format(event_date, "%Y")),
    reino = ifelse(grupo == "flora", "Flora", "Fauna")
  )

districts <- st_read(dist_path, quiet = TRUE) |>
  st_make_valid() |>
  st_transform(4326) |>
  transmute(distrito = tools::toTitleCase(tolower(as.character(NOMBDIST))))

message("Realizando unión espacial con distritos...")
valid <- occ |>
  filter(
    taxnRnk %in% c("SPECIES", "SUBSPECIES"),
    !is.na(species), species != "",
    is.na(coordinate_uncertainty_m) | coordinate_uncertainty_m <= 5000
  ) |>
  st_join(districts, left = FALSE, join = st_within)

# Guardar objeto sf completo de ocurrencias válidas para intersección espacial
occ_sf_clean <- valid |>
  transmute(
    species,
    nombre_cientifico = as.character(scntfcN),
    grupo,
    reino,
    clase = as.character(class),
    orden = as.character(order),
    familia = as.character(family),
    fuente = source,
    plataforma_origen = plataforma,
    dataset_origen = as.character(dataset_origen),
    canales_descarga = as.character(canales_descarga),
    id_registro_origen = as.character(id_registro_origen),
    incertidumbre_m = coordinate_uncertainty_m,
    distrito,
    year,
    tooltip = paste0(
      "<b><i>", species, "</i></b><br>", reino, " · ", plataforma_origen,
      "<br>Canal: ", fuente, "<br>Distrito: ", distrito,
      "<br>Año: ", ifelse(is.na(year), "S/F", year)
    )
  )

saveRDS(occ_sf_clean, "outputs/analisis_biodiversidad/ocurrencias_puntos_sf.rds")

# Capa liviana exclusiva para visualización. La consulta espacial conserva la
# capa completa anterior; el mapa agrupa observaciones que comparten una
# posición prácticamente idéntica (5 decimales, ~1 m en el ecuador).
message("Construyendo capa agregada para visualización web...")
coords_mapa <- st_coordinates(occ_sf_clean)

ocurrencias_mapa <- occ_sf_clean |>
  st_drop_geometry() |>
  mutate(
    lon_mapa = round(coords_mapa[, "X"], 5),
    lat_mapa = round(coords_mapa[, "Y"], 5)
  ) |>
  group_by(lon_mapa, lat_mapa) |>
  summarise(
    grupo = if (n_distinct(grupo) == 1) first(grupo) else "mixto",
    n_registros = n(),
    n_especies = n_distinct(species),
    plataformas = paste(sort(unique(plataforma_origen[!is.na(plataforma_origen)])), collapse = " / "),
    distritos = paste(sort(unique(distrito[!is.na(distrito)])), collapse = ", "),
    .groups = "drop"
  ) |>
  mutate(
    tooltip = paste0(
      "<b>", format(n_registros, big.mark = ","), " registros</b><br>",
      format(n_especies, big.mark = ","), " especies · ",
      ifelse(grupo == "mixto", "Flora y fauna", tools::toTitleCase(grupo)),
      "<br>Plataforma: ", plataformas,
      "<br>Distrito: ", distritos
    )
  ) |>
  st_as_sf(coords = c("lon_mapa", "lat_mapa"), crs = 4326, remove = FALSE)

saveRDS(ocurrencias_mapa, "outputs/analisis_biodiversidad/ocurrencias_mapa_sf.rds")

# Conteo de distritos por especie para determinar exclusividad
species_dist_count <- valid |>
  st_drop_geometry() |>
  distinct(species, distrito) |>
  count(species, name = "n_distritos_total")

message("Construyendo tabla agregada de especies por distrito...")
especies_distrito <- valid |>
  st_drop_geometry() |>
  group_by(distrito, species, reino) |>
  summarise(
    nombre_cientifico = first(scntfcN),
    clase = first(class),
    orden = first(order),
    familia = first(family),
    genero = first(genus),
    n_registros = n(),
    fuentes = paste(sort(unique(source[!is.na(source)])), collapse = " / "),
    plataformas = paste(sort(unique(plataforma[!is.na(plataforma)])), collapse = " / "),
    primer_anio = suppressWarnings(min(year, na.rm = TRUE)),
    ultimo_anio = suppressWarnings(max(year, na.rm = TRUE)),
    .groups = "drop"
  ) |>
  left_join(species_dist_count, by = "species") |>
  mutate(
    es_exclusiva = (n_distritos_total == 1),
    primer_anio = ifelse(is.infinite(primer_anio), NA, primer_anio),
    ultimo_anio = ifelse(is.infinite(ultimo_anio), NA, ultimo_anio)
  ) |>
  arrange(distrito, desc(n_registros))

# Guardar RDS y CSV
saveRDS(especies_distrito, "outputs/analisis_biodiversidad/especies_por_distrito.rds")
write.csv(especies_distrito, "outputs/analisis_biodiversidad/especies_por_distrito.csv", row.names = FALSE)

message(sprintf(
  "Listo: %d especies distritales, %d ocurrencias analíticas y %d puntos agregados para el mapa.",
  nrow(especies_distrito), nrow(occ_sf_clean), nrow(ocurrencias_mapa)
))
