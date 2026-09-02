# Test iucnr
.libPaths(c(file.path(getwd(), ".r-library"), .libPaths()))
library(iucnr)

test_spp <- c("Vultur gryphus", "Oreomanes fraseri", "Polylepis racemosa", "Puma concolor", "Cinclodes aricomae")
res <- iucnr::iucn_match(splist = test_spp)
print(res)
