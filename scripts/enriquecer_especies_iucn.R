# =============================================================================
# enriquecer_especies_iucn.R
# Categorización oficial de todas las especies de Anta en la Lista Roja de la UICN
# utilizando el paquete iucnr (v0.0.3, UICN 2026-1) sobre los datos de GBIF e iNaturalist.
# =============================================================================

.libPaths(c(file.path(getwd(), ".r-library"), .libPaths()))

suppressPackageStartupMessages({
  library(sf)
  library(dplyr)
  library(iucnr)
  library(jsonlite)
})

message("=== Enriqueciendo especies de Anta con iucnr (IUCN 2026-1) ===")

# 1. Cargar especies distritales de GBIF e iNaturalist
especies_distrito <- readRDS("outputs/analisis_biodiversidad/especies_por_distrito.rds")
lista_spp_unicas <- sort(unique(especies_distrito$species))

message(sprintf("Consultando %d especies únicas (Flora y Fauna de GBIF/iNaturalist) en UICN...", length(lista_spp_unicas)))

# Realizar matching taxonómico con iucnr
iucn_results <- iucnr::iucn_match(splist = lista_spp_unicas) |>
  select(
    species = submitted_name,
    iucn_match_name = matched_species,
    iucn_categoria_raw = redlist_category,
    iucn_id = internal_taxon_id
  ) |>
  mutate(
    iucn_categoria = case_when(
      iucn_categoria_raw == "Critically Endangered" ~ "En Peligro Crítico (CR)",
      iucn_categoria_raw == "Endangered" ~ "En Peligro (EN)",
      iucn_categoria_raw == "Vulnerable" ~ "Vulnerable (VU)",
      iucn_categoria_raw == "Near Threatened" ~ "Casi Amenazada (NT)",
      iucn_categoria_raw == "Least Concern" ~ "Preocupación Menor (LC)",
      iucn_categoria_raw == "Data Deficient" ~ "Datos Insuficientes (DD)",
      TRUE ~ "No Evaluada (NE)"
    ),
    es_amenazada_iucn = iucn_categoria %in% c("En Peligro Crítico (CR)", "En Peligro (EN)", "Vulnerable (VU)")
  )

# 2. Unir a la tabla de especies por distrito
especies_distrito_iucn <- especies_distrito |>
  select(-any_of(c("iucn_match_name", "iucn_categoria_raw", "iucn_id", "iucn_categoria", "es_amenazada_iucn"))) |>
  left_join(iucn_results, by = "species") |>
  mutate(
    iucn_categoria = ifelse(is.na(iucn_categoria), "No Evaluada (NE)", iucn_categoria),
    es_amenazada_iucn = ifelse(is.na(es_amenazada_iucn), FALSE, es_amenazada_iucn)
  ) |>
  arrange(distrito, desc(n_registros))

# Guardar formatos usados por la aplicación y las descargas
saveRDS(especies_distrito_iucn, "outputs/analisis_biodiversidad/especies_por_distrito.rds")
write.csv(especies_distrito_iucn, "outputs/analisis_biodiversidad/especies_por_distrito.csv", row.names = FALSE, fileEncoding = "UTF-8")

# 3. Enriquecer los puntos de ocurrencia homologados de GBIF/iNaturalist
message("Enriqueciendo capa de puntos de ocurrencias sf con categorización UICN...")
if (file.exists("outputs/analisis_biodiversidad/ocurrencias_puntos_sf.rds")) {
  occ_sf <- readRDS("outputs/analisis_biodiversidad/ocurrencias_puntos_sf.rds") |>
    select(-any_of(c("iucn_categoria", "es_amenazada_iucn"))) |>
    left_join(
      iucn_results |> select(species, iucn_categoria, es_amenazada_iucn),
      by = "species"
    ) |>
    mutate(
      iucn_categoria = ifelse(is.na(iucn_categoria), "No Evaluada (NE)", iucn_categoria),
      es_amenazada_iucn = ifelse(is.na(es_amenazada_iucn), FALSE, es_amenazada_iucn),
      tooltip = paste0(
        "<b>", nombre_cientifico, "</b><br>",
        "Reino: ", reino, " | Clase: ", clase, "<br>",
        "Distrito: ", distrito, "<br>",
        "Categoría UICN: ", iucn_categoria, "<br>",
        "Origen: ", plataforma_origen, " vía ", fuente,
        " (", ifelse(is.na(year), "S/A", year), ")"
      )
    )
  
  saveRDS(occ_sf, "outputs/analisis_biodiversidad/ocurrencias_puntos_sf.rds")
  message(sprintf("Capa sf actualizada con %d ocurrencias y categorías UICN.", nrow(occ_sf)))
}

# 4. Actualizar tabla de eBird
if (file.exists("outputs/analisis_biodiversidad/ebird_especies_consolidadas.rds")) {
  ebird_spp <- readRDS("outputs/analisis_biodiversidad/ebird_especies_consolidadas.rds") |>
    select(-any_of(c("iucn_categoria_raw", "iucn_id", "iucn_categoria_oficial"))) |>
    left_join(
      iucn_results |> select(species, iucn_categoria_oficial = iucn_categoria),
      by = "species"
    ) |>
    mutate(
      iucn_categoria = ifelse(!is.na(iucn_categoria_oficial) & iucn_categoria_oficial != "No Evaluada (NE)",
                              iucn_categoria_oficial, iucn_categoria)
    ) |>
    select(-any_of("iucn_categoria_oficial"))
  
  saveRDS(ebird_spp, "outputs/analisis_biodiversidad/ebird_especies_consolidadas.rds")
  write.csv(ebird_spp, "outputs/analisis_biodiversidad/ebird_especies_consolidadas.csv", row.names = FALSE, fileEncoding = "UTF-8")
}

# 5. Actualizar resumen de distritos con métricas UICN
if (file.exists("outputs/analisis_biodiversidad/resumen_distritos.csv")) {
  resumen_distritos <- read.csv("outputs/analisis_biodiversidad/resumen_distritos.csv", stringsAsFactors = FALSE)
  
  amenazadas_por_dist <- especies_distrito_iucn |>
    filter(es_amenazada_iucn == TRUE) |>
    group_by(district = distrito) |>
    summarise(especies_amenazadas_iucn = n_distinct(species), .groups = "drop")
  
  resumen_distritos <- resumen_distritos |>
    select(-any_of("especies_amenazadas_iucn")) |>
    left_join(amenazadas_por_dist, by = "district") |>
    mutate(especies_amenazadas_iucn = ifelse(is.na(especies_amenazadas_iucn), 0, especies_amenazadas_iucn))
  
  write.csv(resumen_distritos, "outputs/analisis_biodiversidad/resumen_distritos.csv", row.names = FALSE, fileEncoding = "UTF-8")
}

message(sprintf("¡Proceso completado exitosamente! Especies de flora/fauna amenazadas en Anta: %d",
                n_distinct(filter(especies_distrito_iucn, es_amenazada_iucn == TRUE)$species)))
