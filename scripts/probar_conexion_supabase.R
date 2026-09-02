#!/usr/bin/env Rscript
# ==============================================================================
# PROBAR_CONEXION_SUPABASE.R: Diagnóstico de Conexión a Supabase
# Municipalidad Provincial de Anta - Gerencia de Desarrollo Urbano y Rural
# ==============================================================================

.libPaths(c(file.path(getwd(), ".r-library"), .libPaths()))

suppressPackageStartupMessages({
  library(DBI)
  library(RPostgres)
})

if (file.exists(".Renviron")) {
  readRenviron(".Renviron")
}

message("=== Diagnóstico de Conexión a Supabase ===")

host <- Sys.getenv("SUPABASE_HOST", "aws-0-us-west-2.pooler.supabase.com")
port <- as.integer(Sys.getenv("SUPABASE_PORT", "5432"))
dbname <- Sys.getenv("SUPABASE_DB", "postgres")
user <- Sys.getenv("SUPABASE_USER", "postgres.biosgkmmkjylceckzmcu")
password <- Sys.getenv("SUPABASE_PASSWORD", "")

message(sprintf("Host: %s", host))
message(sprintf("Port: %d", port))
message(sprintf("Database: %s", dbname))
message(sprintf("User: %s", user))
message(sprintf("Password configurada: %s", ifelse(password == "" || password == "TU_PASSWORD_AQUI", "NO (Pendiente)", "SÍ")))

if (password == "" || password == "TU_PASSWORD_AQUI") {
  stop("Por favor edite el archivo .Renviron e ingrese su contraseña en SUPABASE_PASSWORD.")
}

message("Probando conexión...")

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
  stop(sprintf("Error al conectar: %s", e$message))
})

message("¡Conexión exitosa a Supabase!")

# Verificar versión de PostgreSQL y PostGIS
pg_ver <- DBI::dbGetQuery(con, "SELECT version();")$version
message(sprintf("PostgreSQL Version: %s", pg_ver))

postgis_check <- tryCatch({
  DBI::dbGetQuery(con, "SELECT PostGIS_Full_Version();")$postgis_full_version
}, error = function(e) "No habilitada aún")

message(sprintf("PostGIS Status: %s", postgis_check))

DBI::dbDisconnect(con)
message("Prueba finalizada correctamente.")
