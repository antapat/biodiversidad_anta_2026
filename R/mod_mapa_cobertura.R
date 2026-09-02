# ==============================================================================
# MOD_MAPA_COBERTURA.R: Visor Cartográfico Interactivo y Panel Comparativo
# Municipalidad Provincial de Anta - Gerencia de Desarrollo Urbano y Rural (GDUR)
# ==============================================================================

mod_mapa_cobertura_ui <- function(id) {
  ns <- NS(id)
  
  tagList(
    # ── Banner Prominente de Diagnóstico Territorial para GDUR ─────────────────
    div(
      class = "row mb-3",
      div(
        class = "col-12",
        uiOutput(ns("diagnostico_territorial"))
      )
    ),
    
    # ── Barra de Controles de Capas ───────────────────────────────────────────
    div(
      class = "row g-3 mb-3",
      div(
        class = "col-md-8",
        div(
          class = "d-flex align-items-center gap-3",
          selectInput(
            inputId = ns("tipo_mapa"),
            label = tags$strong("Capa Temática Activa:"),
            choices = c(
              "Cobertura y Vacíos de Muestreo (Grilla 5 km)" = "cobertura",
              "Riqueza Distrital de Especies (Flora + Fauna)" = "riqueza",
              "Recambio Medio Distrital (Disimilitud Jaccard)" = "recambio"
            ),
            selected = "cobertura",
            width = "380px"
          ),
          div(
            class = "mt-3 pt-1",
            span(
              class = "badge bg-dark",
              icon("layer-group"), " Proyección UTM 18S / WGS84"
            )
          )
        )
      ),
      div(
        class = "col-md-4 text-end d-flex align-items-center justify-content-end",
        div(
          style = "font-size: 0.8rem; color: #64748b;",
          icon("info-circle"), " El panel lateral se adapta automáticamente a la capa seleccionada."
        )
      )
    ),
    
    # ── Visor Cartográfico y Panel Comparativo Dinámico ──────────────────────
    div(
      class = "row g-4",
      # Mapa MapLibre (Columna Izquierda)
      div(
        class = "col-lg-7",
        div(
          class = "map-container-wrapper",
          mapgl::maplibreOutput(ns("mapa_interactivo"), height = "640px")
        )
      ),
      
      # Panel Lateral Comparativo Dinámico (Columna Derecha)
      div(
        class = "col-lg-5",
        div(
          class = "content-card h-100 d-flex flex-column",
          div(
            class = "content-card-header",
            div(class = "content-card-title", uiOutput(ns("titulo_panel_derecho")))
          ),
          
          # Contenido reactivo según la capa activa
          div(
            class = "flex-grow-1",
            uiOutput(ns("contenido_panel_derecho"))
          )
        )
      )
    )
  )
}

