#!/usr/bin/env Rscript
# ==============================================================================
# MIGRAR_A_NEON.R: Migración y Carga de Datos de Biodiversidad a Neon PostgreSQL
# Municipalidad Provincial de Anta - Gerencia de Desarrollo Urbano y Rural (GDUR)
# ==============================================================================

script_args <- commandArgs(trailingOnly = TRUE)
dry_run <- "--dry-run" %in% script_args
root_arg <- grep("^--project-root=", script_args, value = TRUE)
project_root <- if (length(root_arg) > 0) {
  sub("^--project-root=", "", root_arg[[1]])
} else {
  normalizePath(getwd(), winslash = "/", mustWork = TRUE)
}

# Rscript --vanilla no carga .Renviron automáticamente; cargar el del proyecto.
project_root <- normalizePath(project_root, winslash = "/", mustWork = TRUE)
setwd(project_root)
renviron_path <- file.path(project_root, ".Renviron")
if (file.exists(renviron_path)) {
  readRenviron(renviron_path)
}

message("=================================================================")
message("  CARGA DE BIODIVERSIDAD DE ANTA A NEON (POSTGIS)")
message("  Municipalidad Provincial de Anta · GDUR")
message("=================================================================")

data_dir <- "outputs/analisis_biodiversidad"
required_files <- c(
  "especies_por_distrito.rds", "resumen_distritos.csv",
  "singularidad_distritos.csv", "recambio_jaccard_distritos.csv",
  "ebird_especies_consolidadas.rds", "ebird_hotspots_resumen.rds",
  "cobertura_cuadricula_5km.csv", "biodiversidad_distritos.geojson",
  "cobertura_cuadricula_5km.geojson", "ebird_hotspots_anta.geojson",
  "ocurrencias_mapa_sf.rds", "ocurrencias_puntos_sf.rds"
)
missing_files <- required_files[!file.exists(file.path(data_dir, required_files))]
if (length(missing_files) > 0) {
  stop("Faltan archivos fuente requeridos: ", paste(missing_files, collapse = ", "))
}
if (dry_run) {
  message("Modo simulación: todos los archivos fuente están presentes; Neon no será modificado.")
  if (sys.nframe() == 0L) quit(save = "no", status = 0)
  return(invisible(TRUE))
}

.libPaths(c(file.path(getwd(), ".r-library"), .libPaths()))

suppressPackageStartupMessages({
  library(DBI)
  library(RPostgres)
  library(sf)
  library(dplyr)
})

# Parámetros de conexión
database_url <- Sys.getenv("NEON_DATABASE_URL", "")
host <- Sys.getenv("NEON_HOST", "")
port <- as.integer(Sys.getenv("NEON_PORT", "5432"))
dbname <- Sys.getenv("NEON_DB", "neondb")
user <- Sys.getenv("NEON_USER", "neondb_owner")
password <- Sys.getenv("NEON_PASSWORD", "")

if (!nzchar(database_url) && (host == "" || password == "")) {
  stop("Configure NEON_DATABASE_URL o NEON_HOST/NEON_PASSWORD en .Renviron antes de ejecutar la carga.")
}

message(sprintf("Configuración Neon detectada: %s", if (nzchar(database_url)) "URL" else "host y credenciales"))

message("Conectando a Neon PostgreSQL...")
if (nzchar(database_url)) {
  parsed_url <- utils::URLdecode(database_url)
  url_parts <- regexec("^postgres(?:ql)?://([^:]+):([^@]+)@([^/:?]+)(?::([0-9]+))?/([^?]+)(?:\\?(.*))?$",
                       parsed_url, perl = TRUE)
  url_match <- regmatches(parsed_url, url_parts)[[1]]
  if (length(url_match) == 0) {
    stop("NEON_DATABASE_URL no tiene el formato PostgreSQL esperado.")
  }
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
    connect_timeout = 30
  )
  if (!is.null(query_values$channel_binding)) con_args$channel_binding <- query_values$channel_binding
  if (!is.null(query_values$sslmode)) con_args$sslmode <- query_values$sslmode
  message(sprintf("Destino de conexión: host=%s, puerto=%s, base=%s, usuario=%s",
                  con_args$host, con_args$port, con_args$dbname, con_args$user))
  con <- do.call(DBI::dbConnect, con_args)
} else {
  con <- DBI::dbConnect(
    RPostgres::Postgres(), host = host, port = port, dbname = dbname,
    user = user, password = password, sslmode = "require", connect_timeout = 30
  )
}

