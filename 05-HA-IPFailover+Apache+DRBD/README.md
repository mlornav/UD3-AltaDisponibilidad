# Cluster de Alta Disponibilidad con Corosync y Pacemaker<br/>(IP Failover + Apache + DRBD)

## Descripción del escenario

Partiendo del escenario de **IP Failover + Apache** ya configurado, vamos a agregar los recursos **DRBD** y **Filesystem** al monitor de recursos del cluster.

[DRBD](https://www.drbd.org/en/comp/drbd-linux-driver) consiste en un sistema de replicación de dispositivos de bloques por red. Podemos pensar el él como en una especie de RAID1 donde los discos que conforman el conjunto no están en el mismo equipo. Se encuentran en equipos distintos que sincronizan los cambios a través de la red.

DRBD nos permitirá añadir posteriormente un recurso más al clúster: el **directorio de datos del sitio web**, que se mantendrá replicado y operativo en modo maestro/esclavo gracias a esta tecnología.

Como en el escenario anterior, Pacemaker controlará que los servicios estén siempre operativos en el nodo necesario. Además, como tenemos asociado el nombre de dominio **www.example.com** a la IP virtual **172.31.0.100**, accederemos siempre al servicio web al poner en el navegador la dirección
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
www.example.com   | 172.31.0.100 | Sitio Web


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

Anteriormente, ya habíamos configurado la IP virtual como recurso de la siguiente forma:

~~~.sh
# Desactivamos STONITH y ignoramos el quorum
pcs property set stonith-enabled=false
pcs property set no-quorum-policy=ignore

# Definimos timeout por defecto
pcs resource op defaults update timeout=20s

# Definimos el recurso CLUSTER_IP gestionado por el agente ocf:heartbeat:IPaddr2
pcs resource create CLUSTER_IP ocf:heartbeat:IPaddr2 \
	ip=172.31.0.100 cidr_netmask=16 \
	op monitor interval=60s

# El resurso CLUSTER_IP tiene afinidad por el nodo1
pcs constraint location CLUSTER_IP prefers nodo1.example.com=INFINITY
~~~

También habíamos configurado Apache2 como recurso:

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

Podemos comprobar que todo esto ya está configurado en este escenario con el siguiente comando:

~~~
crm configure show
~~~

Para salir, pulsamos `q`.

## Ejercicio 2. Configuración inicial de DRBD

### 1) En ambos nodos:

Instalamos **DRBD**:

~~~
apt install drbd-utils
~~~

Configuramos DRBD y definimos el multi-dispositivo de bloques replicado por red. Para ello editamos `/etc/drbd.d/global_common.conf`:

~~~
global {
	usage-count yes;
}

common {
	protocol C;
}

resource web_data {
	meta-disk internal;
	device /dev/drbd1;

	syncer {
		verify-alg sha1;
		#rate 10M;
	}

	net {
		#allow-two-primaries;
	}

	on nodo1 {
		disk /dev/sdb;
		address 172.31.0.11:7789;
	}

	on nodo2 {
		disk /dev/sdb;
		address 172.31.0.12:7789;
	}
}
~~~

Inicializamos el dispositivo de bloques:

~~~
drbdadm create-md web_data
~~~

Levantamos el dispositivo de bloques:

~~~
drbdadm up web_data
~~~

Comprobamos que aparece un nuevo dispositivo llamado **drbd1**:

~~~
lsblk
~~~

Comprobamos el estado de replicación:

~~~
drbdsetup status
cat /proc/drbd
~~~

Veremos que el estado es inconsistente porque los datos de los discos que conforman el RAID basado en DRBD todavía no se han sincronizado.

Para finalizar, vamos a modificar de antemano el sitio web para que la raíz del mismo esté en `/mnt`.

Primero movemos el directorio del sitio:

~~~
mv /var/www/html /mnt
~~~

Seguidamente, actualizamos el archivo correspondiente dentro de `/etc/apache2/sites-available/`:

~~~
<VirtualHost *:80>
	# ...

	DocumentRoot /mnt/html/

	<Directory /mnt/html/ >
		# ...
	</Directory>
</VirtualHost>
~~~

Esto lo hacemos porque más adelante necesitaremos montar en este directorio el dispositivo DRBD donde estará almacenado el sitio web.

Finalmente, no debemos olvidar reiniciar el recurso **APACHE** para que cargue la nueva configuración:

~~~
pcs resource restart APACHE 
~~~

Si por algún motivo no se inicia el recurso APACHE, podemos intentar hacer lo siguiente:

~~~
pcs resource enable APACHE 
~~~


### 2) En el nodo maestro:

Sincronizamos los dos discos sobreescribiendo los datos del nodo secundario mientras observamos cómo se van sincronizando ambos nodos:

~~~
drbdadm -- --overwrite-data-of-peer primary web_data
watch drbdsetup status
~~~

Creamos el sistema de archivos en el multi-dispositivo DRBD:

~~~
mkfs.ext4 /dev/drbd1
~~~

Montamos temporalmente el sistema de archivos:

~~~
mount /dev/drbd1 /mnt/
~~~

Colocamos un archivo **index.html** para comprobar el correcto funcionamiento posteriormente:

~~~
mkdir /mnt/html
echo "Sitio de pruebas - DRBD" > /mnt/html/index.html
chown -R www-data:www-data /mnt/html
~~~

Desmontamos el sistema de archivos:

~~~
umount /mnt
~~~


## Ejercicio 3. Configurar los nuevos recursos del cluster

Una vez configurado y creado el dispositivo múltiple de bloques DRBD, procedemos a definir los agentes de recursos y las restricciones necesarias para que se cumpla lo siguiente:

- El dispositivo DRBD (**web_data**) funcionará en modo **maestro/esclavo**.
- El **sistema de archivos** almacenado en el dispositivo **web_data** se montará en el directorio **/mnt**.
- El **sistema de archivos** solo se montará en el **nodo maestro**.
- Si el nodo maestro cae, **el esclavo promocionará a maestro** y después se montará el **sistema de archivos** en él.
- **Apache** debe colocarse en el mismo nodo que el **sistema de archivos**.
- Si los recursos cambian de nodo, primero debe montarse el **sistema de archivos** y luego iniciarse **Apache**.

Antes de empezar a configurar, es conveniente dejar abierta una consola monitorizando el estado del cluster:

~~~
crm_mon
~~~

Mientras tanto, en otra consola, podemos ir configurando los nuevos recursos:

~~~.sh
# Configurar el recurso DRBD especificando su nombre
pcs resource create WEB_DATA ocf:linbit:drbd \
	drbd_resource="web_data" \
	op monitor interval="30s" role="Slave" \
	op monitor interval="29s" role="Master"

# Definir conjunto Maestro/Esclavo
pcs resource promotable WEB_DATA \
	meta master-max=1 master-node-max=1 clone-max=2 clone-node-max=1 notify=true

# Limpiar el recurso WEB_DATA en el caso de que se haya quedado atascado
# en modo "unmanaged"
# Otra opción es ejecutar "crm_resource -C" que limpia todos los recursos
pcs resource cleanup WEB_DATA

# Configurar recurso para montar el sistema de archivos del dispositivo DRBD
# en un punto de montaje
pcs resource create WEB_FS ocf:heartbeat:Filesystem \
	device="/dev/drbd1" directory="/mnt" fstype="ext4"

# Indicar al cluster que el sistema de archivos debe ir en el nodo maestro
pcs constraint colocation add WEB_FS with WEB_DATA-clone INFINITY \
	with-rsc-role=Master

# Si es necesario, limpiamos las posibles acciones fallidas que hayan sucedido
# relacionadas con el recurso WEB_FS
pcs resource cleanup WEB_FS

# Indicar al cluster que primero se debe promocionar DRBD y después se debe
# iniciar el sistema de archivos
pcs constraint order promote WEB_DATA-clone then start WEB_FS

# Apache debe colocarse en el nodo donde esté montado el sistema de archivos
pcs constraint colocation add APACHE with WEB_FS INFINITY

# Primero se monta el sistema de archivos y luego se inicia Apache
pcs constraint order WEB_FS then APACHE
~~~

>

## Ejercicio 4. Comprobación del funcionamiento

Realiza las siguientes acciones:

- Utiliza el navegador y accede a la dirección **www.example.com**. Recarga la página y comprueba que siempre responde el mismo nodo (nodo maestro).
- Para el nodo maestro con `pcs node standby` y comprueba el estado del clúster con `crm_mon` en el otro nodo. Verifica que es posible acceder con el navegador al sitio **www.example.com**, pero que ahora el contenido lo sirve el otro nodo.
- Realiza alguna modificación en la página que se sirve por HTTP. Levanta el nodo que estaba parado con `crm node online` y comprueba que los cambios se han sincronizado.
- Elimina la regla de **preferencia por el nodo1** para evitar que vuelvan siempre al **nodo1**:

~~~
pcs constraint list --full
pcs constraint delete location-CLUSTER_IP-nodo1.example.com-INFINITY
~~~

- Pon en **standby** el nodo maestro y comprueba que, después de ponerlo de nuevo **online**, los recursos se quedan en el otro nodo.
