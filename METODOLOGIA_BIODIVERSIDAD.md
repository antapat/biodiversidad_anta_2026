# Análisis de biodiversidad de Anta

> La secuencia de optimizaciones, errores corregidos y pruebas de la aplicación Shiny se conserva en [BITACORA_OPTIMIZACION_SHINY.md](BITACORA_OPTIMIZACION_SHINY.md).

El producto principal es `outputs/analisis_biodiversidad/index.html`. Se genera con `scripts/02_analisis_biodiversidad_mapgl.R` y utiliza **mapgl 0.5.0** con MapLibre, sin token.

## Alcance analítico

- Fuente canónica: `data/spatial/ocurrencias_homologadas.gpkg`, generada desde la descarga original mediante `scripts/homologar_datos_biodiversidad.R`.
- Homologación: los nombres directos de iNaturalist se contrastan con el backbone taxonómico de GBIF; se conservan el nombre enviado, el nombre aceptado, la confianza y el tipo de coincidencia.
- Procedencia: `fuente_descarga` identifica el canal; `plataforma_origen` y `dataset_origen` identifican el origen biológico. Los registros de iNaturalist presentes por ambos canales se consolidan por ID de observación.
- Registros válidos: ocurrencias con rango `SPECIES` o `SUBSPECIES`, nombre de especie informado e incertidumbre conocida no mayor de 5 km. Los registros sin incertidumbre declarada se conservan identificados como tales.
- Asignación territorial: unión espacial de cada ocurrencia con los nueve distritos de Anta.
- Cobertura espacial: cuadrícula regular de 5 km en UTM 18S. Las celdas menores de 0.5 km² se excluyen para evitar fragmentos de borde.
- Vacíos: celdas sin registros. La cobertura “muy baja” corresponde a menos de 10 registros o 5 especies; la cobertura “baja”, a menos de 50 registros o 15 especies.
- Recambio: disimilitud de Jaccard sobre presencia/ausencia de especies por distrito: `1 - especies compartidas / especies combinadas`.
- Singularidad distrital: recambio medio frente a los demás distritos y número de especies registradas exclusivamente en cada distrito.

## Interpretación responsable

Los resultados representan la biodiversidad **registrada**, no la riqueza verdadera. Accesibilidad, esfuerzo, fecha, protocolo y sesgo de plataforma influyen en los patrones. Un vacío de registros es una prioridad de información, no evidencia de ausencia biológica. El recambio alto también puede estar inflado por inventarios incompletos.

## Reproducción

Desde PowerShell, ejecutar:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\ejecutar_analisis.ps1
```

Los CSV y GeoJSON derivados quedan en `outputs/analisis_biodiversidad/`.
