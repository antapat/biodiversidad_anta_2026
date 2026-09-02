# ==============================================================================
# MOD_RECAMBIO_ECOLOGICO.R: Módulo de Recambio Ecológico (Jaccard) y Singularidad
# ==============================================================================

mod_recambio_ecologico_ui <- function(id) {
  ns <- NS(id)
  
  tagList(
    div(
      class = "row g-4 mb-4",
      # Matriz de Calor de Jaccard
      div(
        class = "col-lg-7",
        div(
          class = "content-card h-100",
          div(
            class = "content-card-header",
            div(class = "content-card-title", icon("th"), " Matriz de Disimilitud Ecológica (Índice de Jaccard)")
          ),
          div(
            style = "font-size: 0.85rem; color: #64748b; margin-bottom: 0.75rem;",
            "Mide la proporción de especies no compartidas entre distritos (1.0 = recambio total, 0.0 = comunidades idénticas):"
          ),
          plotly::plotlyOutput(ns("plot_matriz_jaccard"), height = "420px")
        )
      ),
      
      # Tabla de Singularidad y Especies Exclusivas
      div(
        class = "col-lg-5",
        div(
          class = "content-card h-100",
          div(
            class = "content-card-header",
            div(class = "content-card-title", icon("star"), " Singularidad y Exclusividad Distrital")
          ),
          div(
            style = "font-size: 0.85rem; color: #64748b; margin-bottom: 0.75rem;",
            "Distritos ordenados por su grado de singularidad biológica y especies no presentes en el resto de Anta:"
          ),
          reactable::reactableOutput(ns("tabla_singularidad"))
        )
      )
    ),
    
    # Detalle de pares con mayor recambio
    div(
      class = "row",
      div(
        class = "col-12",
        div(
          class = "content-card",
          div(
            class = "content-card-header",
            div(class = "content-card-title", icon("exchange-alt"), " Pares Distritales con Mayor Diferenciación Biológica")
          ),
          reactable::reactableOutput(ns("tabla_pares_recambio"))
        )
      )
    )
  )
}

mod_recambio_ecologico_server <- function(id, data_recambio, data_singularidad) {
  moduleServer(id, function(input, output, session) {
    
    # Matriz interactiva de calor con Plotly (Corregido: usa jaccard_turnover)
    output$plot_matriz_jaccard <- plotly::renderPlotly({
      req(data_recambio())
      df <- data_recambio()
      
      distritos <- sort(unique(c(df$district_a, df$district_b)))
      n <- length(distritos)
      
      mat <- matrix(0, nrow = n, ncol = n, dimnames = list(distritos, distritos))
      
      for (i in 1:nrow(df)) {
        da <- as.character(df$district_a[i])
        db <- as.character(df$district_b[i])
        # Usar columna jaccard_turnover
        val <- round(as.numeric(df$jaccard_turnover[i]), 3)
        mat[da, db] <- val
        mat[db, da] <- val
      }
      
      plotly::plot_ly(
        x = distritos,
        y = distritos,
        z = mat,
        type = "heatmap",
        colors = colorRamp(c("#fef3c7", "#ea580c", "#7c2d12")),
        colorbar = list(title = "Recambio", len = 0.8)
      ) |>
        plotly::layout(
          xaxis = list(title = "", tickangle = -30),
          yaxis = list(title = ""),
          margin = list(l = 80, r = 20, t = 20, b = 80),
          paper_bgcolor = "transparent",
          plot_bgcolor = "transparent"
        )
    })
    
    # Tabla de Singularidad
    output$tabla_singularidad <- reactable::renderReactable({
      req(data_singularidad())
      
      df <- data_singularidad() |>
        arrange(desc(exclusive_species), desc(mean_turnover))
      
      reactable::reactable(
        df,
        compact = TRUE,
        striped = TRUE,
        highlight = TRUE,
        columns = list(
          district = reactable::colDef(name = "Distrito", style = list(fontWeight = "bold")),
          exclusive_species = reactable::colDef(
            name = "Esp. Exclusivas",
            align = "right",
            cell = function(val) tags$span(class = "badge-exclusiva", val)
          ),
          mean_turnover = reactable::colDef(
            name = "Recambio Medio",
            align = "right",
            format = reactable::colFormat(percent = TRUE, digits = 1)
          )
        )
      )
    })
    
    # Tabla de pares de mayor recambio (Corregido: jaccard_turnover)
    output$tabla_pares_recambio <- reactable::renderReactable({
      req(data_recambio())
      
      df <- data_recambio() |>
        arrange(desc(jaccard_turnover)) |>
        head(20)
      
      reactable::reactable(
        df,
        striped = TRUE,
        highlight = TRUE,
        defaultPageSize = 8,
        columns = list(
          district_a = reactable::colDef(name = "Distrito A", style = list(fontWeight = "600")),
          district_b = reactable::colDef(name = "Distrito B", style = list(fontWeight = "600")),
          jaccard_turnover = reactable::colDef(
            name = "Disimilitud Jaccard",
            format = reactable::colFormat(percent = TRUE, digits = 1),
            style = function(val) {
              list(fontWeight = "bold", color = if (!is.na(val) && val > 0.85) "#991b1b" else "#1e293b")
            }
          ),
          shared_species = reactable::colDef(name = "Especies Compartidas", align = "right"),
          total_species = reactable::colDef(name = "Especies Combinadas", align = "right"),
          jaccard_similarity = reactable::colDef(
            name = "Similitud Jaccard",
            format = reactable::colFormat(percent = TRUE, digits = 1)
          )
        )
      )
    })
  })
}
