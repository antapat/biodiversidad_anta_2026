# ==============================================================================
# UTILS_DATA.R: Funciones de carga y estructuración de datos de biodiversidad
# Municipalidad Provincial de Anta - Gerencia de Desarrollo Urbano y Rural
# Integra conexión Supabase (PostgreSQL + PostGIS) con fallback local
# ==============================================================================

if (file.exists("R/utils_supabase.R")) {
  source("R/utils_supabase.R", encoding = "UTF-8")
}

# Cargar tabla de especies por distrito
load_especies_distrito <- function() {
  # 1. Intentar desde Supabase
  sb_data <- tryCatch(supabase_read_table("tab_especies_distrito"), error = function(e) NULL)
  if (!is.null(sb_data) && nrow(sb_data) > 0) {
    return(sb_data)
  }
  
  # 2. Fallback local
  rds_path <- "outputs/analisis_biodiversidad/especies_por_distrito.rds"
  csv_path <- "outputs/analisis_biodiversidad/especies_por_distrito.csv"
  
  if (file.exists(rds_path)) {
    return(readRDS(rds_path))
  } else if (file.exists(csv_path)) {
    return(read.csv(csv_path, stringsAsFactors = FALSE))
  } else {
    stop("No se encontró el archivo de especies por distrito ni en Supabase ni localmente.")
  }
}

# Cargar ocurrencias espaciales completas (sf)
load_ocurrencias_sf <- function() {
  # 1. Intentar desde Supabase
  sb_data <- tryCatch(supabase_read_sf("geo_ocurrencias_puntos"), error = function(e) NULL)
  if (!is.null(sb_data) && nrow(sb_data) > 0) {
    return(sb_data)
  }
  
  # 2. Fallback local
  rds_path <- "outputs/analisis_biodiversidad/ocurrencias_puntos_sf.rds"
  if (file.exists(rds_path)) {
    return(readRDS(rds_path))
  }
  return(NULL)
}

# Cargar capa espacial agregada para el mapa web
load_ocurrencias_mapa_sf <- function() {
  # 1. Intentar desde Supabase
  sb_data <- tryCatch(supabase_read_sf("geo_ocurrencias_mapa"), error = function(e) NULL)
  if (!is.null(sb_data) && nrow(sb_data) > 0) {
    return(sb_data)
  }
  
  # 2. Fallback local
  rds_path <- "outputs/analisis_biodiversidad/ocurrencias_mapa_sf.rds"
  if (file.exists(rds_path)) {
    return(readRDS(rds_path))
  }
  load_ocurrencias_sf()
}

# Cargar resumen estadístico distrital
load_resumen_distritos <- function() {
  sb_data <- tryCatch(supabase_read_table("tab_resumen_distritos"), error = function(e) NULL)
  if (!is.null(sb_data) && nrow(sb_data) > 0) {
    return(sb_data)
  }
  
  path <- "outputs/analisis_biodiversidad/resumen_distritos.csv"
  if (file.exists(path)) {
    return(read.csv(path, stringsAsFactors = FALSE))
  }
  return(data.frame())
}

# Cargar tabla de singularidad ecológica
load_singularidad_distritos <- function() {
  sb_data <- tryCatch(supabase_read_table("tab_singularidad_distritos"), error = function(e) NULL)
  if (!is.null(sb_data) && nrow(sb_data) > 0) {
    return(sb_data)
  }
  
  path <- "outputs/analisis_biodiversidad/singularidad_distritos.csv"
  if (file.exists(path)) {
    return(read.csv(path, stringsAsFactors = FALSE))
  }
  return(data.frame())
}

# Cargar matriz de recambio de Jaccard
load_recambio_jaccard <- function() {
  sb_data <- tryCatch(supabase_read_table("tab_recambio_jaccard"), error = function(e) NULL)
  if (!is.null(sb_data) && nrow(sb_data) > 0) {
    return(sb_data)
  }
  
  path <- "outputs/analisis_biodiversidad/recambio_jaccard_distritos.csv"
  if (file.exists(path)) {
    return(read.csv(path, stringsAsFactors = FALSE))
  }
  return(data.frame())
}

# Cargar resumen de cuadrícula de 5 km
load_cobertura_cuadricula <- function() {
  sb_data <- tryCatch(supabase_read_table("tab_cobertura_cuadricula"), error = function(e) NULL)
  if (!is.null(sb_data) && nrow(sb_data) > 0) {
    return(sb_data)
  }
  
  path <- "outputs/analisis_biodiversidad/cobertura_cuadricula_5km.csv"
  if (file.exists(path)) {
    return(read.csv(path, stringsAsFactors = FALSE))
  }
  return(data.frame())
}

