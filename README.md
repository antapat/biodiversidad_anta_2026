# Sistema de Información de Biodiversidad de la Provincia de Anta (2026)
### Municipalidad Provincial de Anta — Gerencia de Desarrollo Urbano y Rural (GDUR)

Plataforma territorial interactiva para la gestión, análisis, monitoreo y toma de decisiones sobre la biodiversidad de flora y fauna en los 9 distritos de la Provincia de Anta, Cusco, Perú.

---

## 🏛️ Arquitectura del Sistema

- **Frontend & Visualización:** R Shiny, bslib (Bootstrap 5), MapLibre GL (`mapgl`), `reactable`, `plotly`.
- **Backend & Almacén de Datos:** [Supabase](https://supabase.com) (PostgreSQL 17 + PostGIS espacial).
- **Cruce Espacial en la Nube:** Procedimientos PostGIS para análisis de delimitación territorial a mano alzada.
- **Fuentes de Datos Homologadas:** GBIF, iNaturalist, eBird / Cornell Lab of Ornithology, AvesPeru, UICN Red List 2026-1.

---

## 📂 Estructura del Repositorio

```text
├── app.R                  # Punto de entrada de la aplicación R Shiny
├── R/
│   ├── mod_resumen_ejecutivo.R       # Módulo de KPIs y resumen provincial
│   ├── mod_explorador_distrital.R    # Módulo de búsqueda por distrito y especies
│   ├── mod_delimitacion_poligono.R   # Módulo de delimitación a mano alzada (PostGIS)
│   ├── mod_ebird_aves.R              # Módulo de hotspots y monitoreo de aves eBird
│   ├── mod_mapa_cobertura.R          # Visor cartográfico y vacíos de información
│   ├── mod_recambio_ecologico.R      # Análisis de recambio y disimilitud de Jaccard
│   ├── mod_metodologia_descarga.R    # Metodología y descarga de catálogos
│   ├── utils_supabase.R              # Conector seguro a Supabase (PostgreSQL + PostGIS)
│   └── utils_data.R                  # Carga y estructuración de datos
├── scripts/                          # Scripts de mantenimiento, DDL y migración
├── www/                              # Estilos CSS y recursos institucionales
├── DESCRIPTION                       # Metadatos del paquete y dependencias de R
└── README.md                         # Documentación institucional
```

---

## 🚀 Despliegue y Ejecución

### Variables de Entorno Requeridas (`.Renviron`)
Para conectar la aplicación con la base de datos de Supabase, configure las siguientes variables en su entorno:

```env
SUPABASE_HOST="aws-0-us-west-2.pooler.supabase.com"
SUPABASE_PORT=5432
SUPABASE_DB="postgres"
SUPABASE_USER="postgres.<project-ref>"
SUPABASE_PASSWORD="<database-password>"
iucn_key="<iucn-api-key>"
```

### Ejecutar Localmente
```r
shiny::runApp(".", launch.browser = TRUE)
```

---
*Municipalidad Provincial de Anta · Cusco, Perú — Actualización 2026*
