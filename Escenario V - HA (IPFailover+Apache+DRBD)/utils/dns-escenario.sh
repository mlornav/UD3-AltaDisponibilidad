#! /bin/bash

if [ ! $UID -eq 0 ];
then
	echo "Debes ejecutar este script como root"
	exit
fi

echo -n > /etc/resolv.conf
echo "nameserver 172.31.0.10" >> /etc/resolv.conf
echo "nameserver 8.8.8.8" >> /etc/resolv.conf
echo "search example.com" >> /etc/resolv.conf

