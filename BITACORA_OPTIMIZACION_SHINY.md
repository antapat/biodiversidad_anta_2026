# Bitácora de optimización y corrección de la aplicación Shiny

Fecha de ejecución: 29 de agosto de 2026  
Proyecto: Sistema de Información y Monitoreo de Biodiversidad Territorial de Anta

## 1. Objetivo y línea base

Se revisó la aplicación completa después de homologar las fuentes GBIF e iNaturalist. La línea base funcional contenía 67,797 ocurrencias analíticas, 1,494 especies, 2,712 combinaciones especie-distrito y 2,235 filas de eBird. La aplicación funcionaba, pero los módulos de delimitación y eBird transferían más información al navegador de la necesaria.

| Operación de referencia | Tiempo aproximado antes del cambio |
|---|---:|
| Inicio de sesión y resumen | 3.37 s |
| Explorador distrital | 1.31 s |
| Mapa de delimitación | 4.33 s |
| Módulo eBird completo | 10.56 s |
| Visor territorial | 0.60 s |

Los tiempos dependen del equipo, caché y número de sesiones; se conservan como referencia, no como prueba de carga.

## 2. Secuencia de cambios implementados

### Cambio 1. Separación entre datos analíticos y datos de visualización

**Problema:** el mapa enviaba las 67,797 geometrías completas al navegador; el GeoJSON pesaba aproximadamente 19.56 MB por sesión.

**Corrección:** `scripts/preparar_datos_shiny.R` agrupa posiciones a cinco decimales (~1 m), conserva los totales de registros y especies por ubicación y genera `ocurrencias_mapa_sf.rds`. La capa completa se mantiene para las intersecciones del servidor.

**Resultado:** 3,544 ubicaciones, 0.86 MB de GeoJSON y conservación exacta de las 67,797 ocurrencias mediante `sum(n_registros)`. Reducción geométrica: 95.6%.

### Cambio 2. Consulta espacial sin doble ejecución

**Problema:** dibujar una geometría disparaba la intersección y el botón **Consultar** ejecutaba de nuevo el mismo cálculo.

**Corrección:** se eliminó el disparador automático de `drawn_features`. La consulta se ejecuta una sola vez mediante el botón, evitando cálculos involuntarios mientras se edita la geometría.

### Cambio 3. Tabla provincial eBird agregada

**Problema:** “Todos los hotspots” entregaba 2,235 filas repetidas por combinación especie-hotspot.

**Corrección:** la vista provincial agrupa una fila por especie, suma observaciones e informa el número de hotspots. Un hotspot específico conserva el detalle original.

**Resultado:** 457 filas en la tabla provincial. Las descargas CSV mantienen el detalle filtrado.

### Cambio 4. Eliminación de la copia client-side redundante

**Problema:** `jsplyr` copiaba 2,712 filas especie-distrito al navegador, aunque los filtros reales se resolvían en el servidor.

**Corrección:** se retiraron la dependencia, `include_jsplyr()`, `copy_to()`, sus referencias visuales y el JSON auxiliar. Se eliminó `www/especies_anta.json` (1.38 MB) y se regeneró `manifest.json`.

### Cambio 5. Reutilización del caché compartido

**Problema:** el visor releía `resumen_distritos.csv` una vez por sesión.

**Corrección:** el módulo recibe el resumen ya cargado en `app_data`, el caché global e inmutable creado al iniciar el proceso Shiny.

### Cambio 6. Indicadores calculados desde los datos vigentes

Se reemplazaron valores fijos por salidas dinámicas:

- 88 celdas → 130 celdas, calculadas en resumen, metodología y tooltips.
- Mollepata 705 / Limatambo 434 → 1,011 / 579 especies.
- singularidad fija → distritos con mayor `mean_turnover`; actualmente Mollepata 87.1% y Pucyura 86.5%.
- inventario fijo → 2,712 registros especie-distrito.
- período “2018–2026” → “desde 2020”, consistente con el filtro analítico.

### Cambio 7. Robustez de codificación en Windows

Se mantuvo la normalización UTF-8 en los scripts de inicio y prueba, y se añadió un intento defensivo en `app.R`. En Windows debe preferirse `iniciar_app.ps1`, que configura la codificación antes de que Shiny analice la aplicación.

