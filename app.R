# ==============================================================================
# APP.R: Sistema de Información de Biodiversidad de la Provincia de Anta
# Municipalidad Provincial de Anta - Gerencia de Desarrollo Urbano y Rural (GDUR)
# Preparado y optimizado para despliegue en shinyapps.io y ejecución local
# ==============================================================================

# Soporte de biblioteca local para Windows sin interferir con shinyapps.io (Linux)
if (dir.exists(".r-library")) {
  .libPaths(c(file.path(getwd(), ".r-library"), .libPaths()))
}

# Windows puede iniciar R con una página de códigos que no admite acentos ni
# símbolos UTF-8 presentes en la interfaz. Normalizarla aquí permite ejecutar
# la app directamente, además de usar el lanzador incluido en el proyecto.
invisible(try(Sys.setlocale("LC_CTYPE", "English_United States.utf8"), silent = TRUE))

suppressPackageStartupMessages({
  library(shiny)
  library(bslib)
  library(reactable)
  library(mapgl)
  library(plotly)
  library(dplyr)
  library(sf)
  library(htmltools)
  library(jsonlite)
  library(geojsonsf)
  library(DBI)
  library(RPostgres)
})

# Cargar funciones auxiliares y módulos
source("R/utils_data.R", encoding = "UTF-8")
source("R/mod_resumen_ejecutivo.R", encoding = "UTF-8")
source("R/mod_explorador_distrital.R", encoding = "UTF-8")
source("R/mod_delimitacion_poligono.R", encoding = "UTF-8")
source("R/mod_ebird_aves.R", encoding = "UTF-8")
source("R/mod_mapa_cobertura.R", encoding = "UTF-8")
source("R/mod_recambio_ecologico.R", encoding = "UTF-8")
source("R/mod_metodologia_descarga.R", encoding = "UTF-8")

# Los insumos son estáticos durante la vida de cada versión publicada. Cargarlos
# una sola vez por proceso evita E/S, deserialización y lectura GDAL por sesión.
app_data <- load_app_data()

# ── Interfaz de Usuario (UI) ──────────────────────────────────────────────────
ui <- page_fluid(
  theme = bs_theme(
    version = 5,
    primary = "#0f5132",
    secondary = "#1e293b",
    success = "#059669",
    warning = "#d97706",
    danger = "#dc2626",
    bg = "#f8fafc",
    fg = "#1e293b"
  ),
  
  # CSS institucional
  tags$head(
    tags$link(rel = "stylesheet", type = "text/css", href = "custom.css"),
    tags$title("Sistema de Biodiversidad Territorial · Municipalidad Provincial de Anta")
  ),
  
  # Encabezado Institucional
  div(
    class = "institutional-header",
    div(
      class = "container-fluid header-shell",
      div(
        class = "header-topline",
        div(
          class = "header-brand",
          tags$img(src = "logo_anta.jpg", class = "logo-img", alt = "Escudo de la Municipalidad Provincial de Anta"),
          div(
            class = "header-institution",
            tags$p("MUNICIPALIDAD PROVINCIAL DE ANTA", class = "institution-name"),
            tags$p("Gerencia de Desarrollo Urbano y Rural · GDUR", class = "institution-unit")
          )
        ),
        div(
          class = "header-system",
          tags$p("PLATAFORMA DE INFORMACIÓN TERRITORIAL", class = "system-kicker"),
          tags$h1("Sistema de Información y Monitoreo de Biodiversidad Territorial"),
          tags$p("Indicadores, registros y herramientas para la gestión provincial.", class = "system-description")
        ),
        div(
          class = "header-context",
          div(class = "context-location", icon("map-marker-alt"), " Provincia de Anta · Cusco"),
          div(class = "context-meta", "Cusco · Perú"),
          span(class = "update-badge", "Actualización 2026-I")
        )
      )
    )
  ),
  
  # Contenedor Principal con Pestañas de Navegación Temáticas Limpias
  div(
    class = "app-navigation",
    div(
      class = "container-fluid px-4",
    navset_pill(
      id = "main_nav",
      
      nav_panel(
        title = tags$span(icon("chart-pie"), " Resumen Ejecutivo"),
        div(class = "pt-3", mod_resumen_ejecutivo_ui("resumen"))
      ),
      
      nav_panel(
        title = tags$span(icon("search-location"), " Explorador Distrital"),
        div(class = "pt-3", mod_explorador_distrital_ui("explorador"))
      ),
      
      nav_panel(
        title = tags$span(icon("draw-polygon"), " Delimitación Territorial"),
        div(class = "pt-3", mod_delimitacion_poligono_ui("delimitacion"))
      ),
      
      nav_panel(
        title = tags$span(icon("dove"), " Monitoreo de Aves (eBird)"),
        div(class = "pt-3", mod_ebird_aves_ui("ebird"))
      ),
      
      nav_panel(
        title = tags$span(icon("map-marked-alt"), " Visor Territorial"),
        div(class = "pt-3", mod_mapa_cobertura_ui("mapa"))
      ),
      
      nav_panel(
        title = tags$span(icon("project-diagram"), " Recambio Ecológico"),
        div(class = "pt-3", mod_recambio_ecologico_ui("recambio"))
      ),
      
      nav_panel(
        title = tags$span(icon("file-alt"), " Metodología & Descargas"),
        div(class = "pt-3", mod_metodologia_descarga_ui("metodologia"))
      )
    )
    )
  ),
  
  # Footer Institucional
  tags$footer(
    class = "institutional-footer",
    div(
      class = "container footer-shell",
      div(
        class = "footer-identity",
        tags$p(tags$strong("Municipalidad Provincial de Anta"), " · Gerencia de Desarrollo Urbano y Rural — GDUR"),
        tags$p("Sistema de Información y Monitoreo de Biodiversidad Territorial · Versión 2026")
      ),
      div(
        class = "footer-provenance",
        tags$p("Datos actualizados: 2026-I"),
        tags$p("Fuentes: GBIF · iNaturalist · eBird · Cornell Lab · UICN")
      )
    )
  )
)

