# Cluster de Alta Disponibilidad con Corosync y Pacemaker (IP Failover)

## Descripción del escenario

El caso más sencillo de cluster de alta disponibilidad es utilizar dos nodos que funcionen en modo maestro-esclavo y que ofrezcan como recurso de alta disponibilidad una dirección IP, que se denomina, en algunos casos, **IP virtual**.

Cada nodo del cluster posee su propia dirección IP y uno de ellos posee además la dirección IP virtual. El software de alta disponibilidad está monitorizando ambos nodos en todo momento y en el caso de que el nodo que ofrece el **recurso** tenga algún problema, el recurso (la dirección IP en este caso) pasa al nodo que esté en modo esclavo.

Vamos a utilizar la siguiente configuración de equipos, con la peculiaridad de que, además, utilizaremos la dirección **172.31.0.100** como **IP virtual** asociada a **www.example.com.**

Servidores que componen el escenario:

Nodo              | IP           | Descripción
------------------|--------------|------------
dns.example.com   | 172.31.0.10  | Servidor DNS
nodo1.example.com | 172.31.0.11  | Un nodo cualquiera
nodo2.example.com | 172.31.0.12  | Un nodo cualquiera

Forma en la que los clientes acceden a los servicios:

Nombre de dominio | IP virtual   | Servicio
------------------|--------------|------------
www.example.com   | 172.31.0.100 | PING


## Utilización básica del escenario

### Desplegar y configurar el escenario base

~~~
vagrant up
ssh-add ~/.vagrant.d/insecure_private_key
ansible-playbook site.yml
~~~

### Utilizar el servidor DNS del escenario

~~~
sudo ./utils/dns-escenario.sh
~~~

### Desechar el escenario correctamente

Cuando termines de trabajar con el escenario, puedes desecharlo haciendo lo siguiente:

~~~
vagrant destroy -f
sudo ./utils/dns-sistema.sh
~~~


## Ejercicio 1. Instalación y configuración básica del cluster

Para implementar un cluster de alta disponibilidad vamos a necesitar los siguientes componentes y herramientas:

