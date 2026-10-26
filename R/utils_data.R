# ==============================================================================
# UTILS_DATA.R: Funciones de carga y estructuración de datos de biodiversidad
# Municipalidad Provincial de Anta - Gerencia de Desarrollo Urbano y Rural
# Carga desde Neon PostgreSQL + PostGIS; fallback local optativo para desarrollo
# ==============================================================================

if (file.exists("R/utils_supabase.R")) {
  source("R/utils_supabase.R", encoding = "UTF-8")
}

local_fallback_enabled <- function() {
  identical(tolower(Sys.getenv("BIODIVERSIDAD_ALLOW_LOCAL_FALLBACK", "false")), "true")
}

load_neon_required <- function() {
  con <- supabase_connect()
  if (is.null(con)) stop("No se pudo conectar a Neon. Verifica NEON_DATABASE_URL.", call. = FALSE)
  required <- c(
    "tab_especies_distrito", "geo_ocurrencias_puntos", "geo_ocurrencias_mapa",
    "tab_resumen_distritos", "tab_singularidad_distritos", "tab_recambio_jaccard",
    "tab_cobertura_cuadricula", "geo_distritos", "geo_cuadricula_5km",
    "tab_ebird_especies", "tab_ebird_hotspots_resumen", "geo_ebird_hotspots"
  )
  missing <- required[!vapply(required, DBI::dbExistsTable, logical(1), conn = con)]
  if (length(missing) > 0) {
    stop("Faltan tablas/capas en Neon: ", paste(missing, collapse = ", "),
         ". Ejecuta scripts/actualizar_neon.R para cargarlas.", call. = FALSE)
  }
  invisible(con)
}

# Cargar tabla desde Neon; ante error solo usar local si se habilitó explícitamente.
load_neon_table_or_local <- function(table_name, local_loader) {
  con <- supabase_connect()
  if (!is.null(con)) {
    data <- tryCatch(DBI::dbReadTable(con, table_name), error = function(e) {
      if (!local_fallback_enabled()) {
        stop("No se pudo leer ", table_name, " en Neon: ", conditionMessage(e), call. = FALSE)
      }
      NULL
    })
    if (!is.null(data) && nrow(data) > 0) return(data)
    if (!local_fallback_enabled()) {
      stop("La tabla Neon ", table_name, " está vacía.", call. = FALSE)
    }
  } else if (!local_fallback_enabled()) {
    stop("No hay conexión a Neon. Verifica NEON_DATABASE_URL.", call. = FALSE)
  }
  local_loader()
}

load_neon_sf_or_local <- function(table_name, local_loader) {
  con <- supabase_connect()
  if (!is.null(con)) {
    data <- tryCatch(sf::st_read(con, query = sprintf("SELECT * FROM %s", table_name), quiet = TRUE),
                     error = function(e) {
                       if (!local_fallback_enabled()) {
                         stop("No se pudo leer la capa ", table_name, " en Neon: ", conditionMessage(e), call. = FALSE)
                       }
                       NULL
                     })
    if (!is.null(data) && nrow(data) > 0) return(data)
    if (!local_fallback_enabled()) {
      stop("La capa Neon ", table_name, " está vacía.", call. = FALSE)
    }
  } else if (!local_fallback_enabled()) {
    stop("No hay conexión a Neon. Verifica NEON_DATABASE_URL.", call. = FALSE)
  }
  local_loader()
}

# Cargar tabla de especies por distrito
load_especies_distrito <- function() {
  load_neon_table_or_local("tab_especies_distrito", function() {
    rds <- "outputs/analisis_biodiversidad/especies_por_distrito.rds"
    csv <- "outputs/analisis_biodiversidad/especies_por_distrito.csv"
    if (file.exists(rds)) readRDS(rds) else if (file.exists(csv)) read.csv(csv, stringsAsFactors = FALSE) else data.frame()
  })
}

# Cargar ocurrencias espaciales completas (sf)
load_ocurrencias_sf <- function() {
  load_neon_sf_or_local("geo_ocurrencias_puntos", function() {
    p <- "outputs/analisis_biodiversidad/ocurrencias_puntos_sf.rds"
    if (file.exists(p)) readRDS(p) else NULL
  })
}

