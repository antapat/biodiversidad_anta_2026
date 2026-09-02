# Test avesperu
.libPaths(c(file.path(getwd(), ".r-library"), .libPaths()))
library(avesperu)

splist <- c("Vultur gryphus", "Falco peregrinus", "Patagioenas maculosa", "Zenaida auriculata")
res <- avesperu::search_avesperu(splist = splist)
print(head(res))
