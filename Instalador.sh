#!/bin/bash

# Actualizar los repositorios
echo "Actualizando los repositorios..."
sudo apt update

# Instalar dependencias necesarias
echo "Instalando dependencias..."
sudo apt install -y software-properties-common wget gnupg2 lsb-release curl

# Instalar VirtualBox
echo "Instalando VirtualBox..."
sudo apt install -y virtualbox virtualbox-ext-pack

# Agregar la clave GPG de HashiCorp
echo "Agregando la clave GPG de HashiCorp..."
wget -O - https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg

# Agregar el repositorio de HashiCorp
echo "Agregando el repositorio de HashiCorp..."
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list

# Actualizar los paquetes e instalar Vagrant
echo "Instalando Vagrant..."
sudo apt update && sudo apt install -y vagrant

# Instalar Ansible
echo "Instalando Ansible..."
sudo apt install -y ansible

# Verificar las versiones instaladas
echo "Verificando las versiones de las herramientas instaladas..."
virtualbox --help | head -n 1
vagrant --version
ansible --version

echo "Instalación completada."

