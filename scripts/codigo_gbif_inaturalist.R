# =============================================================================
# SCRIPT: Consolidación de Biodiversidad de la Provincia de Anta (9 Distritos)
# Fuentes: GBIF + iNaturalist (peruocc) + eBird (rvest) + avesperu (UNOP)
# =============================================================================

# ============================================================
# 1. LIBRERÍAS
# ============================================================
library(peruocc)
library(tidyverse)
library(sf)
library(readr)
library(writexl)
library(rvest)
library(purrr)
library(lubridate)
library(janitor)
library(avesperu)

# ============================================================
# 2. CONFIGURACIÓN DE RUTAS Y ÁMBITO DE ESTUDIO
# ============================================================
# Rutas relativas del proyecto
dir_spatial  <- "data/spatial"
dir_tabular  <- "data/tabular"
dir_outputs  <- "outputs"

# Crear carpetas si no existen
for (dir in c(dir_spatial, dir_tabular, dir_outputs)) {
  if (!dir.exists(dir)) dir.create(dir, recursive = TRUE)
}

# Parámetros geográficos
provincia    <- "Anta"
departamento <- "Cusco"

# Cargar polígono distrital para consultas espaciales personalizadas
poligonos_distritales <- sf::st_read(file.path(dir_spatial, "DISTRITOS_PROV_ANTA.shp"), quiet = TRUE)
mollepata_poly <- poligonos_distritales |> dplyr::filter(NOMBDIST == "MOLLEPATA")

# ============================================================
# 3. BÚSQUEDA DE ESPECIES - FLORA (9 DISTRITOS DE ANTA)
# ============================================================
message(">>> Descargando ocurrencias de FLORA para los 9 distritos...")

resultado_anta_flora <- buscar_especies_distrito(
  distrito = "Anta", provincia = provincia, departamento = departamento,
  grupo = "flora", limite_por_api = NULL
)

resultado_zurite_flora <- buscar_especies_distrito(
  distrito = "Zurite", provincia = provincia, departamento = departamento,
  grupo = "flora", limite_por_api = NULL
)

resultado_ancahuasi_flora <- buscar_especies_distrito(
  distrito = "Ancahuasi", provincia = provincia, departamento = departamento,
  grupo = "flora", limite_por_api = NULL
)

resultado_huarocondo_flora <- buscar_especies_distrito(
  distrito = "Huarocondo", provincia = provincia, departamento = departamento,
  grupo = "flora", limite_por_api = NULL
)

resultado_cachimayo_flora <- buscar_especies_distrito(
  distrito = "Cachimayo", provincia = provincia, departamento = departamento,
  grupo = "flora", limite_por_api = NULL
)

resultado_pucyura_flora <- buscar_especies_distrito(
  distrito = "Pucyura", provincia = provincia, departamento = departamento,
  grupo = "flora", limite_por_api = NULL
)

resultado_limatambo_flora <- buscar_especies_distrito(
  distrito = "Limatambo", provincia = provincia, departamento = departamento,
  grupo = "flora", limite_por_api = NULL
)

resultado_chinchaypujio_flora <- buscar_especies_distrito(
  distrito = "Chinchaypujio", provincia = provincia, departamento = departamento,
  grupo = "flora", limite_por_api = NULL
)

resultado_mollepata_flora <- buscar_especies_poligono(
  poligono = mollepata_poly, nombre = "Mollepata",
  grupo = "flora", limite_por_api = NULL
)

# ------------------------------------------------------------
# 3.1 Consolidado provincial de ocurrencias de Flora
# ------------------------------------------------------------
flora_anta <- dplyr::bind_rows(
  resultado_anta_flora$ocurrencias          |> tibble::as_tibble(),
  resultado_zurite_flora$ocurrencias        |> tibble::as_tibble(),
  resultado_ancahuasi_flora$ocurrencias     |> tibble::as_tibble(),
  resultado_huarocondo_flora$ocurrencias    |> tibble::as_tibble(),
  resultado_cachimayo_flora$ocurrencias     |> tibble::as_tibble(),
  resultado_pucyura_flora$ocurrencias       |> tibble::as_tibble(),
  resultado_limatambo_flora$ocurrencias     |> tibble::as_tibble(),
  resultado_chinchaypujio_flora$ocurrencias |> tibble::as_tibble(),
  resultado_mollepata_flora$ocurrencias     |> tibble::as_tibble()
) |> 
  dplyr::distinct()

