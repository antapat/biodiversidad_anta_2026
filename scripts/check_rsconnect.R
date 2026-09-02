# Instalar rsconnect si no está presente
.libPaths(c(file.path(getwd(), ".r-library"), .libPaths()))
options(repos = c(CRAN = "https://cloud.r-project.org"))

lib_dir <- file.path(getwd(), ".r-library")
installed <- rownames(installed.packages(lib.loc = lib_dir))

if (!"rsconnect" %in% installed) {
  install.packages("rsconnect", lib = lib_dir)
}

library(rsconnect, lib.loc = lib_dir)
cat("rsconnect disponible versión:", as.character(packageVersion("rsconnect")), "\n")