on.exit({
  if (exists("con") && DBI::dbIsValid(con)) {
    DBI::dbDisconnect(con)
    message("Conexión con Neon cerrada correctamente.")
  }
}, add = TRUE)

message("Conexión exitosa a Neon.")

# ── 1. Ejecutar DDL del Esquema ───────────────────────────────────────────────
message("\n--- Paso 1: Creando Tablas Tabulares ---")
DBI::dbExecute(con, "CREATE EXTENSION IF NOT EXISTS postgis")
schema_sql <- readLines("scripts/supabase_schema.sql", encoding = "UTF-8", warn = FALSE)
schema_sql_clean <- paste(schema_sql[!grepl("^--", schema_sql)], collapse = "\n")

statements <- strsplit(schema_sql_clean, ";(?=(?:[^']*'[^']*')*[^']*$)", perl = TRUE)[[1]]

for (stmt in statements) {
  stmt_trimmed <- trimws(stmt)
  if (nchar(stmt_trimmed) > 5) {
    tryCatch({
      DBI::dbExecute(con, stmt_trimmed)
    }, error = function(e) {
      stop(sprintf("Falló una sentencia del esquema: %s", e$message))
    })
  }
}
message("Tablas base creadas exitosamente.")

# ── 2. Cargar Tablas Tabulares ────────────────────────────────────────────────
message("\n--- Paso 2: Cargando Tablas Tabulares y Analíticas ---")

replace_table <- function(table_name, data) {
  if (!DBI::dbExistsTable(con, table_name)) {
    stop("La tabla ", table_name, " no existe en el esquema Neon.")
  }
  DBI::dbWithTransaction(con, {
    DBI::dbExecute(con, sprintf("TRUNCATE TABLE %s RESTART IDENTITY",
                                DBI::dbQuoteIdentifier(con, table_name)))
    DBI::dbWriteTable(con, table_name, data, append = TRUE, row.names = FALSE)
  })
}

# 2.1 Especies por Distrito
path_esp <- "outputs/analisis_biodiversidad/especies_por_distrito.rds"
if (file.exists(path_esp)) {
  df_esp <- readRDS(path_esp)
  message(sprintf("Subiendo tab_especies_distrito (%d filas)...", nrow(df_esp)))
  replace_table("tab_especies_distrito", df_esp)
}

# 2.2 Resumen Distritos
path_res <- "outputs/analisis_biodiversidad/resumen_distritos.csv"
if (file.exists(path_res)) {
  df_res <- read.csv(path_res, stringsAsFactors = FALSE)
  message(sprintf("Subiendo tab_resumen_distritos (%d filas)...", nrow(df_res)))
  replace_table("tab_resumen_distritos", df_res)
}

# 2.3 Singularidad Distrital
path_sing <- "outputs/analisis_biodiversidad/singularidad_distritos.csv"
if (file.exists(path_sing)) {
  df_sing <- read.csv(path_sing, stringsAsFactors = FALSE)
  message(sprintf("Subiendo tab_singularidad_distritos (%d filas)...", nrow(df_sing)))
  replace_table("tab_singularidad_distritos", df_sing)
}

# 2.4 Recambio de Jaccard
path_jacc <- "outputs/analisis_biodiversidad/recambio_jaccard_distritos.csv"
if (file.exists(path_jacc)) {
  df_jacc <- read.csv(path_jacc, stringsAsFactors = FALSE)
  message(sprintf("Subiendo tab_recambio_jaccard (%d filas)...", nrow(df_jacc)))
  replace_table("tab_recambio_jaccard", df_jacc)
}

# 2.5 eBird Especies
path_ebird_esp <- "outputs/analisis_biodiversidad/ebird_especies_consolidadas.rds"
if (file.exists(path_ebird_esp)) {
  df_ebird_esp <- readRDS(path_ebird_esp)
  message(sprintf("Subiendo tab_ebird_especies (%d filas)...", nrow(df_ebird_esp)))
  replace_table("tab_ebird_especies", df_ebird_esp)
}

# 2.6 eBird Hotspots Resumen
path_ebird_res <- "outputs/analisis_biodiversidad/ebird_hotspots_resumen.rds"
if (file.exists(path_ebird_res)) {
  df_ebird_res <- readRDS(path_ebird_res)
  message(sprintf("Subiendo tab_ebird_hotspots_resumen (%d filas)...", nrow(df_ebird_res)))
  replace_table("tab_ebird_hotspots_resumen", df_ebird_res)
}

