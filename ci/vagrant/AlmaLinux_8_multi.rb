# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure('2') do |config|
  config.vagrant.plugins = 'vagrant-libvirt'

  config.vm.synced_folder '.', '/vagrant', type: 'virtiofs'

  config.vm.provider 'libvirt' do |v|
    v.uri = 'qemu:///system'
    v.memory = 8192
    v.memorybacking :access, mode: 'shared'
    v.machine_type = 'q35'
    v.cpu_mode = 'host-passthrough'
    v.cpus = 8
    v.disk_bus = 'scsi'
    v.disk_driver cache: 'writeback', discard: 'unmap'
    v.random_hostname = true
    v.management_network_keep = true
  end

  media_types = ['gnome', 'gnomemini', 'kde', 'xfce', 'mate']

  media_types.each do |media_type|
    config.vm.define "almalinux_8_#{media_type}" do |machine|
      machine.vm.box = 'almalinux/8'
      machine.vm.hostname = "livemediabuilder-8-#{media_type}.test"

      if media_type == media_types[-1]
        machine.vm.provision 'ansible' do |ansible|
          ansible.compatibility_mode = '2.0'
          ansible.limit = 'all'
          ansible.playbook = 'ci/ansible/configure_builder.yaml'
          ansible.config_file = 'ci/ansible/ansible.cfg'
        end
      end
    end
  end
end
