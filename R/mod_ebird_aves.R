# ==============================================================================
# MOD_EBIRD_AVES.R: Módulo de Monitoreo de Aves en Hotspots Oficiales de eBird
# Layout: Fila 1 en 2 Columnas (Mapa + Gráfico Comparativo de Riqueza)
# Municipalidad Provincial de Anta - Gerencia de Desarrollo Urbano y Rural
# ==============================================================================

mod_ebird_aves_ui <- function(id) {
  ns <- NS(id)
  
  tagList(
    # ── Barra Superior de Filtros y Descargas ─────────────────────────────────
    div(
      class = "row g-3 mb-3",
      div(
        class = "col-lg-8",
        div(
          class = "d-flex flex-wrap align-items-center gap-2",
          selectInput(
            inputId = ns("select_hotspot"),
            label = tags$strong("Sitio de Monitoreo / Hotspot eBird:"),
            choices = c("Todos los Hotspots eBird de Anta" = "ALL"),
            selected = "ALL",
            width = "350px"
          ),
          selectInput(
            inputId = ns("filtro_conservacion"),
            label = tags$strong("Estado de Conservación:"),
            choices = c(
              "Todas las Aves eBird" = "ALL",
              "Solo Especies Amenazadas (D.S. 004 / UICN)" = "AMENAZADAS",
              "Solo Especies Endémicas del Perú (🇵🇪)" = "ENDEMICAS",
              "Especies en CITES (Apéndices I y II)" = "CITES"
            ),
            selected = "ALL",
            width = "310px"
          )
        )
      ),
      div(
        class = "col-lg-4 text-lg-end d-flex align-items-center justify-content-lg-end gap-2 mt-3 mt-lg-0",
        downloadButton(
          outputId = ns("btn_descargar_ebird_csv"),
          label = "Descargar Aves eBird (CSV)",
          class = "btn-sm btn-success font-weight-bold shadow-sm"
        ),
        downloadButton(
          outputId = ns("btn_descargar_hotspots_geojson"),
          label = "Puntos Hotspots (GeoJSON)",
          class = "btn-sm btn-outline-primary"
        )
      )
    ),
    
    # ── FILA 1: 2 COLUMNAS (MAPA INTERACTIVO + GRÁFICO DE BARRAS DE DIVERSIDAD) ──
    div(
      class = "row g-3 mb-3",
      # Columna Izquierda: Mapa de los 17 Hotspots
      div(
        class = "col-lg-6",
        div(
          class = "content-card p-3 h-100",
          div(
            class = "p-2 mb-2 d-flex justify-content-between align-items-center border-bottom",
            div(
              tags$strong(style = "color: #0f5132;", icon("dove"), " Mapa de Hotspots eBird (Anta)"),
              tags$small(class = "text-muted ms-2", "(17 Sitios Oficiales)")
            ),
            span(class = "badge bg-primary", icon("check-double"), " avesperu 2026")
          ),
          div(
            class = "map-container-wrapper",
            mapgl::maplibreOutput(ns("mapa_ebird_hotspots"), height = "480px")
          )
        )
      ),
      
      # Columna Derecha: Gráfico de Barras de Diversidad Comparativa
      div(
        class = "col-lg-6",
        div(
          class = "content-card p-3 h-100",
          div(
            class = "p-2 mb-2 d-flex justify-content-between align-items-center border-bottom",
            div(
              tags$strong(style = "color: #0f5132;", icon("chart-bar"), " Diversidad y Riqueza de Aves por Sitio de Monitoreo"),
              tags$small(class = "text-muted ms-2", "(Número de especies registradas en eBird)")
            ),
            span(class = "badge bg-dark", "Comparativo Provincial")
          ),
          plotly::plotlyOutput(ns("grafico_barras_diversidad"), height = "480px")
        )
      )
    ),
    
    # ── FILA 2: Métricas del Hotspot, Tabla de Aves Validadas y Citas ─────────
    div(
      class = "row g-3 mb-4",
      div(
        class = "col-12",
        div(
          class = "content-card",
          
          # Encabezado de la Ficha
          div(
            class = "content-card-header d-flex flex-wrap justify-content-between align-items-center gap-2",
            div(
              class = "d-flex align-items-center gap-3",
              div(class = "content-card-title", icon("feather-alt"), textOutput(ns("titulo_ficha_ebird"), inline = TRUE)),
              uiOutput(ns("badge_hotspot_distrito"))
            ),
            uiOutput(ns("link_ebird_oficial"))
          ),
          
          # Tarjetas de KPIs de eBird
          div(
            class = "row g-3 text-center my-1",
            div(
              class = "col-md-3 col-6",
              div(
                style = "background: #f8fafc; border-radius: 8px; padding: 12px; border: 1px solid #e2e8f0;",
                div(style = "font-size: 0.75rem; color: #64748b; font-weight: 700;", "ESPECIES DE AVES (eBird)"),
                div(style = "font-size: 1.5rem; font-weight: 800; color: #0f5132;", textOutput(ns("kpi_ebird_species")))
              )
            ),
            div(
              class = "col-md-3 col-6",
              div(
                style = "background: #fef3c7; border-radius: 8px; padding: 12px; border: 1px solid #fde68a;",
                div(style = "font-size: 0.75rem; color: #92400e; font-weight: 700;", "ESPECIES AMENAZADAS"),
                div(style = "font-size: 1.5rem; font-weight: 800; color: #b45309;", textOutput(ns("kpi_ebird_threatened")))
              )
            ),
            div(
              class = "col-md-3 col-6",
              div(
                style = "background: #ecfdf5; border-radius: 8px; padding: 12px; border: 1px solid #a7f3d0;",
                div(style = "font-size: 0.75rem; color: #065f46; font-weight: 700;", "ENDÉMICAS DEL PERÚ"),
                div(style = "font-size: 1.5rem; font-weight: 800; color: #059669;", textOutput(ns("kpi_ebird_endemic")))
              )
            ),
            div(
              class = "col-md-3 col-6",
              div(
                style = "background: #f8fafc; border-radius: 8px; padding: 12px; border: 1px solid #e2e8f0;",
                div(style = "font-size: 0.75rem; color: #64748b; font-weight: 700;", "OBSERVACIONES eBird"),
                div(style = "font-size: 1.5rem; font-weight: 800; color: #0284c7;", textOutput(ns("kpi_ebird_records")))
              )
            )
          ),
          
          # Tabla de Aves Validadas en eBird
          div(
            class = "mt-3",
            reactable::reactableOutput(ns("tabla_aves_ebird"))
          ),
          
          # Cuadro Metodológico y Citas Bibliográficas Oficiales
          div(
            class = "p-3 mt-4 border rounded bg-light",
            style = "font-size: 0.8rem; color: #475569; line-height: 1.6;",
            tags$strong(icon("quote-right"), " Citas Bibliográficas y Fuentes Oficiales:"),
            tags$ul(
              class = "mt-1 mb-0 ps-3",
              tags$li(
                tags$strong("eBird / Cornell Lab of Ornithology: "),
                "eBird. (2026). ", tags$em("eBird: An online database of bird distribution and abundance [Web application]."),
                " Cornell Lab of Ornithology, Ithaca, New York. Disponible en: ",
                tags$a(href = "https://ebird.org/home", target = "_blank", "https://ebird.org")
              ),
              tags$li(
                tags$strong("Lista Oficial de las Aves del Perú (UNOP / avesperu): "),
                "Santos-Andrade, P. E. (2026). ", tags$em("avesperu: Official Checklist of the Birds of Peru."),
                " Unión de Ornitólogos del Perú (UNOP). Paquete R versión 2026.v1. Disponible en: ",
                tags$a(href = "https://github.com/PaulESantos/avesperu", target = "_blank", "https://github.com/PaulESantos/avesperu")
              ),
              tags$li(
                tags$strong("Categorización UICN (iucnr): "),
                "Santos-Andrade, P. E. (2026). ", tags$em("iucnr: An R package to access and match species against the IUCN Red List of Threatened Species (version 2026-1)."),
                " Disponible en: ", tags$a(href = "https://paulesantos.github.io/iucnr/", target = "_blank", "https://paulesantos.github.io/iucnr/")
              ),
              tags$li(
                tags$strong("Normativa Nacional de Conservación: "),
                "Decreto Supremo Nº 004-2014-MINAGRI (Categorización de Especies Amenazadas de Fauna Silvestre Legalmente Protegidas) y Apéndices de la Convención CITES."
              )
            )
          )
        )
      )
    )
  )
}

