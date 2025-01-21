# UD3: Alta Disponibilidad
La **alta disponibilidad (HA)** asegura que los servicios críticos estén siempre accesibles, minimizando el tiempo de inactividad. Siendo ideal para servicios web, bases de datos críticas y aplicaciones donde la interrupción no es aceptable.

### Claves de HA:
---
- **Redundancia**: Recursos duplicados para garantizar continuidad ante fallos.  
- **Tolerancia a fallos**: Resistencia a problemas de hardware, software o red.  
- **Balanceo de carga**: Distribuye el tráfico para evitar saturaciones.  
- **Monitoreo**: Detecta y soluciona problemas automáticamente.

### Preparación de Escenarios:
---
En los diferentes escenarios de esta unidad se utiliza **Vagrant** y **Ansible** para automatizar la configuración de entornos de desarrollo.

- **Vagrant**: Herramienta para gestionar máquinas virtuales fácilmente y reproducir entornos de manera consistente.  
- **Ansible**: Herramienta de automatización para configurar servidores, instalar dependencias y ejecutar scripts.

Tanto **Vagrant**, **Ansible** y **VirtualBox** pueden instalarse utilizando el script `instalador.sh`.  

#### Pasos para Ejecutar el Script
1. Da permisos de ejecución al archivo:  
   ```bash
   chmod +x instalador.sh
1. Ejecuta el script con el siguiente comando:
   ```bash
   ./instalador.sh