# ── Servidor (Server) ─────────────────────────────────────────────────────────
server <- function(input, output, session) {
  
  # Reactivos ligeros que exponen el caché inmutable compartido por el proceso.
  data_especies <- reactive({
    app_data$especies
  })
  
  sf_ocurrencias <- reactive({
    app_data$ocurrencias
  })

  sf_ocurrencias_mapa <- reactive({
    app_data$ocurrencias_mapa
  })
  
  data_resumen <- reactive({
    app_data$resumen
  })
  
  data_singularidad <- reactive({
    app_data$singularidad
  })
  
  data_recambio <- reactive({
    app_data$recambio
  })
  
  data_cuadricula <- reactive({
    app_data$cuadricula
  })
  
  sf_distritos <- reactive({
    app_data$distritos
  })
  
  sf_cuadricula <- reactive({
    app_data$cuadricula_sf
  })
  
  # Datos eBird
  data_ebird_especies <- reactive({
    app_data$ebird_especies
  })
  
  data_ebird_resumen <- reactive({
    app_data$ebird_resumen
  })
  
  sf_ebird_hotspots <- reactive({
    app_data$ebird_hotspots
  })
  
  # Invocar Servidores de Módulos
  mod_resumen_ejecutivo_server("resumen", data_especies, data_resumen, data_cuadricula)
  mod_explorador_distrital_server("explorador", data_especies, data_resumen)
  mod_delimitacion_poligono_server("delimitacion", sf_ocurrencias, sf_ocurrencias_mapa, sf_distritos)
  mod_ebird_aves_server("ebird", data_ebird_especies, data_ebird_resumen, sf_ebird_hotspots, sf_distritos)
  mod_mapa_cobertura_server("mapa", sf_distritos, sf_cuadricula, data_cuadricula, data_resumen)
  mod_recambio_ecologico_server("recambio", data_recambio, data_singularidad)
  mod_metodologia_descarga_server("metodologia", data_especies, data_ebird_especies, data_cuadricula)
}

# Ejecutar la aplicación
shinyApp(ui = ui, server = server)
