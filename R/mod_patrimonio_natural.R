mod_patrimonio_natural_ui <- function(id) {
  ns <- NS(id)
  tagList(
    div(class = "content-card mb-3",
      div(class = "content-card-header",
        div(class = "content-card-title", icon("mountain"), " Patrimonio natural y paisajístico")),
      p(style = "font-size: 0.85rem; color: #475569;",
        "Inventario de sitios naturales de la provincia de Anta. Explore sus atributos, tipos y distribución territorial."),
      div(class = "row g-3",
        div(class = "col-md-4", selectInput(ns("distrito"), "Distrito", choices = "Todos")),
        div(class = "col-md-4", selectInput(ns("tipo"), "Tipo", choices = "Todos")),
        div(class = "col-md-4", textInput(ns("buscar"), "Buscar sitio", placeholder = "Nombre o subtipo"))),
      textOutput(ns("indicadores"))),
    div(class = "map-container-wrapper mb-3", mapgl::maplibreOutput(ns("mapa"), height = "580px")),
    div(class = "content-card",
      div(class = "content-card-header",
        div(class = "content-card-title", icon("list"), " Sitios del inventario")),
      reactable::reactableOutput(ns("tabla")),
      div(class = "d-flex gap-2 mt-3",
        downloadButton(ns("geojson"), "Descargar selección GeoJSON"),
        downloadButton(ns("csv"), "Descargar selección CSV")))
  )
}

filter_patrimonio <- function(x, distrito = "Todos", tipo = "Todos", buscar = "") {
  # El campo del insumo original no se utiliza ni se publica en este módulo.
  x <- x[, setdiff(names(x), "UBI_VERIFI")]
  for (field in c("DISTRITO", "TIPO")) {
    value <- switch(field, DISTRITO = distrito, TIPO = tipo)
    if (!is.null(value) && value != "Todos") x <- x[!is.na(x[[field]]) & x[[field]] == value, ]
  }
  if (!is.null(buscar) && nzchar(trimws(buscar))) {
    text <- paste(x$Name, x$SUB_TIPO)
    x <- x[grepl(tolower(trimws(buscar)), tolower(text), fixed = TRUE), ]
  }
  x
}

mod_patrimonio_natural_server <- function(id, patrimonio, distritos) {
  moduleServer(id, function(input, output, session) {
    observe({
      x <- patrimonio()
      for (pair in list(c("distrito", "DISTRITO"), c("tipo", "TIPO"))) {
        values <- sort(unique(x[[pair[2]]]))
        values <- values[!is.na(values) & nzchar(values)]
        updateSelectInput(session, pair[1], choices = c("Todos", values))
      }
    })
    selected <- reactive(filter_patrimonio(patrimonio(), input$distrito, input$tipo, input$buscar))
    output$indicadores <- renderText({
      x <- selected()
      paste0(nrow(x), " de ", nrow(patrimonio()), " sitios · ",
        length(unique(x$DISTRITO[!is.na(x$DISTRITO)])), " distritos")
    })
    output$mapa <- mapgl::renderMaplibre({
      x <- selected()
      bounds <- if (nrow(x)) x else patrimonio()
      m <- maplibre_with_satellite(style = mapgl::carto_style("positron"), bounds = bounds) |>
        mapgl::add_line_layer(id = "limites", source = distritos(), line_color = "#64748b", line_width = 1)
      if (nrow(x)) {
        types <- sort(unique(patrimonio()$TIPO))
        types <- types[!is.na(types) & nzchar(types)]
        colors <- grDevices::hcl.colors(length(types), palette = "Dark 3")
        safe <- function(v) as.character(htmltools::htmlEscape(ifelse(is.na(v), "Sin información", as.character(v))))
        x$tooltip <- paste0("<b>", safe(x$Name), "</b><br>Distrito: ", safe(x$DISTRITO),
          "<br>Categoría: ", safe(x$CATEGORIA), "<br>Tipo: ", safe(x$TIPO),
          "<br>Subtipo: ", safe(x$SUB_TIPO))
        m <- m |> mapgl::add_circle_layer(id = "sitios", source = x,
          circle_radius = 7, circle_color = mapgl::match_expr("TIPO",
            values = types, stops = colors, default = "#64748b"),
          circle_stroke_color = "#ffffff", circle_stroke_width = 2,
          tooltip = "tooltip", popup = "tooltip",
          tooltip_style = mapgl::tooltip_style(background_color = "#064e3b",
            text_color = "#ffffff", border_color = "#fbbf24", border_width = 2,
            border_radius = 10, font_size = 14, padding = 14, max_width = 340),
          popup_style = mapgl::popup_style(background_color = "#064e3b",
            text_color = "#ffffff", border_color = "#fbbf24", border_width = 2,
            border_radius = 10, font_size = 14, padding = 14, max_width = 340)) |>
          mapgl::add_categorical_legend(legend_title = "Tipo de patrimonio natural",
            values = c(types, "Sin información / otro"), colors = c(colors, "#64748b"), position = "bottom-left")
      }
      m
    })
    output$tabla <- reactable::renderReactable({
      x <- sf::st_drop_geometry(selected())
      x <- x[, c("Name", "DISTRITO", "CATEGORIA", "TIPO", "SUB_TIPO")]
      names(x) <- c("Sitio", "Distrito", "Categoría", "Tipo", "Subtipo")
      reactable::reactable(x, searchable = TRUE, striped = TRUE, highlight = TRUE,
        defaultPageSize = 10, language = reactable::reactableLang(noData = "No hay sitios que coincidan con los filtros."))
    })
    output$geojson <- downloadHandler(
      filename = function() "patrimonio_natural_seleccion.geojson",
      content = function(file) sf::st_write(selected(), file, driver = "GeoJSON", quiet = TRUE,
        layer_options = c("RFC7946=YES", "COORDINATE_PRECISION=6")), contentType = "application/geo+json")
    output$csv <- downloadHandler(filename = function() "patrimonio_natural_seleccion.csv",
      content = function(file) write.csv(sf::st_drop_geometry(selected()), file, row.names = FALSE, fileEncoding = "UTF-8"))
  })
}
