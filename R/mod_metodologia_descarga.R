# ==============================================================================
# MOD_METODOLOGIA_DESCARGA.R: Protocolo Metodológico, Fuentes y Centro de Descarga
# Municipalidad Provincial de Anta - Gerencia de Desarrollo Urbano y Rural
# ==============================================================================

mod_metodologia_descarga_ui <- function(id) {
  ns <- NS(id)
  
  tagList(
    div(
      class = "row g-4",
      
      # ── Columna 1: Protocolo Metodológico y Fuentes Científicas ─────────────
      div(
        class = "col-lg-7",
        div(
          class = "content-card",
          div(
            class = "content-card-header",
            div(class = "content-card-title", icon("book-open"), " Protocolo Metodológico y Estandarización de Datos")
          ),
          
          div(
            style = "font-size: 0.88rem; color: #334155; line-height: 1.6;",
            
            # Sección 1: GBIF e iNaturalist
            tags$h6(tags$strong("1. Plataformas Globales de Biodiversidad (GBIF & iNaturalist)"), style = "color: #0f5132;"),
            tags$p(
              "La información biológica base fue estructurada a partir de los repositorios de ",
              tags$strong("GBIF"), " (Global Biodiversity Information Facility) y de la plataforma de ciencia ciudadana ",
              tags$strong("iNaturalist"), " (California Academy of Sciences & National Geographic Society), aplicando filtros de calidad estrictos:"
            ),
            tags$ul(
              tags$li(
                tags$strong("Filtro de Grado de Investigación (Research Grade): "),
                "Se priorizaron registros con evidencia fotográfica o auditiva validada por consenso de especialistas (≥ 2 identificaciones concordantes)."
              ),
              tags$li(
                tags$strong("Estandarización Darwin Core (DwC): "),
                "Homogeneización de campos taxonómicos (", tags$code("kingdom"), ", ", tags$code("phylum"), ", ",
                tags$code("class"), ", ", tags$code("order"), ", ", tags$code("family"), ", ", tags$code("genus"), ", ",
                tags$code("species"), ") mediante el backbone taxonómico de GBIF, conservando el nombre original y la correspondencia aceptada."
              ),
              tags$li(
                tags$strong("Trazabilidad y deduplicación: "),
                "Separación entre canal de descarga (GBIF o iNaturalist), plataforma y conjunto de origen; las observaciones de iNaturalist publicadas también por GBIF se consolidaron mediante su identificador original."
              ),
              tags$li(
                tags$strong("Control de Calidad Geográfica: "),
                "Exclusión analítica de registros con incertidumbre conocida superior a 5 km y verificación de intersección espacial estricta con el límite provincial. Los registros sin incertidumbre declarada se conservan identificados como tales."
              )
            ),
            
            # Sección 2: eBird y avesperu
            tags$h6(tags$strong("2. Red de Monitoreo Ornitológico (eBird & avesperu 2026)"), style = "color: #0f5132;", class = "mt-3"),
            tags$p(
              "Para el análisis de avifauna se integró la red de ", tags$strong("17 Hotspots oficiales de eBird (Cornell Lab of Ornithology)"),
              " distribuidos en los ecosistemas de puna, valles interandinos y ceja de selva de la provincia. Toda la nomenclatura ornitológica fue validada mediante el paquete ",
              tags$strong("avesperu (versión 2026.v1)"), ", reflejando la ", tags$strong("Lista Oficial de las Aves del Perú (UNOP)"),
              " y los lineamientos del Comité de Clasificación de Aves de América del Sur (SACC)."
            ),
            
            # Sección 3: Categorización UICN con iucnr y D.S. 004-2014-MINAGRI
            tags$h6(tags$strong("3. Evaluación de Estado de Conservación (UICN / iucnr & Normativa Nacional)"), style = "color: #0f5132;", class = "mt-3"),
            tags$p(
              "Cada taxón registrado en Anta fue evaluado y cruzado con los siguientes marcos normativos y de conservación:"
            ),
            tags$ul(
              tags$li(
                tags$strong("Lista Roja de la UICN (versión 2026-1): "),
                "Matching taxonómico ejecutado con el paquete ", tags$code("iucnr"), " (Santos-Andrade, 2026), clasificando las especies en: ",
                tags$span(class = "badge bg-danger", "En Peligro Crítico (CR)"), " ",
                tags$span(class = "badge bg-danger", "En Peligro (EN)"), " ",
                tags$span(class = "badge bg-warning text-dark", "Vulnerable (VU)"), " ",
                tags$span(class = "badge bg-warning text-dark", "Casi Amenazada (NT)"), " y ",
                tags$span(class = "badge bg-light text-dark border", "Preocupación Menor (LC)"), "."
              ),
              tags$li(
                tags$strong("Decreto Supremo Nº 004-2014-MINAGRI: "),
                "Categorización oficial de especies amenazadas de fauna silvestre legalmente protegidas por el Estado Peruano."
              ),
              tags$li(
                tags$strong("Convención CITES: "),
                "Inclusión en los Apéndices I (prohibición de comercio) y II (comercio regulado sustentable)."
              )
            ),
            
            # Sección 4: Citas Bibliográficas Normalizadas
            tags$h6(tags$strong("4. Citas Bibliográficas Oficiales"), style = "color: #0f5132;", class = "mt-3"),
            tags$div(
              class = "p-3 border rounded bg-light",
              style = "font-size: 0.78rem; line-height: 1.5; color: #475569;",
              tags$ul(
                class = "mb-0 ps-3",
                tags$li(
                  tags$strong("GBIF: "), "GBIF.org (2026). ", tags$em("GBIF Occurrence Download."),
                  " Global Biodiversity Information Facility. Disponible en: ",
                  tags$a(href = "https://www.gbif.org/es/", target = "_blank", "https://www.gbif.org")
                ),
                tags$li(
                  tags$strong("iNaturalist: "), "iNaturalist.org (2026). ", tags$em("iNaturalist Research-Grade Observations."),
                  " California Academy of Sciences and National Geographic Society. Disponible en: ",
                  tags$a(href = "https://www.inaturalist.org/", target = "_blank", "https://www.inaturalist.org")
                ),
                tags$li(
                  tags$strong("eBird: "), "eBird. (2026). ", tags$em("eBird: An online database of bird distribution and abundance [Web application]."),
                  " Cornell Lab of Ornithology, Ithaca, New York. Disponible en: ",
                  tags$a(href = "https://ebird.org/home", target = "_blank", "https://ebird.org")
                ),
                tags$li(
                  tags$strong("avesperu (UNOP): "), "Santos-Andrade, P. E. (2026). ", tags$em("avesperu: Official Checklist of the Birds of Peru."),
                  " Unión de Ornitólogos del Perú (UNOP). Paquete R versión 2026.v1. Disponible en: ",
                  tags$a(href = "https://github.com/PaulESantos/avesperu", target = "_blank", "https://github.com/PaulESantos/avesperu")
                ),
                tags$li(
                  tags$strong("iucnr (UICN Red List): "), "Santos-Andrade, P. E. (2026). ", tags$em("iucnr: Access and Match Species against the IUCN Red List of Threatened Species (v2026-1)."),
                  " Disponible en: ", tags$a(href = "https://paulesantos.github.io/iucnr/", target = "_blank", "https://paulesantos.github.io/iucnr/")
                )
              )
            )
          )
        )
      ),
      
      # ── Columna 2: Centro de Descargas SIG / Planificación ───────────────────
      div(
        class = "col-lg-5",
        div(
          class = "content-card",
          div(
            class = "content-card-header",
            div(class = "content-card-title", icon("download"), " Centro de Descarga de Datos para SIG y GDUR")
          ),
          
          div(
            style = "font-size: 0.85rem; color: #64748b; margin-bottom: 1.25rem;",
            "Capas cartográficas (GeoJSON en EPSG:4326) y bases de datos tabulares (CSV en UTF-8) compatibles con QGIS, ArcGIS y herramientas de planificación urbana y rural:"
          ),
          
          div(
            class = "d-grid gap-3",
            
            # Descarga 1: Hotspots eBird
            div(
              class = "p-3 border rounded bg-light d-flex justify-content-between align-items-center",
              div(
                tags$strong("Red de 17 Hotspots eBird"),
                div(style = "font-size: 0.75rem; color: #64748b;", "Puntos de monitoreo con atributos de riqueza")
              ),
              downloadButton(
                outputId = ns("descargar_ebird_geojson"),
                label = "GeoJSON",
                class = "btn-sm btn-primary"
              )
            ),
            
            # Descarga 2: Aves Validadas eBird
            div(
              class = "p-3 border rounded bg-light d-flex justify-content-between align-items-center",
              div(
                tags$strong("Aves eBird Validadas (avesperu)"),
                div(style = "font-size: 0.75rem; color: #64748b;", "Listado con UICN (iucnr) y D.S. 004-2014")
              ),
              downloadButton(
                outputId = ns("descargar_ebird_csv"),
                label = "CSV",
                class = "btn-sm btn-success"
              )
            ),
            
            # Descarga 3: Cuadrícula 5km
            div(
              class = "p-3 border rounded bg-light d-flex justify-content-between align-items-center",
              div(
                tags$strong("Cuadrícula 5 km (Vacíos y Prioridad)"),
                div(style = "font-size: 0.75rem; color: #64748b;", textOutput(ns("texto_celdas_descarga"), inline = TRUE))
              ),
              downloadButton(
                outputId = ns("descargar_grid_geojson"),
                label = "GeoJSON",
                class = "btn-sm btn-primary"
              )
            ),
            
            # Descarga 4: Distritos con Biodiversidad
            div(
              class = "p-3 border rounded bg-light d-flex justify-content-between align-items-center",
              div(
                tags$strong("Biodiversidad por Distritos"),
                div(style = "font-size: 0.75rem; color: #64748b;", "Límites distritales con índices ecológicos")
              ),
              downloadButton(
                outputId = ns("descargar_distritos_geojson"),
                label = "GeoJSON",
                class = "btn-sm btn-primary"
              )
            ),
            
            # Descarga 5: Inventario Provincial de Especies con UICN
            div(
              class = "p-3 border rounded bg-light d-flex justify-content-between align-items-center",
              div(
                tags$strong("Inventario Provincial de Especies"),
                div(style = "font-size: 0.75rem; color: #64748b;", textOutput(ns("texto_inventario_descarga"), inline = TRUE))
              ),
              downloadButton(
                outputId = ns("descargar_especies_csv"),
                label = "CSV",
                class = "btn-sm btn-success"
              )
            )
          )
        )
      )
    )
  )
}