# 2.7 Cobertura Cuadrícula
path_cuad <- "outputs/analisis_biodiversidad/cobertura_cuadricula_5km.csv"
if (file.exists(path_cuad)) {
  df_cuad <- read.csv(path_cuad, stringsAsFactors = FALSE)
  message(sprintf("Subiendo tab_cobertura_cuadricula (%d filas)...", nrow(df_cuad)))
  replace_table("tab_cobertura_cuadricula", df_cuad)
}

# ── 3. Cargar Capas Espaciales PostGIS ─────────────────────────────────────────
message("\n--- Paso 3: Cargando Capas Espaciales PostGIS ---")

# 3.1 Distritos
path_dist_sf <- "outputs/analisis_biodiversidad/biodiversidad_distritos.geojson"
if (file.exists(path_dist_sf)) {
  sf_dist <- sf::st_read(path_dist_sf, quiet = TRUE)
  message(sprintf("Subiendo geo_distritos (%d polígonos)...", nrow(sf_dist)))
  sf::st_write(sf_dist, con, "geo_distritos", delete_layer = TRUE, append = FALSE, row.names = FALSE)
}

# 3.2 Cuadrícula 5 km
path_cuad_sf <- "outputs/analisis_biodiversidad/cobertura_cuadricula_5km.geojson"
if (file.exists(path_cuad_sf)) {
  sf_cuad <- sf::st_read(path_cuad_sf, quiet = TRUE)
  message(sprintf("Subiendo geo_cuadricula_5km (%d celdas)...", nrow(sf_cuad)))
  sf::st_write(sf_cuad, con, "geo_cuadricula_5km", delete_layer = TRUE, append = FALSE, row.names = FALSE)
}

# 3.3 Hotspots eBird
path_hotspots_sf <- "outputs/analisis_biodiversidad/ebird_hotspots_anta.geojson"
if (file.exists(path_hotspots_sf)) {
  sf_hotspots <- sf::st_read(path_hotspots_sf, quiet = TRUE)
  message(sprintf("Subiendo geo_ebird_hotspots (%d puntos)...", nrow(sf_hotspots)))
  sf::st_write(sf_hotspots, con, "geo_ebird_hotspots", delete_layer = TRUE, append = FALSE, row.names = FALSE)
}

# 3.4 Ocurrencias Mapa (Agregadas)
path_occ_mapa <- "outputs/analisis_biodiversidad/ocurrencias_mapa_sf.rds"
if (file.exists(path_occ_mapa)) {
  sf_occ_mapa <- readRDS(path_occ_mapa)
  message(sprintf("Subiendo geo_ocurrencias_mapa (%d puntos)...", nrow(sf_occ_mapa)))
  sf::st_write(sf_occ_mapa, con, "geo_ocurrencias_mapa", delete_layer = TRUE, append = FALSE, row.names = FALSE)
}

# 3.5 Ocurrencias Puntos (67,797 observaciones)
path_occ_puntos <- "outputs/analisis_biodiversidad/ocurrencias_puntos_sf.rds"
if (file.exists(path_occ_puntos)) {
  sf_occ_puntos <- readRDS(path_occ_puntos)
  message(sprintf("Subiendo geo_ocurrencias_puntos (%d puntos completos)...", nrow(sf_occ_puntos)))
  if (nrow(sf_occ_puntos) > 0) {
    batch_size <- 5000
    n_batches <- ceiling(nrow(sf_occ_puntos) / batch_size)
    for (b in seq_len(n_batches)) {
      i_start <- (b - 1) * batch_size + 1
      i_end <- min(b * batch_size, nrow(sf_occ_puntos))
      batch_sf <- sf_occ_puntos[i_start:i_end, ]
      if (b == 1) {
        sf::st_write(batch_sf, con, "geo_ocurrencias_puntos", delete_layer = TRUE,
                     append = FALSE, row.names = FALSE, quiet = TRUE)
      } else {
        sf::st_write(batch_sf, con, "geo_ocurrencias_puntos", append = TRUE,
                     row.names = FALSE, quiet = TRUE)
      }
      message(sprintf("  -> Lote %d/%d: filas %d a %d", b, n_batches, i_start, i_end))
    }
  }
}

# ── 4. Crear Índices y Funciones PostGIS ───────────────────────────────────────
message("\n--- Paso 4: Creando Índices Espaciales y Funciones RPC ---")

