#!/usr/bin/env Rscript
# ==============================================================================
# MIGRAR_A_SUPABASE.R: Migración y Carga de Datos de Biodiversidad a Supabase
# Municipalidad Provincial de Anta - Gerencia de Desarrollo Urbano y Rural (GDUR)
# ==============================================================================

.libPaths(c(file.path(getwd(), ".r-library"), .libPaths()))

suppressPackageStartupMessages({
  library(DBI)
  library(RPostgres)
  library(sf)
  library(dplyr)
})

# Cargar variables de entorno de .Renviron si existe
if (file.exists(".Renviron")) {
  readRenviron(".Renviron")
}

message("=================================================================")
message("  MIGRACIÓN DE BIODIVERSIDAD DE ANTA A SUPABASE (POSTGIS)")
message("  Municipalidad Provincial de Anta · GDUR")
message("=================================================================")

# Parámetros de conexión
host <- Sys.getenv("SUPABASE_HOST", "aws-0-us-west-2.pooler.supabase.com")
port <- as.integer(Sys.getenv("SUPABASE_PORT", "5432"))
dbname <- Sys.getenv("SUPABASE_DB", "postgres")
user <- Sys.getenv("SUPABASE_USER", "postgres.biosgkmmkjylceckzmcu")
password <- Sys.getenv("SUPABASE_PASSWORD", "")

if (password == "" || password == "TU_PASSWORD_AQUI") {
  stop("Por favor configure SUPABASE_PASSWORD en el archivo .Renviron antes de ejecutar la migracion.")
}

message(sprintf("Conectando a Supabase PostgreSQL en %s:%d...", host, port))

con <- DBI::dbConnect(
  RPostgres::Postgres(),
  host = host,
  port = port,
  dbname = dbname,
  user = user,
  password = password,
  sslmode = "require",
  connect_timeout = 30
)

on.exit({
  if (exists("con") && DBI::dbIsValid(con)) {
    DBI::dbDisconnect(con)
    message("Conexión con Supabase cerrada correctamente.")
  }
}, add = TRUE)

message("Conexión exitosa a Supabase.")

# ── 1. Ejecutar DDL del Esquema ───────────────────────────────────────────────
message("\n--- Paso 1: Creando Tablas Tabulares ---")
schema_sql <- readLines("scripts/supabase_schema.sql", encoding = "UTF-8", warn = FALSE)
schema_sql_clean <- paste(schema_sql[!grepl("^--", schema_sql)], collapse = "\n")

statements <- strsplit(schema_sql_clean, ";(?=(?:[^']*'[^']*')*[^']*$)", perl = TRUE)[[1]]

for (stmt in statements) {
  stmt_trimmed <- trimws(stmt)
  if (nchar(stmt_trimmed) > 5) {
    tryCatch({
      DBI::dbExecute(con, stmt_trimmed)
    }, error = function(e) {
      message(sprintf("Aviso en sentencia SQL: %s", e$message))
    })
  }
}
message("Tablas base creadas exitosamente.")

# ── 2. Cargar Tablas Tabulares ────────────────────────────────────────────────
message("\n--- Paso 2: Cargando Tablas Tabulares y Analíticas ---")

# 2.1 Especies por Distrito
path_esp <- "outputs/analisis_biodiversidad/especies_por_distrito.rds"
if (file.exists(path_esp)) {
  df_esp <- readRDS(path_esp)
  message(sprintf("Subiendo tab_especies_distrito (%d filas)...", nrow(df_esp)))
  DBI::dbWriteTable(con, "tab_especies_distrito", df_esp, append = TRUE, row.names = FALSE)
}

# 2.2 Resumen Distritos
path_res <- "outputs/analisis_biodiversidad/resumen_distritos.csv"
if (file.exists(path_res)) {
  df_res <- read.csv(path_res, stringsAsFactors = FALSE)
  message(sprintf("Subiendo tab_resumen_distritos (%d filas)...", nrow(df_res)))
  DBI::dbWriteTable(con, "tab_resumen_distritos", df_res, append = TRUE, row.names = FALSE)
}

# 2.3 Singularidad Distrital
path_sing <- "outputs/analisis_biodiversidad/singularidad_distritos.csv"
if (file.exists(path_sing)) {
  df_sing <- read.csv(path_sing, stringsAsFactors = FALSE)
  message(sprintf("Subiendo tab_singularidad_distritos (%d filas)...", nrow(df_sing)))
  DBI::dbWriteTable(con, "tab_singularidad_distritos", df_sing, append = TRUE, row.names = FALSE)
}

