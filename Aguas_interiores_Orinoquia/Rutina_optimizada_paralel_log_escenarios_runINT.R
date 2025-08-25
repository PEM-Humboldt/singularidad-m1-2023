# ..............................................................................
# PRIORIZACION ESPACIAL CON PRIORITIZR + LOGGING ROBUSTO
# ..............................................................................

# 1. DEPENDENCIAS ------------------------------------------------------------
if (!require("pacman")) install.packages("pacman")
pacman::p_load(
  terra, sf, prioritizr, prioritizrdata, ggplot2,
  ggspatial, viridis, dplyr, tidyr, raster, fasterize,
  stringr, openxlsx, crayon, furrr, future, rcbc, progress
)

# 2. CONFIGURACIÓN -----------------------------------------------------------
plan(multisession, workers = 8)
sf_use_s2(FALSE)
options(scipen=999)
global_start_time <- Sys.time()

setwd('C:/PrioritizR_Run_Orinoquia')
output.base.dir <- "Resultados_INT"

# 3. INSUMOS -----------------------------------------------------------------

# Área de estudio
ae <- st_read('Area_estudio/Microcuencas.shp')

# Especies
spp.list <- list.files('Caracteristicas/Especies/biomodelos', full.names = T)
features.list <- lapply(spp.list, function(f) { r <- raster(f); names(r) <- basename(f); r })

# Ecosistemas
eco.list <- list.files('Caracteristicas/Ecosistemas/Estandarizados', full.names = T)
eco.rasters <- lapply(eco.list, function(f) { r <- raster(f); names(r) <- basename(f); r })
features.list <- c(features.list, eco.rasters)

# Stack versión 1
raster_stack_v1 <- stack(features.list)
crs(raster_stack_v1) <- "EPSG:9377"

# Cultura
cul.list <- list.files('Caracteristicas/Cultura/Estandarizados', full.names = T)
cul.rasters <- lapply(cul.list, function(f) { r <- raster(f); names(r) <- basename(f); r })
features.list <- c(features.list, cul.rasters)

# Stack versión 2
raster_stack_v2 <- stack(features.list)
crs(raster_stack_v2) <- "EPSG:9377"

# Inclusiones
locked.in1 <- raster("Restricciones/Inclusion/RUNAP_1000_stdr.tif")
crs(locked.in1) <- "EPSG:9377"

# Costos
costo.int <- st_read('Costos/Integridad_total_cor.shp')
costo.int$Int_ttl.r <- 100 - ((costo.int[['Int_ttl']] - min(costo.int$Int_ttl, na.rm = TRUE)) /
                                (max(costo.int$Int_ttl, na.rm = TRUE) - min(costo.int$Int_ttl, na.rm = TRUE)) * 100)

# Conectividad
conectividad <- st_read("Conectividad/microcuencas_con_CI.shp")
conectividad <- st_transform(conectividad, crs = 9377)
rast_templ <- raster(resolution = 1000, crs=9377, ext = extent(ae))
conectividad.r <- fasterize(conectividad, rast_templ, field = "CI")

r_normalized <- classify(rast(conectividad.r), 
                         matrix(c(0, 0.00062, 1, 0.00062, 0.000809, 0.8,
                                  0.000809, 0.001105, 0.6, 0.001105, 0.001821, 0.4,
                                  0.001821, 0.1, 0.2), ncol = 3, byrow = TRUE), include.lowest=TRUE)

con_scores <- connectivity_matrix(costo.int, r_normalized)
con_scores <- rescale_matrix(con_scores, max = 1)

# Plantilla microcuencas
plantilla.micro <- ae
plantilla.micro$area_km2 <- st_area(ae) / 10^6
total_area_km2 <- sum(plantilla.micro$area_km2)

# 4. PARÁMETROS ----------------------------------------------------------------
targets <- seq(0.1, 1, 0.1)
penalties <- c(0, 1, 2, 4, 6, 8, 10)
scenarios <- c("solucion1", "solucion2", "solucion3", "solucion4")

# 5. FOLDERS -------------------------------------------------------------------

if (!dir.exists(output.base.dir)) {
  dir.create(output.base.dir)
  cat(blue(paste0("Carpeta creada:", output.base.dir, '\n')))
}
# Define subfolder names
subfolders <- scenarios
for (folder in subfolders) {
  path <- file.path(output.base.dir, folder)
  if (!dir.exists(path)) {
    dir.create(path)
  }
}

# 5. FUNCIONES AUXILIARES ------------------------------------------------------