mod_mapa_cobertura_server <- function(id, sf_distritos, sf_cuadricula, data_cuadricula, data_resumen) {
  moduleServer(id, function(input, output, session) {

    # Diagnóstico calculado desde la versión vigente de la cuadrícula, para
    # evitar que el mensaje institucional quede desactualizado al renovar datos.
    output$diagnostico_territorial <- renderUI({
      df <- data_cuadricula()
      req(nrow(df) > 0)

      prioritarias <- df |>
        filter(status %in% c("Sin registros", "Cobertura muy baja"))

      n_total <- nrow(df)
      n_prioritarias <- nrow(prioritarias)
      pct_celdas <- round(100 * n_prioritarias / n_total, 1)
      area_prioritaria <- round(sum(prioritarias$area_km2, na.rm = TRUE), 1)

      div(
        class = "territorial-alert-banner",
        div(
          class = "territorial-alert-title",
          icon("exclamation-triangle"),
          "Diagnóstico Territorial GDUR: Vacíos de Información Biológica"
        ),
        p(
          class = "territorial-alert-text",
          "El ",
          tags$strong(paste0(pct_celdas, "% de las celdas analizadas (", n_prioritarias, " de ", n_total, ")")),
          " presenta ausencia de registros o cobertura muy baja de muestreo biológico, equivalente a ",
          tags$strong(paste0(format(area_prioritaria, big.mark = ",", decimal.mark = "."), " km²")),
          ". Estas celdas constituyen áreas prioritarias para orientar el levantamiento de información de campo y fortalecer los instrumentos de ordenamiento territorial."
        )
      )
    })
    
    # Cargar datos de resumen distrital para los gráficos comparativos
    data_distritos_resumen <- reactive({
      data_resumen()
    })
    
    # ── Título dinámico del panel derecho ─────────────────────────────────────
    output$titulo_panel_derecho <- renderUI({
      tipo <- input$tipo_mapa
      if (tipo == "cobertura") {
        tags$span(icon("shield-alt"), " Diagnóstico de Vacíos y Prioridades")
      } else if (tipo == "riqueza") {
        tags$span(icon("chart-bar"), " Comparativa Distrital de Riqueza")
      } else {
        tags$span(icon("project-diagram"), " Recambio y Diferenciación Ecológica")
      }
    })
    
    # ── Contenido dinámico del panel derecho ──────────────────────────────────
    output$contenido_panel_derecho <- renderUI({
      tipo <- input$tipo_mapa
      
      if (tipo == "cobertura") {
        tagList(
          div(
            style = "font-size: 0.83rem; color: #475569; margin-bottom: 0.5rem;",
            "Distribución del esfuerzo de muestreo en celdas de 5 km × 5 km (25 km²) y celdas críticas sin información biológica:"
          ),
          plotly::plotlyOutput(session$ns("plot_cobertura_comparativo"), height = "240px"),
          div(
            class = "mt-3",
            tags$strong(style = "font-size: 0.85rem; color: #0f5132;", icon("list-ol"), " Celdas Prioritarias para Trabajo de Campo:"),
            div(class = "mt-1", reactable::reactableOutput(session$ns("tabla_celdas_prioritarias")))
          )
        )
      } else if (tipo == "riqueza") {
        top_riqueza <- data_distritos_resumen() |>
          arrange(desc(species)) |>
          slice_head(n = 2)
        riqueza_texto <- paste(
          paste0(
            top_riqueza$district, " (",
            vapply(top_riqueza$species, fmt_num, character(1)), " esp.)"
          ),
          collapse = " y "
        )
        tagList(
          div(
            style = "font-size: 0.83rem; color: #475569; margin-bottom: 0.5rem;",
            "Comparación de la riqueza total de especies identificadas por distrito, desglosando la contribución de flora y fauna:"
          ),
          plotly::plotlyOutput(session$ns("plot_riqueza_comparativo"), height = "360px"),
          div(
            class = "p-3 mt-3 border rounded bg-light",
            style = "font-size: 0.8rem; color: #334155; line-height: 1.5;",
            tags$strong(icon("info-circle"), " Hallazgo Clave: "),
            "Los distritos de ", tags$strong(riqueza_texto),
            " albergan la mayor riqueza debido al gradiente altitudinal y al intenso esfuerzo de observación ecoturística en las rutas de Salkantay y Choquequirao."
          )
        )
      } else {
        top_recambio <- data_distritos_resumen() |>
          arrange(desc(mean_turnover)) |>
          slice_head(n = 2)
        recambio_texto <- paste(
          paste0(
            top_recambio$district, " (",
            vapply(100 * top_recambio$mean_turnover, fmt_pct, character(1)), ")"
          ),
          collapse = " y "
        )
        tagList(
          div(
            style = "font-size: 0.83rem; color: #475569; margin-bottom: 0.5rem;",
            "Disimilitud ecológica media de Jaccard por distrito (mayor valor = ensamblaje de especies más singular y exclusivo):"
          ),
          plotly::plotlyOutput(session$ns("plot_recambio_comparativo"), height = "360px"),
          div(
            class = "p-3 mt-3 border rounded bg-light",
            style = "font-size: 0.8rem; color: #334155; line-height: 1.5;",
            tags$strong(icon("leaf"), " Singularidad Ecológica: "),
            tags$strong(recambio_texto),
            " presentan el mayor recambio de especies, lo que indica que albergan comunidades biológicas altamente exclusivas que no se replican en el resto de la provincia."
          )
        )
      }
    })
    
    # ── Mapa MapLibre ─────────────────────────────────────────────────────────
    output$mapa_interactivo <- mapgl::renderMaplibre({
      req(sf_distritos(), sf_cuadricula())
      
      dist_sf <- sf_distritos()
      grid_sf <- sf_cuadricula()
      tipo <- input$tipo_mapa
      
      if (tipo == "cobertura") {
        m <- mapgl::maplibre(
          style = mapgl::carto_style("positron"),
          bounds = grid_sf,
          projection = "mercator"
        ) |>
          mapgl::add_fill_layer(
            id = "coverage-grid",
            source = grid_sf,
            fill_color = mapgl::match_expr(
              "status",
              values = c("Sin registros", "Cobertura muy baja", "Cobertura baja", "Cobertura suficiente"),
              stops = c("#ef4444", "#f97316", "#f59e0b", "#10b981")
            ),
            fill_opacity = 0.65,
            fill_outline_color = "#475569",
            tooltip = "tooltip"
          ) |>
          mapgl::add_line_layer(
            id = "dist-boundaries",
            source = dist_sf,
            line_color = "#0f172a",
            line_width = 2
          ) |>
          mapgl::add_categorical_legend(
            legend_title = "Estado de Cobertura (5 km)",
            values = c("Cobertura suficiente", "Cobertura baja", "Cobertura muy baja", "Sin registros"),
            colors = c("#10b981", "#f59e0b", "#f97316", "#ef4444"),
            position = "bottom-left"
          )
      } else if (tipo == "riqueza") {
        r_vals <- range(dist_sf$species, na.rm = TRUE)
        r_stops <- c("#e0f2fe", "#0f5132")
        
        m <- mapgl::maplibre(
          style = mapgl::carto_style("voyager"),
          bounds = dist_sf,
          projection = "mercator"
        ) |>
          mapgl::add_fill_layer(
            id = "richness-fill",
            source = dist_sf,
            fill_color = mapgl::interpolate(
              "species",
              values = r_vals,
              stops = r_stops
            ),
            fill_opacity = 0.75,
            fill_outline_color = "#0f172a",
            tooltip = "tooltip"
          ) |>
          mapgl::add_line_layer(
            id = "dist-lines",
            source = dist_sf,
            line_color = "#0f172a",
            line_width = 2
          ) |>
          mapgl::add_continuous_legend(
            legend_title = "Riqueza Total de Especies",
            values = r_vals,
            colors = r_stops,
            position = "bottom-left"
          )
      } else {
        t_vals <- range(dist_sf$mean_turnover, na.rm = TRUE)
        t_stops <- c("#fef3c7", "#7f1d1d")
        
        m <- mapgl::maplibre(
          style = mapgl::carto_style("voyager"),
          bounds = dist_sf,
          projection = "mercator"
        ) |>
          mapgl::add_fill_layer(
            id = "turnover-fill",
            source = dist_sf,
            fill_color = mapgl::interpolate(
              "mean_turnover",
              values = t_vals,
              stops = t_stops
            ),
            fill_opacity = 0.75,
            fill_outline_color = "#0f172a",
            tooltip = "tooltip"
          ) |>
          mapgl::add_line_layer(
            id = "dist-lines",
            source = dist_sf,
            line_color = "#0f172a",
            line_width = 2
          ) |>
          mapgl::add_continuous_legend(
            legend_title = "Recambio Medio (Jaccard)",
            values = round(t_vals * 100, 1),
            colors = t_stops,
            position = "bottom-left"
          )
      }
      
      m |>
        mapgl::add_navigation_control(position = "top-right") |>
        mapgl::add_fullscreen_control(position = "top-right") |>
        mapgl::add_scale_control(position = "bottom-right", unit = "metric")
    })
    
    # ── Gráfico 1: Cobertura Comparativa (Donut/Bar) ──────────────────────────
    output$plot_cobertura_comparativo <- plotly::renderPlotly({
      req(data_cuadricula())
      df <- data_cuadricula() |>
        count(status) |>
        mutate(
          status = factor(
            status,
            levels = c("Cobertura suficiente", "Cobertura baja", "Cobertura muy baja", "Sin registros")
          ),
          pct = round((n / sum(n)) * 100, 1)
        ) |>
        arrange(status)
      
      color_map <- c(
        "Cobertura suficiente" = "#10b981",
        "Cobertura baja"       = "#f59e0b",
        "Cobertura muy baja"   = "#f97316",
        "Sin registros"        = "#ef4444"
      )
      
      plotly::plot_ly(
        df,
        y = ~status,
        x = ~n,
        type = "bar",
        orientation = "h",
        marker = list(color = color_map[as.character(df$status)]),
        text = ~paste0(n, " celdas (", pct, "%)"),
        textposition = "auto",
        hovertemplate = paste0(
          "<b>%{y}</b><br>Celdas: %{x} de ", nrow(data_cuadricula()),
          " (%{text})<extra></extra>"
        )
      ) |>
        plotly::layout(
          xaxis = list(title = "Número de Celdas (25 km² c/u)", gridcolor = "#e2e8f0"),
          yaxis = list(title = "", autorange = "reversed"),
          margin = list(l = 10, r = 20, t = 10, b = 35),
          paper_bgcolor = "rgba(0,0,0,0)",
          plot_bgcolor = "rgba(0,0,0,0)",
          font = list(family = "Inter, sans-serif", size = 11)
        ) |>
        plotly::config(displayModeBar = FALSE)
    })
    
    # ── Gráfico 2: Riqueza Comparativa (Flora vs Fauna) ───────────────────────
    output$plot_riqueza_comparativo <- plotly::renderPlotly({
      req(data_distritos_resumen())
      df <- data_distritos_resumen() |> arrange(species)
      
      plotly::plot_ly(
        data = df,
        y = ~reorder(district, species),
        x = ~flora_species,
        type = "bar",
        orientation = "h",
        name = "Flora",
        marker = list(color = "#059669"),
        hovertemplate = "<b>%{y}</b><br>Flora: %{x} esp.<extra></extra>"
      ) |>
        plotly::add_trace(
          x = ~fauna_species,
          name = "Fauna",
          marker = list(color = "#0284c7"),
          hovertemplate = "<b>%{y}</b><br>Fauna: %{x} esp.<extra></extra>"
        ) |>
        plotly::layout(
          barmode = "stack",
          xaxis = list(title = "Número de Especies", gridcolor = "#e2e8f0"),
          yaxis = list(title = ""),
          legend = list(orientation = "h", x = 0.25, y = 1.12),
          margin = list(l = 10, r = 20, t = 20, b = 40),
          paper_bgcolor = "rgba(0,0,0,0)",
          plot_bgcolor = "rgba(0,0,0,0)",
          font = list(family = "Inter, sans-serif", size = 11)
        ) |>
        plotly::config(displayModeBar = FALSE)
    })
    
    # ── Gráfico 3: Recambio Comparativo (% Jaccard) ───────────────────────────
    output$plot_recambio_comparativo <- plotly::renderPlotly({
      req(data_distritos_resumen())
      df <- data_distritos_resumen() |>
        mutate(recambio_pct = round(mean_turnover * 100, 1)) |>
        arrange(recambio_pct)
      
      plotly::plot_ly(
        data = df,
        y = ~reorder(district, recambio_pct),
        x = ~recambio_pct,
        type = "bar",
        orientation = "h",
        marker = list(
          color = ~recambio_pct,
          colorscale = list(c(0, "#fed7aa"), c(1, "#991b1b")),
          showscale = FALSE,
          line = list(color = "#7c2d12", width = 0.5)
        ),
        text = ~paste0(recambio_pct, "%"),
        textposition = "outside",
        hovertemplate = "<b>%{y}</b><br>Recambio Medio: %{x}%<br>Especies Exclusivas: %{customdata} esp.<extra></extra>",
        customdata = ~exclusive_species
      ) |>
        plotly::layout(
          xaxis = list(
            title = "Recambio Medio de Especies (%)",
            range = c(60, 100),
            ticksuffix = "%",
            gridcolor = "#e2e8f0"
          ),
          yaxis = list(title = ""),
          margin = list(l = 10, r = 35, t = 15, b = 40),
          paper_bgcolor = "rgba(0,0,0,0)",
          plot_bgcolor = "rgba(0,0,0,0)",
          font = list(family = "Inter, sans-serif", size = 11)
        ) |>
        plotly::config(displayModeBar = FALSE)
    })
    
    # ── Tabla de celdas prioritarias ──────────────────────────────────────────
    output$tabla_celdas_prioritarias <- reactable::renderReactable({
      req(data_cuadricula())
      
      df_prio <- data_cuadricula() |>
        filter(status %in% c("Sin registros", "Cobertura muy baja")) |>
        select(cell_id, status, records, area_km2, priority) |>
        arrange(priority, records) |>
        head(15)
      
      reactable::reactable(
        df_prio,
        striped = TRUE,
        highlight = TRUE,
        bordered = FALSE,
        pagination = TRUE,
        defaultPageSize = 5,
        columns = list(
          cell_id = reactable::colDef(name = "Celda", width = 75, style = list(fontWeight = "bold")),
          status = reactable::colDef(
            name = "Estado",
            minWidth = 125,
            cell = function(val) {
              if (val == "Sin registros") {
                tags$span(class = "badge bg-danger", val)
              } else {
                tags$span(class = "badge bg-warning text-dark", val)
              }
            }
          ),
          records = reactable::colDef(name = "Obs.", width = 55, align = "right"),
          area_km2 = reactable::colDef(
            name = "Área (km²)",
            width = 90,
            align = "right",
            format = reactable::colFormat(digits = 1)
          ),
          priority = reactable::colDef(name = "Prioridad", width = 75, align = "center")
        )
      )
    })
  })
}
