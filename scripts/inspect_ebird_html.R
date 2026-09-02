# Inspeccionar estructura HTML retornada por eBird
.libPaths(c(file.path(getwd(), ".r-library"), .libPaths()))
suppressPackageStartupMessages({
  library(rvest)
  library(httr)
})

url <- "https://ebird.org/hotspot/L8166287/bird-list"
req <- httr::GET(url, httr::user_agent("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"))
html_txt <- httr::content(req, as = "text", encoding = "UTF-8")

cat("Status:", httr::status_code(req), "\n")
cat("Longitud HTML:", nchar(html_txt), "\n")
cat("Primeros 1000 caracteres:\n")
cat(substr(html_txt, 1, 1000), "\n")

# Buscar si hay JSON embebido o etiquetas de especies
has_species <- grepl("Species", html_txt, ignore.case = TRUE)
has_json <- grepl("application/json|window\\.__data|data-species", html_txt, ignore.case = TRUE)
cat("Tiene 'Species':", has_species, "| Tiene JSON/Data:", has_json, "\n")
