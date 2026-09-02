# ==============================================================================
# UTILS_SUPABASE.R: Conector y Consultas a Supabase (PostgreSQL + PostGIS)
# Municipalidad Provincial de Anta - Gerencia de Desarrollo Urbano y Rural (GDUR)
# ==============================================================================

# Carga opcional y segura de dependencias de base de datos
if (requireNamespace("DBI", quietly = TRUE)) suppressPackageStartupMessages(library(DBI))
if (requireNamespace("RPostgres", quietly = TRUE)) suppressPackageStartupMessages(library(RPostgres))
if (requireNamespace("sf", quietly = TRUE)) suppressPackageStartupMessages(library(sf))

# Gestión de conexión singleton / pool a Supabase
supabase_env <- new.env(parent = emptyenv())
supabase_env$con <- NULL

#' Obtener o reutilizar conexión a Supabase
#' @return Conexión DBI a PostgreSQL
supabase_connect <- function() {
  if (!is.null(supabase_env$con) && DBI::dbIsValid(supabase_env$con)) {
    return(supabase_env$con)
  }
  
  if (file.exists(".Renviron")) {
    readRenviron(".Renviron")
  }
  
  host <- Sys.getenv("SUPABASE_HOST", "aws-0-us-west-2.pooler.supabase.com")
  port <- as.integer(Sys.getenv("SUPABASE_PORT", "5432"))
  dbname <- Sys.getenv("SUPABASE_DB", "postgres")
  user <- Sys.getenv("SUPABASE_USER", "postgres.biosgkmmkjylceckzmcu")
  password <- Sys.getenv("SUPABASE_PASSWORD", "")
  
  if (password == "" || password == "TU_PASSWORD_AQUI") {
    return(NULL)
  }
  
  con <- tryCatch({
    DBI::dbConnect(
      RPostgres::Postgres(),
      host = host,
      port = port,
      dbname = dbname,
      user = user,
      password = password,
      sslmode = "require",
      connect_timeout = 15
    )
  }, error = function(e) {
    # Fallback con host directo
    alt_host <- Sys.getenv("SUPABASE_DIRECT_HOST", "db.biosgkmmkjylceckzmcu.supabase.co")
    tryCatch({
      DBI::dbConnect(
        RPostgres::Postgres(),
        host = alt_host,
        port = 5432,
        dbname = dbname,
        user = "postgres",
        password = password,
        sslmode = "require",
        connect_timeout = 15
      )
    }, error = function(e2) {
      warning("No se pudo conectar a Supabase: ", e2$message)
      return(NULL)
    })
  })
  
  supabase_env$con <- con
  return(con)
}

#' Leer tabla tabular desde Supabase
#' @param table_name Nombre de la tabla
#' @return data.frame
supabase_read_table <- function(table_name) {
  con <- supabase_connect()
  if (is.null(con)) return(NULL)
  
  tryCatch({
    DBI::dbReadTable(con, table_name)
  }, error = function(e) {
    warning(sprintf("Error al leer tabla %s desde Supabase: %s", table_name, e$message))
    return(NULL)
  })
}

#' Leer capa espacial PostGIS desde Supabase
#' @param table_name Nombre de la tabla espacial
#' @param geom_col Nombre de la columna de geometría
#' @return sf object
supabase_read_sf <- function(table_name, geom_col = "geom") {
  con <- supabase_connect()
  if (is.null(con)) return(NULL)
  
  tryCatch({
    sf::st_read(con, query = sprintf("SELECT * FROM %s", table_name), quiet = TRUE)
  }, error = function(e) {
    warning(sprintf("Error al leer capa espacial %s desde Supabase: %s", table_name, e$message))
    return(NULL)
  })
}

#' Consultar especies dentro de una geometría dibujada usando PostGIS RPC en Supabase
#' @param geojson_str Cadena GeoJSON del polígono dibujado
#' @return data.frame con resumen taxonómico de especies
supabase_consultar_zona <- function(geojson_str) {
  con <- supabase_connect()
  if (is.null(con)) return(NULL)
  
  tryCatch({
    query <- "SELECT * FROM fn_consultar_especies_zona($1)"
    res <- DBI::dbGetQuery(con, query, params = list(geojson_str))
    return(res)
  }, error = function(e) {
    warning("Error al consultar zona espacial en Supabase: ", e$message)
    return(NULL)
  })
}
