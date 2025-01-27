#! /bin/bash

if [ ! $UID -eq 0 ];
then
	echo "Debes ejecutar este script como root"
	exit
fi

systemctl restart systemd-resolved.service