# Logger robusto
write_log <- function(log_path, escenario, start_time, end_time, summary_table, penalties, targets, error = NULL) {
  tiempo_total <- round(difftime(end_time, start_time, units = "mins"), 2)
  dir.create(dirname(log_path), recursive = TRUE, showWarnings = FALSE)
  
  sink(log_path)
  cat("=============================================\n")
  cat(" PRIORIZACIÓN - LOG EJECUCIÓN\n")
  cat("=============================================\n")
  cat("Escenario:", escenario, "\n")
  cat("Inicio:", format(start_time), "\n")
  cat("Fin:", format(end_time), "\n")
  cat("Duración (minutos):", tiempo_total, "\n\n")
  cat("Parámetros:\n")
  cat("Penalties:", paste(penalties, collapse = ", "), "\n")
  cat("Targets:", paste(targets, collapse = ", "), "\n")
  cat("Total soluciones:", ifelse(is.null(summary_table), 0, nrow(summary_table)), "\n\n")
  
  if (!is.null(summary_table) && nrow(summary_table) > 0) {
    cat("Resumen de área priorizada (km2):\n")
    print(summary_table %>% summarise(
      min_area = as.numeric(min(Area_priorizada_km2)),
      max_area = as.numeric(max(Area_priorizada_km2)),
      mean_area = as.numeric(mean(Area_priorizada_km2))
    ))
  }
  
  if (!is.null(error)) {
    cat("\n*** ERROR DETECTADO ***\n")
    cat(as.character(error), "\n")
  }
  cat("=============================================\n")
  sink()
}

# Optimización por escenario
run_scenario <- function(escenario, p, t) {
  
  # Definir stack e inclusiones
  if (escenario == 'solucion1') {
    raster_stack <- raster_stack_v1
    inclusion <- NULL
  } else if (escenario == 'solucion2') {
    raster_stack <- raster_stack_v2
    inclusion <- NULL
  } else if (escenario == 'solucion3') {
    raster_stack <- raster_stack_v1
    inclusion <- 1
  } else if (escenario == 'solucion4') {
    raster_stack <- raster_stack_v2
    inclusion <- 1
  }
  
  # Construcción del problema
  p1 <- problem(costo.int, rast(raster_stack), cost_column = "Int_ttl.r") %>%
    add_min_set_objective() %>%
    add_relative_targets(t) %>%
    add_cbc_solver(verbose = FALSE) %>%
    add_binary_decisions() %>%
    add_connectivity_penalties(penalty = p, data = con_scores)
  
  if (!is.null(inclusion)) p1 <- p1 %>% 
    add_locked_in_constraints(rast(locked.in1))
  
  s1 <- solve(p1)
  target_coverage <- eval_target_coverage_summary(p1, s1[,"solution_1"])
  
  plantilla.micro$temp_solution <- s1$solution_1
  seleccionadas <- plantilla.micro %>% filter(temp_solution == 1)
  num_microcuencas <- nrow(seleccionadas)
  area_priorizada <- sum(st_area(seleccionadas)) / 10^6  
  representatividad <- (area_priorizada / total_area_km2) * 100
  
  list(
    scenario = escenario,
    name = paste0("Penalty_", p, "_Target_", t),
    penalty = p, target = t,
    num_microcuencas = num_microcuencas,
    area_km2 = area_priorizada,
    representatividad = representatividad,
    coverage = target_coverage,
    solution = s1$solution_1
  )
}

# 6. LOOP GENERAL POR ESCENARIO ------------------------------------------------

for (escenario in scenarios) {
  
  cat(blue(paste0("\nEjecutando ", escenario, " ...\n")))
  
  param_grid <- expand.grid(penalty = penalties, target = targets, stringsAsFactors = FALSE)
  escenario_start_time <- Sys.time()
  
  error_catch <- NULL
  resultados <- NULL
  summary_table <- NULL
  
  tryCatch({
    resultados <- future_pmap(
      list(param_grid$penalty, param_grid$target),
      function(p, t) run_scenario(escenario, p, t)
    )
    
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
    
    plantilla.micro.temp <- plantilla.micro
    for (res in resultados) {
      plantilla.micro.temp[[res$name]] <- res$solution
    }
    
    dir.create(file.path(output.base.dir, escenario), recursive = TRUE, showWarnings = FALSE)
    st_write(plantilla.micro.temp, file.path(output.base.dir, escenario, paste0("Orinoquia_", escenario, ".shp")), delete_dsn = TRUE)
    
    wb <- createWorkbook()
    for (i in seq_along(resultados)) {
      addWorksheet(wb, sheetName = resultados[[i]]$name)
      writeData(wb, sheet = resultados[[i]]$name, x = resultados[[i]]$coverage, rowNames = FALSE)
    }
    saveWorkbook(wb, file = file.path(output.base.dir, escenario, paste0("Orinoquia_", escenario, "_coverage.xlsx")), overwrite = TRUE)
    
    write.xlsx(summary_table, file = file.path(output.base.dir, escenario, paste0("Orinoquia_", escenario, "_resumen.xlsx")))
    save(resultados, summary_table, file = file.path(output.base.dir, escenario, paste0("Orinoquia_", escenario, ".RData")))
    
  }, error = function(e) {
    error_catch <<- e
  })
  
  escenario_end_time <- Sys.time()
  
  log_file <- file.path(output.base.dir, escenario, paste0("Orinoquia_", escenario, "_log.txt"))
  write_log(log_file, escenario, escenario_start_time, escenario_end_time, summary_table, penalties, targets, error_catch)
  
  if (is.null(error_catch)) {
    cat(green(paste0("Finalizado correctamente: ", escenario, "\n")))
  } else {
    cat(red(paste0("Error en ", escenario, ": ", error_catch$message, "\n")))
  }
}

global_end_time <- Sys.time()
cat(blue(paste0("TIEMPO TOTAL COMPLETO: ", global_end_time - global_start_time, "\n")))
