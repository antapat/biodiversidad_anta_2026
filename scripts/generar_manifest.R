# Generador nativo y canónico de manifest.json para Posit Connect Cloud
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
  list.files("R", full.names = TRUE),
  list.files("www", full.names = TRUE)
)
app_files <- gsub("^\\./", "", gsub("\\\\", "/", app_files))
app_files <- app_files[file.exists(app_files)]

message("Archivos incluidos en el manifiesto:")
print(app_files)

# Generar manifiesto nativo con rsconnect (mantiene tipos null exactos requeridos por Posit Connect)
rsconnect::writeManifest(
  appPrimaryDoc = "app.R",
  appFiles = app_files,
  quiet = FALSE
)

# Reemplazo seguro de versión de terra a 1.9-27 para compatibilidad Linux Connect Cloud
manifest_txt <- readLines("manifest.json", warn = FALSE)
# Reemplazar versión de terra de forma quirúrgica manteniendo el formato JSON estricto
manifest_txt <- gsub('"Version": "1.9-34"', '"Version": "1.9-27"', manifest_txt, fixed = TRUE)
writeLines(manifest_txt, "manifest.json", useBytes = TRUE)

message("manifest.json canónico generado exitosamente.")
