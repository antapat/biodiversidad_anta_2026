# ==============================================================================
# MOD_EXPLORADOR_DISTRITAL.R: Módulo de Exploración y Recuperación de Especies
# Integración con reactable y Diagnóstico Territorial Enriquecido
# ==============================================================================

mod_explorador_distrital_ui <- function(id) {
  ns <- NS(id)
  
  tagList(
    div(
      class = "row g-3 mb-4",
      # Columna Izquierda: Selección Territorial y Filtros
      div(
        class = "col-lg-4",
        div(
          class = "content-card h-100",
          div(
            class = "content-card-header",
            div(class = "content-card-title", icon("map-marker-alt"), " Selección y Filtros")
          ),
          
          # Selector de distrito
          selectInput(
            inputId = ns("select_distrito"),
            label = tags$strong("Seleccionar Distrito de Anta:"),
            choices = c(
              "Anta", "Ancahuasi", "Cachimayo", "Chinchaypujio",
              "Huarocondo", "Limatambo", "Mollepata", "Pucyura", "Zurite"
            ),
            selected = "Anta",
            width = "100%"
          ),
          
          # Filtros adicionales
          div(
            class = "row g-2 mt-2",
            div(
              class = "col-6",
              selectInput(
                inputId = ns("filtro_reino"),
                label = "Reino:",
                choices = c("Todos" = "ALL", "Flora" = "Flora", "Fauna" = "Fauna"),
                selected = "ALL",
                width = "100%"
              )
            ),
            div(
              class = "col-6",
              selectInput(
                inputId = ns("filtro_iucn"),
                label = "Categoría UICN:",
                choices = c(
                  "Todas" = "ALL",
                  "Solo Amenazadas (CR/EN/VU)" = "AMENAZADAS",
                  "Casi Amenazada (NT)" = "NT",
                  "Preocupación Menor (LC)" = "LC"
                ),
                selected = "ALL",
                width = "100%"
              )
            )
          ),
          div(
            class = "mt-2",
            selectInput(
              inputId = ns("filtro_exclusiva"),
              label = "Singularidad Territorial:",
              choices = c("Todas las especies" = "ALL", "Solo Especies Exclusivas del Distrito" = "ONLY_EXC"),
              selected = "ALL",
              width = "100%"
            )
          ),
          
          # Indicador de filtros reactivos y descarga
          div(
            class = "mt-3 pt-2 border-top d-flex justify-content-between align-items-center",
            div(
              class = "reactive-indicator",
              div(class = "reactive-pulse"),
              "Filtros reactivos activos"
            ),
            downloadButton(
              outputId = ns("btn_descargar_csv"),
              label = "Descargar CSV",
              class = "btn-sm btn-outline-success font-weight-bold"
            )
          )
        )
      ),
      
      # Columna Derecha: Ficha de Diagnóstico y Métricas del Distrito
      div(
        class = "col-lg-8",
        div(
          class = "content-card h-100",
          div(
            class = "content-card-header d-flex justify-content-between align-items-center",
            div(class = "content-card-title", icon("id-card"), textOutput(ns("ficha_distrito_nombre"), inline = TRUE)),
            uiOutput(ns("badge_estado_distrito"))
          ),
          
          # Tarjetas de Indicadores Rápidos
          div(
            class = "row g-2 text-center my-2",
            div(
              class = "col-md-3 col-6",
              div(
                style = "background: #f8fafc; border-radius: 8px; padding: 10px; border: 1px solid #e2e8f0;",
                div(style = "font-size: 0.72rem; color: #64748b; font-weight: 700;", "TOTAL ESPECIES"),
                div(style = "font-size: 1.4rem; font-weight: 800; color: #0f5132;", textOutput(ns("stat_dist_species")))
              )
            ),
            div(
              class = "col-md-3 col-6",
              div(
                style = "background: #f8fafc; border-radius: 8px; padding: 10px; border: 1px solid #e2e8f0;",
                div(style = "font-size: 0.72rem; color: #64748b; font-weight: 700;", "FLORA / FAUNA"),
                div(style = "font-size: 1.25rem; font-weight: 800; color: #1e293b;", textOutput(ns("stat_dist_flora_fauna")))
              )
            ),
            div(
              class = "col-md-3 col-6",
              div(
                style = "background: #fef3c7; border-radius: 8px; padding: 10px; border: 1px solid #fde68a;",
                div(style = "font-size: 0.72rem; color: #92400e; font-weight: 700;", "AMENAZADAS UICN"),
                div(style = "font-size: 1.4rem; font-weight: 800; color: #b45309;", textOutput(ns("stat_dist_iucn")))
              )
            ),
            div(
              class = "col-md-3 col-6",
              div(
                style = "background: #ecfdf5; border-radius: 8px; padding: 10px; border: 1px solid #a7f3d0;",
                div(style = "font-size: 0.72rem; color: #065f46; font-weight: 700;", "SINGULARES / EXC."),
                div(style = "font-size: 1.4rem; font-weight: 800; color: #059669;", textOutput(ns("stat_dist_exclusive")))
              )
            )
          ),
          
          # Diagnóstico Territorial Pulido
          div(
            class = "mt-2 pt-2 border-top",
            uiOutput(ns("analisis_detallado_distrito"))
          )
        )
      )
    ),
    
    # Tabla Interactiva de Especies del Distrito
    div(
      class = "row",
      div(
        class = "col-12",
        div(
          class = "content-card",
          div(
            class = "content-card-header d-flex justify-content-between align-items-center",
            div(class = "content-card-title", icon("table"), " Listado de Especies Registradas en GBIF e iNaturalist"),
            span(class = "badge bg-light text-dark border", textOutput(ns("conteo_tabla_filtrada"), inline = TRUE))
          ),
          
          div(
            class = "mt-2",
            reactable::reactableOutput(ns("tabla_especies_distrito"))
          )
        )
      )
    )
  )
}

