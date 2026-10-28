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

### Modo de pruebas local y conexión opcional a Neon

La aplicación usa **datos locales por defecto** (`BIODIVERSIDAD_DATA_MODE=local`). No necesita secretos ni acceso a Neon durante las pruebas, incluso si hay credenciales configuradas. Incluye siete tablas compactas en `app-data/` y las capas optimizadas en `www/spatial/`; ambos directorios se publican con el manifiesto de Connect Cloud. La delimitación de especies se resuelve en memoria con sf. Para regenerar las tablas tras actualizar los análisis, ejecuta `Rscript scripts/preparar_datos_locales.R` y después `Rscript scripts/generar_manifest.R`, y publica los cambios.

Para usar Neon cuando sus tablas estén cargadas, configura **`BIODIVERSIDAD_DATA_MODE=neon`** junto con las siguientes credenciales.
Copie la cadena de conexión **pooled** (host con `-pooler`) desde **Connect** en la rama Neon indicada. Guárdela solo en `.Renviron`, que está excluido de Git:

```env
NEON_DATABASE_URL="postgresql://<usuario>:<contraseña>@<host-pooler>/<base>?sslmode=require"
```

También se acepta la configuración por campos: `NEON_HOST`, `NEON_PORT`, `NEON_DB`, `NEON_USER` y `NEON_PASSWORD`. Neon tiene prioridad si se configura; Supabase se conserva como alternativa mediante `SUPABASE_HOST`, `SUPABASE_PORT`, `SUPABASE_DB`, `SUPABASE_USER` y `SUPABASE_PASSWORD`.

En modo `neon`, si faltan conexión, tablas o registros, la app detiene el inicio con un diagnóstico. El fallback de ese modo solo se habilita explícitamente con `BIODIVERSIDAD_ALLOW_LOCAL_FALLBACK=true`; es independiente del modo de pruebas `local`. Ejecuta la carga desde RStudio abriendo `scripts/actualizar_neon.R` y pulsando **Source**, o usa `Rscript scripts/migrar_a_supabase.R`. La carga actualiza las tablas tabulares reiniciando sus identidades y reemplaza las capas espaciales desde los archivos locales. El esquema base no elimina otras tablas.

El archivo `.Renviron` está excluido de Git. Para que la versión publicada consuma Neon, configura `BIODIVERSIDAD_DATA_MODE=neon` y `NEON_DATABASE_URL` como variable secreta, y vuelve a desplegar. Las publicaciones incluyen `app-data/` para las pruebas locales; no incluyen `outputs/` ni credenciales. El rol de conexión debe tener permiso para `CREATE EXTENSION postgis` durante la carga inicial.

Para automatizar la actualización, cree una tarea en el Programador de tareas de Windows que ejecute PowerShell con `-NoProfile -ExecutionPolicy Bypass -File "D:\\biodiversidad_anta_2026\\scripts\\actualizar_neon.ps1"`. Configure el disparador según la frecuencia con que se regeneren los archivos de `outputs/analisis_biodiversidad`; la carga no descarga fuentes nuevas, solo publica esos archivos locales.

### Ejecutar Localmente
```r
shiny::runApp(".", launch.browser = TRUE)
```

### Publicar en un VPS con Docker

El despliegue de producción usa Caddy como proxy inverso: recibe tráfico en HTTP/HTTPS, obtiene y renueva el certificado TLS automáticamente y reenvía las solicitudes al contenedor Shiny. El puerto 3838 solo queda disponible dentro de la red Docker.

#### Requisitos

- Un VPS Linux con una IP pública fija y Docker Engine con el complemento Docker Compose.
- Un dominio o subdominio bajo control de la municipalidad.
- Reglas de firewall del VPS y del proveedor que permitan entrada TCP 80 y 443. No es necesario publicar 3838.
- El DNS `A` del dominio apuntando a la IP del VPS (y `AAAA` solo si el VPS tiene IPv6 funcional). Espera la propagación DNS antes de iniciar Caddy.
- La URL pooled de Neon y una imagen publicada en Docker Hub.

#### Preparar la publicación de imagen

El workflow `.github/workflows/docker-publish.yml` inicia sesión en Docker Hub como `patanta` y publica `patanta/biodiversidad_anta_2026`. En GitHub, configura el secret `DOCKERHUB_TOKEN` con un access token que pueda escribir en ese repositorio. Ejecuta el workflow manualmente desde **Actions → Build and publish Docker image → Run workflow**, o publica un cambio a `main` en las rutas configuradas.

#### Configurar el VPS