# ------------------------------------------------------------
# 3.2 Lista taxonómica única de especies de Flora
# ------------------------------------------------------------
lista_de_especies_flora <- flora_anta |>
  dplyr::select(
    scientificName, taxonRank,
    kingdom, order, family, genus, species
  ) |>
  dplyr::filter(taxonRank %in% c("SPECIES", "SUBSPECIES")) |>
  dplyr::distinct() |> 
  dplyr::arrange(family, species)

message("Total especies de flora identificadas: ", nrow(lista_de_especies_flora))

# ============================================================
# 4. BÚSQUEDA DE ESPECIES - FAUNA (9 DISTRITOS DE ANTA)
# ============================================================
message(">>> Descargando ocurrencias de FAUNA para los 9 distritos...")

resultado_anta_fauna <- buscar_especies_distrito(
  distrito = "Anta", provincia = provincia, departamento = departamento,
  grupo = "fauna", limite_por_api = NULL
)

resultado_zurite_fauna <- buscar_especies_distrito(
  distrito = "Zurite", provincia = provincia, departamento = departamento,
  grupo = "fauna", limite_por_api = NULL
)

resultado_ancahuasi_fauna <- buscar_especies_distrito(
  distrito = "Ancahuasi", provincia = provincia, departamento = departamento,
  grupo = "fauna", limite_por_api = NULL
)

resultado_huarocondo_fauna <- buscar_especies_distrito(
  distrito = "Huarocondo", provincia = provincia, departamento = departamento,
  grupo = "fauna", limite_por_api = NULL
)

resultado_cachimayo_fauna <- buscar_especies_distrito(
  distrito = "Cachimayo", provincia = provincia, departamento = departamento,
  grupo = "fauna", limite_por_api = NULL
)

resultado_pucyura_fauna <- buscar_especies_distrito(
  distrito = "Pucyura", provincia = provincia, departamento = departamento,
  grupo = "fauna", limite_por_api = NULL
)

resultado_limatambo_fauna <- buscar_especies_distrito(
  distrito = "Limatambo", provincia = provincia, departamento = departamento,
  grupo = "fauna", limite_por_api = NULL
)

resultado_chinchaypujio_fauna <- buscar_especies_distrito(
  distrito = "Chinchaypujio", provincia = provincia, departamento = departamento,
  grupo = "fauna", limite_por_api = NULL
)

resultado_mollepata_fauna <- buscar_especies_poligono(
  poligono = mollepata_poly, nombre = "Mollepata",
  grupo = "fauna", limite_por_api = NULL
)

# ------------------------------------------------------------
# 4.1 Consolidado provincial de ocurrencias de Fauna
# ------------------------------------------------------------
fauna_anta <- dplyr::bind_rows(
  resultado_anta_fauna$ocurrencias          |> tibble::as_tibble(),
  resultado_zurite_fauna$ocurrencias        |> tibble::as_tibble(),
  resultado_ancahuasi_fauna$ocurrencias     |> tibble::as_tibble(),
  resultado_huarocondo_fauna$ocurrencias    |> tibble::as_tibble(),
  resultado_cachimayo_fauna$ocurrencias     |> tibble::as_tibble(),
  resultado_pucyura_fauna$ocurrencias       |> tibble::as_tibble(),
  resultado_limatambo_fauna$ocurrencias     |> tibble::as_tibble(),
  resultado_chinchaypujio_fauna$ocurrencias |> tibble::as_tibble(),
  resultado_mollepata_fauna$ocurrencias     |> tibble::as_tibble()
) |> 
  dplyr::distinct()

# ------------------------------------------------------------
# 4.2 Lista taxonómica única de especies de Fauna
# ------------------------------------------------------------
lista_de_especies_fauna <- fauna_anta |>
  dplyr::select(
    scientificName, taxonRank,
    kingdom, order, family, genus, species
  ) |>
  dplyr::filter(taxonRank %in% c("SPECIES", "SUBSPECIES")) |>
  dplyr::distinct() |> 
  dplyr::arrange(order, family, species)

