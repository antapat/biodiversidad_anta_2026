# ==============================================================================
# MOD_DELIMITACION_POLIGONO.R: Módulo de Ocurrencias y Delimitación a Mano Alzada
# Disposición en 2 filas: Fila 1 (Mapa ancho completo) | Fila 2 (Tabla y Descargas)
# Incluye categorización UICN oficial para todas las especies delimitadas
# ==============================================================================

mod_delimitacion_poligono_ui <- function(id) {
  ns <- NS(id)
  
  tagList(
    # Puente explícito entre el control de dibujo de mapgl y Shiny. Se usa al
    # pulsar el botón de consulta para recuperar siempre la geometría visible.
    tags$script(HTML("\n      (function() {\n        if (window.__antaDrawHandlerRegistered) return;\n        window.__antaDrawHandlerRegistered = true;\n        Shiny.addCustomMessageHandler('anta-get-drawn-features', function(data) {\n          var widget = HTMLWidgets.find('#' + data.mapId);\n          var draw = widget && (widget.drawControl || (widget.getDraw && widget.getDraw()));\n          var features = draw ? draw.getAll() : null;\n          Shiny.setInputValue(data.inputId, features, {priority: 'event'});\n        });\n      })();\n    ")),
    # ── FILA 1: Barra de herramientas y Mapa Ancho Completo ───────────────────
    div(
      class = "row g-3 mb-3",
      div(
        class = "col-12",
        div(
          class = "content-card p-3",
          
          # Barra de Controles Superior
          div(
            class = "d-flex flex-wrap justify-content-between align-items-center gap-2 mb-2 pb-2 border-bottom",
            div(
              class = "toolbar-delimitacion d-flex flex-wrap align-items-center gap-2",
              span(
                class = "paso-dibujo",
                icon("pencil-alt"),
                tags$strong("PASO 1"),
                " Dibuje y cierre el área"
              ),
              actionButton(
                inputId = ns("btn_analizar_dibujo"),
                label = tags$strong("PASO 2 · CONSULTAR ESPECIES Y GENERAR INFORME"),
                class = "btn-consulta-zona px-3",
                icon = icon("draw-polygon")
              ),
              actionButton(
                inputId = ns("btn_limpiar_dibujo"),
                label = "Limpiar Dibujo",
                class = "btn-outline-secondary btn-sm",
                icon = icon("eraser")
              )
            ),
            div(
              tags$small(
                style = "color: #0f5132; font-weight: 700;",
                icon("layer-group"), " 9 Distritos de Anta · Observaciones homologadas de GBIF e iNaturalist con UICN"
              )
            )
          ),
          
          # Visor Cartográfico Ancho Completo
          div(
            class = "map-container-wrapper",
            mapgl::maplibreOutput(ns("mapa_ocurrencias"), height = "560px")
          )
        )
      )
    ),
    
    # ── FILA 2: Ficha de Resultados, Métricas y Tabla de Especies ─────────────
    div(
      class = "row g-3 mb-4",
      div(
        class = "col-12",
        div(
          class = "content-card",
          
          # Encabezado de la Ficha con Botones de Descarga
          div(
            class = "content-card-header d-flex flex-wrap justify-content-between align-items-center gap-2",
            div(
              class = "d-flex align-items-center gap-3",
              div(class = "content-card-title", icon("microscope"), " Inventario de Biodiversidad en la Zona Delimitada"),
              uiOutput(ns("badge_estado_zona"))
            ),
            div(
              class = "d-flex align-items-center gap-2",
              downloadButton(
                outputId = ns("btn_descargar_especies_zona"),
                label = "Descargar Especies de la Zona (CSV)",
                class = "btn-sm btn-success font-weight-bold shadow-sm"
              ),
              downloadButton(
                outputId = ns("btn_descargar_poligono_geojson"),
                label = "Descargar Polígono (GeoJSON)",
                class = "btn-sm btn-outline-primary"
              )
            )
          ),
          
          # Tarjetas de Métricas Resumen
          div(
            class = "row g-2 text-center my-1",
            div(
              class = "col-lg-2 col-md-4 col-6",
              div(
                style = "background: #f8fafc; border-radius: 8px; padding: 10px; border: 1px solid #e2e8f0;",
                div(style = "font-size: 0.72rem; color: #64748b; font-weight: 700;", "SUPERFICIE"),
                div(style = "font-size: 1.35rem; font-weight: 800; color: #0f5132;", textOutput(ns("zona_area")))
              )
            ),
            div(
              class = "col-lg-2 col-md-4 col-6",
              div(
                style = "background: #f8fafc; border-radius: 8px; padding: 10px; border: 1px solid #e2e8f0;",
                div(style = "font-size: 0.72rem; color: #64748b; font-weight: 700;", "TOTAL ESPECIES"),
                div(style = "font-size: 1.35rem; font-weight: 800; color: #1e293b;", textOutput(ns("zona_especies_total")))
              )
            ),
            div(
              class = "col-lg-3 col-md-4 col-6",
              div(
                style = "background: #f8fafc; border-radius: 8px; padding: 10px; border: 1px solid #e2e8f0;",
                div(style = "font-size: 0.72rem; color: #64748b; font-weight: 700;", "FLORA / FAUNA"),
                div(style = "font-size: 1.25rem; font-weight: 800; color: #0284c7; margin-top: 2px;", textOutput(ns("zona_flora_fauna")))
              )
            ),
            div(
              class = "col-lg-2 col-md-6 col-6",
              div(
                style = "background: #fef3c7; border-radius: 8px; padding: 10px; border: 1px solid #fde68a;",
                div(style = "font-size: 0.72rem; color: #92400e; font-weight: 700;", "AMENAZADAS UICN"),
                div(style = "font-size: 1.35rem; font-weight: 800; color: #b45309;", textOutput(ns("zona_iucn_total")))
              )
            ),
            div(
              class = "col-lg-3 col-md-6 col-12",
              div(
                style = "background: #f8fafc; border-radius: 8px; padding: 10px; border: 1px solid #e2e8f0;",
                div(style = "font-size: 0.72rem; color: #64748b; font-weight: 700;", "OBSERVACIONES EN ZONA"),
                div(style = "font-size: 1.35rem; font-weight: 800; color: #6366f1;", textOutput(ns("zona_registros_total")))
              )
            )
          ),
          
          # Tabla de Especies en Zona Delimitada
          div(
            class = "mt-3",
            reactable::reactableOutput(ns("tabla_especies_zona"))
          )
        )
      )
    )
  )
}

