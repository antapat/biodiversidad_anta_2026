# Aislar .libPaths a solo .r-library
lib_dir <- file.path(getwd(), ".r-library")
.libPaths(lib_dir)

suppressPackageStartupMessages({
  library(rsconnect)
})

deps <- rsconnect::appDependencies(appDir = getwd())
cat("Total dependencias detectadas:", nrow(deps), "\n")
cat("¿terra presente en dependencias?:", "terra" %in% deps$Package, "\n")
