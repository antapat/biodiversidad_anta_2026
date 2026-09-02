# Test ebird scraping
.libPaths(c(file.path(getwd(), ".r-library"), .libPaths()))
suppressPackageStartupMessages({
  library(rvest)
  library(dplyr)
  library(httr)
})

url <- "https://ebird.org/hotspot/L8166287/bird-list"
message("Descargando: ", url)

res <- tryCatch({
  # Usar User-Agent estándar para evitar bloqueos
  req <- httr::GET(url, httr::user_agent("Mozilla/5.0 (Windows NT 10.0; Win64; x64)"))
  httr::content(req, as = "parsed", encoding = "UTF-8")
}, error = function(e) {
  message("Error: ", e$message)
  NULL
})

if (!is.null(res)) {
  obs <- res |> 
    rvest::html_nodes(xpath = "//*[@id='content']/div/div[3]/div/div[3]/section[1]/ol/li/div[@class='Obs']")
  message("Observaciones encontradas con XPath principal: ", length(obs))
  
  if (length(obs) == 0) {
    # Probar selectores CSS genéricos de eBird bird-list
    obs_alt <- res |> rvest::html_nodes(".Obs")
    message("Observaciones con .Obs: ", length(obs_alt))
    
    species_common <- res |> rvest::html_nodes(".Species-common") |> rvest::html_text(trim = TRUE)
    species_sci <- res |> rvest::html_nodes(".Species-sci") |> rvest::html_text(trim = TRUE)
    message(sprintf("Nombres comunes: %d | Nombres científicos: %d", length(species_common), length(species_sci)))
  } else {
    # Extraer primera obs de prueba
    first_obs <- obs[[1]]
    c_name <- first_obs |> rvest::html_nodes(xpath = ".//span[@class='Species-common']") |> rvest::html_text(trim = TRUE)
    s_name <- first_obs |> rvest::html_nodes(xpath = ".//span[@class='Species-sci Species-sub']") |> rvest::html_text(trim = TRUE)
    message(sprintf("Ejemplo 1: %s (%s)", c_name, s_name))
  }
}
