# Cluster de Alta Disponibilidad con Corosync y Pacemaker<br/>(IP Failover + Apache)

## Descripción del escenario

Partiendo del escenario de **IP Failover** ya configurado, se añadirá el recurso **Apache** al monitor de recursos del clúster. De este modo, Pacemaker se encargará de asegurar que el servicio esté siempre operativo en el nodo maestro o, en caso de fallo, en el nodo esclavo. Además, al estar asociado el nombre de dominio **www.example.com** a la IP virtual **172.31.0.100**, se podrá acceder al servicio web utilizando la dirección http://www.example.com en el navegador.

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


## Preconfiguración del Escenario

#### 1) Desplegar y configurar el escenario base

~~~
vagrant up
ssh-add ~/.vagrant.d/insecure_private_key
ansible-playbook site.yml
~~~

#### 2) Utilizar el servidor DNS del escenario

~~~
sudo ./utils/dns-escenario.sh
~~~

#### 3) Comprobar el estado del escencario
En el escenario anterior, se configuró la IP virtual como recurso ejecutando los siguientes comandos:

~~~.sh
# Se desactiva STONITH y se ignora el quorum
pcs property set stonith-enabled=false
pcs property set no-quorum-policy=ignore

# Se define el timeout por defecto
pcs resource op defaults update timeout=20s

# Se define el recurso CLUSTER_IP, gestionado por el agente ocf:heartbeat:IPaddr2
pcs resource create CLUSTER_IP ocf:heartbeat:IPaddr2 ip=172.31.0.100 \
    cidr_netmask=16 op monitor interval=60s

# El recurso CLUSTER_IP tiene afinidad por el nodo1
pcs constraint location CLUSTER_IP prefers nodo1.example.com=INFINITY
~~~

Para comprobar que todo esto ya está configurado en este escenario se deberá ejecutar siguiente comando:

~~~
nodo1:~# crm configure show
~~~

Para salir, se debe pulsar `q`.

## Desarrollo del Escenario

Antes de empezar, será necesario instalar los agentes de recursos en **todos los nodos**:

~~~sh
apt install resource-agents
~~~

Para configurar Apache2 como un recurso administrado por el cluster debemos hacer lo siguiente (en alguno de los nodos):

~~~.sh
# Se define el recurso APACHE gestionado por el agente ocf:heartbeat:apache
pcs resource create APACHE ocf:heartbeat:apache \
	configfile="/etc/apache2/apache2.conf" \
	statusurl="http://localhost/server-status" \
	op monitor interval="1min" \
	op start interval="0" timeout="40s" \
	op stop interval="0" timeout="60s"

# Los recursos APACHE y CLUSTER_IP deben ir en el mismo nodo
pcs constraint colocation add CLUSTER_IP with APACHE INFINITY

# El orden de inicio es primero CLUSTER_IP y luego APACHE
pcs constraint order CLUSTER_IP then APACHE
~~~

Cabe destacar que es posible cambiar manualmente los recursos a otro nodo con la instrucción:

~~~
pcs resource move [recurso] [nodo]
~~~

Esto es útil, por ejemplo, para realizar tareas de mantenimiento en uno de los nodos. Aunque es posible que, antes de poder mover manualmente los recursos, sea necesaria quitar la regla que establece la preferencia por el **nodo1**:

~~~
pcs constraint list --full
pcs constraint remove location-CLUSTER_IP-nodo1.example.com-INFINITY
~~~

- Una vez realizadas las tareas que mantenimiento se devuelve el control de los recursos a **pacemaker** para que los siga gestionando:

~~~
pcs resource clear [recurso]
~~~

### Documentacion a Entregar
- Ejecuta la instrucción `crm_mon` (en alguno de los nodos), comprobando que los dos nodos están operativos y que los recursos **CLUSTER_IP** y **APACHE** están funcionando correctamente en uno de ellos.
- Utiliza el navegador y accede a la dirección **www.example.com**. Recarga la página y comprueba que siempre responde el mismo nodo (nodo maestro).
- Para el nodo maestro con `pcs node standby` y verifica que es posible acceder con el navegador al sitio **www.example.com** (el nodo esclavo será el encargo de responder a la solicitud).

### Desechar el escenario correctamente

Cuando termines de trabajar con el escenario, puedes desecharlo haciendo lo siguiente:

~~~
vagrant destroy -f
sudo ./utils/dns-sistema.sh
~~~