mod_metodologia_descarga_server <- function(id, data_especies, data_ebird_especies, data_cuadricula) {
  moduleServer(id, function(input, output, session) {

    output$texto_celdas_descarga <- renderText({
      paste(fmt_num(nrow(data_cuadricula())), "celdas territoriales clasificadas")
    })

    output$texto_inventario_descarga <- renderText({
      paste(fmt_num(nrow(data_especies())), "registros distritales con UICN 2026-1")
    })
    
    output$descargar_ebird_geojson <- downloadHandler(
      filename = function() "anta_ebird_hotspots.geojson",
      content = function(file) {
        file.copy("outputs/analisis_biodiversidad/ebird_hotspots_anta.geojson", file)
      }
    )
    
    output$descargar_ebird_csv <- downloadHandler(
      filename = function() paste0("aves_ebird_hotspots_anta_", Sys.Date(), ".csv"),
      content = function(file) {
        write.csv(data_ebird_especies(), file, row.names = FALSE, fileEncoding = "UTF-8")
      }
    )
    
    output$descargar_grid_geojson <- downloadHandler(
      filename = function() "anta_cuadricula_5km_cobertura.geojson",
      content = function(file) {
        file.copy("outputs/analisis_biodiversidad/cobertura_cuadricula_5km.geojson", file)
      }
    )
    
    output$descargar_distritos_geojson <- downloadHandler(
      filename = function() "anta_biodiversidad_distritos.geojson",
      content = function(file) {
        file.copy("outputs/analisis_biodiversidad/biodiversidad_distritos.geojson", file)
      }
    )
    
    output$descargar_especies_csv <- downloadHandler(
      filename = function() paste0("inventario_biodiversidad_anta_provincia_iucn_", Sys.Date(), ".csv"),
      content = function(file) {
        write.csv(data_especies(), file, row.names = FALSE, fileEncoding = "UTF-8")
      }
    )
  })
}