# Cargar GeoJSON de distritos con atributos
load_distritos_sf <- function() {
  sb_data <- tryCatch(supabase_read_sf("geo_distritos"), error = function(e) NULL)
  if (!is.null(sb_data) && nrow(sb_data) > 0) {
    return(sb_data)
  }
  
  path <- "outputs/analisis_biodiversidad/biodiversidad_distritos.geojson"
  if (file.exists(path)) {
    return(sf::st_read(path, quiet = TRUE))
  }
  return(NULL)
}

# Cargar GeoJSON de cuadrícula 5 km
load_cuadricula_sf <- function() {
  sb_data <- tryCatch(supabase_read_sf("geo_cuadricula_5km"), error = function(e) NULL)
  if (!is.null(sb_data) && nrow(sb_data) > 0) {
    return(sb_data)
  }
  
  path <- "outputs/analisis_biodiversidad/cobertura_cuadricula_5km.geojson"
  if (file.exists(path)) {
    return(sf::st_read(path, quiet = TRUE))
  }
  return(NULL)
}

# ── eBird Datasets ────────────────────────────────────────────────────────────

# Cargar capa espacial sf de hotspots de eBird
load_ebird_hotspots_sf <- function() {
  sb_data <- tryCatch(supabase_read_sf("geo_ebird_hotspots"), error = function(e) NULL)
  if (!is.null(sb_data) && nrow(sb_data) > 0) {
    return(sb_data)
  }
  
  path <- "outputs/analisis_biodiversidad/ebird_hotspots_anta.geojson"
  if (file.exists(path)) {
    return(sf::st_read(path, quiet = TRUE))
  }
  return(NULL)
}

# Cargar tabla consolidada de aves eBird validadas con avesperu
load_ebird_especies <- function() {
  sb_data <- tryCatch(supabase_read_table("tab_ebird_especies"), error = function(e) NULL)
  if (!is.null(sb_data) && nrow(sb_data) > 0) {
    return(sb_data)
  }
  
  rds_path <- "outputs/analisis_biodiversidad/ebird_especies_consolidadas.rds"
  csv_path <- "outputs/analisis_biodiversidad/ebird_especies_consolidadas.csv"
  if (file.exists(rds_path)) {
    return(readRDS(rds_path))
  } else if (file.exists(csv_path)) {
    return(read.csv(csv_path, stringsAsFactors = FALSE))
  }
  return(data.frame())
}

# Cargar resumen por hotspot de eBird
load_ebird_resumen <- function() {
  sb_data <- tryCatch(supabase_read_table("tab_ebird_hotspots_resumen"), error = function(e) NULL)
  if (!is.null(sb_data) && nrow(sb_data) > 0) {
    return(sb_data)
  }
  
  rds_path <- "outputs/analisis_biodiversidad/ebird_hotspots_resumen.rds"
  csv_path <- "outputs/analisis_biodiversidad/ebird_hotspots_resumen.csv"
  if (file.exists(rds_path)) {
    return(readRDS(rds_path))
  } else if (file.exists(csv_path)) {
    return(read.csv(csv_path, stringsAsFactors = FALSE))
  }
  return(data.frame())
}

# Formateadores de texto
fmt_num <- function(x) {
  if (is.null(x) || is.na(x) || length(x) == 0) return("0")
  format(round(as.numeric(x)), big.mark = ",", scientific = FALSE)
}

fmt_pct <- function(x, digits = 1) {
  if (is.null(x) || is.na(x) || length(x) == 0) return("0.0%")
  paste0(format(round(as.numeric(x), digits), nsmall = digits), "%")
}

# Caché compartido por todos los usuarios de un mismo proceso Shiny.
load_app_data <- local({
  cache <- NULL

  function(refresh = FALSE) {
    if (is.null(cache) || isTRUE(refresh)) {
      message("Cargando catálogo de biodiversidad (Supabase / local)...")
      cache <<- list(
        especies = load_especies_distrito(),
        ocurrencias = load_ocurrencias_sf(),
        ocurrencias_mapa = load_ocurrencias_mapa_sf(),
        resumen = load_resumen_distritos(),
        singularidad = load_singularidad_distritos(),
        recambio = load_recambio_jaccard(),
        cuadricula = load_cobertura_cuadricula(),
        distritos = load_distritos_sf(),
        cuadricula_sf = load_cuadricula_sf(),
        ebird_especies = load_ebird_especies(),
        ebird_resumen = load_ebird_resumen(),
        ebird_hotspots = load_ebird_hotspots_sf()
      )
    }

    cache
  }
})