# Cargar capa espacial agregada para el mapa web
load_ocurrencias_mapa_sf <- function() {
  load_neon_sf_or_local("geo_ocurrencias_mapa", function() {
    p <- "outputs/analisis_biodiversidad/ocurrencias_mapa_sf.rds"
    if (file.exists(p)) readRDS(p) else load_ocurrencias_sf()
  })
}

# Cargar resumen estadístico distrital
load_resumen_distritos <- function() {
  load_neon_table_or_local("tab_resumen_distritos", function() {
    p <- "outputs/analisis_biodiversidad/resumen_distritos.csv"
    if (file.exists(p)) read.csv(p, stringsAsFactors = FALSE) else data.frame()
  })
}

# Cargar tabla de singularidad ecológica
load_singularidad_distritos <- function() {
  load_neon_table_or_local("tab_singularidad_distritos", function() {
    p <- "outputs/analisis_biodiversidad/singularidad_distritos.csv"
    if (file.exists(p)) read.csv(p, stringsAsFactors = FALSE) else data.frame()
  })
}

# Cargar matriz de recambio de Jaccard
load_recambio_jaccard <- function() {
  load_neon_table_or_local("tab_recambio_jaccard", function() {
    p <- "outputs/analisis_biodiversidad/recambio_jaccard_distritos.csv"
    if (file.exists(p)) read.csv(p, stringsAsFactors = FALSE) else data.frame()
  })
}

# Cargar resumen de cuadrícula de 5 km
load_cobertura_cuadricula <- function() {
  load_neon_table_or_local("tab_cobertura_cuadricula", function() {
    p <- "outputs/analisis_biodiversidad/cobertura_cuadricula_5km.csv"
    if (file.exists(p)) read.csv(p, stringsAsFactors = FALSE) else data.frame()
  })
}

# Cargar GeoJSON de distritos con atributos
load_distritos_sf <- function() {
  load_neon_sf_or_local("geo_distritos", function() {
    p <- "outputs/analisis_biodiversidad/biodiversidad_distritos.geojson"
    if (file.exists(p)) sf::st_read(p, quiet = TRUE) else NULL
  })
}

# Cargar GeoJSON de cuadrícula 5 km
load_cuadricula_sf <- function() {
  load_neon_sf_or_local("geo_cuadricula_5km", function() {
    p <- "outputs/analisis_biodiversidad/cobertura_cuadricula_5km.geojson"
    if (file.exists(p)) sf::st_read(p, quiet = TRUE) else NULL
  })
}

# ── eBird Datasets ────────────────────────────────────────────────────────────

# Cargar capa espacial sf de hotspots de eBird
load_ebird_hotspots_sf <- function() {
  load_neon_sf_or_local("geo_ebird_hotspots", function() {
    p <- "outputs/analisis_biodiversidad/ebird_hotspots_anta.geojson"
    if (file.exists(p)) sf::st_read(p, quiet = TRUE) else NULL
  })
}

# Cargar tabla consolidada de aves eBird validadas con avesperu
load_ebird_especies <- function() {
  load_neon_table_or_local("tab_ebird_especies", function() {
    rds <- "outputs/analisis_biodiversidad/ebird_especies_consolidadas.rds"
    csv <- "outputs/analisis_biodiversidad/ebird_especies_consolidadas.csv"
    if (file.exists(rds)) readRDS(rds) else if (file.exists(csv)) read.csv(csv, stringsAsFactors = FALSE) else data.frame()
  })
}

# Cargar resumen por hotspot de eBird
load_ebird_resumen <- function() {
  load_neon_table_or_local("tab_ebird_hotspots_resumen", function() {
    rds <- "outputs/analisis_biodiversidad/ebird_hotspots_resumen.rds"
    csv <- "outputs/analisis_biodiversidad/ebird_hotspots_resumen.csv"
    if (file.exists(rds)) readRDS(rds) else if (file.exists(csv)) read.csv(csv, stringsAsFactors = FALSE) else data.frame()
  })
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
      load_neon_required()
      message("Cargando catálogo de biodiversidad desde Neon PostgreSQL / PostGIS...")
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
        ebird_hotspots = load_ebird_hotspots_sf(),
        origen = "Neon PostgreSQL / PostGIS"
      )
    }

    cache
  }
})
