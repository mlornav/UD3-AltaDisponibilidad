# Clúster de servidores web con balanceador de carga

## Descripción del escenario

Utilizando un equipo externo que actúa como intermediario entre los clientes y los servidores web, al cual llamamos [balanceador de carga](https://es.wikipedia.org/wiki/Balanceador_de_carga), es posible repartir de forma equilibrada las peticiones de los usuarios entre todos los nodos.

En este caso vamos a realizar un balanceo de carga entre dos servidores web, para lo que creamos un escenario con tres equipos:

Nodo                      | IP          | Descripción
--------------------------|-------------|------------
balanceador.example.com   | 172.31.0.10 | Servidor DNS + Balanceador (HAProxy)
nodo1.example.com         | 172.31.0.11 | Servidor web
nodo2.example.com         | 172.31.0.12 | Servidor web

En este caso, todos los clientes acceden al clúster a través del nodo balanceador (**balanceador.example.com**), que a su vez, va redirigiendo las conexiones a los **nodos 1 y 2** de forma equilibrada.


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


## Ejercicio 1. Configuración básica de HAProxy

En primer lugar, instalamos **HAProxy**:

~~~
root@balanceador: apt install haproxy
~~~

Seguidamente, podemos revisar los ajustes por defecto del servicio editando el fichero de configuración en `/etc/default/haproxy`:

~~~
# Defaults file for HAProxy
#
# This is sourced by both, the initscript and the systemd unit file, so do not
# treat it as a shell script fragment.

# Change the config file location if needed
#CONFIG="/etc/haproxy/haproxy.cfg"

# Add extra flags here, see haproxy(1) for a few options
#EXTRAOPTS="-de -m 16"
~~~

Como podemos comprobar, el servicio se configura mediante el fichero `/etc/haproxy/haproxy.cfg`.

HAProxy utiliza los siguientes conceptos:

- **Frontends**: son los *servidores virtuales* con los que interactúan los clientes.
- **Backends**: son los servidores reales.

>

El fichero de configuración se basa en:

- Sección **global**: define la configuración global del servidor
- Sección **proxies**: a su vez se define en:
	- Secciones **defaults**: define valores por defecto que serán adoptados por el resto de secciones que se encuentren debajo.
	- Secciones **frontend**: define una serie *sockets* en escucha que aceptan peticiones de clientes.
	- Secciones **backend**: define servidores físicos a los que se conecta el proxy para obtener la respuesta para el cliente.
	- Secciones **listen**: definen proxies completos con la parte de **frontend** y la de **backend**.

El uso de secciones **frontend** y **backend** tiene sentido cuando se pueden reutilizar, en caso contrario es preferible utilizar secciones **listen**.

La cantidad de directivas existentes es muy grande y su uso en las diferentes secciones puede verse en [esta tabla](http://cbonte.github.io/haproxy-dconv/1.6/configuration.html#4.1).

Para nuestro escenario, utilizaremos la siguiente configuración:

~~~.sh
# Parámetros globales
global
	# Indicar como se realiza el log
	log /dev/log	local0
	log /dev/log	local1 notice

	chroot /var/lib/haproxy
	stats socket /run/haproxy/admin.sock mode 660 level admin expose-fd listeners
	stats timeout 30s

	# Indicar el usuario y grupo del sistema que ejecuta haproxy
	user haproxy
	group haproxy

	# Funcionar como demonio
	daemon

	# Localización por defecto para certificados y claves SSL
	ca-base /etc/ssl/certs
	crt-base /etc/ssl/private

	# Algoritmos de cifrado por defecto para sockets con SSL habilitado
	# En este ejemplo se han dejado algunos de los más seguros, pero hay más
	# Ver: https://ssl-config.mozilla.org/#server=haproxy&server-version=2.1&config=intermediate
	# Para comprobar: https://www.ssllabs.com/ssltest/
	ssl-default-bind-ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384
	ssl-default-bind-ciphersuites TLS_AES_128_GCM_SHA256:TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256
	ssl-default-bind-options ssl-min-ver TLSv1.2 no-tls-tickets

	# Número máximo de conexiones globales
	maxconn 4096

	# Si queremos depurar podemos utilizar las siguientes directivas:
	# Deshabilitar la ejecución en segundo plano y sacar toda la información por
	# salida estándar
	#debug

	# Hacer que no se muestre información en el arranque
	#quiet


# Configuracion que se aplica a todos los frontend por defecto
defaults
	# Utilizar el log definido en la seccion global
	log	 global

	# Indicar que el modo es HTTP, ya que se trata de un balanceador web
	mode	http

	# Opciones de registro
	option  httplog
	option  dontlognull

	# Timeouts por defecto (en milisegundos)
	# - Tiempo máximo para conectar a un servidor de backend
	timeout connect 5000
	# - Tiempo que esperamos a un cliente inactivo
	timeout client  50000
	# - Tiempo que esperamos a un servidor inactivo
	timeout server  50000

	# Archivos de error por defecto
	errorfile 400 /etc/haproxy/errors/400.http
	errorfile 403 /etc/haproxy/errors/403.http
	errorfile 408 /etc/haproxy/errors/408.http
	errorfile 500 /etc/haproxy/errors/500.http
	errorfile 502 /etc/haproxy/errors/502.http
	errorfile 503 /etc/haproxy/errors/503.http
	errorfile 504 /etc/haproxy/errors/504.http

	# Indicar el número de reintentos de chequeo de un servidor de backend antes
	# de darlo por muerto
	retries 3

	# Permitir que un cliente sea redirigido si tiene persistencia en un
	# servidor de backend que se cae
	option redispatch

	# Número máximo de conexiones en el balanceador
	maxconn 2000


# Definimos el balanceador HTTP mediante un proxy definido con listen
listen balanceador
	# Indicar la IP y el puerto por donde se conectarán los clientes al
	# balanceador
	bind <ip_balanceador>:80

	# Indicar el algoritmo de balanceo utilizado (roundrobin incluye peso)
	balance roundrobin

	# Archivo que el balanceador pedirá a los servidores web periódicamente
	# para comprobar si siguen con vida
	option httpchk GET /accesible.html

	# server es una directiva compleja y admite multitud de parámetros, como
	# podemos ver en:
	# http://cbonte.github.io/haproxy-dconv/1.6/configuration.html#5
	# - check provoca que los servidores sean comprobados cada cierto tiempo
	#   para mantenerlos activos
	# - inter indica el tiempo en milisengundos entre chequeos
	# - rise indica el número de chequeos positivos consecutivos necesarios para
	#   considerar el servidor online
	# - fall indica el número de chequeos negativos consecutivos necesarios para
	#   considerar el servidor caído
	# - weight indica el peso del servidor dentro del conjunto
	server host1 <ip_nodo1>:80 check inter 2000 rise 2 fall 3 weight 50
	server host2 <ip_nodo2>:80 check inter 2000 rise 2 fall 3 weight 50
~~~

Podemos verificar que la configuración es correcta mediante el comando:

~~~
haproxy -f /etc/haproxy/haproxy.cfg -c
~~~

Finalmente, reiniciamos el servicio para que la nueva configuración tenga efecto, con lo cual, deberíamos tener el balanceador completamente operativo:

~~~
systemctl restart haproxy
~~~

!!! Nota
	Si todo está bien configurado, se puede comprobar que se realiza balanceo entre el **nodo1** y el **nodo2** al acceder a **balanceador.example.com**. Para ello podemos probar a cargar en repetidas ocasiones la dirección <http://balanceador.example.com> (es necesario forzar la recarga con CTRL+F5).

Las directivas de proxies más interesantes son las siguientes (pudiendo aplicarse en defaults, frontend, backend y/o listen):

- **mode**: indica el tipo de balanceador, en nuestro caso HTTP pero se admite también TCP.
- **retries**: número de fallos necesarios para considerar un servidor de backend caído.
- **option redispatch**: permite que un cliente sea redirigido a otro servidor de backend si el servidor en el que tenía persistencia se cae.
- **balance**: indica el algoritmo utilizado en el balanceo: round robin (pesos), menos conexiones, por cabeceras o datos de cliente.
- **option httpchk**: fuerza a que el chequeo de un servidor de backend se haga usando protocolo HTTP mediante una petición completa.
- **weight**: indica el peso del servidor en el algoritmo de balanceo.
- **backup**: indica que este servidor funciona como backup, es decir, sólo se utilizará si todos los demás servidores se han caído (sólo se activa un servidor de backup).

Relativo a los servidores de backup existe también:

- **option allbackups**: hace que, en caso de caída de todos los servidores, funcionen todos los servidores de backup balanceados.

Para poder monitorizar el balanceador, vamos a activar estadísticas en el servidor. HAProxy permite habilitar un socket al que hacer peticiones sobre sus propias estadísticas de uso. Además, dispone de un interfaz web que muestra dicha información y que se habilita como un proxy más. Por ejemplo:

~~~.sh
# Activar las estadísticas a través de 172.31.0.10:1936
listen  stats
	bind	172.31.0.10:1936
	mode	http
	log		global

	maxconn 10

	timeout connect	100s
	timeout client	100s
	timeout server	100s
	timeout queue	100s

	stats enable
	stats hide-version
	stats refresh 30s
	stats show-node
	stats auth admin:entrar
	stats uri  /haproxy?stats
~~~

!!! Nota
	Para consultar las estadísticas, accederemos a la dirección <http://balanceador.example.com:1936/haproxy?stats> (Usuario: *admin*, Clave: *entrar*).


## Ejercicio 2. Configuración de un servidor de respaldo

Actualiza el escenario para añadir un nuevo nodo llamado **respaldo** que actúe como servidor de *backup* en el caso de que los dos nodos principales fallen.

Comprueba el correcto funcionamiento del clúster: mientras al haya funcionando al menos uno de los dos nodos principales, el balanceador no redirigirá el tráfico al servidor de respaldo. En el momento en que todos los nodos principales dejen de funcionar, el balanceador hará uso del nodo de respaldo.
