# SIG - AlmaLinux Live Media

This git repository contains Kickstarts and other scripts needed to produce the AlmaLinux Live DVDs. Two ways to create/build this project. Using `docker` containers or `AlmaLinux` system.

## Using Live media

Live media ISO files are available at https://repo.almalinux.org/almalinux/8/live/x86_64/ or use mirrors https://mirrors.almalinux.org find a close one. Refer to project wiki https://wiki.almalinux.org/LiveMedia.html#about-live-media for detailed installation steps.

## Build using AlmaLinux System

`AlmaLinux` system installed on a physical or vitual system is required use these steps to live-media ISO files. This proces takes `20-50 minutes` depends on number of CPU cores and internet speed. Minimum `15GB` work space for temporary files. Resulting ISO size ranges from `1.4GB` to `2.4GB` depends on build type. Execute following commands from root folder of sources.


### Build Environments

This project contains number of `KickStart` files to build live media for AlmaLiux. It uses `anaconda` and `livecd-tools` or `lorax` packages for ISO file build process. Use following command to install necessary softwares to build this project. Make sure to reboot the system prior to run the build commands.

```sh
sudo dnf -y install epel-release elrepo-release
sudo dnf -y update
sudo dnf --enablerepo="powertools" --enablerepo="epel" install anaconda-tui \
                livecd-tools \
                lorax \
                subscription-manager \
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

### Build using `livecd-tools`

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


### Build using `lorax`

Run following commands inside docker shell to build Gnome live media. Remove old symbolic link to packages, choose right package and run build commands.

```sh
rm -f $PWD/kickstarts/packages-gnome.txt
ln -s $PWD/kickstarts/packages-gnome-full.txt $PWD/kickstarts/packages-gnome.txt 
ksflatten --config $PWD/kickstarts/almalinux-8-live-gnome.ks --output flat-gnome.ks
sed -i 's/repo --name="baseos" --base/url --/' $PWD/flat-gnome.ks &>/dev/null
sudo livemedia-creator \
    --ks=flat-gnome.ks \
    --no-virt --resultdir  ./iso \
    --project "AlmaLinux live gnome" \
    --make-iso \
    --iso-only \
    --iso-name almalinux-8-live-gnome.iso \
    --releasever 8 \
    --volid "AlmaLinux 8 live" \
    --title "AlmaLinux 8" \
    --nomacboot 
```

Run following commands inside docker shell to build Gnome Mini live media.

```sh
rm -f $PWD/kickstarts/packages-gnome.txt
ln -s $PWD/kickstarts/packages-gnome-mini.txt $PWD/kickstarts/packages-gnome.txt 
ksflatten --config $PWD/kickstarts/almalinux-8-live-gnome.ks --output flat-mini.ks
sed -i 's/repo --name="baseos" --base/url --/' $PWD/flat-mini.ks &>/dev/null
sudo livemedia-creator \
    --ks=flat-mini.ks \
    --no-virt --resultdir  ./iso \
    --project "AlmaLinux live gnome" \
    --make-iso \
    --iso-only \
    --iso-name almalinux-8-live-mini.iso \
    --releasever 8 \
    --volid "AlmaLinux 8 live" \
    --title "AlmaLinux 8" \
    --nomacboot 
```

Run following commands inside docker shell to build KDE live media.

```sh
ksflatten --config $PWD/kickstarts/almalinux-8-live-kde.ks --output flat-kde.ks
sed -i 's/repo --name="baseos" --base/url --/' $PWD/flat-kde.ks &>/dev/null
sudo livemedia-creator \
    --ks=flat-kde.ks \
    --no-virt --resultdir  ./iso \
    --project "AlmaLinux live kde" \
    --make-iso \
    --iso-only \
    --iso-name almalinux-8-live-kde.iso \
    --releasever 8 \
    --volid "AlmaLinux 8 live" \
    --title "AlmaLinux 8" \
    --nomacboot 

```

Run following commands inside docker shell to build XFCE live media.

```sh
ksflatten --config $PWD/kickstarts/almalinux-8-live-xfce.ks --output flat-xfce.ks
sed -i 's/repo --name="baseos" --base/url --/' $PWD/flat-xfce.ks &>/dev/null
sudo livemedia-creator \
    --ks=flat-xfce.ks \
    --no-virt --resultdir  ./iso \
    --project "AlmaLinux live xfce" \
    --make-iso \
    --iso-only \
    --iso-name almalinux-8-live-xfce.iso \
    --releasever 8 \
    --volid "AlmaLinux 8 live" \
    --title "AlmaLinux 8" \
    --nomacboot 

```

### Additional notes

* Current build scripts uses the AlmaLinux mirror closer to `US/East` zone. Use https://mirrors.almalinux.org to find and change different mirror.
* Use following commnd to generate package list to install `rpm -qa --qf "%{n}\n" | grep -v pubkey | sort > packages-name.txt`
* Make sure to use `--cache` for build process, it will help for faster build and less network traffic.'
