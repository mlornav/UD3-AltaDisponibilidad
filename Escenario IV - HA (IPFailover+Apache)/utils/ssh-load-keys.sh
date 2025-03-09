#! /bin/bash

if [ $UID -eq 0 ];
then
	echo "Debes ejecutar este script como un usuario distinto a root"
	exit
fi

#ssh-add ~/.vagrant.d/insecure_private_key

vagrant ssh-config | awk '/IdentityFile/ { print $2 }' | while read KEY
do
	ssh-add "$KEY"
done
