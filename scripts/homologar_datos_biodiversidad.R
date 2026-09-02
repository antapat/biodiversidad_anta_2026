#!/usr/bin/env Rscript

.libPaths(c(file.path(getwd(), ".r-library"), .libPaths()))

suppressPackageStartupMessages({
  library(sf)
  library(dplyr)
  library(jsonlite)
})

source("R/utils_homologacion.R")

dir.create("data/tabular", recursive = TRUE, showWarnings = FALSE)
dir.create("data/spatial", recursive = TRUE, showWarnings = FALSE)
dir.create("outputs/analisis_biodiversidad", recursive = TRUE, showWarnings = FALSE)

archivo_origen <- "data/spatial/ocurrencias_flora_fauna_anta_0803.shp"
archivo_taxonomia <- "data/tabular/homologacion_taxonomica_inaturalist.csv"
archivo_datasets <- "data/tabular/catalogo_datasets_gbif.csv"
archivo_crosswalk <- "data/tabular/crosswalk_inaturalist_gbif.csv"
archivo_salida <- "data/spatial/ocurrencias_homologadas.gpkg"
archivo_resumen <- "outputs/analisis_biodiversidad/resumen_homologacion.csv"

stopifnot(file.exists(archivo_origen))

leer_json_reintentos <- function(url, intentos = 4L) {
  for (i in seq_len(intentos)) {
    resultado <- tryCatch(
      jsonlite::fromJSON(url, simplifyVector = TRUE),
      error = function(e) NULL
    )
    if (!is.null(resultado)) return(resultado)
    Sys.sleep(0.5 * i)
  }
  NULL
}

consultar_en_paralelo <- function(urls, trabajadores = 6L) {
  if (length(urls) == 0L) return(list())
  trabajadores <- max(1L, min(trabajadores, length(urls)))
  cluster <- parallel::makeCluster(trabajadores)
  on.exit(parallel::stopCluster(cluster), add = TRUE)
  parallel::clusterEvalQ(cluster, library(jsonlite))
  parallel::clusterExport(cluster, "leer_json_reintentos", envir = environment())
  parallel::parLapply(cluster, urls, leer_json_reintentos)
}

message("Leyendo ocurrencias originales...")
occ <- st_read(archivo_origen, quiet = TRUE) |>
  st_transform(4326)

# -----------------------------------------------------------------------------
# 1. Homologación taxonómica de los nombres recuperados por la API de iNaturalist
# -----------------------------------------------------------------------------
inat_nombres <- occ |>
  st_drop_geometry() |>
  filter(tolower(source) == "inaturalist") |>
  transmute(
    nombre_enviado = trimws(as.character(scntfcN)),
    reino_enviado = as.character(kingdom)
  ) |>
  filter(!is.na(nombre_enviado), nombre_enviado != "") |>
  distinct()

lookup_existente <- if (file.exists(archivo_taxonomia)) {
  read.csv(
    archivo_taxonomia,
    stringsAsFactors = FALSE,
    check.names = FALSE,
    colClasses = "character",
    encoding = "UTF-8"
  )
} else {
  data.frame()
}

if (nrow(lookup_existente) > 0L) {
  clave_existente <- paste(lookup_existente$nombre_enviado, lookup_existente$reino_enviado, sep = "||")
} else {
  clave_existente <- character()
}

clave_nombres <- paste(inat_nombres$nombre_enviado, inat_nombres$reino_enviado, sep = "||")
faltantes <- inat_nombres[!clave_nombres %in% clave_existente, , drop = FALSE]

