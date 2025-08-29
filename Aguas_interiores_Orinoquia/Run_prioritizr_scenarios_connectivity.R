# ..............................................................................
# SCRIPT: Run-prioritizr-scenarios_connectivity.R
# PROYECTO: Prioridades de conservación aguas interiores - Cuenca del Orinoco
# ..............................................................................

# DESCRIPCIÓN:
# 1. Utiliza valores de conectividad como costos principales (no como penalización)
# 2. Aplica penalizaciones lineales basadas en integridad ecológica
# 3. Targets (10-60%) y penalidades (0-100)

# CARACTERÍSTICAS TÉCNICAS:
# - Procesamiento paralelo con future y furrr (6 workers)
# - Costos basados en índice de conectividad (reclasificado)
# - Penalizaciones lineales por integridad ecológica
# - Sistema de logging robusto con registro de errores
# - Cuatro escenarios con diferentes combinaciones de características

# AUTOR: [Pioridades de conservación]
# FECHA: [29/08/2025]

# COMENTARIOS:
# LOS COMENTARIOS CON "(USUARIO)" INDICAN LAS FUNCIONES DONDE EL USUARIO DEBE AJUSTAR
# ..............................................................................

# 1. CONFIGURACIÓN INICIAL Y DEPENDENCIAS --------------------------------------

# Verificar e instalar paquete pacman si es necesario
if (!require("pacman")) install.packages("pacman")

# Cargar/correr todos los paquetes necesarios
pacman::p_load(
  # Análisis espacial
  terra, sf, raster, fasterize,
  # Priorización
  prioritizr, prioritizrdata, rcbc,
  # Manipulación de datos
  dplyr, tidyr, stringr,
  # Visualización
  ggplot2, ggspatial, viridis,
  # Exportación
  openxlsx,
  # Procesamiento paralelo
  furrr, future,
  # Utilidades
  crayon, progress
)

# 2. CONFIGURACIÓN DEL ENTORNO -------------------------------------------------

# Configurar procesamiento paralelo (USUARIO)
plan(multisession, workers = 6) 

# Desactivar cálculos S2 para sf (mejor rendimiento con datos proyectados)
sf_use_s2(FALSE)

# Desactivar notación científica
options(scipen = 999)

# Registrar tiempo de inicio global
global_start_time <- Sys.time()

# Establecer directorio de trabajo (USUARIO)
setwd('C:/PrioritizR_Run_Orinoquia')

# Directorio base para resultados de conectividad (USUARIO)
output.base.dir <- "Resultados_CON"

# 3. CARGA Y PREPARACIÓN DE DATOS ----------------------------------------------

# 3.1. Área de estudio - Microcuencas
ae <- st_read('Area_estudio/Microcuencas.shp')

# 3.2. Características de biodiversidad
# 3.2.1. Especies (archivos de Biomodelos)
spp.list <- list.files('Caracteristicas/Especies/biomodelos', full.names = TRUE)
features.list <- lapply(spp.list, function(f) {
  r <- raster(f)
  names(r) <- basename(f)  # Mantener nombre original como identificador
  return(r)
})

# 3.2.2. Ecosistemas
eco.list <- list.files('Caracteristicas/Ecosistemas/Estandarizados', full.names = TRUE)
eco.rasters <- lapply(eco.list, function(f) {
  r <- raster(f)
  names(r) <- basename(f)
  return(r)
})
features.list <- c(features.list, eco.rasters)

# Crear primer stack de características (solo especies y ecosistemas)
raster_stack_v1 <- stack(features.list)
crs(raster_stack_v1) <- "EPSG:9377"  # Establecer CRS apropiado

# 3.2.3. Características culturales
cul.list <- list.files('Caracteristicas/Cultura/Estandarizados', full.names = TRUE)
cul.rasters <- lapply(cul.list, function(f) {
  r <- raster(f)
  names(r) <- basename(f)
  return(r)
})
features.list <- c(features.list, cul.rasters)

# Crear segundo stack de características (todas las características)
raster_stack_v2 <- stack(features.list)
crs(raster_stack_v2) <- "EPSG:9377"

# 3.3. Áreas de inclusión forzada (locked-in)
locked.in1 <- raster("Restricciones/Inclusion/RUNAP_1000_stdr.tif")
crs(locked.in1) <- "EPSG:9377"

