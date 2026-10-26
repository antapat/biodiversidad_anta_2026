# Sistema de Información de Biodiversidad de la Provincia de Anta (2026)
### Municipalidad Provincial de Anta — Gerencia de Desarrollo Urbano y Rural (GDUR)

Plataforma territorial interactiva para la gestión, análisis, monitoreo y toma de decisiones sobre la biodiversidad de flora y fauna en los 9 distritos de la Provincia de Anta, Cusco, Perú.

---

## 🏛️ Arquitectura del Sistema

- **Frontend & Visualización:** R Shiny, bslib (Bootstrap 5), MapLibre GL (`mapgl`), `reactable`, `plotly`.
- **Backend & Almacén de Datos:** [Neon](https://neon.tech) (PostgreSQL + PostGIS espacial).
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
│   ├── utils_supabase.R              # Conector PostgreSQL para Neon (Supabase como alternativa)
│   └── utils_data.R                  # Carga y estructuración de datos
├── scripts/                          # Scripts de mantenimiento, DDL y migración
├── www/                              # Estilos CSS y recursos institucionales
├── DESCRIPTION                       # Metadatos del paquete y dependencias de R
└── README.md                         # Documentación institucional
```

---

## 🚀 Despliegue y Ejecución

### Variables de Entorno Requeridas (`.Renviron`)
Copie la cadena de conexión **pooled** (host con `-pooler`) desde **Connect** en la rama Neon indicada. Guárdela solo en `.Renviron`, que está excluido de Git:

```env
NEON_DATABASE_URL="postgresql://<usuario>:<contraseña>@<host-pooler>/<base>?sslmode=require"
```

También se acepta la configuración por campos: `NEON_HOST`, `NEON_PORT`, `NEON_DB`, `NEON_USER` y `NEON_PASSWORD`. Neon tiene prioridad si se configura; Supabase se conserva como alternativa mediante `SUPABASE_HOST`, `SUPABASE_PORT`, `SUPABASE_DB`, `SUPABASE_USER` y `SUPABASE_PASSWORD`.

La app lee de Neon y, si faltan conexión, tablas o registros, detiene el inicio con un diagnóstico en lugar de presentar archivos locales como datos remotos. El fallback local solo se habilita explícitamente con `BIODIVERSIDAD_ALLOW_LOCAL_FALLBACK=true` para desarrollo. Ejecuta la carga desde RStudio abriendo `scripts/actualizar_neon.R` y pulsando **Source**, o usa `Rscript scripts/migrar_a_supabase.R`. La carga actualiza las tablas tabulares reiniciando sus identidades y reemplaza las capas espaciales desde los archivos locales. El esquema base no elimina otras tablas.

El archivo `.Renviron` está configurado localmente y excluido de Git. Para que la versión de shinyapps.io consuma Neon, configura `NEON_DATABASE_URL` como variable de entorno secreta en la configuración de esa aplicación en shinyapps.io y luego vuelve a desplegar. El script de despliegue ya no incluye archivos `outputs/`; producción requiere que Neon contenga las 12 tablas/capas. El rol de conexión debe tener permiso para `CREATE EXTENSION postgis` durante la carga inicial.

Para automatizar la actualización, cree una tarea en el Programador de tareas de Windows que ejecute PowerShell con `-NoProfile -ExecutionPolicy Bypass -File "D:\\biodiversidad_anta_2026\\scripts\\actualizar_neon.ps1"`. Configure el disparador según la frecuencia con que se regeneren los archivos de `outputs/analisis_biodiversidad`; la carga no descarga fuentes nuevas, solo publica esos archivos locales.

### Ejecutar Localmente
```r
shiny::runApp(".", launch.browser = TRUE)
```

### Ejecutar con Docker

Docker permite alojar la app en un servidor propio o VPS que mantenga el contenedor activo. No depende de los límites de sesión de shinyapps.io, aunque la disponibilidad depende del servidor y del plan de Neon.

1. Instala Docker Engine y Docker Compose en el servidor.
2. Copia `.env.example` a `.env` y configura `NEON_DATABASE_URL` con la conexión pooled de Neon. No subas `.env` a Git.
3. Después de publicar la imagen en Docker Hub, desde la carpeta con `docker-compose.prod.yml` y `.env` ejecuta `docker compose -f docker-compose.prod.yml pull` y luego `docker compose -f docker-compose.prod.yml up -d`.
4. Abre `http://<servidor>:3838`. Revisa el estado con `docker compose -f docker-compose.prod.yml ps` y los registros con `docker compose -f docker-compose.prod.yml logs -f biodiversidad-anta`.

El contenedor instala R y las dependencias de la app durante la construcción; solo copia `app.R`, `R/` y `www/`. No incluye los datos locales: necesita que las tablas y capas estén cargadas en Neon. Para producción pública, coloca un proxy inverso con HTTPS delante del puerto 3838 y restringe el acceso al archivo `.env`.

#### Publicar en Docker Hub

El workflow `.github/workflows/docker-publish.yml` construye y publica `patanta/biodiversidad-anta:latest` y una etiqueta por commit al hacer push a `main`, o al ejecutarlo manualmente desde **GitHub → Actions → Build and publish Docker image → Run workflow**. En Docker Hub crea el repositorio `patanta/biodiversidad-anta` (público si el servidor descargará sin autenticación). En el repositorio GitHub configura los secrets `DOCKERHUB_USERNAME` (usuario `patanta`) y `DOCKERHUB_TOKEN` (access token de Docker Hub con permiso de escritura). Al terminar el workflow, el servidor descarga y arranca la imagen con `docker compose -f docker-compose.prod.yml pull` y `docker compose -f docker-compose.prod.yml up -d`.

---
*Municipalidad Provincial de Anta · Cusco, Perú — Actualización 2026*

El lanzador guarda un registro de cada ejecución en `logs/` y devuelve error al Programador de tareas si la carga falla.
