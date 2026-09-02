# =============================================================================
# SCRIPT: Monitoreo de aves - eBird + validación con lista oficial (avesperu)
# Descripción: Extrae observaciones de aves desde hotspots de eBird 
#              (https://ebird.org/hotspots) para los puntos de monitoreo del 
#              proyecto, arma una lista consolidada por especie/ubicación, y valida
#              los nombres científicos contra la lista oficial de aves del 
#              Perú (UNOP/avesperu).
# =============================================================================

# ---- 1. Librerías ----------------------------------------------------------
library(rvest)
library(tidyverse)
library(purrr)
library(lubridate)
library(janitor)
library(avesperu)   # Validación taxonómica: https://github.com/PaulESantos/avesperu


# ---- 2. Función para extraer información de observaciones de eBird --------
# Dado un URL de hotspot de eBird, devuelve un tibble con todas las
# observaciones registradas (especie, conteo, fecha, observador, ubicación).
get_ebird_info <- function(url) {
  
  # Leer la página web forzando codificación UTF-8 (evita problemas con tildes/ñ)
  page <- rvest::read_html(url, encoding = "UTF-8")
  
  # Extraer cada bloque de observación individual mediante XPath
  bird_observations <- page |> 
    rvest::html_nodes(
      xpath = "//*[@id='content']/div/div[3]/div/div[3]/section[1]/ol/li/div[@class='Obs']"
    )
  
  # Sub-función: extrae los campos de UNA observación puntual
  extract_bird_info <- function(obs) {
    
    # Nombre común de la especie
    common_name <- obs |> 
      rvest::html_nodes(xpath = ".//span[@class='Species-common']") |> 
      rvest::html_text(trim = TRUE)
    
    # Nombre científico de la especie
    sci_name <- obs |> 
      rvest::html_nodes(xpath = ".//span[@class='Species-sci Species-sub']") |> 
      rvest::html_text(trim = TRUE)
    
    # Conteo de individuos observados
    count <- obs |> 
      rvest::html_nodes(xpath = ".//div[contains(@class, 'Obs-count')]/span") |> 
      rvest::html_text(trim = TRUE) |> 
      (\(x) x[length(x)])()  # Último elemento del vector = el conteo real
    
    # Fecha de la observación
    date <- obs |> 
      rvest::html_nodes(xpath = ".//div[contains(@class, 'Obs-date')]/a/time") |> 
      rvest::html_attr("datetime") |> 
      as.Date()
    
    # Observador que reportó el registro
    observer <- obs |> 
      rvest::html_nodes(xpath = ".//div[contains(@class, 'Obs-observer')]/span") |> 
      rvest::html_text(trim = TRUE) |> 
      (\(x) x[length(x)])()  # Último elemento = nombre del observador
    
    # Ubicación puntual reportada por eBird (puede diferir del punto de monitoreo)
    location <- obs |> 
      rvest::html_nodes(
        xpath = ".//div[contains(@class, 'Obs-location')]/span[contains(@class, 'Obs-location-name')]/a"
      ) |> 
      rvest::html_text(trim = TRUE)
    
    dplyr::tibble(
      nombre_comun      = common_name,
      nombre_cientifico = sci_name,
      conteo            = count,
      fecha             = date,
      observador        = observer,
      ubicacion         = location
    )
  }
  
  # Aplica la extracción a cada observación y las une en un solo data frame
  purrr::map_df(bird_observations, extract_bird_info)
}


# ---- 3. Configuración de rutas y URLs de los puntos de monitoreo ----------


# Puntos de monitoreo eBird: nombre del punto + URL de su lista de especies
listas_eu_pdm <- tibble::tribble(
  ~ubicacion_punto,                       ~url,
  "Q'ente Q'entiyoc",                     "https://ebird.org/hotspot/L16831267/bird-list",
  "Sitio Arqueológico de Killarumiyoc",   "https://ebird.org/hotspot/L8166287/bird-list",
  "Humedal del Yungaqui",                 "https://ebird.org/hotspot/L13016446/bird-list"
)


# ---- 4. Extracción de datos desde eBird ------------------------------------

# data frame base: un URL por fila, con su nombre de punto asociado
listas_eu_pdm

# Aplica get_ebird_info() a cada URL y expande los resultados (unnest)
ebird_data <- listas_eu_pdm |> 
  dplyr::mutate(data = purrr::map(url, get_ebird_info)) |> 
  tidyr::unnest(c(data)) |> 
  # Corrige mojibake (UTF-8 mal interpretado como Latin-1) en texto con tildes/ñ
  dplyr::mutate(
    dplyr::across(c(ubicacion, ubicacion_punto), \(x) iconv(x, from = "latin1", to = "UTF-8"))
  )

ebird_data


# ---- 5. Consolidar lista de especies por ubicación -------------------------
# Una fila por especie, con las ubicaciones donde fue registrada (concatenadas)
aves_list <- ebird_data |> 
  select(-c(ubicacion_punto, url, conteo, fecha, observador)) |> 
  group_by(nombre_comun, nombre_cientifico) |> 
  summarise(
    ubicacion = paste0(unique(ubicacion), collapse = " - "),
    .groups = "drop"   # Evita el mensaje de "regrouped output" y no deja grupos activos
  )

aves_list


# ---- 6. Validación taxonómica con la lista oficial (avesperu) -------------

# Verifica si hay una versión más reciente de la lista oficial de aves del Perú
avesperu::unop_check_update()

# Busca cada nombre científico en la lista oficial y trae detalles taxonómicos
aves_peru_lista <- avesperu::search_avesperu(
  aves_list$nombre_cientifico,
  return_details = TRUE
) |> 
  dplyr::as_tibble()

aves_peru_lista

# Une la lista consolidada de eBird con la validación taxonómica oficial,
# y se queda solo con las especies que sí fueron encontradas (order_name no NA)
aves_validadas <- aves_list |> 
  left_join(aves_peru_lista, by = c("nombre_cientifico" = "name_submitted")) |> 
  dplyr::select(
    ubicacion,
    order_name, 
    family_name,
    nombre_cientifico,
    nombre_comun_sp = spanish_name,
    status
  ) |> 
  filter(!is.na(order_name))

aves_validadas


# ---- 7. Exportar lista final -----------------------------------------------

# Carpeta de destino para el reporte final
carpeta_salida <- "D:/esquemas_urbanos/datos/biodiversidad_2026"

# Crea la carpeta si no existe
if (!dir.exists(carpeta_salida)) {
  dir.create(carpeta_salida, recursive = TRUE)
}

# Exporta la lista validada en formato CSV (compatible con Excel, UTF-8)
writexl::write_xlsx(
  aves_validadas |> 
    dplyr::select(-ubicacion),
  path = file.path(carpeta_salida, "lista_aves_validada.xlsx")
)

