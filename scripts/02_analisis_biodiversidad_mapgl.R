#!/usr/bin/env Rscript

# Analisis reproducible de biodiversidad y cobertura para la provincia de Anta.
# Genera tablas, GeoJSON y un tablero HTML dinamico basado en mapgl/MapLibre.

.libPaths(c(file.path(getwd(), ".r-library"), .libPaths()))

suppressPackageStartupMessages({
  library(sf)
  library(dplyr)
  library(mapgl)
  library(htmltools)
  library(htmlwidgets)
})

source("R/utils_homologacion.R")

options(scipen = 999)
sf_use_s2(FALSE)

dir.create("outputs/analisis_biodiversidad", recursive = TRUE, showWarnings = FALSE)
out_dir <- "outputs/analisis_biodiversidad"

occ_path <- "data/spatial/ocurrencias_homologadas.gpkg"
dist_path <- "data/spatial/DISTRITOS_PROV_ANTA.shp"

stopifnot(file.exists(occ_path), file.exists(dist_path))

occ <- st_read(occ_path, quiet = TRUE) |>
  st_transform(4326) |>
  mutate(
    species = trimws(as.character(species)),
    grupo = tolower(as.character(grupo)),
    source = normalizar_fuente_descarga(fuente_descarga),
    plataforma = as.character(plataforma_origen),
    coordinate_uncertainty_m = suppressWarnings(as.numeric(crdnUIM)),
    event_date = as.Date(substr(as.character(eventDt), 1, 10)),
    year = as.integer(format(event_date, "%Y"))
  )

districts <- st_read(dist_path, quiet = TRUE) |>
  st_make_valid() |>
  st_transform(4326) |>
  transmute(district = tools::toTitleCase(tolower(as.character(NOMBDIST))))

province <- districts |> summarise(district = "Provincia de Anta")

# Filtrado analitico: registros determinados a especie o subespecie.
valid <- occ |>
  filter(
    taxnRnk %in% c("SPECIES", "SUBSPECIES"),
    !is.na(species), species != "",
    is.na(coordinate_uncertainty_m) | coordinate_uncertainty_m <= 5000
  ) |>
  st_join(districts, left = FALSE, join = st_within)

# -----------------------------------------------------------------------------
# 1. Cobertura distrital, taxonomica y temporal
# -----------------------------------------------------------------------------
district_summary <- valid |>
  st_drop_geometry() |>
  group_by(district) |>
  summarise(
    records = n(),
    flora_species = n_distinct(species[grupo == "flora"]),
    fauna_species = n_distinct(species[grupo == "fauna"]),
    species = n_distinct(species),
    families = n_distinct(family[!is.na(family)]),
    sources = n_distinct(source[!is.na(source)]),
    platforms = n_distinct(plataforma[!is.na(plataforma)]),
    first_year = suppressWarnings(min(year, na.rm = TRUE)),
    last_year = suppressWarnings(max(year, na.rm = TRUE)),
    recent_records = sum(year >= 2020, na.rm = TRUE),
    .groups = "drop"
  ) |>
  mutate(
    records_per_species = round(records / species, 1),
    recent_pct = round(100 * recent_records / records, 1)
  )

district_map <- districts |>
  left_join(district_summary, by = "district") |>
  mutate(across(c(records, species, flora_species, fauna_species, families), ~ifelse(is.na(.x), 0, .x)))

# -----------------------------------------------------------------------------
# 2. Cuadricula de 5 km y vacios espaciales
# La proyeccion UTM 18S permite medir superficie y construir celdas regulares.
# -----------------------------------------------------------------------------
districts_utm <- st_transform(districts, 32718)
province_utm <- districts_utm |> summarise()
valid_utm <- st_transform(valid, 32718)

grid_sfc <- st_make_grid(province_utm, cellsize = 5000, square = TRUE)
grid <- st_sf(cell_id = sprintf("A%03d", seq_along(grid_sfc)), geometry = grid_sfc) |>
  st_intersection(province_utm) |>
  mutate(area_km2 = as.numeric(st_area(geometry)) / 1e6) |>
  filter(area_km2 >= 0.5)

# Asignación uno-a-uno. Los puntos exactamente sobre el borde de una celda no
# cumplen st_within(); se asignan a la celda más cercana para no perderlos.
grid_index <- st_within(valid_utm, grid)
sin_celda <- lengths(grid_index) == 0L
if (any(sin_celda)) {
  vecinos <- st_nearest_feature(valid_utm[sin_celda, ], grid)
  grid_index[sin_celda] <- lapply(vecinos, function(i) as.integer(i))
}
grid_join <- valid_utm
grid_join$cell_id <- grid$cell_id[vapply(grid_index, function(i) i[1], integer(1))]

