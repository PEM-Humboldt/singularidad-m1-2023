# 💧 Áreas prioritarias para la conservación de ecosistemas de aguas interiores

La PSC en los ecosistemas de aguas dulce interiores presenta rezagos teóricos y metodológicos en comparación a los ámbitos terrestres y marinos, debido a la complejidad de la conectividad fluvial, la falta de datos de distribución de especies y su alta variabilidad espacial y temporal. Algunos desafíos que complican los procesos de priorización en estos ecosistemas son: 
*	Definición de las unidades de planeación acuáticas.
*	Conservación basada en procesos, en lugar de conservación unicamente basada en área.
* Selección de verdaderos sustitutos (biodiversidad representativa) de la biodiversidad acuática.

En este repositorio se compilan las rutinas para la priorización de ecosistemas de aguas interiores con base en metas nacionales y globales. Aqunque se utiliza como caso piloto la Orinoquia Colombiana, una región rica en ecosistemas acuatícos, también se apunta a que estas metodologías puedan escalarse al nivel nacional y en otras regiones de Colombia.

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

# Versiones utilizadas
package_versions <- list(
  terra = "1.8-15",
  sf = "1.0-18", 
  prioritizr = "8.0.4",
  dplyr = "1.1.4",
  tidyr = "1.3.1",
  fasterize = "1.1.0",
  openxlsx = "4.2.8",
  crayon = "1.5.3",
  furrr = "0.3.1",
  future = "1.58.0",
  rcbc = "0.1.0.9002",
  progress = "1.2.3"
)
```
# Descripción flujo de análisis

La planificación sistemática de la conservación (PSC) para las aguas interiores de la Orinoquia siguió una metodología de cuatro etapas (diagrama abajo): (i) Conceptualización: se definieron unidades de planificación, metas y objetivos de conservación, incluyendo la selección de portafolios (por ejemplo, escenarios con y sin restricciones); (ii) Preprocesamiento de datos: los conjuntos de datos de entrada (por ejemplo, características hidrológicas, distribuciones de especies) fueron procesados para garantizar consistencia espacial y temática; (iii) Algoritmo de optimización: el modelo PrioritizR fue configurado con restricciones espaciales, métricas de conectividad y capas de costo, y ejecutado iterativamente para generar áreas prioritarias; y (iv) Postprocesamiento: los resultados fueron evaluados con base en la representatividad de las aguas interiores e interpretados frente a otros productos espaciales (por ejemplo, mapas de cobertura del suelo).

![Image](https://github.com/PEM-Humboldt/singularidad-m1-2023/blob/7b0e7e0818c7e1d95726fe03a20468a2cfde96e8/Worlflux.jpg)


## Ejecución del algoritmo (iV)
Específicamente la estapa cuatro del flujo de análisis comprenden las funciones principales 

Las siguientes secciones y subsecciones pueden visualizarse fácilmente en RStudio:

![Image](https://github.com/PEM-Humboldt/singularidad-m1-2023/blob/5ad64386aea3e43276e69d5cccc7b1579013130e/Imagenes/Estructura_algoirmo.png)

# Archivos necesarios
Para este flujo de análisis se necesitan x archivos principales que son nombrados en el código de la siguiente manera:

```R
# En construcción
```






# Errores comunes

🚨Paquetes no instalados o conflictos entre versiones.

📁 Archivos de entrada no encontrados o rutas incorrectas.

🗺️ Inconsistencias entre los CRS de diferentes capas.

💾 Agotamiento de memoria o fallos en procesamiento paralelo.


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