# 3.4. Costos de conservación 
# 3.4.1. Costos por integridad ecológica (para penalizaciones lineales)
costo.int <- st_read('Costos/Integridad_total_cor.shp')

# Normalizar costos (0 = mayor costo, 100 = menor costo)
costo.int$Int_ttl.r <- 100 - ((costo.int[['Int_ttl']] - min(costo.int$Int_ttl, na.rm = TRUE)) /
                                (max(costo.int$Int_ttl, na.rm = TRUE) - min(costo.int$Int_ttl, na.rm = TRUE)) * 100)

# 3.4.2. Costos principales basados en conectividad
conectividad <- st_read("Conectividad/microcuencas_con_CI.shp")
conectividad <- st_transform(conectividad, crs = 9377)  # Asegurar CRS consistente

# Crear raster template para visualización
rast_templ <- raster(resolution = 1000, crs = 9377, ext = extent(ae))

# 3.5. Reclasificación de valores de conectividad para usar como costos
# Definir breaks basados en análisis de cuartiles o percentiles
breaks <- c(0, 0.00062, 0.000809, 0.001105, 0.001821, Inf)
labels <- rev(c(10, 8, 6, 4, 2))  # Valores más altos = mayor conectividad = menor costo

# Reclasificar valores de conectividad (CI) para usar como costos
# Valores más altos de CI indican mayor conectividad, por lo que se asignan costos menores
conectividad$reclassified <- cut(conectividad$CI,
                                 breaks = breaks,
                                 labels = labels,
                                 include.lowest = TRUE,
                                 right = FALSE)
conectividad$reclassified <- as.numeric(as.character(conectividad$reclassified))

# Visualización de reclasificación (descomentar para ver)
# plot(conectividad['reclassified'])

# 3.6. Preparar datos para penalizaciones lineales
# Incorporar información de integridad para usar en penalizaciones
conectividad$Int_ttl.r <- costo.int$Int_ttl.r

# 3.7. Plantilla de microcuencas con información de área
plantilla.micro <- ae
plantilla.micro$area_km2 <- as.numeric(st_area(ae) / 10^6)  # Área en km²
total_area_km2 <- sum(plantilla.micro$area_km2)  # Área total de reference

# PRUEBA DE CONCEPTOS (TESTER) -------------------------------------------------

# Bloque de prueba para verificar configuración antes de ejecución completa
if (FALSE) {
  tester_start_time <- Sys.time()
  
  # Construir problema de prueba
  p1 <- problem(conectividad, rast(raster_stack_v2), 
                cost_column = "reclassified") %>%
    add_min_set_objective() %>%
    add_relative_targets(0.3) %>%
    add_cbc_solver(verbose = FALSE) %>%
    add_binary_decisions() %>%
    add_linear_penalties(penalty = 30, data = 'Int_ttl.r')
  
  # Resolver y medir tiempo
  s1 <- solve(p1)
  tester_end_time <- Sys.time()
  
  # Reportar tiempo de prueba
  cat("Tiempo de prueba:", tester_end_time - tester_start_time, "\n")
  
  # Visualizar solución de prueba
  plot(s1['solution_1'], main = "Solución de prueba - Costos por Conectividad")
}

# 4. PARÁMETROS DE EJECUCIÓN ---------------------------------------------------

# Definir parámetros para los escenarios (USUARIO)
targets <- seq(0.1, 0.6, 0.1)  # Targets del 10% al 60% 
penalties <- seq(0, 100, 20)   # rango de penalizaciones (0-100)
scenarios <- c("solucion1", "solucion2", "solucion3", "solucion4")  # Escenarios

# 5. PREPARACIÓN DE CARPETAS DE RESULTADOS -------------------------------------

# Crear directorio principal si no existe
if (!dir.exists(output.base.dir)) {
  dir.create(output.base.dir)
  cat(blue(paste0("Carpeta principal creada: ", output.base.dir, '\n')))
}

# Crear subdirectorios para cada escenario
for (folder in scenarios) {
  path <- file.path(output.base.dir, folder)
  if (!dir.exists(path)) {
    dir.create(path)
    cat(blue(paste0("Subcarpeta creada: ", path, '\n')))
  }
}

# 6. DEFINICIÓN DE FUNCIONES PRINCIPALES ---------------------------------------