# 2.4 Recambio de Jaccard
path_jacc <- "outputs/analisis_biodiversidad/recambio_jaccard_distritos.csv"
if (file.exists(path_jacc)) {
  df_jacc <- read.csv(path_jacc, stringsAsFactors = FALSE)
  message(sprintf("Subiendo tab_recambio_jaccard (%d filas)...", nrow(df_jacc)))
  DBI::dbWriteTable(con, "tab_recambio_jaccard", df_jacc, append = TRUE, row.names = FALSE)
}

# 2.5 eBird Especies
path_ebird_esp <- "outputs/analisis_biodiversidad/ebird_especies_consolidadas.rds"
if (file.exists(path_ebird_esp)) {
  df_ebird_esp <- readRDS(path_ebird_esp)
  message(sprintf("Subiendo tab_ebird_especies (%d filas)...", nrow(df_ebird_esp)))
  DBI::dbWriteTable(con, "tab_ebird_especies", df_ebird_esp, append = TRUE, row.names = FALSE)
}

# 2.6 eBird Hotspots Resumen
path_ebird_res <- "outputs/analisis_biodiversidad/ebird_hotspots_resumen.rds"
if (file.exists(path_ebird_res)) {
  df_ebird_res <- readRDS(path_ebird_res)
  message(sprintf("Subiendo tab_ebird_hotspots_resumen (%d filas)...", nrow(df_ebird_res)))
  DBI::dbWriteTable(con, "tab_ebird_hotspots_resumen", df_ebird_res, append = TRUE, row.names = FALSE)
}

# 2.7 Cobertura Cuadrícula
path_cuad <- "outputs/analisis_biodiversidad/cobertura_cuadricula_5km.csv"
if (file.exists(path_cuad)) {
  df_cuad <- read.csv(path_cuad, stringsAsFactors = FALSE)
  message(sprintf("Subiendo tab_cobertura_cuadricula (%d filas)...", nrow(df_cuad)))
  DBI::dbWriteTable(con, "tab_cobertura_cuadricula", df_cuad, append = TRUE, row.names = FALSE)
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
  
  # Crear capa vacía primero
  sf::st_write(sf_occ_puntos[1:100, ], con, "geo_ocurrencias_puntos", delete_layer = TRUE, append = FALSE, row.names = FALSE)
  
  # Cargar el resto por lotes para optimizar transferencia
  batch_size <- 10000
  n_total <- nrow(sf_occ_puntos)
  n_batches <- ceiling(n_total / batch_size)
  
  # Subir lotes desde el índice 101
  sf_rest <- sf_occ_puntos[101:n_total, ]
  n_rest <- nrow(sf_rest)
  n_rest_batches <- ceiling(n_rest / batch_size)
  
  for (b in seq_len(n_rest_batches)) {
    i_start <- (b - 1) * batch_size + 1
    i_end <- min(b * batch_size, n_rest)
    batch_sf <- sf_rest[i_start:i_end, ]
    message(sprintf("  -> Lote %d/%d: filas %d a %d...", b, n_rest_batches, i_start + 100, i_end + 100))
    sf::st_write(batch_sf, con, "geo_ocurrencias_puntos", append = TRUE, row.names = FALSE)
  }
}

# ── 4. Crear Índices y Funciones PostGIS ───────────────────────────────────────
message("\n--- Paso 4: Creando Índices Espaciales y Funciones RPC ---")

# Detectar nombre de columna de geometría en geo_ocurrencias_puntos
geom_cols <- DBI::dbGetQuery(con, "
  SELECT column_name 
  FROM information_schema.columns 
  WHERE table_name = 'geo_ocurrencias_puntos' AND data_type = 'USER-DEFINED'
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
  message("Aviso en creación de índices: ", e$message)
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
  message("Aviso en creación de función RPC: ", e$message)
})

# ── 5. Verificación y Conteos ─────────────────────────────────────────────────
message("\n=================================================================")
message("  VERIFICACIÓN FINAL DE DATOS EN SUPABASE")
message("=================================================================")

tablas <- c(
  "tab_especies_distrito", "tab_resumen_distritos", "tab_singularidad_distritos",
  "tab_recambio_jaccard", "tab_ebird_especies", "tab_ebird_hotspots_resumen",
  "tab_cobertura_cuadricula", "geo_distritos", "geo_cuadricula_5km",
  "geo_ebird_hotspots", "geo_ocurrencias_mapa", "geo_ocurrencias_puntos"
)

for (tb in tablas) {
  tryCatch({
    cnt <- DBI::dbGetQuery(con, sprintf("SELECT COUNT(*) AS n FROM %s", tb))$n
    message(sprintf("  ✓ %-30s : %s registros", tb, format(cnt, big.mark = ",")))
  }, error = function(e) {
    message(sprintf("  ✗ %-30s : Error (%s)", tb, e$message))
  })
}

message("\n¡Migración a Supabase completada con éxito!")