mod_delimitacion_poligono_server <- function(id, sf_ocurrencias, sf_ocurrencias_mapa, sf_distritos) {
  moduleServer(id, function(input, output, session) {
    
    # Reactivos para almacenar resultados del trazo
    resultado_zona <- reactiveVal(NULL)
    area_zona_ha <- reactiveVal(NULL)
    geometria_zona_sf <- reactiveVal(NULL)
    consulta_pendiente <- reactiveVal(FALSE)
    
    # ── Mapa Principal con MapLibre ───────────────────────────────────────────
    output$mapa_ocurrencias <- mapgl::renderMaplibre({
      req(sf_ocurrencias_mapa(), sf_distritos())
      
      dist_sf <- sf_distritos()
      occ_sf <- sf_ocurrencias_mapa()
      
      mapgl::maplibre(
        style = mapgl::carto_style("voyager"),
        bounds = dist_sf,
        projection = "mercator"
      ) |>
        # 1. Capa de relleno de distritos
        mapgl::add_fill_layer(
          id = "distritos-fill",
          source = dist_sf,
          fill_color = "#0f5132",
          fill_opacity = 0.08,
          fill_outline_color = "#1e293b",
          tooltip = "tooltip"
        ) |>
        # 2. Límites distritales
        mapgl::add_line_layer(
          id = "distritos-lineas",
          source = dist_sf,
          line_color = "#0f172a",
          line_width = 1.8
        ) |>
        # 3. Puntos de Ocurrencias con clustering
        mapgl::add_circle_layer(
          id = "ocurrencias-puntos",
          source = occ_sf,
          circle_color = mapgl::match_expr(
            column = "grupo",
            values = c("flora", "fauna", "mixto"),
            stops = c("#10b981", "#3b82f6", "#8b5cf6"),
            default = "#8b5cf6"
          ),
          circle_radius = 4.5,
          circle_opacity = 0.85,
          circle_stroke_width = 0.5,
          circle_stroke_color = "#ffffff",
          tooltip = "tooltip",
          cluster_options = mapgl::cluster_options(
            max_zoom = 14,
            cluster_radius = 45,
            color_stops = c("#10b981", "#d97706", "#dc2626"),
            count_stops = c(0, 50, 200),
            radius_stops = c(12, 18, 25)
          )
        ) |>
        # 4. Herramienta de Dibujo Mapbox Draw
        mapgl::add_draw_control(
          position = "top-left",
          draw_polygon = TRUE,
          draw_rectangle = TRUE,
          draw_radius = TRUE,
          draw_freehand = TRUE,
          trash = TRUE
        ) |>
        mapgl::add_navigation_control(position = "top-right") |>
        mapgl::add_fullscreen_control(position = "top-right") |>
        mapgl::add_scale_control(position = "bottom-right", unit = "metric") |>
        mapgl::add_categorical_legend(
          legend_title = "Ubicaciones con registros",
          values = c("Flora (Plantas)", "Fauna (Animales)", "Flora y fauna", "Ubicaciones agrupadas"),
          colors = c("#10b981", "#3b82f6", "#8b5cf6", "#dc2626"),
          position = "bottom-left",
          collapsible = TRUE
        )
    })
    
    # Función auxiliar para convertir geometrías dibujadas a sf
    convertir_dibujo_sf <- function() {
      raw_features <- input$mapa_ocurrencias_drawn_features
      if (is.null(raw_features)) return(NULL)
      
      if (inherits(raw_features, "sf")) {
        return(sf::st_make_valid(raw_features))
      }
      
      tryCatch({
        json_str <- if (is.character(raw_features)) {
          paste(raw_features, collapse = "\n")
        } else {
          jsonlite::toJSON(raw_features, auto_unbox = TRUE, null = "null")
        }
        
        parsed <- jsonlite::fromJSON(json_str, simplifyVector = FALSE)
        if (is.null(parsed$features) || length(parsed$features) == 0) return(NULL)
        
        sf_obj <- geojsonsf::geojson_sf(json_str)
        if (nrow(sf_obj) == 0) return(NULL)
        
        sf_obj <- sf::st_make_valid(sf_obj)
        sf::st_crs(sf_obj) <- 4326
        
        geom_types <- unique(sf::st_geometry_type(sf_obj))
        if (any(geom_types %in% c("LINESTRING", "MULTILINESTRING"))) {
          sf_obj_utm <- sf::st_transform(sf_obj, 32718)
          sf_obj_utm <- sf::st_buffer(sf_obj_utm, dist = 30)
          sf_obj <- sf::st_transform(sf_obj_utm, 4326)
        }
        
        return(sf_obj)
      }, error = function(e) {
        message("Error al procesar geometrías dibujadas: ", e$message)
        return(NULL)
      })
    }
    
    # Procesar intersección espacial
    procesar_interseccion <- function() {
      drawn <- convertir_dibujo_sf()
      
      if (is.null(drawn) || nrow(drawn) == 0) {
        showNotification(
          "Por favor dibuje un polígono o área en el mapa antes de consultar.",
          type = "warning",
          duration = 4
        )
        return()
      }
      
      withProgress(message = "Analizando registros en la zona...", value = 0.3, {
        drawn_valid <- sf::st_make_valid(drawn)
        drawn_utm <- sf::st_transform(drawn_valid, 32718)
        area_m2 <- sum(as.numeric(sf::st_area(drawn_utm)), na.rm = TRUE)
        area_ha_val <- round(area_m2 / 10000, 2)
        area_zona_ha(area_ha_val)
        geometria_zona_sf(drawn_valid)
        
        incProgress(0.4, detail = "Cruzando ocurrencias...")
        
        # 1. Intentar consulta acelerada PostGIS en Supabase
        df_especies_zona <- NULL
        if (exists("supabase_consultar_zona", mode = "function")) {
          geojson_str <- tryCatch(geojsonsf::sf_geojson(drawn_valid), error = function(e) NULL)
          if (!is.null(geojson_str)) {
            df_especies_zona <- tryCatch(supabase_consultar_zona(geojson_str), error = function(e) NULL)
          }
        }
        
        # 2. Fallback a cruce local en memoria sf si no hay respuesta de Supabase
        if (is.null(df_especies_zona) && !is.null(sf_ocurrencias())) {
          occ_sf <- sf_ocurrencias()
          intersected <- suppressWarnings(
            sf::st_filter(occ_sf, drawn_valid, .predicate = sf::st_intersects)
          )
          
          if (nrow(intersected) > 0) {
            df_especies_zona <- intersected |>
              sf::st_drop_geometry() |>
              group_by(species, reino) |>
              summarise(
                nombre_cientifico = first(nombre_cientifico),
                clase = first(clase),
                familia = first(familia),
                iucn_categoria = first(iucn_categoria),
                distritos_abarcados = paste(sort(unique(distrito[!is.na(distrito)])), collapse = ", "),
                n_registros_zona = n(),
                fuentes = paste(sort(unique(fuente[!is.na(fuente)])), collapse = " / "),
                primer_anio = suppressWarnings(min(year, na.rm = TRUE)),
                ultimo_anio = suppressWarnings(max(year, na.rm = TRUE)),
                .groups = "drop"
              ) |>
              mutate(
                primer_anio = ifelse(is.infinite(primer_anio), NA, primer_anio),
                ultimo_anio = ifelse(is.infinite(ultimo_anio), NA, ultimo_anio)
              ) |>
              arrange(desc(n_registros_zona))
          } else {
            df_especies_zona <- data.frame()
          }
        }
        
        if (is.null(df_especies_zona) || nrow(df_especies_zona) == 0) {
          resultado_zona(data.frame())
          showNotification(
            "No se encontraron registros biológicos dentro del área delimitada.",
            type = "message",
            duration = 4
          )
        } else {
          resultado_zona(df_especies_zona)
          incProgress(0.3, detail = "Listo")
        }
      })
    }

    # Solicitar al widget su estado actual en el momento de la consulta. La
    # sincronización automática de MapLibre puede no estar disponible según la
    # versión de htmlwidgets; el mensaje proxy fuerza una respuesta Shiny con
    # la colección GeoJSON vigente y evita depender de un valor obsoleto.
    solicitar_dibujo_actual <- function() {
      session$sendCustomMessage(
        "anta-get-drawn-features",
        list(
          mapId = session$ns("mapa_ocurrencias"),
          inputId = session$ns("mapa_ocurrencias_drawn_features")
        )
      )
    }
    
    observeEvent(input$btn_analizar_dibujo, {
      consulta_pendiente(TRUE)
      solicitar_dibujo_actual()
    })

    observeEvent(input$mapa_ocurrencias_drawn_features, {
      if (!isTRUE(consulta_pendiente())) return()
      consulta_pendiente(FALSE)
      procesar_interseccion()
    }, ignoreInit = FALSE, ignoreNULL = FALSE)
    
    observeEvent(input$btn_limpiar_dibujo, {
      mapgl::clear_drawn_features(mapgl::maplibre_proxy("mapa_ocurrencias", session = session))
      resultado_zona(NULL)
      area_zona_ha(NULL)
      geometria_zona_sf(NULL)
      consulta_pendiente(FALSE)
    })
    
    # Salidas visuales
    output$badge_estado_zona <- renderUI({
      if (isTRUE(consulta_pendiente())) {
        return(tags$span(class = "badge bg-info text-dark", "Leyendo área dibujada..."))
      }
      res <- resultado_zona()
      if (is.null(res)) {
        tags$span(class = "badge bg-secondary", "Esperando dibujo")
      } else if (nrow(res) == 0) {
        tags$span(class = "badge bg-warning text-dark", "Sin registros")
      } else {
        tags$span(class = "badge bg-success", paste(nrow(res), "especies identificadas"))
      }
    })
    
    output$zona_area <- renderText({
      ha <- area_zona_ha()
      if (is.null(ha)) return("-")
      if (ha >= 100) {
        paste(format(round(ha / 100, 2), big.mark = ","), "km²")
      } else {
        paste(format(ha, big.mark = ","), "ha")
      }
    })
    
    output$zona_especies_total <- renderText({
      res <- resultado_zona()
      if (is.null(res)) return("-")
      fmt_num(n_distinct(res$species))
    })
    
    output$zona_flora_fauna <- renderText({
      res <- resultado_zona()
      if (is.null(res) || nrow(res) == 0) return("-")
      flora <- sum(tolower(res$reino) %in% c("plantae", "flora"))
      fauna <- sum(tolower(res$reino) %in% c("animalia", "fauna"))
      paste(fmt_num(flora), "Flora /", fmt_num(fauna), "Fauna")
    })
    
    output$zona_iucn_total <- renderText({
      res <- resultado_zona()
      if (is.null(res) || nrow(res) == 0) return("-")
      amenazadas <- res |>
        filter(iucn_categoria %in% c("En Peligro Crítico (CR)", "En Peligro (EN)", "Vulnerable (VU)"))
      fmt_num(n_distinct(amenazadas$species))
    })
    
    output$zona_registros_total <- renderText({
      res <- resultado_zona()
      if (is.null(res)) return("-")
      fmt_num(sum(res$n_registros_zona, na.rm = TRUE))
    })
    
    # Tabla reactable interactiva
    output$tabla_especies_zona <- reactable::renderReactable({
      res <- resultado_zona()
      
      if (is.null(res)) {
        return(reactable::reactable(
          data.frame(Mensaje = "Trace un área o polígono en el mapa superior para extraer las especies registradas en esa zona."),
          columns = list(Mensaje = reactable::colDef(name = "Guía de Consulta", align = "center"))
        ))
      }
      
      if (nrow(res) == 0) {
        return(reactable::reactable(
          data.frame(Mensaje = "No se encontraron registros de biodiversidad dentro del polígono delimitado."),
          columns = list(Mensaje = reactable::colDef(name = "Resultado", align = "center"))
        ))
      }
      
      df_tab <- res |>
        select(
          species, nombre_cientifico, reino, clase, familia,
          iucn_categoria, distritos_abarcados, n_registros_zona, fuentes, ultimo_anio
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
            name = "Especie",
            minWidth = 170,
            cell = function(val) tags$em(style = "font-weight: 700; color: #0f172a;", val)
          ),
          nombre_cientifico = reactable::colDef(
            name = "Nombre Científico / Autoría",
            minWidth = 200,
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
          clase = reactable::colDef(name = "Clase", width = 110),
          familia = reactable::colDef(name = "Familia", width = 120),
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
          distritos_abarcados = reactable::colDef(name = "Distrito(s)", minWidth = 140),
          n_registros_zona = reactable::colDef(
            name = "Obs. Zona",
            width = 100,
            align = "right",
            format = reactable::colFormat(separators = TRUE)
          ),
          fuentes = reactable::colDef(name = "Fuentes", width = 110),
          ultimo_anio = reactable::colDef(name = "Año Rec.", width = 85, align = "center")
        )
      )
    })
    
    # Descargas
    output$btn_descargar_especies_zona <- downloadHandler(
      filename = function() {
        paste0("especies_zona_delimitada_anta_", Sys.Date(), ".csv")
      },
      content = function(file) {
        req(resultado_zona())
        write.csv(resultado_zona(), file, row.names = FALSE, fileEncoding = "UTF-8")
      }
    )
    
    output$btn_descargar_poligono_geojson <- downloadHandler(
      filename = function() {
        paste0("poligono_zona_delimitada_anta_", Sys.Date(), ".geojson")
      },
      content = function(file) {
        req(geometria_zona_sf())
        sf::st_write(geometria_zona_sf(), file, driver = "GeoJSON", delete_dsn = TRUE, quiet = TRUE)
      }
    )
  })
}