message("Total especies de fauna identificadas: ", nrow(lista_de_especies_fauna))

# ============================================================
# 5. EXPORTACIÓN DE TABLAS (CSV) Y CAPAS ESPACIALES (SHP)
# ============================================================

# ------------------------------------------------------------
# 5.1 Exportar listas taxonómicas únicas (CSV)
# ------------------------------------------------------------
readr::write_csv(
  lista_de_especies_flora,
  file.path(dir_tabular, "lista_especies_flora.csv")
)

readr::write_csv(
  lista_de_especies_fauna,
  file.path(dir_tabular, "lista_especies_fauna.csv")
)
message("Listas de especies guardadas en '", dir_tabular, "'")

# ------------------------------------------------------------
# 5.2 Preparar ocurrencias espaciales consolidadas
# ------------------------------------------------------------
flora_tagged <- flora_anta |> dplyr::mutate(grupo = "flora")
fauna_tagged <- fauna_anta |> dplyr::mutate(grupo = "fauna")

ocurrencias_totales <- dplyr::bind_rows(flora_tagged, fauna_tagged)

# Filtrar registros con coordenadas válidas
ocurrencias_validas <- ocurrencias_totales |>
  dplyr::filter(!is.na(decimalLongitude), !is.na(decimalLatitude))

n_descartados <- nrow(ocurrencias_totales) - nrow(ocurrencias_validas)
if (n_descartados > 0) {
  message("Aviso: ", n_descartados, " registro(s) sin coordenadas fueron excluidos del shapefile.")
}

# Convertir a objeto espacial sf (WGS84 / EPSG:4326)
ocurrencias_sf <- sf::st_as_sf(
  ocurrencias_validas,
  coords = c("decimalLongitude", "decimalLatitude"),
  crs = 4326
)

# ------------------------------------------------------------
# 5.3 Exportar Shapefiles
# ------------------------------------------------------------
# Shapefile general (Flora + Fauna de los 9 distritos)
sf::st_write(
  ocurrencias_sf,
  file.path(dir_spatial, "ocurrencias_flora_fauna.shp"),
  delete_dsn = TRUE
)

# Shapefiles independientes por grupo
flora_sf <- ocurrencias_sf |> dplyr::filter(grupo == "flora")
fauna_sf <- ocurrencias_sf |> dplyr::filter(grupo == "fauna")

sf::st_write(flora_sf, file.path(dir_spatial, "ocurrencias_flora.shp"), delete_dsn = TRUE)
sf::st_write(fauna_sf, file.path(dir_spatial, "ocurrencias_fauna.shp"), delete_dsn = TRUE)

message("Capas Shapefile guardadas exitosamente en '", dir_spatial, "'")





# ============================================================
# UNIR BASES YA EXPORTADAS (Grupo 1: 4 distritos | Grupo 2: 5 distritos + Mollepata)
# ============================================================
# Este script NO vuelve a consultar la API: parte de los archivos
# que ya se exportaron a disco y los consolida en una sola base.

library(tidyverse)
library(sf)
library(readr)

ruta <- "D:/biodiversidad_2026"

# ------------------------------------------------------------
# 1. LEER SHAPEFILES DE OCURRENCIAS (flora + fauna) DE CADA GRUPO
# ------------------------------------------------------------
# Grupo 1: Anta, Zurite, Ancahuasi, Huarocondo
oc_grupo1 <- sf::st_read(file.path(ruta, 
                                   "data\\spatial\\ocurrencias_flora_fauna.shp"), quiet = TRUE)

# Grupo 2: Cachimayo, Pucyura, Limatambo, Chinchaypujio, Mollepata
oc_grupo2 <- sf::st_read(file.path(ruta, "ocurrencias_flora_fauna_2.shp"), quiet = TRUE)

# Aviso si los nombres de columnas no coinciden (los .shp truncan
# nombres a 10 caracteres, así que puede haber diferencias)
nombres_1 <- names(oc_grupo1)
nombres_2 <- names(oc_grupo2)
if (!identical(sort(nombres_1), sort(nombres_2))) {
  message("Atención: las columnas no coinciden exactamente entre los dos shapefiles.")
  message("Solo en grupo 1: ", paste(setdiff(nombres_1, nombres_2), collapse = ", "))
  message("Solo en grupo 2: ", paste(setdiff(nombres_2, nombres_1), collapse = ", "))
}

