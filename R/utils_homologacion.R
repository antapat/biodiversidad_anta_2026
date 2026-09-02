# Utilidades para homologar ocurrencias recuperadas mediante GBIF e iNaturalist.

INAT_GBIF_DATASET_KEY <- "50c9509d-22c7-4a22-a47d-8c48425ef4a7"
EBIRD_GBIF_DATASET_KEY <- "4fa7b334-ce0d-4e88-aaae-2e0c138d049e"

es_vacio <- function(x) {
  is.na(x) | trimws(as.character(x)) %in% c("", "NA", "NULL")
}

reemplazar_vacios <- function(original, reemplazo) {
  idx <- es_vacio(original) & !es_vacio(reemplazo)
  original[idx] <- reemplazo[idx]
  original
}

normalizar_fuente_descarga <- function(x) {
  dplyr::case_when(
    tolower(trimws(as.character(x))) == "gbif" ~ "GBIF",
    tolower(trimws(as.character(x))) == "inaturalist" ~ "iNaturalist",
    TRUE ~ as.character(x)
  )
}

homologar_ocurrencias <- function(
    ocurrencias,
    lookup_taxonomia,
    catalogo_datasets,
    crosswalk_inat_gbif) {
  stopifnot(inherits(ocurrencias, "sf"))

  taxonomia <- lookup_taxonomia |>
    dplyr::distinct(nombre_enviado, reino_enviado, .keep_all = TRUE) |>
    dplyr::rename(
      taxon_match_rank = rank,
      taxon_match_kingdom = kingdom,
      taxon_match_phylum = phylum,
      taxon_match_class = class,
      taxon_match_order = order,
      taxon_match_family = family,
      taxon_match_genus = genus,
      taxon_match_species = species
    )

  datasets <- catalogo_datasets |>
    dplyr::distinct(dataset_key, .keep_all = TRUE)

  crosswalk <- crosswalk_inat_gbif |>
    dplyr::mutate(occrrID = as.character(gbif_key)) |>
    dplyr::select(occrrID, inat_observation_id, occurrence_id_original)

  homologadas <- ocurrencias |>
    dplyr::mutate(
      fila_origen = dplyr::row_number(),
      occrrID = as.character(.data$occrrID),
      srcRcID = as.character(.data$srcRcID),
      nombre_cientifico_original = trimws(as.character(.data$scntfcN)),
      reino_original = as.character(.data$kingdom),
      fuente_descarga = normalizar_fuente_descarga(.data$source),
      dataset_key = dplyr::na_if(as.character(.data$datstKy), "NA")
    ) |>
    dplyr::left_join(
      taxonomia,
      by = c(
        "nombre_cientifico_original" = "nombre_enviado",
        "reino_original" = "reino_enviado"
      )
    ) |>
    dplyr::mutate(
      taxnRnk = reemplazar_vacios(.data$taxnRnk, .data$taxon_match_rank),
      kingdom = reemplazar_vacios(.data$kingdom, .data$taxon_match_kingdom),
      phylum = reemplazar_vacios(.data$phylum, .data$taxon_match_phylum),
      class = reemplazar_vacios(.data$class, .data$taxon_match_class),
      order = reemplazar_vacios(.data$order, .data$taxon_match_order),
      family = reemplazar_vacios(.data$family, .data$taxon_match_family),
      genus = reemplazar_vacios(.data$genus, .data$taxon_match_genus),
      species = reemplazar_vacios(.data$species, .data$taxon_match_species),
      nombre_cientifico_aceptado = dplyr::coalesce(
        dplyr::na_if(as.character(.data$taxon_match_species), ""),
        dplyr::na_if(as.character(.data$species), ""),
        .data$nombre_cientifico_original
      )
    ) |>
    dplyr::left_join(datasets, by = "dataset_key") |>
    dplyr::left_join(crosswalk, by = "occrrID") |>
    dplyr::mutate(
      inat_observation_id = dplyr::case_when(
        .data$fuente_descarga == "iNaturalist" ~ .data$srcRcID,
        .data$dataset_key == INAT_GBIF_DATASET_KEY ~ .data$inat_observation_id,
        TRUE ~ NA_character_
      ),
      plataforma_origen = dplyr::case_when(
        .data$fuente_descarga == "iNaturalist" |
          .data$dataset_key == INAT_GBIF_DATASET_KEY ~ "iNaturalist",
        .data$dataset_key == EBIRD_GBIF_DATASET_KEY ~ "eBird",
        grepl("Observation.org", dplyr::coalesce(.data$dataset_title, ""), fixed = TRUE) ~ "Observation.org",
        grepl("Xeno-canto", dplyr::coalesce(.data$dataset_title, ""), ignore.case = TRUE) ~ "Xeno-canto",
        TRUE ~ "Otros conjuntos mediados por GBIF"
      ),
      dataset_origen = dplyr::case_when(
        .data$fuente_descarga == "iNaturalist" ~ "iNaturalist API (Research Grade)",
        !es_vacio(.data$dataset_title) ~ .data$dataset_title,
        TRUE ~ "Conjunto no informado"
      ),
      id_registro_origen = dplyr::case_when(
        .data$plataforma_origen == "iNaturalist" & !es_vacio(.data$inat_observation_id) ~
          paste0("iNaturalist:", .data$inat_observation_id),
        .data$fuente_descarga == "GBIF" ~ paste0("GBIF:", .data$occrrID),
        TRUE ~ paste0(.data$fuente_descarga, ":", .data$srcRcID)
      ),
      prioridad_fuente = dplyr::case_when(
        .data$fuente_descarga == "iNaturalist" ~ 1L,
        TRUE ~ 2L
      )
    ) |>
    dplyr::group_by(.data$id_registro_origen) |>
    dplyr::mutate(
      canales_descarga = paste(sort(unique(.data$fuente_descarga)), collapse = " | "),
      n_copias_fuente = dplyr::n()
    ) |>
    dplyr::arrange(.data$prioridad_fuente, .data$fila_origen, .by_group = TRUE) |>
    dplyr::slice(1L) |>
    dplyr::ungroup() |>
    dplyr::select(-dplyr::any_of(c(
      "prioridad_fuente", "taxon_match_rank", "taxon_match_kingdom",
      "taxon_match_phylum", "taxon_match_class", "taxon_match_order",
      "taxon_match_family", "taxon_match_genus", "taxon_match_species"
    )))

  homologadas
}