# Detectar nombre de columna de geometría en geo_ocurrencias_puntos
geom_cols <- DBI::dbGetQuery(con, "
  SELECT column_name 
  FROM information_schema.columns 
  WHERE table_schema = current_schema() AND table_name = 'geo_ocurrencias_puntos' AND udt_name = 'geometry'
")$column_name

geom_name <- if (length(geom_cols) > 0) geom_cols[1] else "geom"
message(sprintf("Columna geométrica detectada: %s", geom_name))

tryCatch({
  DBI::dbExecute(con, sprintf("CREATE INDEX IF NOT EXISTS idx_geo_occ_geom ON geo_ocurrencias_puntos USING GIST (%s)", geom_name))
  DBI::dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_geo_occ_species ON geo_ocurrencias_puntos (species)")
  DBI::dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_geo_occ_distrito ON geo_ocurrencias_puntos (distrito)")
  DBI::dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_geo_occ_reino ON geo_ocurrencias_puntos (reino)")
  DBI::dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_geo_occ_iucn ON geo_ocurrencias_puntos (iucn_categoria)")
  DBI::dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_geo_occ_amenazada ON geo_ocurrencias_puntos (es_amenazada_iucn)")
  message("Índices espaciales y taxonómicos creados exitosamente.")
}, error = function(e) {
  stop("Falló la creación de índices: ", e$message)
})

# Crear función RPC para consulta rápida de polígono a mano alzada
fn_sql <- sprintf("
CREATE OR REPLACE FUNCTION fn_consultar_especies_zona(p_geojson text)
RETURNS TABLE (
    species VARCHAR,
    reino VARCHAR,
    nombre_cientifico VARCHAR,
    clase VARCHAR,
    familia VARCHAR,
    iucn_categoria VARCHAR,
    distritos_abarcados TEXT,
    n_registros_zona BIGINT,
    fuentes TEXT,
    primer_anio INTEGER,
    ultimo_anio INTEGER
) LANGUAGE sql STABLE AS $BODY$
    WITH zona AS (
        SELECT ST_SetSRID(ST_GeomFromGeoJSON(p_geojson), 4326) AS geom
    )
    SELECT 
        o.species::varchar,
        o.reino::varchar,
        MAX(o.nombre_cientifico)::varchar AS nombre_cientifico,
        MAX(o.clase)::varchar AS clase,
        MAX(o.familia)::varchar AS familia,
        MAX(o.iucn_categoria)::varchar AS iucn_categoria,
        STRING_AGG(DISTINCT o.distrito, ', ') AS distritos_abarcados,
        COUNT(*) AS n_registros_zona,
        STRING_AGG(DISTINCT o.fuente, ' / ') AS fuentes,
        MIN(o.year)::integer AS primer_anio,
        MAX(o.year)::integer AS ultimo_anio
    FROM geo_ocurrencias_puntos o
    JOIN zona z ON ST_Intersects(o.%s, z.geom)
    GROUP BY o.species, o.reino
    ORDER BY n_registros_zona DESC, o.species ASC;
$BODY$;
", geom_name)

tryCatch({
  DBI::dbExecute(con, fn_sql)
  message("Función RPC fn_consultar_especies_zona creada exitosamente.")
}, error = function(e) {
  stop("Falló la creación de la función espacial: ", e$message)
})

# ── 5. Verificación y Conteos ─────────────────────────────────────────────────
message("\n=================================================================")
message("  VERIFICACIÓN FINAL DE DATOS EN NEON")
message("=================================================================")

tablas <- c(
  "tab_especies_distrito", "tab_resumen_distritos", "tab_singularidad_distritos",
  "tab_recambio_jaccard", "tab_ebird_especies", "tab_ebird_hotspots_resumen",
  "tab_cobertura_cuadricula", "geo_distritos", "geo_cuadricula_5km",
  "geo_ebird_hotspots", "geo_ocurrencias_mapa", "geo_ocurrencias_puntos"
)

for (tb in tablas) {
  cnt <- DBI::dbGetQuery(con, sprintf("SELECT COUNT(*) AS n FROM %s",
                                      DBI::dbQuoteIdentifier(con, tb)))$n
  if (is.na(cnt) || cnt < 1) stop("Verificación falló: tabla vacía ", tb)
  message(sprintf("  ✓ %-30s : %s registros", tb, format(cnt, big.mark = ",")))
}

message("\n¡Carga a Neon completada con éxito!")
