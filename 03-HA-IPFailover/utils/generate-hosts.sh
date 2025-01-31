#! /bin/bash

if [ $UID -eq 0 ];
then
	echo "Debes ejecutar este script como un usuario distinto a root"
	exit
fi

HOST_FILE="hosts"

echo Generating Ansible inventory file for Vagrant machines running...
	
echo "# inventory file for local development" > $HOST_FILE
echo >> $HOST_FILE
echo "[default]" >> $HOST_FILE

vagrant ssh-config | awk '/^Host/ { print $2 }' | while read HOST
do
	IP=`vagrant ssh-config $HOST | awk '/HostName/ { print $2 }'`
	PORT=`vagrant ssh-config $HOST | awk '/Port/ { print $2 }'`
	USER=`vagrant ssh-config $HOST | awk '/User[[:blank:]]/ { print $2 }'`

	echo "$HOST ansible_ssh_host=$IP ansible_ssh_port=$PORT ansible_ssh_user=$USER"
	echo "$HOST ansible_ssh_host=$IP ansible_ssh_port=$PORT ansible_ssh_user=$USER" >> $HOST_FILE
done
