# Ejecutar desde RStudio con Source para cargar los datos en Neon.
# Cambia dry_run a TRUE solo si deseas validar archivos sin escribir en la base.

actualizar_neon <- function(dry_run = FALSE, project_dir = NULL) {
  if (is.null(project_dir)) {
    project_dir <- tryCatch(
      normalizePath(rstudioapi::getActiveProject(), winslash = "/", mustWork = TRUE),
      error = function(e) normalizePath(getwd(), winslash = "/", mustWork = TRUE)
    )
  }
  if (basename(project_dir) == "scripts") project_dir <- dirname(project_dir)
  if (!file.exists(file.path(project_dir, "scripts", "migrar_a_supabase.R"))) {
    stop("No encuentro el proyecto. Abre el archivo biodiversidad_anta_2026.Rproj en RStudio o pasa project_dir explícitamente.")
  }

  if (!dry_run) {
    required_packages <- c("DBI", "RPostgres", "sf", "dplyr")
    unavailable <- required_packages[!vapply(required_packages, requireNamespace,
                                            logical(1), quietly = TRUE)]
    if (length(unavailable) > 0) {
      stop(
        "No se puede cargar a Neon porque faltan paquetes R: ",
        paste(unavailable, collapse = ", "), ". Instálalos en esta versión de R con:\n",
        "install.packages(c(", paste(sprintf('"%s"', unavailable), collapse = ", "), "))"
      )
    }
  }

  old_wd <- getwd()
  on.exit(setwd(old_wd), add = TRUE)
  setwd(project_dir)

  migration_path <- normalizePath(file.path("scripts", "migrar_a_supabase.R"),
                                  winslash = "/", mustWork = TRUE)
  output <- system2(file.path(R.home("bin"), "Rscript.exe"),
                    args = c("--vanilla", shQuote(migration_path),
                             paste0("--project-root=", shQuote(project_dir)),
                             if (dry_run) "--dry-run"),
                    stdout = TRUE, stderr = TRUE)
  status <- attr(output, "status")
  if (is.null(status)) status <- 0L
  cat(paste(output, collapse = "\n"), "\n")
  if (status != 0L) stop("El proceso de carga terminó con error (código ", status, ").")
  invisible(TRUE)
}

# Source realiza la carga real. Para una simulación, usa TRUE explícitamente.
actualizar_neon(dry_run = FALSE)