# Homogeneizar CRS por si acaso, y unir en una sola capa
oc_grupo2 <- sf::st_transform(oc_grupo2, sf::st_crs(oc_grupo1))

ocurrencias_consolidado <- dplyr::bind_rows(oc_grupo1, oc_grupo2)

ocurrencias_consolidado

# ------------------------------------------------------------
# 2. LEER LAS LISTAS DE ESPECIES YA EXPORTADAS
# ------------------------------------------------------------
# OJO: en la exportación original solo se guardó la lista de flora
# del grupo 2 (lista_especies_flora_2.csv) y la de fauna del grupo 2
# (guardada, por un detalle de nombre, como lista_especies_fauna.csv).
# La lista de flora y fauna del grupo 1 nunca se exportó a CSV por
# separado. Por eso, la forma más confiable de tener la lista de
# especies COMPLETA es reconstruirla desde el shapefile consolidado
# (paso 3), no desde esos CSV parciales.

# ------------------------------------------------------------
# 3. RECONSTRUIR LISTA DE ESPECIES DESDE LA BASE CONSOLIDADA
# ------------------------------------------------------------
# (usar los nombres de columna reales que quedaron en el shapefile;
#  revisa `names(ocurrencias_consolidado)` si algún nombre fue truncado)

lista_especies_flora <- ocurrencias_consolidado |>
  sf::st_drop_geometry() |>
  dplyr::filter(grupo == "flora") |>
  dplyr::select(scntfcN, taxnRnk, kingdom, order, family, genus, species) |>
  dplyr::filter(taxnRnk %in% c("SPECIES", "SUBSPECIES")) |>
  dplyr::distinct()

lista_especies_fauna <- ocurrencias_consolidado |>
  sf::st_drop_geometry() |>
  dplyr::filter(grupo == "fauna") |>
  dplyr::select(scntfcN, taxnRnk, kingdom, order, family, genus, species) |>
  dplyr::filter(taxnRnk %in% c("SPECIES", "SUBSPECIES")) |>
  dplyr::distinct()

lista_especies_flora
lista_especies_fauna

# ------------------------------------------------------------
# 4. EXPORTAR LA BASE CONSOLIDADA FINAL (9 distritos: 8 + Mollepata)
# ------------------------------------------------------------

# 4.1 Shapefile único con todas las ocurrencias
sf::st_write(
  ocurrencias_consolidado,
  file.path(ruta, "data\\ocurrencias_flora_fauna_anta_0803.shp"),
  delete_dsn = TRUE
)

# 4.2 Shapefiles separados por grupo (opcional)
flora_final <- ocurrencias_consolidado |> dplyr::filter(grupo == "flora")
fauna_final <- ocurrencias_consolidado |> dplyr::filter(grupo == "fauna")
flora_final
fauna_final
sf::st_write(flora_final, 
             file.path(ruta, "data\\ocurrencias_flora_anta_0803.shp"), 
             delete_dsn = TRUE)
sf::st_write(fauna_final,
             file.path(ruta, "data\\ocurrencias_fauna_anta_0803.shp"),
             delete_dsn = TRUE)

# 4.3 CSV de la base completa (sin geometría) y de las listas de especies
readr::write_csv(sf::st_drop_geometry(ocurrencias_consolidado),
                 file.path(ruta, "data\\ocurrencias_totales_anta_0803.csv"))
readr::write_csv(lista_especies_flora, 
                 file.path(ruta, "data\\lista_especies_flora_anta_0803.csv"))
readr::write_csv(lista_especies_fauna,
                 file.path(ruta, "data\\lista_especies_fauna_anta_0803.csv"))














# =============================================================================
# 6. MONITOREO DE AVES - eBird + VALIDACIÓN TAXONÓMICA (avesperu)
# =============================================================================
message(">>> Procesando inventarios de aves desde eBird y validación taxonómica...")

