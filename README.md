# SIG - AlmaLinux Live Media

This git repository contains Kickstarts and other scripts needed to produce the AlmaLinux Live DVDs. Two ways to create/build this project. Using `docker` containers or `AlmaLinux` system.

## Using Live media

Live media ISO files are available at https://repo.almalinux.org/almalinux/8/live/x86_64/ or use mirrors https://mirrors.almalinux.org find a close one. Refer to project wiki https://wiki.almalinux.org/LiveMedia.html#about-live-media for detailed installation steps.

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
livecd-creator --config flat-gnome.ks \
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
livecd-creator --config flat-mini.ks \
               --fslabel AlmaLinux-8-LiveDVD-Mini \
               --title=AlmaLinux-8-LiveDVD \
               --product="AlmaLinux 8.5 Live" \
               --cache=$PWD/pkg-cache-alma \
               --releasever=8.5
```

Run following commands inside docker shell to build KDE live media.

```sh
ksflatten --config $PWD/kickstarts/almalinux-8-live-kde.ks --output flat-kde.ks
livecd-creator --config flat-kde.ks \
               --fslabel AlmaLinux-8-LiveDVD-KDE \
               --title=AlmaLinux-8-LiveDVD \
               --product="AlmaLinux 8 Live" \
               --cache=$PWD/pkg-cache-alma \
               --releasever=8.5
```

Run following commands inside docker shell to build XFCE live media.

```sh
ksflatten --config $PWD/kickstarts/almalinux-8-live-xfce.ks --output flat-xfce.ks
livecd-creator --config flat-xfce.ks \
               --fslabel AlmaLinux-8-LiveDVD-XFCE \
               --title=AlmaLinux-8-LiveDVD \
               --product="AlmaLinux 8.5 Live" \
               --cache=$PWD/pkg-cache-alma \
               --releasever=8.5
```

## Build using AlmaLinux System

### Build Environments

This project contains number of `KickStart` files to build live media for AlmaLiux. It uses `anaconda` and `livecd-tools` packages for ISO file build process. `livecd-tools` available in `epel` repos, enable prior to install.

`AlmaLinux` system installed on a physical or vitual system is prefered.

```sh
sudo dnf -y install epel-release
sudo dnf -y update
sudo dnf --enablerepo="powertools" --enablerepo="epel" install anaconda\
                livecd-tools \
                pykickstart \
                efibootmgr \
                efi-filesystem \
                efi-srpm-macros \
                efivar-libs \
                grub2-efi-*64 \
                grub2-efi-*64-cdboot \
                grub2-tools-efi \
                shim-*64
```

### Build ISOs

Local build proces takes `20-50 minutes` depends on number of CPU cores and internet speed. Minimum `15GB` work space for temporary files. Resulting ISO size ranges from `1.4GB` to `2.4GB` depends on build type. Execute following commands from root folder of sources.

Building `gnome live media`

```sh
rm -f $PWD/kickstarts/packages-gnome.txt
ln -s $PWD/kickstarts/packages-gnome-full.txt $PWD/kickstarts/packages-gnome.txt 
ksflatten --config $PWD/kickstarts/almalinux-8-live-gnome.ks --output flat-gnome.ks
sudo livecd-creator \
    --cache=~/livecd-creator/package-cache \
    -c flat-gnome.ks \
    -f AlmaLinux-8-Live-GNOME
 
```

Building `mini live media`

```sh
rm -f $PWD/kickstarts/packages-gnome.txt
ln -s $PWD/kickstarts/packages-gnome-mini.txt $PWD/kickstarts/packages-gnome.txt 
ksflatten --config $PWD/kickstarts/almalinux-8-live-gnome.ks --output flat-gnome.ks
sudo livecd-creator \
    --cache=~/livecd-creator/package-cache \
    -c flat-gnome.ks \
    -f AlmaLinux-8-Live-mini
```

Building `KDE live media`

```sh
ksflatten --config $PWD/kickstarts/almalinux-8-live-kde.ks --output flat-kde.ks
sudo livecd-creator \
    --cache=~/livecd-creator/package-cache \
    -c flat-kde.ks \
    -f AlmaLinux-8-Live-KDE
```

Building `XFCE live media`

```sh
ksflatten --config $PWD/kickstarts/almalinux-8-live-xfce.ks --output flat-xfce.ks
sudo livecd-creator \
    --cache=~/livecd-creator/package-cache \
    -c flat-xfce.ks \
    -f AlmaLinux-8-Live-XFCE
```

### Full live media

![image](https://user-images.githubusercontent.com/1273137/126790113-42c76349-cb33-4e21-a55a-fe59ff49459f.png)

### Minimal live media

![image](https://user-images.githubusercontent.com/1273137/126832606-52fc45c6-7bf2-4df0-b9c5-408e0b38af95.png)

### Live Media installer

Make adjustment to install options and start the install process.

![image](https://user-images.githubusercontent.com/1273137/126913694-e0f4ad15-e405-4764-a24c-8c63f5d5799c.png)

### Installer options

![image](https://user-images.githubusercontent.com/1273137/127050590-d52c0da5-320d-4489-8fcf-0059bc52d05d.png)

### Installer in progress

![image](https://user-images.githubusercontent.com/1273137/127050781-b9fb8284-bb7e-42f5-aa24-d7dfd7490965.png)

![image](https://user-images.githubusercontent.com/1273137/127051887-20990fe4-27e1-4133-b1f9-fa61bdce4e69.png)

![image](https://user-images.githubusercontent.com/1273137/127052376-2a8f88c9-a77e-4236-a721-6d502e35e0a7.png)

### Post install

Reboot the system, accept the license. Now system is ready to use.

![image](https://user-images.githubusercontent.com/1273137/127054222-2a94b1b5-b7ed-408c-9567-37dd105ddc91.png)

![image](https://user-images.githubusercontent.com/1273137/127054274-45668685-48c2-4dcb-800a-ccd7f8d4b2bd.png)

### Additional notes

* Current build scripts uses the AlmaLinux mirror closer to `US/East` zone. Use https://mirrors.almalinux.org to find and change different mirror.
* Use following commnd to generate package list to install `rpm -qa --qf "%{n}\n" | grep -v pubkey | sort > packages-name.txt`
* Make sure to use `--cache` for build process, it will help for faster build and less network traffic.'
