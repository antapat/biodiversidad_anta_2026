# =============================================================================
# 03_recuperar_ordenar_ebird_anta.R
# Consolidación de datos de eBird en los 17 Hotspots de la provincia de Anta,
# validación taxonómica con avesperu 2026 y categorización de conservación.
# =============================================================================

.libPaths(c(file.path(getwd(), ".r-library"), .libPaths()))

suppressPackageStartupMessages({
  library(sf)
  library(dplyr)
  library(tidyr)
  library(janitor)
  library(avesperu)
  library(jsonlite)
})

options(scipen = 999)
sf_use_s2(FALSE)

dir.create("outputs/analisis_biodiversidad", recursive = TRUE, showWarnings = FALSE)

# -----------------------------------------------------------------------------
# 1. Definición de los 17 Hotspots Oficiales de eBird en la Provincia de Anta
# -----------------------------------------------------------------------------
message("=== 1. Definiendo los 17 Hotspots de eBird en Anta ===")

hotspots_anta <- tibble::tribble(
  ~id_hotspot, ~nombre_hotspot,                                           ~url_ebird,                                     ~utm_x,  ~utm_y,
  "L782919",   "Parque Arqueológico Choquequirao",                        "https://ebird.org/hotspot/L782919/bird-list",    730235, 8518378,
  "L8571886",  "Laguna Humantay",                                         "https://ebird.org/hotspot/L8571886/bird-list",   761576, 8519678,
  "L15073939", "Laguna Humantay - Caminata Puesto de Control",           "https://ebird.org/hotspot/L15073939/bird-list",  762596, 8518704,
  "L5065776",  "Mirador de Condor",                                       "https://ebird.org/hotspot/L5065776/bird-list",   772687, 8498012,
  "L5065724",  "Yoga Limatambo Hotel",                                    "https://ebird.org/hotspot/L5065724/bird-list",   770811, 8505210,
  "L4820432",  "Reposo del Angel",                                        "https://ebird.org/hotspot/L4820432/bird-list",   770654, 8505398,
  "L8413446",  "Pincopata EcoCamp",                                       "https://ebird.org/hotspot/L8413446/bird-list",   767058, 8507193,
  "L13016446", "Humedal del Yungaqui",                                    "https://ebird.org/hotspot/L13016446/bird-list",  805612, 8507935,
  "L5054377",  "Represa Chacan",                                          "https://ebird.org/hotspot/L5054377/bird-list",   810745, 8512843,
  "L892475",   "Laguna Huaypo",                                           "https://ebird.org/hotspot/L892475/bird-list",    811011, 8516648,
  "L4544771",  "Laguna Loocray Huayllacocha",                             "https://ebird.org/hotspot/L4544771/bird-list",   806299, 8516035,
  "L16831267", "Zurite Qente Qentiyoc",                                    "https://ebird.org/hotspot/L16831267/bird-list",  797636, 8513296,
  "L8166287",  "Sitio Arqueologico de Killarumiyoc",                      "https://ebird.org/hotspot/L8166287/bird-list",   791167, 8512001,
  "L3483388",  "Soraypampa",                                              "https://ebird.org/hotspot/L3483388/bird-list",   762812, 8517590,
  "L21694969", "Paso Salkantay",                                          "https://ebird.org/hotspot/L21694969/bird-list",  764317, 8522731,
  "L33530159", "Santuario Historico Machu Picchu - Challacancha a Soraypampa", "https://ebird.org/hotspot/L33530159/bird-list", 763177, 8515610,
  "L6347866",  "Puente Cunyac",                                           "https://ebird.org/hotspot/L6347866/bird-list",   762402, 8499330
)

# Convertir hotspots a objeto espacial sf (UTM 18S)
hotspots_sf_utm <- st_as_sf(hotspots_anta, coords = c("utm_x", "utm_y"), crs = 32718)
hotspots_sf_4326 <- st_transform(hotspots_sf_utm, 4326)

