# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure(2) do |config|

  config.vm.box = "landregistry/centos"
  config.vm.box_check_update = true

  # Manage Virtualbox Guest Additions
  if Vagrant.has_plugin?("vagrant-vbguest")
    config.vbguest.auto_update = false
  end

  # Use shared Cachier cache
  if Vagrant.has_plugin?("vagrant-cachier")
    config.cache.scope = :box
  end

  # Forward server ports
  config.vm.network "forwarded_port", guest: 27015, host: 27015, protocol: 'tcp'
  config.vm.network "forwarded_port", guest: 27015, host: 27015, protocol: 'udp'
  config.vm.network "forwarded_port", guest: 27020, host: 27020, protocol: 'udp'

  # Set memory for VM in VirtualBox
  config.vm.provider :virtualbox do |vb|
    vb.customize ['modifyvm', :id, '--memory', "2048"]
  end

  # Run setup script
  config.vm.provision :shell,
    path: 'setup.sh'

end
