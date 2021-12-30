# Building LiveMedia using docker

## Build Environment

Repo live images can be build using AlmaLinux using `almalinux/ks2rootfs:all-in-one` docker image utility OR using an AlmaLinux physical or virtual machine.

### Using `almalinux/ks2rootfs:all-in-one` docker image

Project root directory is mapped to `build` directory inside docker container as below.

```sh
docker pull almalinux/ks2rootfs:all-in-one
docker run --privileged --rm -it -v "$PWD:/build:z" almalinux/ks2rootfs:all-in-one /bin/bash
```

Run following commands inside docker shell to build Gnome live media. Remove old symbolic link to packages, choose right package and run build commands.

```sh
rm -f $PWD/kickstarts/packages-gnome.txt
ln -s $PWD/kickstarts/packages-gnome-full.txt $PWD/kickstarts/packages-gnome.txt 
ksflatten --config $PWD/kickstarts/almalinux-8-live-gnome.ks --output flat-gnome.ks
sudo livecd-creator --config flat-gnome.ks \
               --fslabel AlmaLinux-8-LiveDVD-Gnome \
               --title=AlmaLinux-8-LiveDVD \
               --product="AlmaLinux 8.5 Live" \
               --cache=$PWD/pkg-cache-alma \
               --releasever=8.5
```

Run following commands inside docker shell to build Gnome Mini live media.

```sh
rm -f $PWD/kickstarts/packages-gnome.txt
ln -s $PWD/kickstarts/packages-gnome-mini.txt $PWD/kickstarts/packages-gnome.txt 
ksflatten --config $PWD/kickstarts/almalinux-8-live-gnome.ks --output flat-mini.ks
sudo livecd-creator --config flat-mini.ks \
               --fslabel AlmaLinux-8-LiveDVD-Mini \
               --title=AlmaLinux-8-LiveDVD \
               --product="AlmaLinux 8.5 Live" \
               --cache=$PWD/pkg-cache-alma \
               --releasever=8.5
```

Run following commands inside docker shell to build KDE live media.

```sh
ksflatten --config $PWD/kickstarts/almalinux-8-live-kde.ks --output flat-kde.ks
sudo livecd-creator --config flat-kde.ks \
               --fslabel AlmaLinux-8-LiveDVD-KDE \
               --title=AlmaLinux-8-LiveDVD \
               --product="AlmaLinux 8 Live" \
               --cache=$PWD/pkg-cache-alma \
               --releasever=8.5
```

Run following commands inside docker shell to build XFCE live media.

```sh
ksflatten --config $PWD/kickstarts/almalinux-8-live-xfce.ks --output flat-xfce.ks
sudo livecd-creator --config flat-xfce.ks \
               --fslabel AlmaLinux-8-LiveDVD-XFCE \
               --title=AlmaLinux-8-LiveDVD \
               --product="AlmaLinux 8.5 Live" \
               --cache=$PWD/pkg-cache-alma \
               --releasever=8.5
```