mod_ebird_aves_server <- function(id, data_ebird_especies, data_ebird_resumen, sf_ebird_hotspots, sf_distritos) {
  moduleServer(id, function(input, output, session) {
    
    # Llenar opciones del selector de hotspots dinámicamente
    observe({
      req(data_ebird_resumen())
      df_res <- data_ebird_resumen() |> arrange(desc(total_especies_ebird))
      
      opciones <- c("Todos los Hotspots eBird de Anta" = "ALL")
      for (i in 1:nrow(df_res)) {
        label <- sprintf("%s (%d esp. eBird)", df_res$nombre_hotspot[i], df_res$total_especies_ebird[i])
        opciones[label] <- df_res$id_hotspot[i]
      }
      
      updateSelectInput(session, "select_hotspot", choices = opciones, selected = "ALL")
    })
    
    # Filtrar datos reactivos de aves de los hotspots
    aves_filtradas <- reactive({
      req(data_ebird_especies())
      df <- data_ebird_especies()
      
      # Filtro por hotspot específico
      if (input$select_hotspot != "ALL") {
        df <- df |> filter(id_hotspot == input$select_hotspot)
      }
      
      # Filtro por conservación
      if (input$filtro_conservacion == "AMENAZADAS") {
        df <- df |> filter(ds_004_2014 != "No Amenazada" | iucn_categoria %in% c("Vulnerable (VU)", "En Peligro (EN)", "En Peligro Crítico (CR)"))
      } else if (input$filtro_conservacion == "ENDEMICAS") {
        df <- df |> filter(es_endemica_peru == TRUE)
      } else if (input$filtro_conservacion == "CITES") {
        df <- df |> filter(cites_apendice %in% c("Apéndice I", "Apéndice II"))
      }
      
      df |> arrange(desc(n_observaciones))
    })

    # La vista provincial presenta una fila por especie. Esto evita transferir
    # al navegador una repetición por cada hotspot, pero mantiene el detalle
    # original cuando el usuario selecciona un sitio específico.
    aves_tabla <- reactive({
      df <- aves_filtradas()
      req(df)

      if (input$select_hotspot != "ALL") {
        return(df)
      }

      df |>
        group_by(species) |>
        summarise(
          nombre_espanol = first(nombre_espanol),
          nombre_ingles = first(nombre_ingles),
          familia = first(familia),
          orden = first(orden),
          nombre_hotspot = paste0(n_distinct(id_hotspot), " hotspots"),
          ds_004_2014 = first(ds_004_2014),
          iucn_categoria = first(iucn_categoria),
          cites_apendice = first(cites_apendice),
          estatus_residencia = first(estatus_residencia),
          n_observaciones = sum(n_observaciones, na.rm = TRUE),
          ultimo_anio = suppressWarnings(max(ultimo_anio, na.rm = TRUE)),
          .groups = "drop"
        ) |>
        mutate(ultimo_anio = ifelse(is.infinite(ultimo_anio), NA, ultimo_anio)) |>
        arrange(desc(n_observaciones))
    })
    
    # Datos del hotspot actual
    hotspot_actual_info <- reactive({
      req(data_ebird_resumen())
      if (input$select_hotspot == "ALL") {
        return(NULL)
      }
      data_ebird_resumen() |> filter(id_hotspot == input$select_hotspot)
    })
    
    # Título de la ficha
    output$titulo_ficha_ebird <- renderText({
      if (input$select_hotspot == "ALL") {
        "Aves en la Red de Hotspots eBird de Anta"
      } else {
        info <- hotspot_actual_info()
        if (!is.null(info) && nrow(info) > 0) {
          paste("Hotspot:", info$nombre_hotspot[1])
        } else {
          "Hotspot Seleccionado"
        }
      }
    })
    
    output$badge_hotspot_distrito <- renderUI({
      info <- hotspot_actual_info()
      if (is.null(info)) {
        tags$span(class = "badge bg-dark", "17 Hotspots Registrados")
      } else {
        tags$span(class = "badge bg-success", paste("Ubicación:", info$distrito_ubicacion[1]))
      }
    })
    
    output$link_ebird_oficial <- renderUI({
      if (input$select_hotspot != "ALL") {
        url_hotspot <- paste0("https://ebird.org/hotspot/", input$select_hotspot)
        tags$a(
          href = url_hotspot,
          target = "_blank",
          class = "btn btn-sm btn-outline-dark",
          icon("external-link-alt"), " Ver Hotspot en eBird.org"
        )
      }
    })
    
    # KPIs
    output$kpi_ebird_species <- renderText({
      req(aves_filtradas())
      fmt_num(n_distinct(aves_filtradas()$species))
    })
    
    output$kpi_ebird_threatened <- renderText({
      req(aves_filtradas())
      df <- aves_filtradas()
      amenazadas <- df |>
        filter(ds_004_2014 != "No Amenazada" | iucn_categoria %in% c("Vulnerable (VU)", "En Peligro (EN)", "En Peligro Crítico (CR)"))
      fmt_num(n_distinct(amenazadas$species))
    })
    
    output$kpi_ebird_endemic <- renderText({
      req(aves_filtradas())
      df <- aves_filtradas()
      endemicas <- df |> filter(es_endemica_peru == TRUE)
      fmt_num(n_distinct(endemicas$species))
    })
    
    output$kpi_ebird_records <- renderText({
      req(aves_filtradas())
      fmt_num(sum(aves_filtradas()$n_observaciones, na.rm = TRUE))
    })
    
    # ── Mapa de Hotspots de eBird con MapLibre ────────────────────────────────
    output$mapa_ebird_hotspots <- mapgl::renderMaplibre({
      req(sf_ebird_hotspots(), sf_distritos())
      
      hotspots_sf <- sf_ebird_hotspots()
      dist_sf <- sf_distritos()
      
      mapgl::maplibre(
        style = mapgl::carto_style("voyager"),
        bounds = dist_sf,
        projection = "mercator"
      ) |>
        mapgl::add_fill_layer(
          id = "dist-fill-ebird",
          source = dist_sf,
          fill_color = "#0f5132",
          fill_opacity = 0.04,
          fill_outline_color = "#1e293b",
          tooltip = "tooltip"
        ) |>
        mapgl::add_line_layer(
          id = "dist-lines-ebird",
          source = dist_sf,
          line_color = "#0f172a",
          line_width = 1.4,
          line_opacity = 0.7
        ) |>
        mapgl::add_circle_layer(
          id = "hotspots-puntos",
          source = hotspots_sf,
          circle_color = mapgl::interpolate(
            "total_especies_ebird",
            values = range(hotspots_sf$total_especies_ebird, na.rm = TRUE),
            stops = c("#fed7aa", "#c2410c")
          ),
          circle_radius = mapgl::interpolate(
            "total_especies_ebird",
            values = range(hotspots_sf$total_especies_ebird, na.rm = TRUE),
            stops = c(7, 16)
          ),
          circle_opacity = 0.92,
          circle_stroke_width = 1.5,
          circle_stroke_color = "#ffffff",
          tooltip = "tooltip"
        ) |>
        mapgl::add_navigation_control(position = "top-right") |>
        mapgl::add_fullscreen_control(position = "top-right") |>
        mapgl::add_scale_control(position = "bottom-right", unit = "metric") |>
        mapgl::add_continuous_legend(
          legend_title = "Riqueza de Aves (eBird)",
          values = range(hotspots_sf$total_especies_ebird, na.rm = TRUE),
          colors = c("#fed7aa", "#c2410c"),
          position = "bottom-left",
          collapsible = TRUE
        )
    })
    
    # ── Gráfico de Barras Interactivo de Riqueza por Hotspot con Plotly ───────
    output$grafico_barras_diversidad <- plotly::renderPlotly({
      req(data_ebird_resumen())
      df_res <- data_ebird_resumen() |>
        arrange(total_especies_ebird) # Orden ascendente para barra horizontal
      
      # Truncar nombres largos para una lectura estética
      df_res$nombre_corto <- ifelse(
        nchar(df_res$nombre_hotspot) > 28,
        paste0(substr(df_res$nombre_hotspot, 1, 26), "..."),
        df_res$nombre_hotspot
      )
      
      p <- plotly::plot_ly(
        data = df_res,
        y = ~reorder(nombre_corto, total_especies_ebird),
        x = ~total_especies_ebird,
        type = "bar",
        orientation = "h",
        marker = list(
          color = ~total_especies_ebird,
          colorscale = list(c(0, "#fed7aa"), c(1, "#c2410c")),
          showscale = FALSE,
          line = list(color = "#7c2d12", width = 0.8)
        ),
        text = ~paste0(total_especies_ebird, " especies"),
        textposition = "outside",
        hovertemplate = paste0(
          "<b>%{customdata[0]}</b><br>",
          "Ubicación: %{customdata[1]}<br>",
          "Riqueza de Aves: %{x} especies<br>",
          "Observaciones Totales: %{customdata[2]}<br>",
          "<extra></extra>"
        ),
        customdata = ~mapply(list, nombre_hotspot, distrito_ubicacion, total_observaciones_ebird, SIMPLIFY = FALSE)
      ) |>
        plotly::layout(
          xaxis = list(
            title = "Número de Especies Identificadas",
            gridcolor = "#e2e8f0",
            zeroline = FALSE
          ),
          yaxis = list(
            title = "",
            tickfont = list(size = 11)
          ),
          margin = list(l = 10, r = 35, t = 15, b = 40),
          paper_bgcolor = "rgba(0,0,0,0)",
          plot_bgcolor = "rgba(0,0,0,0)",
          font = list(family = "Inter, sans-serif")
        ) |>
        plotly::config(displayModeBar = FALSE)
      
      p
    })
    
    # ── Tabla Interactiva de Aves en eBird con reactable ──────────────────────
    output$tabla_aves_ebird <- reactable::renderReactable({
      req(aves_tabla())
      
      df <- aves_tabla() |>
        select(
          species, nombre_espanol, nombre_ingles, familia, orden,
          nombre_hotspot, ds_004_2014, iucn_categoria, cites_apendice,
          estatus_residencia, n_observaciones, ultimo_anio
        )
      
      reactable::reactable(
        df,
        striped = TRUE,
        highlight = TRUE,
        searchable = TRUE,
        defaultPageSize = 10,
        showPageSizeOptions = TRUE,
        pageSizeOptions = c(10, 25, 50, 100),
        columns = list(
          species = reactable::colDef(
            name = "Nombre Científico",
            minWidth = 180,
            cell = function(val) tags$em(style = "font-weight: 700; color: #0f172a;", val)
          ),
          nombre_espanol = reactable::colDef(
            name = "Nombre Común (avesperu)",
            minWidth = 170,
            style = list(fontWeight = "600", color = "#0f5132")
          ),
          nombre_ingles = reactable::colDef(name = "Nombre en Inglés", minWidth = 160),
          familia = reactable::colDef(name = "Familia", width = 120),
          orden = reactable::colDef(name = "Orden", width = 120),
          nombre_hotspot = reactable::colDef(name = "Cobertura de hotspots", minWidth = 150),
          ds_004_2014 = reactable::colDef(
            name = "D.S. 004-2014-MINAGRI",
            minWidth = 160,
            cell = function(val) {
              if (grepl("Peligro Crítico", val)) tags$span(class = "badge bg-danger", val)
              else if (grepl("En Peligro", val)) tags$span(class = "badge bg-danger", val)
              else if (grepl("Vulnerable", val)) tags$span(class = "badge bg-warning text-dark", val)
              else if (grepl("Casi Amenazado", val)) tags$span(class = "badge bg-warning text-dark", val)
              else tags$span(class = "text-muted", style = "font-size: 0.75rem;", "No amenazada")
            }
          ),
          iucn_categoria = reactable::colDef(
            name = "UICN Global (iucnr)",
            width = 140,
            cell = function(val) {
              if (grepl("CR|EN|VU", val)) tags$span(class = "badge bg-danger", val)
              else if (grepl("NT", val)) tags$span(class = "badge bg-warning text-dark", val)
              else if (grepl("DD", val)) tags$span(class = "badge bg-secondary", val)
              else if (grepl("LC", val)) tags$span(class = "badge bg-light text-dark border", "LC")
              else tags$span(class = "text-muted", style = "font-size: 0.75rem;", val)
            }
          ),
          cites_apendice = reactable::colDef(
            name = "CITES",
            width = 110,
            cell = function(val) {
              if (val != "No CITES") tags$span(class = "badge bg-dark", val)
              else tags$span(class = "text-muted", style = "font-size: 0.75rem;", "-")
            }
          ),
          estatus_residencia = reactable::colDef(
            name = "Estatus Residencia",
            width = 130,
            cell = function(val) {
              if (identical(val, "Endémico")) tags$span(class = "badge bg-success", "🇵🇪 Endémica")
              else if (identical(val, "Migratorio Boreal")) tags$span(class = "badge bg-info text-dark", "Migratoria")
              else tags$span(val)
            }
          ),
          n_observaciones = reactable::colDef(
            name = "Observaciones eBird",
            width = 110,
            align = "right",
            format = reactable::colFormat(separators = TRUE)
          ),
          ultimo_anio = reactable::colDef(name = "Año Rec.", width = 85, align = "center")
        )
      )
    })
    
    # Descargas
    output$btn_descargar_ebird_csv <- downloadHandler(
      filename = function() {
        paste0("aves_ebird_hotspots_anta_", Sys.Date(), ".csv")
      },
      content = function(file) {
        write.csv(aves_filtradas(), file, row.names = FALSE, fileEncoding = "UTF-8")
      }
    )
    
    output$btn_descargar_hotspots_geojson <- downloadHandler(
      filename = function() "anta_ebird_hotspots.geojson",
      content = function(file) {
        file.copy("outputs/analisis_biodiversidad/ebird_hotspots_anta.geojson", file)
      }
    )
  })
}