# 6.1. Función de logging robusto
write_log <- function(log_path, escenario, start_time, end_time, summary_table, 
                      penalties, targets, error = NULL) {
  # Crear directorio para logs si no existe
  dir.create(dirname(log_path), recursive = TRUE, showWarnings = FALSE)
  
  # Calcular tiempo total de ejecución
  tiempo_total <- round(difftime(end_time, start_time, units = "mins"), 2)
  
  # Iniciar captura de output
  sink(log_path)
  
  # Encabezado del log
  cat("=============================================\n")
  cat(" PRIORIZACIÓN - LOG EJECUCIÓN (COSTOS CONECTIVIDAD)\n")
  cat("=============================================\n")
  cat("Escenario:", escenario, "\n")
  cat("Inicio:", format(start_time), "\n")
  cat("Fin:", format(end_time), "\n")
  cat("Duración (minutos):", tiempo_total, "\n\n")
  
  # Parámetros de ejecución
  cat("Parámetros:\n")
  cat("Penalties:", paste(penalties, collapse = ", "), "\n")
  cat("Targets:", paste(targets, collapse = ", "), "\n")
  cat("Total soluciones:", ifelse(is.null(summary_table), 0, nrow(summary_table)), "\n\n")
  
  # Resumen de áreas priorizadas
  if (!is.null(summary_table) && nrow(summary_table) > 0) {
    cat("Resumen de área priorizada (km2):\n")
    print(summary_table %>% summarise(
      min_area = as.numeric(min(Area_priorizada_km2)),
      max_area = as.numeric(max(Area_priorizada_km2)),
      mean_area = as.numeric(mean(Area_priorizada_km2))
    ))
  }
  
  # Información de error si existe
  if (!is.null(error)) {
    cat("\n*** ERROR DETECTADO ***\n")
    cat(as.character(error), "\n")
  }
  
  cat("=============================================\n")
  
  # Finalizar captura
  sink()
}

# 6.2. Función de optimización por escenario
run_scenario <- function(escenario, p, t) {
  # Determinar configuración según escenario
  if (escenario == 'solucion1') {
    raster_stack <- raster_stack_v1  # Solo especies y ecosistemas
    inclusion <- NULL               # Sin inclusiones forzadas
  } else if (escenario == 'solucion2') {
    raster_stack <- raster_stack_v2  # Todas las características
    inclusion <- NULL               # Sin inclusiones forzadas
  } else if (escenario == 'solucion3') {
    raster_stack <- raster_stack_v1  # Solo especies y ecosistemas
    inclusion <- 1                  # Con inclusiones forzadas
  } else if (escenario == 'solucion4') {
    raster_stack <- raster_stack_v2  # Todas las características
    inclusion <- 1                  # Con inclusiones forzadas
  }
  
  # Construir problema de optimización con costos de conectividad
  p1 <- problem(conectividad, rast(raster_stack), cost_column = "reclassified") %>%
    add_min_set_objective() %>%
    add_relative_targets(t) %>%
    add_cbc_solver(verbose = FALSE) %>%
    add_binary_decisions() %>%
    add_linear_penalties(penalty = p, data = 'Int_ttl.r')  # Penalización por integridad
  
  # Agregar constraint de inclusiones si corresponde
  if (!is.null(inclusion)) {
    p1 <- p1 %>% add_locked_in_constraints(rast(locked.in1))
  }
  
  # Resolver problema
  s1 <- solve(p1)
  
  # Evaluar cumplimiento de targets
  target_coverage <- eval_target_coverage_summary(p1, s1[,"solution_1"])
  
  # Calcular métricas de la solución
  plantilla.micro$temp_solution <- s1$solution_1
  seleccionadas <- plantilla.micro %>% filter(temp_solution == 1)
  num_microcuencas <- nrow(seleccionadas)
  area_priorizada <- sum(st_area(seleccionadas)) / 10^6  
  representatividad <- (area_priorizada / total_area_km2) * 100
  
  # Devolver resultados
  list(
    scenario = escenario,
    name = paste0("Penalty_", p, "_Target", t),
    penalty = p, 
    target = t,
    num_microcuencas = num_microcuencas,
    area_km2 = area_priorizada,
    representatividad = representatividad,
    coverage = target_coverage,
    solution = s1$solution_1
  )
}