La validación final también detectó que el lanzador, al estar en la raíz, calculaba como proyecto su carpeta padre (`D:\`). Se corrigió para usar directamente `$PSScriptRoot` (`D:\biodiversidad_2026`) y para establecer UTF-8 dentro de R antes de llamar a `runApp()`.

### Cambio 8. Error detectado durante la validación

La primera versión de los hallazgos dinámicos pasó dos valores a `fmt_num()`/`fmt_pct()`, funciones escalares, y mostró `'length = 2' in coercion to 'logical(1)'`. Se corrigió aplicando cada formateador individualmente con `vapply()`.

La comprobación posterior mostró correctamente:

- Mollepata (1,011 esp.) y Limatambo (579 esp.).
- Mollepata (87.1%) y Pucyura (86.5%).

## 3. Archivos modificados

- `app.R`: retiro de jsplyr, nueva capa de mapa, parámetros de módulos y control de codificación.
- `R/utils_data.R`: carga y caché de la capa cartográfica agregada.
- `scripts/preparar_datos_shiny.R`: generación de la capa de visualización.
- `R/mod_delimitacion_poligono.R`: capa ligera y ejecución explícita única.
- `R/mod_ebird_aves.R`: tabla agregada provincial.
- `R/mod_explorador_distrital.R`: retiro de copia client-side y período corregido.
- `R/mod_mapa_cobertura.R`: caché y hallazgos dinámicos.
- `R/mod_resumen_ejecutivo.R`: total de celdas dinámico.
- `R/mod_metodologia_descarga.R`: totales dinámicos.
- `scripts/enriquecer_especies_iucn.R`: retiro del JSON sin consumidor.
- `DESCRIPTION`, `manifest.json`, `www/custom.css` y `scripts/test_app.R`: limpieza de dependencia y despliegue.

## 4. Validaciones ejecutadas

1. Pipeline completo `scripts/ejecutar_analisis.ps1`: finalizó correctamente.
2. `scripts/test_app.R`: todos los módulos, datos y caché cargaron correctamente.
3. `scripts/test_draw_intersection.R`: recuperó 10,019 ocurrencias y 224 especies en el polígono de prueba.
4. Integridad de la capa agregada: `sum(n_registros) = 67,797`.
5. Prueba en navegador de las siete pestañas, tablas, mapas e indicadores: sin errores ni advertencias en la consola.
6. Vista provincial eBird verificada como “1–10 of 457 rows”.
7. Manifiesto regenerado con 109 dependencias; `mapgl` incluido y `jsplyr` excluido.

## 5. Mensajes conocidos no bloqueantes

- UICN informa `Multiple fuzzy genus matches detected`; el proceso completa, pero las coincidencias ambiguas requieren auditoría taxonómica separada.
- `sf` informa que algunas operaciones en longitud/latitud se tratan como planas al desactivar S2. Las superficies se calculan en UTM 18S y los mensajes no impidieron las pruebas.
- R puede advertir sobre la configuración regional si se ejecuta directamente desde una consola Windows mal configurada. `iniciar_app.ps1` es la ruta soportada.

## 6. Incidente corregido: informe de delimitación territorial

Fecha de corrección: 29 de agosto de 2026.

**Síntoma:** el polígono quedaba visible en el mapa, pero el panel permanecía en “Esperando dibujo” y no calculaba superficie, especies ni observaciones.

**Causa:** después de retirar la ejecución automática para evitar intersecciones duplicadas, el botón intentaba leer directamente `input$mapa_ocurrencias_drawn_features`. La colección dibujada no siempre estaba sincronizada con Shiny en ese momento, aunque MapLibre sí mostraba la geometría.

**Corrección funcional:** el botón ahora solicita explícitamente al widget su estado actual, recupera `draw.getAll()` y lo envía a Shiny como un evento prioritario. Una bandera `consulta_pendiente` garantiza que la intersección se procese exactamente una vez.

**Corrección visual:** el flujo se presenta como dos pasos. La guía azul identifica **PASO 1: dibujar y cerrar el área**; el botón naranja de alto contraste identifica **PASO 2: consultar especies y generar informe**.

**Ajuste de consistencia visual:** los controles se ordenaron como **Paso 1 → Paso 2 → Limpiar**. La guía usa verde menta y la acción principal verde institucional (`#0f5132`), eliminando el naranja para mantener la paleta general de la plataforma. En pantallas pequeñas los controles pasan a una disposición vertical.

**Pruebas:** se añadió `scripts/test_mod_delimitacion.R`. La prueba automatizada generó 313.97 ha y 2 especies. La validación con un polígono real en el navegador produjo un informe de 268.63 km², 445 especies, 8 especies amenazadas y 10,153 observaciones, sin errores de consola.

## 7. Secuencia para futuras actualizaciones

1. Ejecutar `scripts/ejecutar_analisis.ps1`.
2. Ejecutar `scripts/test_app.R`.
3. Ejecutar `scripts/test_draw_intersection.R`.
4. Ejecutar `scripts/test_mod_delimitacion.R`.
5. Verificar que la suma `n_registros` de `ocurrencias_mapa_sf.rds` coincida con las filas de `ocurrencias_puntos_sf.rds`.
6. Abrir con `iniciar_app.ps1` y revisar las siete pestañas.
7. Regenerar `manifest.json` antes del despliegue si cambian dependencias o archivos publicados.
