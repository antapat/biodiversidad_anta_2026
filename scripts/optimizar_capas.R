# Regenera todas las capas de data/spatial y las capas consumidas por Shiny.
.libPaths(c(file.path(getwd(), ".r-library"), .libPaths()))
invisible(try(Sys.setlocale("LC_CTYPE", "English_United States.utf8"), silent = TRUE))
source("R/utils_spatial.R", encoding = "UTF-8")
dir.create("www/spatial", recursive = TRUE, showWarnings = FALSE)
report <- list()
export_layer <- function(x, name, origin, source_bytes) {
  original <- x
  x <- optimize_spatial_geometry(x)
  # Reparar después de cuantizar: redondear al escribir puede unir vértices.
  if (any(grepl("POLYGON|LINESTRING", sf::st_geometry_type(x)))) {
    geometry <- sf::st_as_sfc(sf::st_as_binary(sf::st_set_precision(sf::st_geometry(x), 1e6)), crs = 4326)
    geometry <- sf::st_make_valid(geometry,
      s2_options = s2::s2_options(snap = s2::s2_snap_precision(1e6)))
    sf::st_geometry(x) <- geometry
  }
  tmp <- tempfile(fileext = ".geojson")
  on.exit(unlink(tmp), add = TRUE)
  sf::st_write(x, tmp, driver = "GeoJSON", quiet = TRUE,
    layer_options = c("RFC7946=YES", "COORDINATE_PRECISION=6", "WRITE_BBOX=NO"))
  path <- spatial_asset_path(name)
  input <- file(tmp, "rb")
  output <- gzfile(path, "wb", compression = 9)
  tryCatch({
    repeat {
      chunk <- readBin(input, "raw", n = 1048576)
      if (!length(chunk)) break
      writeBin(chunk, output)
    }
  }, finally = { close(input); close(output) })
  check <- read_spatial_asset(name)
  stopifnot(nrow(check) == nrow(original), sf::st_crs(check)$epsg == 4326,
    !any(sf::st_is_empty(check)), all(sf::st_is_valid(check)))
  report[[length(report) + 1L]] <<- data.frame(
    capa = name, origen = origin, elementos = nrow(x),
    bytes_original = source_bytes, bytes_geojson = file.info(tmp)$size,
    bytes_gzip = file.info(path)$size,
    reduccion_pct = round(100 * (1 - file.info(path)$size / source_bytes), 1),
    tolerancia_m = if (any(grepl("POLYGON|LINESTRING", sf::st_geometry_type(x)))) 10 else 0,
    precision_decimales = 6)
  message(name, ": ", nrow(x), " elementos; ", file.info(path)$size, " bytes")
}
sources <- list.files("data/spatial", pattern = "\\.(shp|gpkg|kmz|geojson|parquet)$", full.names = TRUE, ignore.case = TRUE)
for (path in sources) {
  ext <- tolower(tools::file_ext(path))
  base <- tools::file_path_sans_ext(basename(path))
  size <- file.info(path)$size
  if (ext == "shp") {
    parts <- paste0(tools::file_path_sans_ext(path), c(".shp", ".shx", ".dbf", ".prj", ".cpg"))
    size <- sum(file.info(parts)$size, na.rm = TRUE)
  }
  if (ext == "kmz") {
    folder <- tempfile(); dir.create(folder)
    unzip(path, exdir = folder)
    kml <- list.files(folder, pattern = "\\.kml$", recursive = TRUE, full.names = TRUE)
    if (!length(kml)) stop("KMZ sin KML: ", path)
    for (k in seq_along(kml)) {
      layers <- sf::st_layers(kml[k])$name
      for (j in seq_along(layers)) export_layer(
        sf::st_read(kml[k], layer = layers[j], quiet = TRUE),
        paste0(base, "_", k, "_", j), path, size)
    }
    unlink(folder, recursive = TRUE)
  } else {
    layers <- sf::st_layers(path)$name
    for (j in seq_along(layers)) {
      name <- if (base == "D_0803_Patrimonio_natural_paisajistico") "patrimonio_natural" else base
      if (length(layers) > 1) name <- paste0(name, "_", j)
      export_layer(sf::st_read(path, layer = layers[j], quiet = TRUE), name, path, size)
    }
  }
}
# Mantener todos los atributos que utilizan los módulos actuales.
viewer <- c(geo_distritos = "biodiversidad_distritos.geojson",
  geo_cuadricula_5km = "cobertura_cuadricula_5km.geojson",
  geo_ebird_hotspots = "ebird_hotspots_anta.geojson",
  geo_ocurrencias_puntos = "ocurrencias_puntos_sf.rds",
  geo_ocurrencias_mapa = "ocurrencias_mapa_sf.rds")
for (name in names(viewer)) {
  path <- file.path("outputs/analisis_biodiversidad", viewer[[name]])
  if (!file.exists(path)) stop("Falta el insumo del visor: ", path)
  x <- if (grepl("rds$", path)) readRDS(path) else sf::st_read(path, quiet = TRUE)
  export_layer(x, name, path, file.info(path)$size)
}
report <- do.call(rbind, report)
inventory_path <- file.path(getwd(), "www", "spatial", "inventario.csv")
inventory_connection <- file(inventory_path, open = "wt", encoding = "UTF-8")
tryCatch(write.csv(report, inventory_connection, row.names = FALSE),
  finally = close(inventory_connection))
stopifnot(file.exists(inventory_path))
message("Optimización terminada. Inventario: www/spatial/inventario.csv")
