# -*- mode: ruby -*-
# # vi: set ft=ruby :
 
# Indicar la versión mínima de Vagrant y la versión de la API del Vagrantfile
Vagrant.require_version ">= 1.8"
VAGRANTFILE_API_VERSION = "2"
 
# Requiere el módulo YAML
require 'yaml'
 
# Leer el archivo YAML con los detalles de las máquinas virtuales
stage = YAML.load_file(File.join(File.dirname(__FILE__), 'Vagrantfile.yml'))
prefix = stage['prefix']
servers = stage['servers']

# Crear máquinas virtuales
Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  # Utilizar plugin vagrant-cachier si está disponible
  if Vagrant.has_plugin?("vagrant-cachier")
    config.cache.scope = :box
  end

  # No sustituir la clave privada insegura de Vagrant
  config.ssh.insert_key = false
 
  # Iterar sobre las entradas del archivo YAML
  servers.each do |server|
    config.vm.define server['name'] do |machine|

      machine.vm.box = server['box']
      machine.vm.network "private_network", ip: server['ip'], :netmask => server['mask']

      machine.vm.provider :virtualbox do |vb|
        # Crear clones enlazados
        vb.linked_clone = true

        vb.name = prefix + '_' + server['name']
        vb.memory = server['ram']
      end # vb
    end # machine
  end # server
end # config

