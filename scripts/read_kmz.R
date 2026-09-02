# Leer lugares_ebird.kmz
.libPaths(c(file.path(getwd(), ".r-library"), .libPaths()))
suppressPackageStartupMessages({ library(sf); library(dplyr) })

kmz <- "data/spatial/lugares_ebird.kmz"
tmp_dir <- tempdir()
unzip(kmz, exdir = tmp_dir)
kml_file <- list.files(tmp_dir, pattern = "\\.kml$", full.names = TRUE)[1]

if (!is.na(kml_file) && file.exists(kml_file)) {
  kml_pts <- st_read(kml_file, quiet = TRUE)
  print(st_drop_geometry(kml_pts))
  print(st_coordinates(kml_pts))
}
