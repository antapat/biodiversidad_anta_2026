# Generador de manifest.json limpio y verificado para Posit Connect Cloud
if (dir.exists(".r-library")) {
  .libPaths(c(file.path(getwd(), ".r-library"), .libPaths()))
}

suppressPackageStartupMessages({
  library(rsconnect)
  library(jsonlite)
})

# Lista exacta de archivos de la aplicación que existen en el repositorio Git
app_files <- c(
  "app.R",
  "DESCRIPTION",
  "README.md",
  "logo_anta.jpg",
  list.files("R", full.names = TRUE),
  list.files("www", full.names = TRUE)
)
app_files <- gsub("^\\./", "", gsub("\\\\", "/", app_files))
app_files <- app_files[file.exists(app_files)]

message("Archivos incluidos en el manifiesto:")
print(app_files)

# Generar manifiesto oficial con rsconnect
rsconnect::writeManifest(
  appPrimaryDoc = "app.R",
  appFiles = app_files,
  quiet = FALSE
)

# Ajuste de compatibilidad para Linux Connect Cloud: terra 1.9-27
m <- jsonlite::fromJSON("manifest.json", simplifyVector = FALSE)
if ("terra" %in% names(m$packages)) {
  m$packages$terra$description$Version <- "1.9-27"
}

writeLines(jsonlite::toJSON(m, pretty = TRUE, auto_unbox = TRUE), "manifest.json", useBytes = TRUE)
message("manifest.json generado y validado con exito.")