# Asignar distrito de ubicación para referencia geográfica del hotspot
dist_path <- "data/spatial/DISTRITOS_PROV_ANTA.shp"
if (file.exists(dist_path)) {
  districts <- st_read(dist_path, quiet = TRUE) |>
    st_make_valid() |>
    st_transform(4326) |>
    transmute(distrito_ubicacion = tools::toTitleCase(tolower(as.character(NOMBDIST))))
  
  hotspots_sf_4326 <- st_join(hotspots_sf_4326, districts, join = st_intersects) |>
    mutate(distrito_ubicacion = ifelse(is.na(distrito_ubicacion), "Anta (Límite)", distrito_ubicacion))
} else {
  hotspots_sf_4326$distrito_ubicacion <- "Anta"
}

hotspots_sf_utm$distrito_ubicacion <- hotspots_sf_4326$distrito_ubicacion

# -----------------------------------------------------------------------------
# 2. Recuperación de Observaciones de Aves en el Ámbito de cada Hotspot eBird
# -----------------------------------------------------------------------------
message("=== 2. Recuperando registros biológicos asociados a cada Hotspot eBird ===")

# Cruzamos espacialmente las observaciones de aves con el radio de cada hotspot
occ_sf <- readRDS("outputs/analisis_biodiversidad/ocurrencias_puntos_sf.rds") |>
  filter(grupo == "fauna" | clase == "Aves")

# Radio de 1500 m para capturar el esfuerzo de observación del hotspot
hotspots_buffer_utm <- st_buffer(hotspots_sf_utm, dist = 1500)
hotspots_buffer_4326 <- st_transform(hotspots_buffer_utm, 4326)

# Intersección espacial exclusiva para los hotspots
occ_por_hotspot <- st_join(
  occ_sf,
  hotspots_buffer_4326[c("id_hotspot", "nombre_hotspot", "url_ebird", "distrito_ubicacion")],
  join = st_intersects
) |>
  filter(!is.na(id_hotspot)) |>
  st_drop_geometry()

message(sprintf("Registros de aves en hotspots eBird: %d observaciones de %d especies.",
                nrow(occ_por_hotspot), n_distinct(occ_por_hotspot$species)))

# Consolidar tabla de especies exclusivamente por Hotspot eBird
aves_hotspots_resumen <- occ_por_hotspot |>
  group_by(id_hotspot, nombre_hotspot, url_ebird, distrito_ubicacion, species) |>
  summarise(
    nombre_cientifico = first(nombre_cientifico),
    n_observaciones = n(),
    primer_anio = suppressWarnings(min(year, na.rm = TRUE)),
    ultimo_anio = suppressWarnings(max(year, na.rm = TRUE)),
    .groups = "drop"
  ) |>
  mutate(
    primer_anio = ifelse(is.infinite(primer_anio), NA, primer_anio),
    ultimo_anio = ifelse(is.infinite(ultimo_anio), NA, ultimo_anio)
  )

# -----------------------------------------------------------------------------
# 3. Validación Taxonómica con avesperu (versión oficial 2026.v1 / UNOP)
# -----------------------------------------------------------------------------
message("=== 3. Validación taxonómica con la Lista Oficial de Aves del Perú (avesperu) ===")

data("aves_peru_2026_v1", package = "avesperu")

aves_validadas <- aves_hotspots_resumen |>
  left_join(
    aves_peru_2026_v1 |>
      select(
        scientific_name,
        orden = order_name,
        familia = family_name,
        nombre_espanol = spanish_name,
        nombre_ingles = english_name,
        estatus_residencia = status
      ),
    by = c("species" = "scientific_name")
  )

# -----------------------------------------------------------------------------
# 4. Asignación de Estado de Conservación (D.S. 004-2014-MINAGRI, IUCN, CITES)
# -----------------------------------------------------------------------------
message("=== 4. Asignando categorías de conservación oficiales ===")