mod_explorador_distrital_server <- function(id, data_especies, data_resumen) {
  moduleServer(id, function(input, output, session) {
    
    # Filtrado reactivo de especies distritales
    especies_filtradas <- reactive({
      req(data_especies(), input$select_distrito)
      
      df <- data_especies() |>
        filter(tolower(distrito) == tolower(input$select_distrito))
      
      if (input$filtro_reino == "Flora") {
        df <- df |> filter(tolower(reino) %in% c("plantae", "flora"))
      } else if (input$filtro_reino == "Fauna") {
        df <- df |> filter(tolower(reino) %in% c("animalia", "fauna"))
      }
      
      if (input$filtro_iucn == "AMENAZADAS") {
        df <- df |> filter(iucn_categoria %in% c("En Peligro Crítico (CR)", "En Peligro (EN)", "Vulnerable (VU)"))
      } else if (input$filtro_iucn == "NT") {
        df <- df |> filter(iucn_categoria == "Casi Amenazada (NT)")
      } else if (input$filtro_iucn == "LC") {
        df <- df |> filter(iucn_categoria == "Preocupación Menor (LC)")
      }
      
      if (input$filtro_exclusiva == "ONLY_EXC") {
        df <- df |> filter(es_exclusiva == TRUE)
      }
      
      df |> arrange(desc(n_registros))
    })
    
    # Resumen del distrito actual
    distrito_resumen_actual <- reactive({
      req(data_resumen(), input$select_distrito)
      res <- data_resumen() |>
        filter(tolower(district) == tolower(input$select_distrito))
      if (nrow(res) == 0) return(NULL)
      res[1, ]
    })
    
    # Ficha UI
    output$ficha_distrito_nombre <- renderText({
      paste("Distrito de", input$select_distrito)
    })
    
    output$badge_estado_distrito <- renderUI({
      res <- distrito_resumen_actual()
      if (is.null(res)) return(NULL)
      rec <- res$records
      if (rec >= 1000) {
        tags$span(class = "badge bg-success", icon("check-circle"), " Cobertura Alta")
      } else if (rec >= 200) {
        tags$span(class = "badge bg-info text-dark", icon("info-circle"), " Cobertura Media")
      } else {
        tags$span(class = "badge bg-warning text-dark", icon("exclamation-triangle"), " Vacío Prioritario")
      }
    })
    
    output$stat_dist_species <- renderText({
      res <- distrito_resumen_actual()
      if (is.null(res)) "0" else fmt_num(res$species)
    })
    
    output$stat_dist_flora_fauna <- renderText({
      res <- distrito_resumen_actual()
      if (is.null(res)) "0 / 0" else paste(fmt_num(res$flora_species), "/", fmt_num(res$fauna_species))
    })
    
    output$stat_dist_iucn <- renderText({
      df <- data_especies() |>
        filter(tolower(distrito) == tolower(input$select_distrito),
               iucn_categoria %in% c("En Peligro Crítico (CR)", "En Peligro (EN)", "Vulnerable (VU)"))
      fmt_num(n_distinct(df$species))
    })
    
    output$stat_dist_exclusive <- renderText({
      res <- distrito_resumen_actual()
      if (is.null(res)) "0" else fmt_num(res$exclusive_species)
    })
    
    # ── Texto de Análisis Territorial Pulido ─────────────────────────────────
    output$analisis_detallado_distrito <- renderUI({
      res <- distrito_resumen_actual()
      df_spp <- data_especies() |> filter(tolower(distrito) == tolower(input$select_distrito))
      if (is.null(res) || nrow(df_spp) == 0) return(NULL)
      
      # Familias dominantes
      top_fam <- df_spp |>
        filter(!is.na(familia) & familia != "") |>
        count(familia, sort = TRUE) |>
        head(3) |>
        pull(familia)
      fam_str <- if (length(top_fam) > 0) paste(top_fam, collapse = ", ") else "Diversas familias"
      
      # Especies amenazadas en el distrito
      amenazadas_spp <- df_spp |>
        filter(iucn_categoria %in% c("En Peligro Crítico (CR)", "En Peligro (EN)", "Vulnerable (VU)")) |>
        distinct(species, iucn_categoria) |>
        head(2)
      
      threat_ui <- if (nrow(amenazadas_spp) == 1) {
        tagList(
          "Registra especies bajo estatus de amenaza global como ",
          tags$em(amenazadas_spp$species[1]), paste0(" (", amenazadas_spp$iucn_categoria[1], "). ")
        )
      } else if (nrow(amenazadas_spp) >= 2) {
        tagList(
          "Registra especies bajo estatus de amenaza global como ",
          tags$em(amenazadas_spp$species[1]), paste0(" (", amenazadas_spp$iucn_categoria[1], ") y "),
          tags$em(amenazadas_spp$species[2]), paste0(" (", amenazadas_spp$iucn_categoria[2], "). ")
        )
      } else {
        tagList("No presenta especies catalogadas en categorías críticas de amenaza en los registros actuales. ")
      }
      
      div(
        style = "font-size: 0.84rem; color: #334155; line-height: 1.55;",
        tags$p(
          class = "mb-1",
          icon("chart-line"), " ",
          tags$strong("Perfil Biológico: "),
          "El distrito acumula ", tags$strong(fmt_num(res$records)), " observaciones biológicas entre ",
          res$first_year, " y ", res$last_year, ", abarcando ", fmt_num(res$families), " familias botánicas y faunísticas (dominadas por ", tags$em(fam_str), "). ",
          "El ", tags$strong(fmt_pct(res$recent_pct)), " de los registros corresponde al período reciente (desde 2020)."
        ),
        tags$p(
          class = "mb-0",
          icon("shield-alt"), " ",
          tags$strong("Conservación y Singularidad: "),
          threat_ui,
          "Además, aporta ", tags$strong(paste(res$exclusive_species, "especies exclusivas")),
          " registradas únicamente en esta jurisdicción distrital."
        )
      )
    })
    
    output$conteo_tabla_filtrada <- renderText({
      req(especies_filtradas())
      paste(fmt_num(nrow(especies_filtradas())), "especies encontradas")
    })
    
    # Tabla reactable interactiva
    output$tabla_especies_distrito <- reactable::renderReactable({
      req(especies_filtradas())
      
      df_tab <- especies_filtradas() |>
        select(
          species, nombre_cientifico, reino, clase, familia,
          iucn_categoria, n_registros, es_exclusiva, fuentes, ultimo_anio
        )
      
      reactable::reactable(
        df_tab,
        striped = TRUE,
        highlight = TRUE,
        searchable = TRUE,
        defaultPageSize = 10,
        showPageSizeOptions = TRUE,
        pageSizeOptions = c(10, 25, 50, 100),
        columns = list(
          species = reactable::colDef(
            name = "Especie / Taxón",
            minWidth = 180,
            cell = function(val) tags$em(style = "font-weight: 700; color: #0f172a;", val)
          ),
          nombre_cientifico = reactable::colDef(
            name = "Autoría / Nombre Completo",
            minWidth = 220,
            style = list(fontSize = "0.82rem", color = "#475569")
          ),
          reino = reactable::colDef(
            name = "Reino",
            width = 100,
            cell = function(val) {
              if (tolower(val) %in% c("plantae", "flora")) tags$span(class = "badge bg-success", "Flora")
              else tags$span(class = "badge bg-primary", "Fauna")
            }
          ),
          clase = reactable::colDef(name = "Clase", width = 120),
          familia = reactable::colDef(name = "Familia", width = 130),
          iucn_categoria = reactable::colDef(
            name = "Categoría UICN (iucnr)",
            minWidth = 160,
            cell = function(val) {
              if (grepl("CR|EN|VU", val)) tags$span(class = "badge bg-danger", val)
              else if (grepl("NT", val)) tags$span(class = "badge bg-warning text-dark", val)
              else if (grepl("DD", val)) tags$span(class = "badge bg-secondary", val)
              else if (grepl("LC", val)) tags$span(class = "badge bg-light text-dark border", "LC")
              else tags$span(class = "text-muted", style = "font-size: 0.75rem;", val)
            }
          ),
          n_registros = reactable::colDef(
            name = "Registros",
            width = 95,
            align = "right",
            format = reactable::colFormat(separators = TRUE)
          ),
          es_exclusiva = reactable::colDef(
            name = "Singularidad",
            width = 120,
            cell = function(val) {
              if (isTRUE(val)) tags$span(class = "badge bg-warning text-dark", "★ Exclusiva")
              else tags$span(class = "text-muted", style = "font-size: 0.75rem;", "Compartida")
            }
          ),
          fuentes = reactable::colDef(name = "Fuentes", width = 110),
          ultimo_anio = reactable::colDef(name = "Año Rec.", width = 85, align = "center")
        )
      )
    })
    
    # Descargar CSV
    output$btn_descargar_csv <- downloadHandler(
      filename = function() {
        paste0("especies_", tolower(input$select_distrito), "_anta_", Sys.Date(), ".csv")
      },
      content = function(file) {
        write.csv(especies_filtradas(), file, row.names = FALSE, fileEncoding = "UTF-8")
      }
    )
  })
}
