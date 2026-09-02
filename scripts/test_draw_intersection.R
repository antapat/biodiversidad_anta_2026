# Prueba de intersección espacial de polígono
.libPaths(c(file.path(getwd(), ".r-library"), .libPaths()))
suppressPackageStartupMessages({
  library(sf)
  library(dplyr)
  library(geojsonsf)
})

occ_sf <- readRDS("outputs/analisis_biodiversidad/ocurrencias_puntos_sf.rds")
message(sprintf("Total ocurrencias cargadas: %d", nrow(occ_sf)))

# Crear un polígono de prueba
bbox <- st_bbox(c(xmin = -72.20, ymin = -13.48, xmax = -72.10, ymax = -13.42), crs = st_crs(4326))
poly_test <- st_as_sfc(bbox) |> st_as_sf()

sf_use_s2(FALSE)
intersected <- suppressWarnings(st_intersection(occ_sf, poly_test))
message(sprintf("Ocurrencias encontradas: %d | Especies únicas: %d", 
                nrow(intersected), n_distinct(intersected$species)))
