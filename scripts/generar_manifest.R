# Script para generar manifest.json compatible con Posit Connect Cloud
if (dir.exists(".r-library")) {
  .libPaths(c(file.path(getwd(), ".r-library"), .libPaths()))
}

suppressPackageStartupMessages({
  library(jsonlite)
  library(digest)
})

# 1. Obtener manifiesto base desde Git
old_manifest_json <- system2("git", c("show", "2e6f775:manifest.json"), stdout = TRUE)
manifest <- jsonlite::fromJSON(paste(old_manifest_json, collapse = "\n"), simplifyVector = FALSE)

# 2. Función para agregar paquete al manifest
add_pkg <- function(pkg_name) {
  desc_raw <- as.list(packageDescription(pkg_name))
  # Remover campos locales
  desc_clean <- desc_raw[!names(desc_raw) %in% c("Built", "Archs")]
  
  manifest$packages[[pkg_name]] <<- list(
    Source = "CRAN",
    Repository = "https://cloud.r-project.org",
    description = desc_clean
  )
  message(sprintf("Paquete %s agregado al manifest.", pkg_name))
}

# Agregar RPostgres y blob si faltan
if (!"RPostgres" %in% names(manifest$packages)) add_pkg("RPostgres")
if (!"blob" %in% names(manifest$packages) && requireNamespace("blob", quietly = TRUE)) add_pkg("blob")
if (!"lubridate" %in% names(manifest$packages) && requireNamespace("lubridate", quietly = TRUE)) add_pkg("lubridate")
if (!"timechange" %in% names(manifest$packages) && requireNamespace("timechange", quietly = TRUE)) add_pkg("timechange")

# 3. Actualizar lista de archivos en el manifest
# Obtener archivos trackeados o relevantes para la app
app_files <- c(
  "app.R",
  "DESCRIPTION",
  "logo_anta.jpg",
  list.files("R", full.names = TRUE, recursive = TRUE),
  list.files("www", full.names = TRUE, recursive = TRUE)
)

manifest$files <- list()
for (f in app_files) {
  if (file.exists(f)) {
    norm_f <- gsub("\\\\", "/", f)
    manifest$files[[norm_f]] <- list(
      checksum = digest::digest(f, algo = "md5", file = TRUE)
    )
  }
}

# 4. Guardar manifest.json
json_out <- jsonlite::toJSON(manifest, pretty = TRUE, auto_unbox = TRUE)
writeLines(json_out, "manifest.json", useBytes = TRUE)
message("manifest.json generado exitosamente con ", length(manifest$packages), " paquetes y ", length(manifest$files), " archivos.")
