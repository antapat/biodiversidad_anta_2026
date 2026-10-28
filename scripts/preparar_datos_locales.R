# Copias compactas de las siete tablas analíticas; no contiene credenciales.
.libPaths(c(file.path(getwd(), ".r-library"), .libPaths()))
if (.Platform$OS.type == "windows") invisible(Sys.setlocale("LC_CTYPE", "English_United States.utf8"))
sources <- c(tab_especies_distrito = "especies_por_distrito.rds",
  tab_resumen_distritos = "resumen_distritos.csv",
  tab_singularidad_distritos = "singularidad_distritos.csv",
  tab_recambio_jaccard = "recambio_jaccard_distritos.csv",
  tab_cobertura_cuadricula = "cobertura_cuadricula_5km.csv",
  tab_ebird_especies = "ebird_especies_consolidadas.rds",
  tab_ebird_hotspots_resumen = "ebird_hotspots_resumen.rds")
dir.create("app-data", showWarnings = FALSE)
for (name in names(sources)) {
  path <- file.path("outputs/analisis_biodiversidad", sources[[name]])
  if (!file.exists(path)) stop("Falta el insumo: ", path)
  data <- if (grepl("rds$", path)) readRDS(path) else read.csv(path, stringsAsFactors = FALSE)
  stopifnot(is.data.frame(data), nrow(data) > 0)
  saveRDS(data, file.path("app-data", paste0(name, ".rds")), compress = "xz")
  message(name, ": ", nrow(data), " filas")
}
