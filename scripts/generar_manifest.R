# Generador nativo y canónico de manifest.json para Posit Connect Cloud
invisible(try(Sys.setlocale("LC_CTYPE", "English_United States.utf8"), silent = TRUE))
if (dir.exists(".r-library")) {
  .libPaths(c(file.path(getwd(), ".r-library"), .libPaths()))
}

suppressPackageStartupMessages({
  library(rsconnect)
})

# Lista exacta de archivos de la aplicación que existen en el repositorio Git
app_files <- c(
  "app.R",
  "DESCRIPTION",
  "README.md",
  "logo_anta.jpg",
  list.files("R", pattern = "\\.R$", full.names = TRUE),
  list.files("www", full.names = TRUE, recursive = TRUE)
)
app_files <- gsub("^\\./", "", gsub("\\\\", "/", app_files))
stopifnot(all(file.exists(app_files)), !any(dir.exists(app_files)))
required_spatial <- file.path("www/spatial", paste0(c("patrimonio_natural",
  "geo_distritos", "geo_cuadricula_5km", "geo_ebird_hotspots",
  "geo_ocurrencias_puntos", "geo_ocurrencias_mapa"), ".geojson.gz"))
stopifnot(all(required_spatial %in% app_files))

message("Archivos incluidos en el manifiesto:")
print(app_files)

# Generar manifiesto nativo con rsconnect (mantiene tipos null exactos requeridos por Posit Connect)
rsconnect::writeManifest(
  appPrimaryDoc = "app.R",
  appMode = "shiny",
  appFiles = app_files,
  quiet = FALSE
)

# Conservar las versiones reales detectadas; no falsear metadatos de paquetes.
manifest <- jsonlite::read_json("manifest.json", simplifyVector = FALSE)
stopifnot(identical(manifest$metadata$appmode, "shiny"),
  all(app_files %in% names(manifest$files)),
  !any(grepl("(^|/)(\\.Renviron|\\.env)$", names(manifest$files))))
for (path in app_files) {
  stopifnot(identical(manifest$files[[path]]$checksum, unname(tools::md5sum(path))))
}

message("manifest.json canónico generado exitosamente.")
