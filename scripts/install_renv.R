lib_dir <- file.path(getwd(), ".r-library")
options(repos = c(CRAN = "https://cloud.r-project.org"))
install.packages("renv", lib = lib_dir)
cat("renv instalado en .r-library\n")