grid_stats <- grid_join |>
  st_drop_geometry() |>
  group_by(cell_id) |>
  summarise(
    records = n(),
    flora_species = n_distinct(species[grupo == "flora"]),
    fauna_species = n_distinct(species[grupo == "fauna"]),
    species = n_distinct(species),
    recent_records = sum(year >= 2020, na.rm = TRUE),
    .groups = "drop"
  )

grid <- grid |>
  left_join(grid_stats, by = "cell_id") |>
  mutate(
    across(c(records, species, flora_species, fauna_species, recent_records), ~ifelse(is.na(.x), 0, .x)),
    status = case_when(
      records == 0 ~ "Sin registros",
      records < 10 | species < 5 ~ "Cobertura muy baja",
      records < 50 | species < 15 ~ "Cobertura baja",
      TRUE ~ "Cobertura suficiente"
    ),
    priority = case_when(
      records == 0 ~ 1L,
      records < 10 | species < 5 ~ 2L,
      records < 50 | species < 15 ~ 3L,
      TRUE ~ 4L
    ),
    tooltip = paste0(
      "Celda: ", cell_id, "<br>Estado: ", status,
      "<br>Registros: ", format(records, big.mark = ","),
      "<br>Especies: ", species, "<br>Area: ", round(area_km2, 1), " km2"
    )
  )

grid_4326 <- st_transform(grid, 4326)

covered_area_pct <- round(100 * sum(grid$area_km2[grid$records > 0]) / sum(grid$area_km2), 1)
empty_cells <- sum(grid$records == 0)
low_cells <- sum(grid$status %in% c("Cobertura muy baja", "Cobertura baja"))

# -----------------------------------------------------------------------------
# 3. Recambio de especies (disimilitud de Jaccard) entre distritos
# -----------------------------------------------------------------------------
pa <- valid |>
  st_drop_geometry() |>
  distinct(district, species) |>
  mutate(present = 1L)

district_names <- sort(unique(districts$district))
species_names <- sort(unique(pa$species))
mat <- matrix(0L, nrow = length(district_names), ncol = length(species_names),
              dimnames = list(district_names, species_names))
mat[cbind(match(pa$district, district_names), match(pa$species, species_names))] <- 1L

pairs <- combn(district_names, 2, simplify = FALSE)
turnover <- do.call(rbind, lapply(pairs, function(p) {
  a <- mat[p[1], ] == 1
  b <- mat[p[2], ] == 1
  shared <- sum(a & b)
  union <- sum(a | b)
  data.frame(
    district_a = p[1], district_b = p[2], shared_species = shared,
    total_species = union, jaccard_similarity = ifelse(union == 0, NA, shared / union),
    jaccard_turnover = ifelse(union == 0, NA, 1 - shared / union)
  )
})) |>
  mutate(across(c(jaccard_similarity, jaccard_turnover), ~round(.x, 3))) |>
  arrange(desc(jaccard_turnover))

uniqueness <- data.frame(
  district = district_names,
  exclusive_species = vapply(seq_along(district_names), function(i) {
    sum(mat[i, ] == 1 & colSums(mat) == 1)
  }, numeric(1)),
  mean_turnover = vapply(seq_along(district_names), function(i) {
    others <- setdiff(seq_along(district_names), i)
    mean(vapply(others, function(j) {
      u <- sum(mat[i, ] == 1 | mat[j, ] == 1)
      if (u == 0) NA_real_ else 1 - sum(mat[i, ] == 1 & mat[j, ] == 1) / u
    }, numeric(1)), na.rm = TRUE)
  }, numeric(1))
) |>
  mutate(mean_turnover = round(mean_turnover, 3)) |>
  arrange(desc(mean_turnover))

district_map <- district_map |>
  left_join(uniqueness, by = "district") |>
  mutate(
    tooltip = paste0(
      "<b>", district, "</b><br>Registros: ", format(records, big.mark = ","),
      "<br>Especies: ", species, "<br>Flora: ", flora_species,
      " | Fauna: ", fauna_species, "<br>Especies exclusivas: ", exclusive_species,
      "<br>Recambio medio: ", round(100 * mean_turnover), "%"
    )
  )