aves_validadas <- aves_validadas |>
  mutate(
    # Categorización nacional D.S. Nº 004-2014-MINAGRI
    ds_004_2014 = case_when(
      species == "Vultur gryphus" ~ "En Peligro (EN)",
      species == "Falco peregrinus" ~ "Casi Amenazado (NT)",
      species == "Phoenicopterus chilensis" ~ "Casi Amenazado (NT)",
      species == "Oreomanes fraseri" ~ "Vulnerable (VU)",
      species == "Cinclodes aricomae" ~ "En Peligro Crítico (CR)",
      species == "Anairetes alpinus" ~ "En Peligro Crítico (CR)",
      species == "Podiceps taczanowskii" ~ "En Peligro Crítico (CR)",
      TRUE ~ "No Amenazada"
    ),
    
    # Categorización global UICN
    iucn_categoria = case_when(
      species %in% c("Cinclodes aricomae", "Anairetes alpinus", "Podiceps taczanowskii") ~ "En Peligro Crítico (CR)",
      species %in% c("Vultur gryphus", "Oreomanes fraseri") ~ "Vulnerable (VU)",
      species %in% c("Falco peregrinus", "Phoenicopterus chilensis") ~ "Casi Amenazada (NT)",
      TRUE ~ "Preocupación Menor (LC)"
    ),
    
    # Apéndices CITES
    cites_apendice = case_when(
      species %in% c("Vultur gryphus", "Falco peregrinus") ~ "Apéndice I",
      species %in% c("Phoenicopterus chilensis", "Buteo polyosoma", "Geranoaetus polyosoma", "Geranoaetus melanoleucus") ~ "Apéndice II",
      TRUE ~ "No CITES"
    ),
    
    # Estatus de endemismo
    es_endemica_peru = (estatus_residencia == "Endémico")
  ) |>
  arrange(nombre_hotspot, desc(n_observaciones))

# -----------------------------------------------------------------------------
# 5. Métricas por Hotspot para el Mapa de eBird
# -----------------------------------------------------------------------------
message("=== 5. Generando capas espaciales de los Hotspots de eBird ===")

hotspots_metricas <- aves_validadas |>
  group_by(id_hotspot, nombre_hotspot, url_ebird, distrito_ubicacion) |>
  summarise(
    total_especies_ebird = n_distinct(species),
    total_observaciones_ebird = sum(n_observaciones),
    especies_amenazadas = sum(ds_004_2014 != "No Amenazada" | iucn_categoria %in% c("Vulnerable (VU)", "En Peligro (EN)", "En Peligro Crítico (CR)")),
    especies_endemicas = sum(isTRUE(es_endemica_peru)),
    ultimo_anio = max(ultimo_anio, na.rm = TRUE),
    .groups = "drop"
  )

# Unir métricas a la capa espacial sf de los 17 hotspots
hotspots_sf_final <- hotspots_sf_4326 |>
  left_join(hotspots_metricas, by = c("id_hotspot", "nombre_hotspot", "url_ebird", "distrito_ubicacion")) |>
  mutate(
    across(c(total_especies_ebird, total_observaciones_ebird, especies_amenazadas, especies_endemicas), ~ifelse(is.na(.x), 0, .x)),
    tooltip = paste0(
      "<b>Sitio eBird: ", nombre_hotspot, "</b><br>",
      "Ubicación: ", distrito_ubicacion, "<br>",
      "Especies de Aves en eBird: ", total_especies_ebird, "<br>",
      "Observaciones en eBird: ", total_observaciones_ebird, "<br>",
      "Amenazadas / Endémicas: ", especies_amenazadas, " / ", especies_endemicas
    )
  )

# -----------------------------------------------------------------------------
# 6. Exportar Productos Listos para el Módulo Shiny
# -----------------------------------------------------------------------------
st_write(hotspots_sf_final, "outputs/analisis_biodiversidad/ebird_hotspots_anta.geojson", delete_dsn = TRUE, quiet = TRUE)
saveRDS(aves_validadas, "outputs/analisis_biodiversidad/ebird_especies_consolidadas.rds")
write.csv(aves_validadas, "outputs/analisis_biodiversidad/ebird_especies_consolidadas.csv", row.names = FALSE, fileEncoding = "UTF-8")
saveRDS(hotspots_metricas, "outputs/analisis_biodiversidad/ebird_hotspots_resumen.rds")
write.csv(hotspots_metricas, "outputs/analisis_biodiversidad/ebird_hotspots_resumen.csv", row.names = FALSE, fileEncoding = "UTF-8")

message(sprintf("¡Proceso completado! %d especies consolidadas en los 17 hotspots eBird de Anta.",
                nrow(aves_validadas)))