# Función para extraer observaciones desde URLs de eBird
get_ebird_info <- function(url) {
  page <- rvest::read_html(url, encoding = "UTF-8")
  
  bird_observations <- page |> 
    rvest::html_nodes(
      xpath = "//*[@id='content']/div/div[3]/div/div[3]/section[1]/ol/li/div[@class='Obs']"
    )
  
  extract_bird_info <- function(obs) {
    common_name <- obs |> 
      rvest::html_nodes(xpath = ".//span[@class='Species-common']") |> 
      rvest::html_text(trim = TRUE)
    
    sci_name <- obs |> 
      rvest::html_nodes(xpath = ".//span[@class='Species-sci Species-sub']") |> 
      rvest::html_text(trim = TRUE)
    
    count <- obs |> 
      rvest::html_nodes(xpath = ".//div[contains(@class, 'Obs-count')]/span") |> 
      rvest::html_text(trim = TRUE) |> 
      (\(x) x[length(x)])()
    
    date <- obs |> 
      rvest::html_nodes(xpath = ".//div[contains(@class, 'Obs-date')]/a/time") |> 
      rvest::html_attr("datetime") |> 
      as.Date()
    
    observer <- obs |> 
      rvest::html_nodes(xpath = ".//div[contains(@class, 'Obs-observer')]/span") |> 
      rvest::html_text(trim = TRUE) |> 
      (\(x) x[length(x)])()
    
    location <- obs |> 
      rvest::html_nodes(
        xpath = ".//div[contains(@class, 'Obs-location')]/span[contains(@class, 'Obs-location-name')]/a"
      ) |> 
      rvest::html_text(trim = TRUE)
    
    dplyr::tibble(
      nombre_comun      = common_name,
      nombre_cientifico = sci_name,
      conteo            = count,
      fecha             = date,
      observador        = observer,
      ubicacion         = location
    )
  }
  
  purrr::map_df(bird_observations, extract_bird_info)
}

# Hotspots de monitoreo ornitológico en la provincia
listas_ebird_hotspots <- tibble::tribble(
  ~ubicacion_punto,                     ~url,
  "Q'ente Q'entiyoc",                   "https://ebird.org/hotspot/L16831267/bird-list",
  "Sitio Arqueológico de Killarumiyoc", "https://ebird.org/hotspot/L8166287/bird-list",
  "Humedal del Yungaqui",               "https://ebird.org/hotspot/L13016446/bird-list"
)

# Extracción de datos
ebird_data <- listas_ebird_hotspots |> 
  dplyr::mutate(data = purrr::map(url, get_ebird_info)) |> 
  tidyr::unnest(c(data)) |> 
  dplyr::mutate(
    dplyr::across(c(ubicacion, ubicacion_punto), \(x) iconv(x, from = "latin1", to = "UTF-8"))
  )

# Consolidar lista de especies por ubicación
aves_list <- ebird_data |> 
  dplyr::select(-c(ubicacion_punto, url, conteo, fecha, observador)) |> 
  dplyr::group_by(nombre_comun, nombre_cientifico) |> 
  dplyr::summarise(
    ubicacion = paste0(unique(ubicacion), collapse = " - "),
    .groups = "drop"
  )

# Validación con lista oficial de aves del Perú (avesperu / UNOP)
avesperu::unop_check_update()
aves_peru_lista <- avesperu::search_avesperu(
  aves_list$nombre_cientifico,
  return_details = TRUE
) |> 
  dplyr::as_tibble()

aves_validadas <- aves_list |> 
  dplyr::left_join(aves_peru_lista, by = c("nombre_cientifico" = "name_submitted")) |> 
  dplyr::select(
    ubicacion,
    order_name, 
    family_name,
    nombre_cientifico,
    nombre_comun_sp = spanish_name,
    status
  ) |> 
  dplyr::filter(!is.na(order_name))

# ------------------------------------------------------------
# 6.1 Exportar lista de aves (Excel)
# ------------------------------------------------------------
writexl::write_xlsx(
  aves_validadas,
  path = file.path(dir_tabular, "lista_aves_ebird.xlsx")
)

writexl::write_xlsx(
  aves_validadas |> dplyr::select(-ubicacion),
  path = file.path(dir_tabular, "lista_aves_validada.xlsx")
)

message("Inventario de aves validado exportado en '", dir_tabular, "'")
message(">>> PROCESO DE INTEGRACIÓN COMPLETADO EXITOSAMENTE.")