# -----------------------------------------------------------------------------
# 4. Productos tabulares y espaciales
# -----------------------------------------------------------------------------
write.csv(st_drop_geometry(district_map), file.path(out_dir, "resumen_distritos.csv"), row.names = FALSE, fileEncoding = "UTF-8")
write.csv(st_drop_geometry(grid), file.path(out_dir, "cobertura_cuadricula_5km.csv"), row.names = FALSE, fileEncoding = "UTF-8")
write.csv(turnover, file.path(out_dir, "recambio_jaccard_distritos.csv"), row.names = FALSE, fileEncoding = "UTF-8")
write.csv(uniqueness, file.path(out_dir, "singularidad_distritos.csv"), row.names = FALSE, fileEncoding = "UTF-8")
st_write(grid_4326, file.path(out_dir, "cobertura_cuadricula_5km.geojson"), delete_dsn = TRUE, quiet = TRUE)
st_write(district_map, file.path(out_dir, "biodiversidad_distritos.geojson"), delete_dsn = TRUE, quiet = TRUE)

# Para mantener el visor fluido se muestra una muestra espacial reproducible de
# puntos; todos los registros participan en los indicadores y la cuadricula.
set.seed(20260821)
points_map <- valid |>
  mutate(record_id = row_number()) |>
  group_by(district, grupo) |>
  slice_sample(n = 1500) |>
  ungroup() |>
  transmute(
    record_id, species, grupo,
    tooltip = paste0(
      "<i>", species, "</i><br>", tools::toTitleCase(grupo), " · ", district,
      "<br>", plataforma, " vía ", source
    )
  )

# -----------------------------------------------------------------------------
# 5. Mapas MapGL / MapLibre (sin token)
# -----------------------------------------------------------------------------
coverage_map <- maplibre(style = carto_style("positron"), bounds = grid_4326,
                         height = 560, projection = "mercator") |>
  add_fill_layer(
    id = "coverage-grid", source = grid_4326,
    fill_color = match_expr("status",
      values = c("Sin registros", "Cobertura muy baja", "Cobertura baja", "Cobertura suficiente"),
      stops = c("#7f1d1d", "#ef7d57", "#f4c95d", "#2a9d8f")),
    fill_opacity = 0.72, fill_outline_color = "#ffffff",
    tooltip = "tooltip"
  ) |>
  add_line_layer(id = "district-lines", source = districts, line_color = "#1f2937", line_width = 1.2) |>
  add_navigation_control() |>
  add_fullscreen_control(position = "top-left") |>
  add_categorical_legend(
    legend_title = "Cobertura · celdas de 5 km",
    values = c("Sin registros", "Muy baja", "Baja", "Suficiente"),
    colors = c("#7f1d1d", "#ef7d57", "#f4c95d", "#2a9d8f"),
    position = "bottom-left", collapsible = TRUE
  )

richness_map <- maplibre(style = carto_style("voyager"), bounds = district_map,
                         height = 560, projection = "mercator") |>
  add_fill_layer(
    id = "district-richness", source = district_map,
    fill_color = interpolate("species", values = range(district_map$species),
                             stops = c("#d8f3dc", "#1b4332")),
    fill_opacity = 0.7, fill_outline_color = "#ffffff", tooltip = "tooltip"
  ) |>
  add_circle_layer(
    id = "occurrences", source = points_map,
    circle_color = match_expr("grupo", values = c("flora", "fauna"), stops = c("#52b788", "#277da1")),
    circle_radius = 3, circle_opacity = 0.48, circle_stroke_width = 0.2,
    circle_stroke_color = "#ffffff", tooltip = "tooltip",
    cluster_options = cluster_options(max_zoom = 11, count_stops = c(0, 100, 500))
  ) |>
  add_navigation_control() |>
  add_fullscreen_control(position = "top-left") |>
  add_categorical_legend(
    legend_title = "Registros mostrados",
    values = c("Flora", "Fauna"), colors = c("#52b788", "#277da1"),
    patch_shape = "circle", position = "bottom-left", collapsible = TRUE
  )

turnover_map <- maplibre(style = carto_style("positron"), bounds = district_map,
                         height = 560, projection = "mercator") |>
  add_fill_layer(
    id = "district-turnover", source = district_map,
    fill_color = interpolate("mean_turnover", values = range(district_map$mean_turnover),
                             stops = c("#fee8c8", "#b30000")),
    fill_opacity = 0.78, fill_outline_color = "#ffffff", tooltip = "tooltip"
  ) |>
  add_navigation_control() |>
  add_fullscreen_control(position = "top-left") |>
  add_continuous_legend(
    legend_title = "Recambio medio (Jaccard)",
    values = round(range(district_map$mean_turnover), 2), colors = c("#fee8c8", "#b30000"),
    position = "bottom-left", collapsible = TRUE
  )

