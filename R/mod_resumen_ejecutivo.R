# ==============================================================================
# MOD_RESUMEN_EJECUTIVO.R: Módulo de Resumen Ejecutivo y Métricas Territoriales
# Municipalidad Provincial de Anta - Gerencia de Desarrollo Urbano y Rural (GDUR)
# ==============================================================================

mod_resumen_ejecutivo_ui <- function(id) {
  ns <- NS(id)
  
  tagList(
    # ── Fila de KPIs Principales con Jerarquía y Acentos Visuales ─────────────
    div(
      class = "row g-3 mb-4",
      div(
        class = "col-lg-3 col-md-6",
        div(
          class = "kpi-card kpi-total",
          div(
            class = "kpi-header-row",
            div(class = "kpi-title", "Riqueza Total"),
            div(class = "kpi-icon", icon("globe-americas"))
          ),
          div(class = "kpi-value", textOutput(ns("kpi_total_species"))),
          div(
            class = "kpi-subtitle",
            tags$span(class = "badge-pill-freshness", icon("check-circle"), " Especies Únicas"),
            tags$span("en 9 distritos")
          )
        )
      ),
      div(
        class = "col-lg-3 col-md-6",
        div(
          class = "kpi-card kpi-flora",
          div(
            class = "kpi-header-row",
            div(class = "kpi-title", "Flora Validada"),
            div(class = "kpi-icon", icon("leaf"))
          ),
          div(class = "kpi-value", textOutput(ns("kpi_flora_species"))),
          div(
            class = "kpi-subtitle",
            tags$span(class = "badge-flora", textOutput(ns("kpi_flora_pct"), inline = TRUE)),
            tags$span("del inventario provincial")
          )
        )
      ),
      div(
        class = "col-lg-3 col-md-6",
        div(
          class = "kpi-card kpi-fauna",
          div(
            class = "kpi-header-row",
            div(class = "kpi-title", "Fauna Validada"),
            div(class = "kpi-icon", icon("dove"))
          ),
          div(class = "kpi-value", textOutput(ns("kpi_fauna_species"))),
          div(
            class = "kpi-subtitle",
            tags$span(class = "badge-fauna", textOutput(ns("kpi_fauna_pct"), inline = TRUE)),
            tags$span("del inventario provincial")
          )
        )
      ),
      div(
        class = "col-lg-3 col-md-6",
        div(
          class = "kpi-card kpi-threatened",
          div(
            class = "kpi-header-row",
            div(class = "kpi-title", "Amenazadas UICN"),
            div(class = "kpi-icon", icon("shield-alt"))
          ),
          div(class = "kpi-value", textOutput(ns("kpi_total_iucn_threatened"))),
          div(
            class = "kpi-subtitle",
            tags$span(class = "badge bg-danger", "CR / EN / VU"),
            tags$span("Evaluación UICN 2026-1")
          )
        )
      )
    ),
    
    # ── Gráficos Comparativos: Barras Horizontales y Donut de Esfuerzo ────────
    div(
      class = "row g-4 mb-4",
      # Gráfico 1: Barras Horizontales con Toggle de Modo
      div(
        class = "col-lg-7",
        div(
          class = "content-card h-100",
          div(
            class = "content-card-header d-flex flex-wrap justify-content-between align-items-center gap-2",
            div(class = "content-card-title", icon("chart-bar"), " Composición de Riqueza por Distrito"),
            div(
              radioButtons(
                inputId = ns("modo_grafico_barras"),
                label = NULL,
                choices = c("Valores Absolutos" = "stack", "Composición (%)" = "percent"),
                selected = "stack",
                inline = TRUE
              )
            )
          ),
          plotly::plotlyOutput(ns("plot_riqueza_distrital"), height = "390px")
        )
      ),
      
      # Gráfico 2: Donut Semántico con KPI Central
      div(
        class = "col-lg-5",
        div(
          class = "content-card h-100",
          div(
            class = "content-card-header",
            div(class = "content-card-title", icon("chart-pie"), " Esfuerzo de Muestreo (Grilla 5 km)")
          ),
          plotly::plotlyOutput(ns("plot_cobertura_pie"), height = "320px"),
          div(
            class = "text-center text-muted mt-2",
            style = "font-size: 0.78rem;",
            textOutput(ns("texto_total_celdas"), inline = TRUE)
          )
        )
      )
    ),
    
    # ── Matriz Territorial Distrital con reactable ────────────────────────────
    div(
      class = "row",
      div(
        class = "col-12",
        div(
          class = "content-card",
          div(
            class = "content-card-header",
            div(class = "content-card-title", icon("table"), " Matriz Territorial de Biodiversidad por Distrito")
          ),
          reactable::reactableOutput(ns("tabla_resumen_distritos"))
        )
      )
    )
  )
}

