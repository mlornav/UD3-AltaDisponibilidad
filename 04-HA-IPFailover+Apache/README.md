# Cluster de Alta Disponibilidad con Corosync y Pacemaker<br/>(IP Failover + Apache)

## Descripción del escenario

Partiendo del escenario de **IP Failover** ya configurado, vamos a agregar el recurso **apache** al monitor de recursos del cluster. De esta forma, Pacemaker controlará que el servicio esté siempre operativo en el nodo maestro o (en caso de fallo) en el esclavo. Además, como tenemos asociado el nombre de dominio **www.example.com** a la IP virtual **172.31.0.100**, accederemos siempre al servicio web al poner en el navegador la dirección
<http://www.example.com>.

Servidores que componen el escenario:

Nodo              | IP           | Descripción
------------------|--------------|------------
dns.example.com   | 172.31.0.10  | Servidor DNS
nodo1.example.com | 172.31.0.11  | Maestro
nodo2.example.com | 172.31.0.12  | Esclavo

Forma en la que los clientes acceden a los servicios:

Nombre de dominio | IP virtual   | Servicio
------------------|--------------|------------
www.example.com   | 172.31.0.100 | HTTP


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


## Ejercicio 1. Revisar la configuración anterior

En el escenario anterior, ya habíamos configurado la IP virtual como recurso de la siguiente forma:

~~~.sh
# Desactivamos STONITH y ignoramos el quorum
pcs property set stonith-enabled=false
pcs property set no-quorum-policy=ignore

# Definimos timeout por defecto
pcs resource op defaults update timeout=20s

# Definimos el recurso CLUSTER_IP gestionado por el agente ocf:heartbeat:IPaddr2
pcs resource create CLUSTER_IP ocf:heartbeat:IPaddr2 ip=172.31.0.100 \
	cidr_netmask=16 op monitor interval=60s

# El resurso CLUSTER_IP tiene afinidad por el nodo1
pcs constraint location CLUSTER_IP prefers nodo1.example.com=INFINITY
~~~

Podemos comprobar que todo esto ya está configurado en este escenario con el siguiente comando:

~~~
crm configure show
~~~

Para salir, pulsamos `q`.

## Ejercicio 2. Configuración del recurso apache

Antes de empezar, necesitamos instalar los agentes de recursos que no se instalan por defecto (en todos los nodos):

~~~sh
apt install resource-agents
~~~

Para configurar Apache2 como un recurso administrado por el cluster debemos hacer lo siguiente:

~~~.sh
# Definimos el recurso APACHE gestionado por el agente ocf:heartbeat:apache
pcs resource create APACHE ocf:heartbeat:apache \
	configfile="/etc/apache2/apache2.conf" \
	statusurl="http://localhost/server-status" \
	op monitor interval="1min" \
	op start interval="0" timeout="40s" \
	op stop interval="0" timeout="60s"

# Indicamos que los recursos APACHE y CLUSTER_IP deben ir en el mismo nodo
pcs constraint colocation add CLUSTER_IP with APACHE INFINITY

# Indicamos que el orden de inicio es: primero CLUSTER_IP y luego APACHE
pcs constraint order CLUSTER_IP then APACHE
~~~

>

## Ejercicio 3. Comprobación del funcionamiento

Realiza las siguientes acciones:

- Comprueba que la dirección **www.example.com** está asociada a la dirección IP **172.31.0.100**, que en este escenario es la **IP virtual** que estará asociada en todo momento al nodo que esté en modo maestro.
- Accede a uno de los nodos del clúster y ejecuta la instrucción `crm_mon`. Comprueba que los dos nodos están operativos y que los recursos **CLUSTER_IP** y **APACHE** están funcionando correctamente en uno de ellos. En esta configuración se ha forzado que todos los recursos se ejecuten siempre en un solo nodo, que será el maestro de todos los recursos.
- Utiliza el navegador y accede a la dirección **www.example.com**. Recarga la página y comprueba que siempre responde el mismo nodo (nodo maestro).
- Entra en el nodo maestro por SSH y para el **servicio apache2**. Comprueba que transcurridos unos instantes el servicio vuelve a estar levantado en ese nodo (pacemaker se encarga de volver a levantarlo). ¿Qué diferencias encuentras entre esta configuración y la del ejercicio de balanceo DNS?
- Para el nodo maestro con `pcs node standby` y comprueba el estado del clúster con `crm_mon` en el otro nodo. Verifica que es posible acceder con el navegador al sitio **www.example.com**, pero que ahora el contenido lo sirve el otro nodo. ¿Piensas que esta configuración es suficiente para ejecutar contenido web dinámico?
- Levanta el nodo que estaba parado con `pcs node unstandby` y accede a él por SSH. Comprueba el estado del clúster con `crm_mon`. ¿Dónde están ahora los recursos?
- Cambia manualmente los recursos a otro nodo con la instrucción:

~~~
pcs resource move [recurso] [nodo]
~~~

Esto es útil, por ejemplo, para realizar tareas de mantenimiento en uno de los nodos. Aunque es posible que, antes de poder mover manualmente los recursos, tengas que quitar la regla que establece la preferencia por el **nodo1**:

~~~
pcs constraint list --full
pcs constraint remove location-CLUSTER_IP-nodo1.example.com-INFINITY
~~~

- Una vez realizadas las tareas que mantenimiento se devuelve el control de los recursos a **pacemaker** para que los siga gestionando:

~~~
pcs resource clear [recurso]
~~~
