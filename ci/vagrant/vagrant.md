# Documentation of Vagrant

The Vagrantfiles was implemented using:
- AlmaLinux OS `9.2`
- Vagrant `2.3.7`
- [vagrant-libvirt](https://github.com/vagrant-libvirt/vagrant-libvirt) `0.12.2`
- ansible-core form Appstream `2.14.2-5`

[Virtio-fs](https://virtio-fs.gitlab.io) is chosen as synced folder type to bidirectionaly mount by multiple machines at the same time.

To take advantage of Ansible parallelism, `AlmaLinux_8_multi.rb` and `AlmaLinux_9_multi.rb` multi-machine Vagrantfiles are created for each major version of AlmaLinux OS. So, instead of executing Ansible provisiner in sequence for each machine, Vagrant only executes the Ansible provisioners once all the machines are up and ready.

## Steps to follow when add or remove a live media type

Add or remove the machine name of the new media type to the `media_types` array on all Vagrantfiles.

example for adding Pantheon:

```ruby
media_types = ['gnome', 'gnomemini', 'kde', 'xfce', 'mate', 'pantheon']
```

example for removing Pantheon:

```ruby
media_types = ['gnome', 'gnomemini', 'kde', 'xfce', 'mate']
```
