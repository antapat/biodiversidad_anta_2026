# Instantáneas cartográficas reproducibles; los originales no se modifican.
maplibre_with_satellite <- function(...) {
  # Se añade antes de las capas temáticas: alternar el fondo no borra dibujos,
  # filtros ni resultados y evita reconstruir el widget de Shiny.
  mapgl::maplibre(...) |>
    mapgl::add_raster_source(
      id = "anta-satellite-source",
      tiles = "https://services.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}",
      tileSize = 256, maxzoom = 19,
      attribution = "Imagery &copy; Esri, Maxar, Earthstar Geographics, and the GIS User Community") |>
    mapgl::add_raster_layer(id = "anta-satellite", source = "anta-satellite-source",
      visibility = "none") |>
    mapgl::add_layers_control(position = "top-right",
      layers = list("Imagen satelital" = "anta-satellite"),
      collapsible = FALSE, use_icon = FALSE)
}

spatial_asset_path <- function(name) file.path("www", "spatial", paste0(name, ".geojson.gz"))

read_spatial_asset <- function(name) {
  path <- spatial_asset_path(name)
  if (!file.exists(path)) stop("Falta la capa optimizada ", name,
    ". Ejecuta Rscript scripts/optimizar_capas.R", call. = FALSE)
  sf::st_read(paste0("/vsigzip/", normalizePath(path, winslash = "/")), quiet = TRUE)
}

optimize_spatial_geometry <- function(x, tolerance_m = 10) {
  if (is.na(sf::st_crs(x))) stop("La capa no tiene un CRS definido.")
  x <- sf::st_zm(x, drop = TRUE, what = "ZM")
  types <- as.character(sf::st_geometry_type(x))
  if (any(grepl("POLYGON|LINESTRING", types))) {
    x <- sf::st_transform(x, 32718)
    x <- sf::st_make_valid(x)
    simplified <- sf::st_simplify(x, dTolerance = tolerance_m, preserveTopology = TRUE)
    # Conservar elementos pequeños que una simplificación pudiera vaciar.
    empty <- sf::st_is_empty(simplified)
    sf::st_geometry(simplified)[empty] <- sf::st_geometry(x)[empty]
    x <- simplified
  }
  sf::st_transform(x, 4326)
}