# 7. EJECUCIÓN PRINCIPAL POR ESCENARIOS ----------------------------------------

# Iterar sobre cada escenario definido
for (escenario in scenarios) {
  
  cat(blue(paste0("\nIniciando ejecución de: ", escenario, " ...\n")))
  
  # Crear grid de parámetros para este escenario
  param_grid <- expand.grid(penalty = penalties, target = targets, 
                            stringsAsFactors = FALSE)
  
  # Registrar tiempo de inicio del escenario
  escenario_start_time <- Sys.time()
  
  # Variables para captura de resultados y errores
  error_catch <- NULL
  resultados <- NULL
  summary_table <- NULL
  
  # Ejecutar optimizaciones en paralelo con manejo de errores
  tryCatch({
    resultados <- future_pmap(
      list(param_grid$penalty, param_grid$target),
      function(p, t) run_scenario(escenario, p, t),
      .progress = TRUE  # Mostrar barra de progreso
    )
    
    # Crear tabla resumen de resultados
    summary_table <- bind_rows(lapply(resultados, function(res) {
      data.frame(
        Escenario = res$scenario,
        Solucion = res$name, 
        Penalty = res$penalty, 
        Target = res$target,
        Microcuencas = res$num_microcuencas, 
        Area_priorizada_km2 = res$area_km2,
        Representatividad_porcentaje = res$representatividad
      )
    }))
    
    # Preparar plantilla con todas las soluciones
    plantilla.micro.temp <- plantilla.micro
    for (res in resultados) {
      plantilla.micro.temp[[res$name]] <- res$solution
    }
    
    # Exportar resultados espaciales
    st_write(plantilla.micro.temp, 
             file.path(output.base.dir, escenario, 
                       paste0("Orinoquia_", escenario, ".shp")), 
             delete_dsn = TRUE)
    
    # Exportar cobertura de targets por solución
    wb <- createWorkbook()
    for (i in seq_along(resultados)) {
      addWorksheet(wb, sheetName = resultados[[i]]$name)
      writeData(wb, sheet = resultados[[i]]$name, 
                x = resultados[[i]]$coverage, 
                rowNames = FALSE)
    }
    saveWorkbook(wb, 
                 file = file.path(output.base.dir, escenario, 
                                  paste0("Orinoquia_", escenario, "_coverage.xlsx")), 
                 overwrite = TRUE)
    
    # Exportar tabla resumen y datos completos
    write.xlsx(summary_table, 
               file = file.path(output.base.dir, escenario, 
                                paste0("Orinoquia_", escenario, "_resumen.xlsx")))
    
    save(resultados, summary_table, 
         file = file.path(output.base.dir, escenario, 
                          paste0("Orinoquia_", escenario, ".RData")))
    
  }, error = function(e) {
    error_catch <<- e
  })
  
  # Registrar tiempo de finalización
  escenario_end_time <- Sys.time()
  
  # Generar log del escenario
  log_file <- file.path(output.base.dir, escenario, 
                        paste0("Orinoquia_", escenario, "_log.txt"))
  write_log(log_file, escenario, escenario_start_time, escenario_end_time, 
            summary_table, penalties, targets, error_catch)
  
  # Reportar estado de finalización
  if (is.null(error_catch)) {
    cat(green(paste0("Finalizado correctamente: ", escenario, "\n")))
  } else {
    cat(red(paste0("Error en ", escenario, ": ", error_catch$message, "\n")))
  }
}

# 8. FINALIZACIÓN --------------------------------------------------------------

# Registrar tiempo final y mostrar resumen
global_end_time <- Sys.time()
tiempo_total_global <- round(difftime(global_end_time, global_start_time, units = "hours"), 2)

cat(blue(paste0("\n=============================================\n")))
cat(blue(paste0("EJECUCIÓN COMPLETADA - COSTOS POR CONECTIVIDAD\n")))
cat(blue(paste0("Tiempo total: ", tiempo_total_global, " horas\n")))
cat(blue(paste0("Escenarios ejecutados: ", length(scenarios), "\n")))
cat(blue(paste0("Soluciones generadas: ", length(scenarios) * length(penalties) * length(targets), "\n")))
cat(blue(paste0("Resultados en: ", output.base.dir, "\n")))
cat(blue(paste0("=============================================\n")))