Conéctate por SSH y ejecuta estos pasos en el VPS (Ubuntu/Debian):

1. Instala Docker Engine y el complemento Compose siguiendo la guía oficial de Docker para la distribución del VPS.
2. Crea una carpeta de despliegue, por ejemplo `/opt/biodiversidad-anta`, y copia allí `docker-compose.prod.yml` y `Caddyfile` desde este repositorio. Puedes usar `git clone` si Git está instalado.
3. En esa carpeta, crea `.env` a partir de `.env.example`. Configura `APP_DOMAIN` con el dominio real y `NEON_DATABASE_URL` con la conexión pooled de Neon. Protege el archivo: `chmod 600 .env`.
4. Inicia la aplicación:

```bash
docker compose -f docker-compose.prod.yml pull
docker compose -f docker-compose.prod.yml up -d
docker compose -f docker-compose.prod.yml ps
```

5. Consulta los registros si el sitio no carga:

```bash
docker compose -f docker-compose.prod.yml logs -f biodiversidad-anta
docker compose -f docker-compose.prod.yml logs -f proxy
```

Cuando GitHub Actions publique una imagen nueva, actualiza el VPS con `docker compose -f docker-compose.prod.yml pull` y `docker compose -f docker-compose.prod.yml up -d`. Caddy conserva los certificados en volúmenes Docker y renueva HTTPS automáticamente.

El contenedor incluye los datos de pruebas locales. Si activas el modo `neon`, necesita las tablas requeridas cargadas en Neon. Mantén privado `.env` y limita el acceso SSH al VPS.

---
*Municipalidad Provincial de Anta · Cusco, Perú — Actualización 2026*

El lanzador guarda un registro de cada ejecución en `logs/` y devuelve error al Programador de tareas si la carga falla.

## Patrimonio natural y capas ligeras

La pestaña **Patrimonio Natural** presenta los 45 sitios del inventario paisajístico, con filtros por distrito, tipo y búsqueda por nombre/subtipo. La referencia institucional es el Plan de Acondicionamiento Territorial de la Provincia de Anta 2025–2045, en cuyo marco se consolidó la información del patrimonio natural y la biodiversidad provincial. Incluye mapa, atributos y descarga de la selección en CSV o GeoJSON. El campo de verificación de ubicación se excluye del módulo y sus descargas. Las fichas emergentes tienen fondo verde oscuro, texto blanco y borde ámbar, y pueden abrirse al pulsar los puntos.

Las capas cartográficas se distribuyen como instantáneas versionadas en `www/spatial/*.geojson.gz`, leídas una vez por proceso. Tienen CRS WGS84, seis decimales y simplificación de líneas/polígonos de 10 metros en UTM 18S. Los puntos mantienen sus posiciones con redondeo submétrico; los atributos se conservan. Los originales de `data/spatial` y `outputs` no se sobrescriben. La geometría simplificada es para visualización; los análisis de precisión deben utilizar los originales.

Para regenerar **todas** las capas SHP, GPKG y KMZ de `data/spatial`, y las cinco capas utilizadas por el visor desde `outputs/analisis_biodiversidad`, ejecutar desde la raíz:

```powershell
Rscript scripts/optimizar_capas.R
Rscript scripts/test_patrimonio.R
```

`www/spatial/inventario.csv` registra origen, elementos, tamaños antes/después y parámetros. Se elige GeoJSON gzip por compatibilidad directa con sf/MapLibre y para evitar un decodificador GeoParquet en el navegador. Las capas adicionales quedan disponibles como archivos comprimidos; el visor utiliza las cinco capas `geo_*` y `patrimonio_natural`.

**Actualización espacial:** al cambiar los insumos, regenerar los archivos y volver a publicar la aplicación. Durante las pruebas, las tablas se leen desde `app-data/` y las capas desde `www/spatial/`. En modo `neon`, las tablas se consultan en la base de datos y las capas usan las instantáneas incluidas, recurriendo a PostGIS si falta una capa. Actualizar Neon por sí solo no actualiza estas instantáneas. Docker, shinyapps.io y el manifiesto de Connect Cloud incluyen ambos directorios locales.

La primera conversión comprende 12 capas (323,7 MB de insumos frente a aproximadamente 13,9 MB comprimidos). El inventario de patrimonio ocupa unos 2,9 KB. La comparación incluye formatos originales diferentes: el GeoJSON gzip de ocurrencias completas resulta mayor que su RDS binario comprimido; este RDS se conserva. Para mostrar ocurrencias se mantiene la capa agregada `geo_ocurrencias_mapa`, de unos 61 KB.