if (nrow(faltantes) > 0L) {
  message(sprintf("Consultando el backbone taxonómico de GBIF para %d nombres...", nrow(faltantes)))
  urls <- sprintf(
    "https://api.gbif.org/v1/species/match?name=%s&kingdom=%s",
    utils::URLencode(faltantes$nombre_enviado, reserved = TRUE),
    utils::URLencode(faltantes$reino_enviado, reserved = TRUE)
  )
  respuestas <- consultar_en_paralelo(urls)

  nuevos <- bind_rows(lapply(seq_along(respuestas), function(i) {
    z <- respuestas[[i]]
    valor <- function(nombre, defecto = NA) {
      if (!is.null(z) && nombre %in% names(z) && length(z[[nombre]]) > 0L) z[[nombre]][1] else defecto
    }
    data.frame(
      nombre_enviado = faltantes$nombre_enviado[i],
      reino_enviado = faltantes$reino_enviado[i],
      usage_key = as.character(valor("usageKey")),
      accepted_usage_key = as.character(valor("acceptedUsageKey")),
      scientific_name = as.character(valor("scientificName")),
      canonical_name = as.character(valor("canonicalName")),
      rank = as.character(valor("rank")),
      status = as.character(valor("status")),
      confidence = as.character(valor("confidence")),
      match_type = as.character(valor("matchType")),
      kingdom = as.character(valor("kingdom")),
      phylum = as.character(valor("phylum")),
      class = as.character(valor("class")),
      order = as.character(valor("order")),
      family = as.character(valor("family")),
      genus = as.character(valor("genus")),
      species = as.character(valor("species")),
      consulta_utc = format(Sys.time(), tz = "UTC", usetz = TRUE),
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
  }))

  lookup_taxonomia <- bind_rows(lookup_existente, nuevos) |>
    distinct(nombre_enviado, reino_enviado, .keep_all = TRUE) |>
    semi_join(inat_nombres, by = c("nombre_enviado", "reino_enviado")) |>
    mutate(confidence = suppressWarnings(as.numeric(confidence))) |>
    arrange(reino_enviado, nombre_enviado)
  write.csv(lookup_taxonomia, archivo_taxonomia, row.names = FALSE, fileEncoding = "UTF-8")
} else {
  lookup_taxonomia <- lookup_existente |>
    semi_join(inat_nombres, by = c("nombre_enviado", "reino_enviado")) |>
    mutate(confidence = suppressWarnings(as.numeric(confidence)))
}

# -----------------------------------------------------------------------------
# 2. Catálogo de conjuntos publicados mediante GBIF
# -----------------------------------------------------------------------------
dataset_keys <- sort(unique(na.omit(as.character(occ$datstKy))))
dataset_keys <- dataset_keys[!dataset_keys %in% c("", "NA")]

catalogo_existente <- if (file.exists(archivo_datasets)) {
  read.csv(
    archivo_datasets,
    stringsAsFactors = FALSE,
    check.names = FALSE,
    colClasses = "character",
    encoding = "UTF-8"
  )
} else {
  data.frame()
}

keys_existentes <- if (nrow(catalogo_existente) > 0L) catalogo_existente$dataset_key else character()
keys_faltantes <- setdiff(dataset_keys, keys_existentes)

if (length(keys_faltantes) > 0L) {
  message(sprintf("Resolviendo %d conjuntos de datos de GBIF...", length(keys_faltantes)))
  respuestas <- consultar_en_paralelo(paste0("https://api.gbif.org/v1/dataset/", keys_faltantes))
  nuevos <- bind_rows(lapply(seq_along(respuestas), function(i) {
    z <- respuestas[[i]]
    valor <- function(nombre, defecto = NA_character_) {
      if (!is.null(z) && nombre %in% names(z) && length(z[[nombre]]) > 0L) as.character(z[[nombre]][1]) else defecto
    }
    data.frame(
      dataset_key = keys_faltantes[i],
      dataset_title = valor("title"),
      dataset_doi = valor("doi"),
      publishing_organization_key = valor("publishingOrganizationKey"),
      stringsAsFactors = FALSE
    )
  }))
  catalogo_datasets <- bind_rows(catalogo_existente, nuevos) |>
    distinct(dataset_key, .keep_all = TRUE) |>
    arrange(dataset_title)
  write.csv(catalogo_datasets, archivo_datasets, row.names = FALSE, fileEncoding = "UTF-8")
} else {
  catalogo_datasets <- catalogo_existente
}

# -----------------------------------------------------------------------------
# 3. Identificador original para registros iNaturalist mediados por GBIF
# -----------------------------------------------------------------------------
gbif_inat_keys <- occ |>
  st_drop_geometry() |>
  filter(datstKy == INAT_GBIF_DATASET_KEY) |>
  transmute(gbif_key = as.character(occrrID)) |>
  distinct()

crosswalk_existente <- if (file.exists(archivo_crosswalk)) {
  read.csv(
    archivo_crosswalk,
    stringsAsFactors = FALSE,
    check.names = FALSE,
    colClasses = "character",
    encoding = "UTF-8"
  )
} else {
  data.frame()
}

crosswalk_keys <- if (nrow(crosswalk_existente) > 0L) as.character(crosswalk_existente$gbif_key) else character()
crosswalk_faltantes <- setdiff(gbif_inat_keys$gbif_key, crosswalk_keys)

if (length(crosswalk_faltantes) > 0L) {
  message(sprintf("Recuperando %d identificadores originales de iNaturalist desde GBIF...", length(crosswalk_faltantes)))
  respuestas <- consultar_en_paralelo(paste0("https://api.gbif.org/v1/occurrence/", crosswalk_faltantes))
  nuevos <- bind_rows(lapply(seq_along(respuestas), function(i) {
    z <- respuestas[[i]]
    occurrence_id <- if (!is.null(z) && "occurrenceID" %in% names(z)) as.character(z$occurrenceID[1]) else NA_character_
    id_inat <- sub(".*/observations/([0-9]+).*", "\\1", occurrence_id)
    if (is.na(occurrence_id) || identical(id_inat, occurrence_id)) id_inat <- NA_character_
    data.frame(
      gbif_key = crosswalk_faltantes[i],
      occurrence_id_original = occurrence_id,
      inat_observation_id = id_inat,
      stringsAsFactors = FALSE
    )
  }))
  crosswalk <- bind_rows(crosswalk_existente, nuevos) |>
    distinct(gbif_key, .keep_all = TRUE)
  write.csv(crosswalk, archivo_crosswalk, row.names = FALSE, fileEncoding = "UTF-8")
} else {
  crosswalk <- crosswalk_existente
}

# -----------------------------------------------------------------------------
# 4. Homologación, trazabilidad y deduplicación entre canales
# -----------------------------------------------------------------------------
message("Homologando campos y eliminando duplicados entre canales...")
homologadas <- homologar_ocurrencias(
  ocurrencias = occ,
  lookup_taxonomia = lookup_taxonomia,
  catalogo_datasets = catalogo_datasets,
  crosswalk_inat_gbif = crosswalk
)

if (file.exists(archivo_salida)) invisible(file.remove(archivo_salida))
st_write(homologadas, archivo_salida, layer = "ocurrencias_homologadas", quiet = TRUE)

inat_original <- sum(normalizar_fuente_descarga(occ$source) == "iNaturalist")
inat_homologado <- sum(homologadas$plataforma_origen == "iNaturalist")
inat_taxonomia_valida <- sum(
  homologadas$plataforma_origen == "iNaturalist" &
    homologadas$taxnRnk %in% c("SPECIES", "SUBSPECIES") &
    !es_vacio(homologadas$species)
)

resumen <- data.frame(
  metrica = c(
    "registros_originales", "registros_homologados_sin_duplicados",
    "duplicados_entre_canales_eliminados", "registros_directos_inaturalist_originales",
    "registros_origen_inaturalist_homologados", "registros_inaturalist_con_taxonomia_valida",
    "nombres_inaturalist_consultados", "nombres_inaturalist_match_confianza_90"
  ),
  valor = c(
    nrow(occ), nrow(homologadas), nrow(occ) - nrow(homologadas), inat_original,
    inat_homologado, inat_taxonomia_valida, nrow(lookup_taxonomia),
    sum(lookup_taxonomia$confidence >= 90, na.rm = TRUE)
  )
)
write.csv(resumen, archivo_resumen, row.names = FALSE, fileEncoding = "UTF-8")

message(sprintf(
  "Homologación terminada: %d registros originales -> %d registros únicos; %d registros de origen iNaturalist.",
  nrow(occ), nrow(homologadas), inat_homologado
))