- **Corosync**: Capa de membresía del cluster. Se trata de un software que facilita la comunicación directa de estados entre nodos del cluster (mensajería). También se encarga de gestionar la pertenencia al mismo, así como de determinar si hay _quorum_ (número mínimo de nodos necesario para prevenir la pérdida o corrupción de datos). A través de Corosync, todas las máquinas conocerán si algún miembro del cluster se encuentra *offline* o en cualquier otro estado que implique la imposibilidad de un funcionamiento normal.
- **Pacemaker**: Gestor de recursos del cluster. Es el cerebro que procesa y reacciona a los eventos que ocurren en el cluster. Los eventos pueden consistir en nodos que se unen o abandonan el cluster, fallos que se producen en los recursos, operaciones de mantenimiento o actividades planificadas. Para alcanzar el nivel de disponibilidad deseado, Pacemaker puede iniciar o detener recursos, así como asilar nodos.
- **pcs**: interfaz de administración que permite configurar todo el cluster (no solo pacemaker, sino también corosync). Existen otras herramientas, como la shell **crm**, que se centra en pacemaker, siendo en este caso responsabilidad del usuario el tener que configurar manualmente corosync. Ver [comparación entre pcs y crm](https://clusterlabs.org/pacemaker/doc/2.1/Pacemaker_Administration/html/pcs-crmsh.html).


### Instalación

Debemos instalarlo en todos los nodos del cluster:

~~~sh
nodo1:~# apt install corosync pacemaker pcs
~~~

~~~sh
nodo2:~# apt install corosync pacemaker pcs
~~~

### Poner contraseña al usuario _hacluster_

Se trata de un usuario que ejerce el papel de administrador del cluster. Hay que poner la misma contraseña en todos los nodos:

~~~sh
nodo1:~# passwd hacluster
~~~

~~~sh
nodo2:~# passwd hacluster
~~~

También hay que asegurarse de que el servicio `pcsd` está funcionando en todos los nodos:

~~~sh
nodo1:~# systemctl --type=service
nodo1:~# systemctl restart pcsd
~~~

~~~sh
nodo2:~# systemctl --type=service
nodo2:~# systemctl restart pcsd
~~~

### Establecer los miembros del cluster

Añadir los nodos a la lista de equipos conocidos (`/var/lib/pcsd/known-hosts`). Este fichero no debemos editarlo a mano. Se configura con la siguiente orden:

~~~sh
nodo1:~# pcs host auth nodo1.example.com addr=172.31.0.11 \
    nodo2.example.com addr=172.31.0.12
~~~

Definir el nombre del cluster y sus miembros:

~~~sh
nodo1:~# pcs cluster setup cluster1 nodo1.example.com addr=172.31.0.11 \
    nodo2.example.com addr=172.31.0.12 transport udp --force
~~~

!!! Nota
    Si tenemos bien configurado el archivo `/etc/hosts` o el servicio DNS, no sería necesario indicar la opción `addr` con las IPs de los nodos.


Esta última orden crea una clave de autenticación (que comparten todos los miembros del cluster) y la distribuye automáticamente entre todos los nodos miembro. Si tuviéramos que crearla a mano, se haría de la siguiente forma:

~~~sh
nodo1:~# corosync-keygen (ejecutar en la consola física)
nodo1:~# scp /etc/corosync/authkey usuario@nodo2:/etc/corosync/authkey
~~~

~~~sh
nodo2:~# chown root: /etc/corosync/authkey
nodo2:~# chmod 400 /etc/corosync/authkey
~~~

!!! Advertencia
	La generación de claves criptográficas en máquinas virtuales es un proceso muy lento. En lugar de hacer lo anterior, podemos coger la clave que ya viene preparada con el escenario en la carpeta `recursos/authkey`. Para ello, en todos los nodos ejecutaremos `cp /vagrant/recursos/authkey /etc/corosync/` seguido de `chmod 400 /etc/corosync/authkey`. Otra opción puede consistir en tener instalado el paquete `haveged` que permite incrementar fácilmente la cantidad de entropía en el servidor. Posteriormente, una vez ejecutado el script `corosync-keygen`, lo desinstalaremos (`sudo apt remove --purge haveged`).


También podemos observar que, además de distribuirse la clave de autenticación, se ha configurado el enlace de sincronización y los logs. Si observamos el fichero de configuración de [Corosync](https://github.com/corosync/corosync/wiki/Archive-configuring-the-base-protocol) `/etc/corosync/corosync.conf`, comprobaremos que su contenido es el siguiente:

~~~text
totem {
    version: 2
    cluster_name: cluster1
    transport: udp
}

nodelist {
    node {
        ring0_addr: 172.31.0.11
        name: nodo1.example.com
        nodeid: 1
    }

    node {
        ring0_addr: 172.31.0.12
        name: nodo2.example.com
        nodeid: 2
    }
}

quorum {
    provider: corosync_votequorum
    two_node: 1
}

logging {
    to_logfile: yes
    logfile: /var/log/corosync/corosync.log
    to_syslog: yes
    timestamp: on
}
~~~

En principio, todos los nodos del cluster tendrán la misma configuración de Corosync. Por medio del usuario `hacluster`, la utilidad `pcs` habrá propagado el mismo archivo de configuración `corosync.conf` por todos los nodos, al igual que pasó con la clave de autenticación. Es posible que en un montaje avanzado, cada nodo posea una configuración distinta (tiempos de espera, transmisión y recepción de datos, etc..), aunque este no es el caso.

### Iniciar los servicios de cluster

Desde cualquier nodo, podemos ejecutar la siguiente ordena para iniciar los servicios (corosync y pacemaker) en todos los nodos:

~~~sh
nodo1:~# pcs cluster start --all
~~~

También es conveniente configurar los servicios de cluster para que se ejecuten al iniciar en todos los nodos:

~~~sh
nodo1:~# pcs cluster enable --all
~~~

### Comprobar el estado del cluster 

Si están iniciados corosync y pacemaker, podremos comprobamos el estado del cluster. En cualquier nodo:

~~~
pcs cluster status 
watch pcs status
crm_mon
~~~

Llegados a este punto, si necesitáramos eliminar el cluster, podemos ejecutar:

~~~sh
pcs cluster stop --all 
pcs cluster destroy --all
~~~

Otras ordenes y comprobaciones que nos pueden ser útiles, son:

~~~
crm_mon --one-shot -V
crm_mon -i 2 -f
crm_verify -L
crm configure show
~~~

Averigua para qué sirven.


## Ejercicio 2. Configuración básica de Pacemaker

Pacemaker incluye un conjunto de utilidades y herramientas para trabajar entorno al fichero `cib.xml` (*Cluster Information Base* o **CIB**), que es donde está declarado el cluster, todos sus componentes, todos los recursos y todas las restricciones.

Existen varias interfaces para Pacemaker y para manejar el `cib.xml`. Las más extendidas:

- **crm**: La más común. Proporciona interfaz de comandos (CLI) con una sintaxis muy simplificada pero con una gran potencia.
- **cibadmin**: Programa CLI de edición directa del `cib.xml` con sintaxis muy compleja.
- **pcs**: Herramienta escrita en Python. Simplifica bastante las tareas de mantenimiento de un cluster de alta disponibilidad ya que, no solo permite modificar el `cib.xml`, sino que también permite realizar la configuración inicial de corosync y la puesta en marcha el cluster, como ya hemos visto.

En este ejemplo se usará la herramienta **pcs** dado que resulta más sencilla y cómoda. La herramienta [crm](https://geekpeek.net/linux-cluster-resources/), que es bastante utilizada, permite trabajar en modo interactivo (con su propio *prompt*) o como un programa normal que recibe parámetros de entrada. En ambos casos la sintaxis es idéntica.

Cabe destacar que el `cib.xml` es propagado automáticamente entre todos los nodos del cluster, por lo que las instrucciones de Pacemaker pueden ejecutarse en cualquier máquina del conjunto.

### Desactivar STONITH e ignorar quorum

Para este escenario no lo necesitamos, así que lo desactivamos de la siguiente forma:

~~~sh
# Desactivamos STONITH y ignoramos el quorum
pcs property set stonith-enabled=false
pcs property set no-quorum-policy=ignore

# Definimos timeout por defecto
pcs resource op defaults update timeout=20s
~~~

También hemos definido un valor de _timeout_ por defecto.

### Configuración de la IP del cluster como recurso

Configuramos la **IP virtual** como recurso, que preferiblemente tendrá el nodo1:

~~~sh
# Definimos el recurso CLUSTER_IP gestionado por el agente ocf:heartbeat:IPaddr2
pcs resource create CLUSTER_IP ocf:heartbeat:IPaddr2 ip=172.31.0.100 cidr_netmask=16 \
    op monitor interval=60s

# El recurso CLUSTER_IP tiene afinidad por el nodo1
pcs constraint location CLUSTER_IP prefers nodo1.example.com=INFINITY
~~~

<!--
pcs resource create http_server ocf:heartbeat:nginx configfile="/etc/nginx/nginx.conf" \
    op monitor timeout="20s" interval="60s"

crm configure group cluster1 floating_ip http_server
-->

Comprobamos el estado del cluster y los recursos:

~~~sh
pcs status resources
pcs status
~~~

Algunos comandos interesantes para probar son:

~~~
pcs node standby
pcs node unstandby
pcs resource move CLUSTER_IP lifetime=PT10S 
pcs resource move CLUSTER_IP nodo2.example.com
pcs resource cleanup CLUSTER_IP
~~~

Descubre para qué sirven.


## Ejercicio 3. Comprobación del funcionamiento

Realiza las siguientes acciones:

- Comprueba que la dirección **www.example.com** está asociada a la dirección IP **172.31.0.100**, que en este escenario es la **IP virtual** que estará asociada en todo momento al nodo que esté en modo maestro.
- Accede a uno de los nodos del cluster y ejecuta la instrucción `crm_mon`. Comprueba que los dos nodos están operativos y que el recurso `CLUSTER_IP` está funcionando correctamente en uno de ellos.
- Haz `ping` a **www.example.com** desde la máquina anfitriona y comprueba la **tabla ARP**. Podrás verificar que la dirección **MAC** asociada a la dirección IP **172.31.0.100** coincide con la del nodo maestro en estos momentos.
- Para el nodo maestro (supongamos que es **nodo1**): `pcs node standby`.
- Haz ping a **www.example.com** y comprueba que la **tabla ARP** ha cambiado. Ahora la  dirección **MAC** asociada a la dirección IP **172.31.0.100** es la del otro nodo.
- Entra en el nodo maestro y comprueba el estado del cluster con `crm_mon`.
- Levanta de nuevo el nodo que estaba parado: `pcs node unstandby`. ¿Qué ocurre?

Dependiendo de la configuración, puede ocurrir que los recursos no vuelvan al nodo inicial porque, en ocasiones, se penaliza el movimiento de los recursos. Así pues, es posible que estos tiendan a quedarse en el nodo en el que se están ejecutando.

Podemos comprobarlo desactivando la preferencia por el **nodo1** y repitiendo las acciones anteriores:

~~~
pcs constraint list --full
pcs constraint delete location-CLUSTER_IP-nodo1.example.com-INFINITY
~~~

## Ejercicio 4. Interfaz web

Accede a la siguiente dirección para echar un vistazo a la interfaz web de administración del cluster:

<https://172.31.0.100:2224/manage>


## Para saber más

- [Ahead of the Pack: the Pacemaker High-Availability Stack ](https://www.linuxjournal.com/content/ahead-pack-pacemaker-high-availability-stack)
- [Introduction to High Availability](https://ubuntu.com/server/docs/ubuntu-ha-introduction)
- [Configuración y gestión de clusters de alta disponibilidad](https://access.redhat.com/documentation/es-es/red_hat_enterprise_linux/8/html/configuring_and_managing_high_availability_clusters/index)
- [Configuring and managing high availability clusters](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/9/html/configuring_and_managing_high_availability_clusters/index)
- [Clusters from Scratch](https://clusterlabs.org/pacemaker/doc/deprecated/en-US/Pacemaker/1.1/html/Clusters_from_Scratch/)
- [Pacemaker para grupos de disponibilidad e instancias de clúster de conmutación por error en Linux](https://learn.microsoft.com/es-es/sql/linux/sql-server-linux-pacemaker-basics?view=sql-server-ver16)
- [Configuración de un clúster de Pacemaker para grupos de disponibilidad de SQL Server](https://learn.microsoft.com/es-es/sql/linux/sql-server-linux-availability-group-cluster-pacemaker?view=sql-server-ver16&tabs=rhel)