mod_resumen_ejecutivo_server <- function(id, data_especies, data_resumen, data_cuadricula) {
  moduleServer(id, function(input, output, session) {

    output$texto_total_celdas <- renderText({
      req(data_cuadricula())
      paste0(fmt_num(nrow(data_cuadricula())), " celdas de 25 km² evaluadas · EPSG:32718 (UTM 18S)")
    })
    
    # KPIs Globales
    output$kpi_total_species <- renderText({
      req(data_especies())
      fmt_num(n_distinct(data_especies()$species))
    })
    
    output$kpi_flora_species <- renderText({
      req(data_especies())
      df_flora <- data_especies() |>
        filter(tolower(reino) %in% c("plantae", "flora"))
      fmt_num(n_distinct(df_flora$species))
    })
    
    output$kpi_flora_pct <- renderText({
      req(data_especies())
      total <- n_distinct(data_especies()$species)
      flora <- n_distinct(
        data_especies() |>
          filter(tolower(reino) %in% c("plantae", "flora")) |>
          pull(species)
      )
      if (total == 0) return("0.0%")
      fmt_pct((flora / total) * 100)
    })
    
    output$kpi_fauna_species <- renderText({
      req(data_especies())
      df_fauna <- data_especies() |>
        filter(tolower(reino) %in% c("animalia", "fauna"))
      fmt_num(n_distinct(df_fauna$species))
    })
    
    output$kpi_fauna_pct <- renderText({
      req(data_especies())
      total <- n_distinct(data_especies()$species)
      fauna <- n_distinct(
        data_especies() |>
          filter(tolower(reino) %in% c("animalia", "fauna")) |>
          pull(species)
      )
      if (total == 0) return("0.0%")
      fmt_pct((fauna / total) * 100)
    })
    
    output$kpi_total_iucn_threatened <- renderText({
      req(data_especies())
      amenazadas <- data_especies() |>
        filter(iucn_categoria %in% c("En Peligro Crítico (CR)", "En Peligro (EN)", "Vulnerable (VU)"))
      fmt_num(n_distinct(amenazadas$species))
    })
    
    # ── Gráfico de Barras Horizontales con Toggle Absoluto / % ────────────────
    output$plot_riqueza_distrital <- plotly::renderPlotly({
      req(data_resumen(), input$modo_grafico_barras)
      
      df <- data_resumen() |>
        arrange(species)
      
      modo <- input$modo_grafico_barras
      
      if (modo == "percent") {
        df <- df |>
          mutate(
            total_sp = flora_species + fauna_species,
            pct_flora = round((flora_species / total_sp) * 100, 1),
            pct_fauna = round((fauna_species / total_sp) * 100, 1)
          )
        
        p <- plotly::plot_ly(
          data = df,
          y = ~reorder(district, species),
          x = ~pct_flora,
          type = "bar",
          orientation = "h",
          name = "Flora (%)",
          marker = list(color = "#059669", line = list(color = "#047857", width = 0.5)),
          hovertemplate = "<b>%{y}</b><br>Flora: %{x}% (%{customdata[0]} esp.)<extra></extra>",
          customdata = ~mapply(list, flora_species, SIMPLIFY = FALSE)
        ) |>
          plotly::add_trace(
            x = ~pct_fauna,
            name = "Fauna (%)",
            marker = list(color = "#0284c7", line = list(color = "#0369a1", width = 0.5)),
            hovertemplate = "<b>%{y}</b><br>Fauna: %{x}% (%{customdata[0]} esp.)<extra></extra>",
            customdata = ~mapply(list, fauna_species, SIMPLIFY = FALSE)
          ) |>
          plotly::layout(
            barmode = "stack",
            xaxis = list(
              title = "Porcentaje Relativo de Riqueza (%)",
              range = c(0, 100),
              ticksuffix = "%",
              gridcolor = "#e2e8f0"
            ),
            yaxis = list(title = ""),
            legend = list(orientation = "h", x = 0.25, y = 1.12),
            margin = list(l = 10, r = 20, t = 20, b = 40),
            paper_bgcolor = "rgba(0,0,0,0)",
            plot_bgcolor = "rgba(0,0,0,0)",
            font = list(family = "Inter, sans-serif")
          )
      } else {
        p <- plotly::plot_ly(
          data = df,
          y = ~reorder(district, species),
          x = ~flora_species,
          type = "bar",
          orientation = "h",
          name = "Flora",
          marker = list(color = "#059669", line = list(color = "#047857", width = 0.5)),
          hovertemplate = "<b>%{y}</b><br>Flora: %{x} especies<extra></extra>"
        ) |>
          plotly::add_trace(
            x = ~fauna_species,
            name = "Fauna",
            marker = list(color = "#0284c7", line = list(color = "#0369a1", width = 0.5)),
            hovertemplate = "<b>%{y}</b><br>Fauna: %{x} especies<extra></extra>"
          ) |>
          plotly::layout(
            barmode = "stack",
            xaxis = list(
              title = "Número de Especies Identificadas",
              gridcolor = "#e2e8f0"
            ),
            yaxis = list(title = ""),
            legend = list(orientation = "h", x = 0.25, y = 1.12),
            margin = list(l = 10, r = 20, t = 20, b = 40),
            paper_bgcolor = "rgba(0,0,0,0)",
            plot_bgcolor = "rgba(0,0,0,0)",
            font = list(family = "Inter, sans-serif")
          )
      }
      
      p |> plotly::config(displayModeBar = FALSE)
    })
    
    # ── Gráfico de Donut Semántico con KPI Central y Tooltips Enriquecidos ────
    output$plot_cobertura_pie <- plotly::renderPlotly({
      req(data_cuadricula())
      
      df <- data_cuadricula() |>
        count(status) |>
        mutate(
          status = factor(
            status,
            levels = c("Cobertura suficiente", "Cobertura baja", "Cobertura muy baja", "Sin registros")
          ),
          pct = round((n / sum(n)) * 100, 1),
          area_km2 = n * 25
        ) |>
        arrange(status)
      
      color_map <- c(
        "Cobertura suficiente" = "#10b981",
        "Cobertura baja"       = "#f59e0b",
        "Cobertura muy baja"   = "#f97316",
        "Sin registros"        = "#ef4444"
      )
      
      vacio_pct <- sum(df$pct[df$status %in% c("Sin registros", "Cobertura muy baja")])
      
      plotly::plot_ly(
        df,
        labels = ~status,
        values = ~n,
        type = "pie",
        hole = 0.62,
        sort = FALSE,
        marker = list(
          colors = color_map[as.character(df$status)],
          line = list(color = "#ffffff", width = 2)
        ),
        textinfo = "percent",
        textposition = "inside",
        hovertemplate = paste0(
          "<b>%{label}</b><br>",
          "Celdas: %{value} de ", nrow(data_cuadricula()), " (%{percent})<br>",
          "Superficie: %{customdata} km²<br>",
          "<extra></extra>"
        ),
        customdata = ~area_km2
      ) |>
        plotly::layout(
          showlegend = TRUE,
          legend = list(orientation = "h", x = 0, y = -0.12, font = list(size = 11)),
          margin = list(l = 10, r = 10, t = 10, b = 40),
          paper_bgcolor = "rgba(0,0,0,0)",
          font = list(family = "Inter, sans-serif"),
          annotations = list(
            list(
              text = paste0("<b>", format(vacio_pct, nsmall = 1), "%</b><br><span style='font-size:10px; color:#64748b;'>Vacío / Muy Baja</span>"),
              x = 0.5, y = 0.5,
              showarrow = FALSE,
              font = list(size = 16, color = "#991b1b")
            )
          )
        ) |>
        plotly::config(displayModeBar = FALSE)
    })
    
    # ── Tabla Resumen Distrital con reactable ──────────────────────────────────
    output$tabla_resumen_distritos <- reactable::renderReactable({
      req(data_resumen())
      
      df <- data_resumen() |>
        select(
          district, records, species, flora_species, fauna_species,
          especies_amenazadas_iucn, exclusive_species, mean_turnover, recent_pct
        ) |>
        arrange(desc(species))
      
      reactable::reactable(
        df,
        striped = TRUE,
        highlight = TRUE,
        bordered = FALSE,
        columns = list(
          district = reactable::colDef(
            name = "Distrito",
            minWidth = 140,
            style = list(fontWeight = "700", color = "#0f172a")
          ),
          records = reactable::colDef(
            name = "Registros",
            align = "right",
            format = reactable::colFormat(separators = TRUE)
          ),
          species = reactable::colDef(
            name = "Total Especies",
            align = "right",
            format = reactable::colFormat(separators = TRUE),
            style = list(fontWeight = "600")
          ),
          flora_species = reactable::colDef(
            name = "Flora",
            align = "center",
            cell = function(value) tags$span(class = "badge-flora", value)
          ),
          fauna_species = reactable::colDef(
            name = "Fauna",
            align = "center",
            cell = function(value) tags$span(class = "badge-fauna", value)
          ),
          especies_amenazadas_iucn = reactable::colDef(
            name = "Amenazadas UICN",
            align = "center",
            cell = function(value) {
              if (value > 0) tags$span(class = "badge bg-danger", value)
              else tags$span(class = "text-muted", "0")
            }
          ),
          exclusive_species = reactable::colDef(
            name = "Exclusivas",
            align = "center",
            cell = function(value) tags$span(class = "badge-exclusiva", value)
          ),
          mean_turnover = reactable::colDef(
            name = "Recambio Medio",
            align = "right",
            format = reactable::colFormat(percent = TRUE, digits = 1)
          ),
          recent_pct = reactable::colDef(
            name = "Recientes (≥2020)",
            align = "right",
            cell = function(value) {
              tags$span(class = "badge-pill-freshness", paste0(format(value, nsmall = 1), "%"))
            }
          )
        )
      )
    })
  })
}
