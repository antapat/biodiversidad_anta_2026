.libPaths(c(file.path(getwd(), ".r-library"), .libPaths()))
invisible(try(Sys.setlocale("LC_CTYPE", "English_United States.utf8"), silent = TRUE))
suppressPackageStartupMessages({library(shiny); library(sf); library(mapgl); library(htmltools)})
source("R/utils_spatial.R", encoding = "UTF-8")
source("R/mod_patrimonio_natural.R", encoding = "UTF-8")
x <- read_spatial_asset("patrimonio_natural")
original <- st_read("data/spatial/D_0803_Patrimonio_natural_paisajistico.shp", quiet = TRUE)
stopifnot(nrow(x) == 45L, identical(x$Name, original$Name), identical(x$DISTRITO, original$DISTRITO))
distance <- as.numeric(st_distance(st_transform(x, 32718), original, by_element = TRUE))
stopifnot(max(distance) < 0.2)
for (district in unique(x$DISTRITO)) {
  filtered <- filter_patrimonio(x, distrito = district)
  stopifnot(all(filtered$DISTRITO == district), nrow(filtered) == sum(x$DISTRITO == district))
}
stopifnot(nrow(filter_patrimonio(x, buscar = "[.*")) == 0,
  nrow(filter_patrimonio(x, buscar = x$Name[1])) >= 1,
  !"UBI_VERIFI" %in% names(filter_patrimonio(x)))
d <- read_spatial_asset("geo_distritos")
testServer(mod_patrimonio_natural_server,
  args = list(patrimonio = reactive(x), distritos = reactive(d)), {
    session$setInputs(distrito = "Todos", tipo = "Todos", buscar = "")
    stopifnot(nrow(selected()) == 45, nzchar(output$mapa), nzchar(output$tabla))
    session$setInputs(buscar = "Sin coincidencias 987654321")
    stopifnot(nrow(selected()) == 0, nzchar(output$mapa), nzchar(output$tabla))
    empty <- tempfile(fileext = ".geojson")
    st_write(selected(), empty, driver = "GeoJSON", quiet = TRUE)
    stopifnot(nrow(st_read(empty, quiet = TRUE)) == 0)
    unlink(empty)
  })
inventory <- read.csv("www/spatial/inventario.csv")
for (name in inventory$capa) {
  layer <- read_spatial_asset(name)
  stopifnot(nrow(layer) == inventory$elementos[inventory$capa == name],
    st_crs(layer)$epsg == 4326, all(st_is_valid(layer)))
}
message("OK: atributos, precisión, filtros, mapa, tabla, selección vacía y todas las capas optimizadas.")
