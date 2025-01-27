# Balanceo de carga basado en DNS

## Descripción del escenario

Utilizando entradas **tipo A** duplicadas en un servidor DNS es posible realizar de forma muy sencilla un balanceo de carga entre varios equipos, esto se conoce como [DNS round robin](http://en.wikipedia.org/wiki/Round-robin_DNS) (aunque este sistema presenta algunos inconvenientes).

En este caso vamos a realizar un balanceo de carga entre dos servidores web, para lo que creamos un escenario con tres equipos:

Nodo              | IP          | Descripción
------------------|-------------|------------
dns.example.com   | 172.31.0.10 | Servidor DNS
nodo1.example.com | 172.31.0.11 | Servidor web
nodo2.example.com | 172.31.0.12 | Servidor web

Los dos servidores WEB comparten el mismo nombre (**www.example.com**):

~~~
www.example.com.	IN	A	172.31.0.11
www.example.com.	IN	A	172.31.0.12
~~~

Cada vez que se hace una consulta, el servidor DNS va rotando el orden de las respuestas. Esto hace que los clientes se vayan conectando alternativamente a un servidor u otro, consiguiendo así que la carga de trabajo se reparta entre los dos.

## Utilización básica del escenario

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

#### 3) Acceder al servidor DNS + Balanceador

~~~
vagrant ssh balanceador
~~~

## Realizacion e iteracion con el escenario

#### 1) Configuración del DNS (Round Robin)

Cambia la configuración de BIND para asociar el mismo nombre (**www.example.com**) a dos direcciones IP distintas (las de los servidores web). Para ello edita `/var/lib/bind/db.example.com` y añade los registros:

~~~
www		IN	A	172.31.0.11
www		IN	A	172.31.0.12
~~~

Reinicia el servicio DNS para que utilice la nueva configuración:

~~~
systemctl restart bind9
~~~

#### 2) Interactuar con el escenario

Si no ha habido errores durante la ejecución de los playbooks y las operaciones manuales de configuración son correctas, se puede comprobar que se realiza el balanceo de **www.example.com** entre el **nodo1** y el **nodo2**, repitiendo la consulta DNS con `dig`:

~~~
dig www.example.com +short
~~~

con `ping`:

~~~
ping www.example.com
~~~

o con `wget`:

~~~
wget -q http://www.example.com -O - | grep nodo
~~~

También puede verse de forma mucho más clara a través del navegador, para lo cual es necesario ir a la siguiente dirección <http://www.example.com> y podremos comprobar como se balancean las peticiones entre los dos servidores web **nodo1** y **nodo2** (es necesario forzar la recarga, por ejemplo, con CTRL+F5).

## Desechar el escenario correctamente

Cuando termines de trabajar con el escenario, puedes desecharlo haciendo lo siguiente:

~~~
vagrant destroy -f
sudo ./utils/dns-sistema.sh
~~~


