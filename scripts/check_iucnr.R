# Verificar e instalar iucnr
.libPaths(c(file.path(getwd(), ".r-library"), .libPaths()))
options(repos = c(CRAN = "https://cloud.r-project.org"))

lib_dir <- file.path(getwd(), ".r-library")
installed <- rownames(installed.packages(lib.loc = lib_dir))

if (!"iucnr" %in% installed) {
  if (!"remotes" %in% installed) {
    install.packages("remotes", lib = lib_dir)
  }
  library(remotes, lib.loc = lib_dir)
  remotes::install_github("PaulESantos/iucnr", lib = lib_dir, upgrade = "never")
}

library(iucnr, lib.loc = lib_dir)
cat("iucnr cargado exitosamente!\n")
print(ls("package:iucnr"))