fmt <- function(x) format(x, big.mark = ",", scientific = FALSE)
n_records <- nrow(valid)
n_species <- n_distinct(valid$species)
n_flora <- n_distinct(valid$species[valid$grupo == "flora"])
n_fauna <- n_distinct(valid$species[valid$grupo == "fauna"])
top_gap <- grid |>
  st_drop_geometry() |>
  arrange(priority, records, desc(area_km2)) |>
  slice_head(n = 8)
top_turnover <- turnover |> slice_head(n = 8)

table_html <- function(df) {
  tags$table(
    tags$thead(tags$tr(lapply(names(df), tags$th))),
    tags$tbody(lapply(seq_len(nrow(df)), function(i) tags$tr(lapply(df[i, ], tags$td))))
  )
}

page <- tagList(
  tags$html(lang = "es",
    tags$head(
      tags$meta(charset = "utf-8"),
      tags$meta(name = "viewport", content = "width=device-width,initial-scale=1"),
      tags$title("Biodiversidad de Anta · Cobertura y recambio"),
      tags$style(HTML("
        :root{--ink:#17211b;--muted:#5d6b63;--paper:#f5f1e8;--card:#fffdf8;--green:#1b5e4b;--line:#d8d2c5}
        *{box-sizing:border-box}body{margin:0;background:var(--paper);color:var(--ink);font-family:Inter,Segoe UI,Arial,sans-serif;line-height:1.55}
        header{padding:56px max(5vw,24px) 42px;background:linear-gradient(125deg,#12372c,#1b5e4b 58%,#aa6b34);color:white}
        .eyebrow{font-size:.76rem;letter-spacing:.16em;text-transform:uppercase;font-weight:700;color:#cfe8db}h1{font-family:Georgia,serif;font-size:clamp(2.2rem,5vw,4.8rem);line-height:1.02;max-width:980px;margin:.25rem 0 1rem}header p{max-width:800px;font-size:1.1rem;color:#e5efe9}
        main{max-width:1420px;margin:auto;padding:34px max(3vw,18px) 70px}.metrics{display:grid;grid-template-columns:repeat(6,1fr);gap:12px;margin-top:-58px}.metric{background:var(--card);padding:18px;border:1px solid var(--line);box-shadow:0 8px 24px #17211b12}.metric b{display:block;font:700 1.75rem Georgia,serif;color:var(--green)}.metric span{font-size:.78rem;color:var(--muted)}
        section{margin-top:56px}.kicker{color:#a5572b;font-size:.74rem;text-transform:uppercase;letter-spacing:.12em;font-weight:800}h2{font:700 clamp(1.7rem,3vw,2.7rem) Georgia,serif;margin:.25rem 0 .6rem}.lead{max-width:900px;color:var(--muted)}.map-card{background:var(--card);border:1px solid var(--line);padding:10px;box-shadow:0 14px 34px #17211b12;margin-top:20px}.grid2{display:grid;grid-template-columns:1.15fr .85fr;gap:22px;align-items:start}.note{background:#e7efe8;border-left:4px solid var(--green);padding:16px 18px;margin:18px 0}.warning{background:#f8e8d5;border-left-color:#b65c2b}
        table{width:100%;border-collapse:collapse;background:var(--card);font-size:.86rem}th,td{text-align:left;padding:9px;border-bottom:1px solid var(--line)}th{background:#ece7db;position:sticky;top:0}.table-wrap{overflow:auto;max-height:420px;border:1px solid var(--line)}footer{border-top:1px solid var(--line);padding:28px 0;color:var(--muted);font-size:.86rem}
        @media(max-width:1000px){.metrics{grid-template-columns:repeat(3,1fr)}.grid2{grid-template-columns:1fr}}@media(max-width:600px){.metrics{grid-template-columns:repeat(2,1fr);margin-top:-35px}.metric{padding:13px}header{padding-top:38px}}
      "))
    ),
    tags$body(
      tags$header(
        tags$div(class = "eyebrow", "Provincia de Anta · Cusco"),
        tags$h1("Biodiversidad registrada, cobertura y recambio"),
        tags$p("Diagnostico espacial de los registros consolidados de GBIF e iNaturalist. Los mapas distinguen evidencia disponible de biodiversidad real para orientar nuevas campañas de campo.")
      ),
      tags$main(
        tags$div(class = "metrics",
          tags$div(class="metric", tags$b(fmt(n_records)), tags$span("registros validos")),
          tags$div(class="metric", tags$b(fmt(n_species)), tags$span("especies observadas")),
          tags$div(class="metric", tags$b(fmt(n_flora)), tags$span("especies de flora")),
          tags$div(class="metric", tags$b(fmt(n_fauna)), tags$span("especies de fauna")),
          tags$div(class="metric", tags$b(paste0(covered_area_pct,"%")), tags$span("area en celdas con datos")),
          tags$div(class="metric", tags$b(empty_cells), tags$span("celdas de 5 km sin registros"))
        ),
        tags$section(
          tags$div(class="kicker", "01 · Cobertura de registros"), tags$h2("Donde sabemos y donde no"),
          tags$p(class="lead", "La cobertura se resume en celdas regulares de 5 km. Una celda roja es un vacio de informacion, no una zona sin especies. Las celdas anaranjadas y amarillas tienen evidencia insuficiente para comparaciones robustas."),
          tags$div(class="note warning", tags$b("Lectura prioritaria: "), paste0(empty_cells, " celdas no tienen registros y ", low_cells, " presentan cobertura baja o muy baja. El ", covered_area_pct, "% de la superficie provincial cae en celdas con al menos un registro.")),
          tags$div(class="map-card", coverage_map)
        ),
        tags$section(
          tags$div(class="kicker", "02 · Biodiversidad observada"), tags$h2("Riqueza y concentracion del esfuerzo"),
          tags$p(class="lead", "El color resume especies distintas por distrito. Los puntos son una muestra cartografica estratificada para mantener el rendimiento; todos los registros fueron usados en los calculos. La agrupacion se deshace al acercarse."),
          tags$div(class="map-card", richness_map)
        ),
        tags$section(
          tags$div(class="kicker", "03 · Recambio de especies"), tags$h2("Comunidades que se complementan"),
          tags$p(class="lead", "El recambio Jaccard vale 0 cuando dos distritos tienen la misma lista y se aproxima a 1 cuando comparten pocas especies. Un valor alto identifica composicion singular, pero tambien puede aumentar por submuestreo."),
          tags$div(class="map-card", turnover_map)
        ),
        tags$section(class="grid2",
          tags$div(
            tags$div(class="kicker", "Pares con mayor recambio"), tags$h2("Complementariedad distrital"),
            tags$div(class="table-wrap", table_html(top_turnover |>
              transmute(`Distrito A`=district_a, `Distrito B`=district_b, `Compartidas`=shared_species,
                        `Total combinado`=total_species, `Recambio`=jaccard_turnover)))
          ),
          tags$div(
            tags$div(class="kicker", "Vacios prioritarios"), tags$h2("Celdas para verificar en campo"),
            tags$div(class="table-wrap", table_html(top_gap |>
              transmute(`Celda`=cell_id, `Estado`=status, `Registros`=records, `Especies`=species, `Area km2`=round(area_km2,1))))
          )
        ),
        tags$section(
          tags$div(class="kicker", "Sintesis para la gestion"), tags$h2("Que hacer con esta linea base"),
          tags$div(class="grid2",
            tags$div(class="note", tags$b("1. Cerrar vacios espaciales."), tags$br(), "Priorizar primero celdas sin registros y luego las de menos de 10 registros o 5 especies, distribuyendo puntos por gradiente altitudinal y tipo de cobertura."),
            tags$div(class="note", tags$b("2. Estandarizar el esfuerzo."), tags$br(), "Registrar horas-persona, distancia recorrida, protocolo y detectabilidad. Sin esfuerzo comparable, la riqueza observada no equivale a riqueza real."),
            tags$div(class="note", tags$b("3. Muestrear flora y fauna por separado."), tags$br(), "La fauna domina el volumen de registros; los vacios de flora requieren campañas botanicas y validacion de ejemplares."),
            tags$div(class="note", tags$b("4. Proteger complementariedad."), tags$br(), "Los distritos con alto recambio aportan especies no representadas en otros lugares; deben leerse junto con endemismo, amenaza y conectividad." )
          )
        ),
        tags$footer("Métodos: homologación taxonómica con backbone GBIF · deduplicación por identificador de origen · ocurrencias a especie/subespecie · incertidumbre conocida <= 5 km · unión espacial con límites distritales · cuadrícula UTM 18S de 5 km · disimilitud de Jaccard. Canales: GBIF e iNaturalist.")
      )
    )
  )
)

save_html(page, file = file.path(out_dir, "index.html"), libdir = "assets", background = "#f5f1e8")

cat("\nAnalisis generado en:", normalizePath(file.path(out_dir, "index.html")), "\n")
cat("Registros validos:", n_records, "| Especies:", n_species, "| Cobertura:", covered_area_pct, "%\n")
