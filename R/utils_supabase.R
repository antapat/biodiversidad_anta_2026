# ==============================================================================
# UTILS_DATABASE.R: Conector y Consultas PostgreSQL (Neon o Supabase)
# Municipalidad Provincial de Anta - Gerencia de Desarrollo Urbano y Rural (GDUR)
# ==============================================================================

# Carga opcional y segura de dependencias de base de datos
if (requireNamespace("DBI", quietly = TRUE)) suppressPackageStartupMessages(library(DBI))
if (requireNamespace("RPostgres", quietly = TRUE)) suppressPackageStartupMessages(library(RPostgres))
if (requireNamespace("sf", quietly = TRUE)) suppressPackageStartupMessages(library(sf))

# El nombre supabase_* se mantiene como API interna para no cambiar los módulos.
database_env <- new.env(parent = emptyenv())
database_env$con <- NULL

#' Obtener o reutilizar conexión PostgreSQL (Neon prioritario; Supabase opcional)
#' @return Conexión DBI a PostgreSQL
supabase_connect <- function() {
  if (!is.null(database_env$con) && DBI::dbIsValid(database_env$con)) {
    return(database_env$con)
  }
  
  if (file.exists(".Renviron")) {
    readRenviron(".Renviron")
  }
  
  # NEON_DATABASE_URL puede pegarse desde el botón Connect de Neon (pooler o directo).
  database_url <- Sys.getenv("NEON_DATABASE_URL", "")
  neon_host <- Sys.getenv("NEON_HOST", "")
  neon_password <- Sys.getenv("NEON_PASSWORD", "")
  use_neon <- nzchar(database_url) || (nzchar(neon_host) && nzchar(neon_password))

  if (use_neon) {
    con <- tryCatch({
      if (nzchar(database_url)) {
        parsed_url <- utils::URLdecode(database_url)
        url_parts <- regexec("^postgres(?:ql)?://([^:]+):([^@]+)@([^/:?]+)(?::([0-9]+))?/([^?]+)(?:\\?(.*))?$",
                             parsed_url, perl = TRUE)
        url_match <- regmatches(parsed_url, url_parts)[[1]]
        if (length(url_match) == 0) stop("NEON_DATABASE_URL no tiene el formato esperado.")
        query <- if (length(url_match) >= 7 && nzchar(url_match[[7]])) {
          strsplit(url_match[[7]], "&", fixed = TRUE)[[1]]
        } else character()
        query_values <- list()
        for (item in query) {
          pair <- strsplit(item, "=", fixed = TRUE)[[1]]
          if (length(pair) >= 2) query_values[[utils::URLdecode(pair[[1]])]] <- utils::URLdecode(pair[[2]])
        }
        con_args <- list(
          drv = RPostgres::Postgres(), host = url_match[[4]],
          port = if (nzchar(url_match[[5]])) as.integer(url_match[[5]]) else 5432L,
          dbname = url_match[[6]], user = utils::URLdecode(url_match[[2]]),
          password = utils::URLdecode(url_match[[3]]), sslmode = "require",
          connect_timeout = 15
        )
        if (!is.null(query_values$channel_binding)) con_args$channel_binding <- query_values$channel_binding
        if (!is.null(query_values$sslmode)) con_args$sslmode <- query_values$sslmode
        do.call(DBI::dbConnect, con_args)
      } else {
        DBI::dbConnect(
          RPostgres::Postgres(), host = neon_host,
          port = as.integer(Sys.getenv("NEON_PORT", "5432")),
          dbname = Sys.getenv("NEON_DB", "neondb"),
          user = Sys.getenv("NEON_USER", "neondb_owner"),
          password = neon_password, sslmode = "require", connect_timeout = 15
        )
      }
    }, error = function(e) {
      warning("No se pudo conectar a Neon: ", e$message)
      NULL
    })
    database_env$con <- con
    return(con)
  }

  if (nzchar(Sys.getenv("NEON_DATABASE_URL", "")) || nzchar(Sys.getenv("NEON_HOST", ""))) {
    return(NULL)
  }

  host <- Sys.getenv("SUPABASE_HOST", "")
  port <- as.integer(Sys.getenv("SUPABASE_PORT", "5432"))
  dbname <- Sys.getenv("SUPABASE_DB", "postgres")
  user <- Sys.getenv("SUPABASE_USER", "")
  password <- Sys.getenv("SUPABASE_PASSWORD", "")

  if (host == "" || password == "" || password == "TU_PASSWORD_AQUI") {
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
      warning("No se pudo conectar a PostgreSQL: ", e2$message)
      return(NULL)
    })
  })
  
  database_env$con <- con
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
