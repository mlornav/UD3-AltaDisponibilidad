# Balanceo de Carga Basado en DNS

## Descripción del Escenario

El balanceo de carga basado en DNS utiliza registros tipo A duplicados para distribuir las solicitudes entre varios servidores. Este método, conocido como [DNS round robin](http://en.wikipedia.org/wiki/Round-robin_DNS) permite que un servidor DNS rote las respuestas de manera alternada, distribuyendo las conexiones entre varios servidores. Aunque presenta limitaciones, es una solución sencilla y práctica para equilibrar la carga.

En este escenario, se realiza el balanceo de carga entre dos servidores web configurados con el mismo nombre (www.example.com). Los detalles de los nodos son los siguientes:

Nodo              | IP          | Descripción
------------------|-------------|------------
dns.example.com   | 172.31.0.10 | Servidor DNS
nodo1.example.com | 172.31.0.11 | Servidor web
nodo2.example.com | 172.31.0.12 | Servidor web

Los registros DNS se configuran como:
~~~
www.example.com.	IN	A	172.31.0.11
www.example.com.	IN	A	172.31.0.12
~~~

Cada vez que se hace una consulta, el servidor DNS va rotando el orden de las respuestas. Esto hace que los clientes se vayan conectando alternativamente a un servidor u otro, consiguiendo así que la carga de trabajo se reparta entre los dos.

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

#### 3) Acceder al servidor DNS + Balanceador

~~~
vagrant ssh dns
~~~

## Desarrollo del Escenario

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

También puede verse de forma mucho más clara a través del navegador, para lo cual es necesario ir a la siguiente dirección <http://www.example.com> y comprobar como se balancean las peticiones entre los dos servidores web **nodo1** y **nodo2** (es necesario forzar la recarga, por ejemplo, con CTRL+F5).

## Documentación a Entregar
- Archivo de configuración de Bind (/var/lib/bind/db.example.com) con los registros A cambiados
- Dos ejecuciones del comando dig www.example.com, mostrando cómo alternan las IP de nodo1 (172.31.0.11) y nodo2 (172.31.0.12).

## Desechar el Escenario Correctamente

Cuando termines de trabajar con el escenario, puedes desecharlo haciendo lo siguiente:

~~~
vagrant destroy -f
sudo ./utils/dns-sistema.sh
~~~


