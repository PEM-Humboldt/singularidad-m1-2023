# Areas de singularidad



---
# Dependencias
* [R](https://cran.r-project.org/mirrors.html)
* [RStudio](https://www.rstudio.com/products/rstudio/download/#download)

# Prerequisitos
El paquete [prioritizr](https://prioritizr.net/) permite ejecutar las funciones más importantes para la priorización de zonas de conservación. En su repositorio se puede encontrar una descripción detallada de cada una de sus funciones.

```R
# Instalación prioritizr
install.packages("prioritizr", repos = "https://cran.rstudio.com/")

# Librerias necesarias
library(terra)
library(sf)
library(prioritizr)
library(dplyr)
library(tidyr)
library(fasterize)
library(openxlsx)
library(crayon)
library(furrr)
library(future)
library(rcbc)
library(progress)

# Versiones
- terra: 1.8-15
- sf: 1.0-18
- prioritizr: 8.0.4
- dplyr: 1.1.4
- tidyr: 1.3.1
- fasterize: 1.1.0
- openxlsx: 4.2.8
- crayon: 1.5.3
- furrr: 0.3.1
- future: 1.58.0
- rcbc: 0.1.0.9002
- progress: 1.2.3   
```
# Archivos necesarios
Para este flujo de análisis se necesitan x archivos principales que son nombrados en el código de la siguiente manera:

```R
# En construcción
```


# Descripción flujo de análisis
En construción

## Diagrama
![Image](https://github.com/PEM-Humboldt/singularidad-m1-2023/blob/7b0e7e0818c7e1d95726fe03a20468a2cfde96e8/Worlflux.jpg)

## Estructura del código
Al igual que en el diagrama, el código se estructuró según las secciones del flujo de trabajo para que el usuario comprenda mejor las funciones.

Las siguientes secciones y subsecciones pueden visualizarse fácilmente en RStudio:

![Image](https://github.com/user-attachments/assets/1be77793-6e02-4941-b753-c7080c65d13e)

# Errores comunes

## 1. Errores de configuración inicial
- **Paquetes faltantes**: Pueden faltar paquetes necesarios (`sf`, `dismo`, `rgdal`, `CENFA`, `raster`, `progress`).  
- **Problemas con rutas de directorio**:  
  - Las rutas en Windows con barras invertidas (`\`) pueden fallar si no se escapan correctamente.  
  - Usa barras inclinadas (`/`) o dobles barras invertidas (`\\`) para mayor compatibilidad.  
- **Problemas con el directorio de trabajo**:  
  - `setwd()` puede fallar si la ruta no existe o contiene caracteres especiales.  

## 2. Errores al cargar datos
### Carga de archivos raster
- Rutas incorrectas en llamadas a `list.files()`.  
- Proyecciones incompatibles entre datos climáticos y shapefiles de especies.  
- Problemas de memoria al apilar archivos raster grandes.  

### Carga de shapefiles
- Shapefiles faltantes en `dir_shapes`.  
- Nombre de campo incorrecto (se espera el campo `"Nombre"`).  
- Shapefiles corruptos o inválidos.  

## 3. Errores en ejecución de funciones
- **Incompatibilidad de CRS**: Los archivos de entrada pueden tener proyecciones distintas a pesar de la configuración.  
- **Problemas específicos por especie**:  
  - Polígonos de distribución vacíos o inválidos.  
  - Distribuciones fuera del área cubierta por los datos climáticos.  
- **Límites de memoria**: Los análisis son intensivos en memoria y pueden fallar en equipos con RAM limitada.  
- **Problemas con procesamiento paralelo**: La opción `parallel = TRUE` puede fallar en algunos sistemas.  

## 4. Errores al guardar resultados
- Permisos insuficientes para escribir en `dir_out`.  
- Conflictos con nombres de archivo ya existentes.  
- Problemas con archivos grandes por espacio en disco o formato.  

## 5. Errores en bucles de ejecución
- **Inconsistencias en nombres de especies**: `species_lista[[i]]` puede no coincidir con los nombres reales de los archivos.  
- **Interrupciones**: Procesos largos pueden fallar antes de completarse.  

## 6. Errores específicos de paquetes
### Problemas con CENFA
- `enfa()` o `cnfa()` pueden fallar con ciertas configuraciones de entrada.  
- El parámetro `field` puede no coincidir con los atributos del shapefile.  

## Errores críticos más frecuentes
1. **Incompatibilidad de CRS**: Archivos con proyecciones diferentes harán fallar el análisis.  
2. **Saturación de memoria**: Procesar muchas especies o raster grandes puede agotar la RAM.  
3. **Falta el campo `"Nombre"`**: La función requiere este campo en todos los shapefiles.  
4. **Áreas de distribución inválidas**: Algunas especies pueden tener rangos demasiado pequeños o no válidos.  
5. **Problemas con rutas**: Rutas en Windows con espacios o caracteres especiales pueden causar errores.  



# Autores(as) y contacto
* **[Elkin Alexi Noguera Urbano](https://github.com/elkalexno)** - *Investigador Titular. I. Humboldt* - [Contact](enoguera@humboldt.org.co)
* **[Edwin Uribe Velasquez](https://github.com/edwinuribeecobio)** - *Investigador Asistente. I. Humboldt* - [Contact](euribe@humboldt.org.co)

## Licencia

Este proyecto está licenciado bajo la licencia MIT. Para obtener más información, consulte el archivo [LICENCIA](https://github.com/PEM-Humboldt/climate-vulnerability-index/blob/main/LICENSE). 

## Financiamiento


# Referencias


Funciones de referencia: 



Repositorio de referencia:
https://prioritizr.net/




