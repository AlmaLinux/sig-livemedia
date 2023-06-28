# SIG - AlmaLinux Live Media

This git repository contains Kickstarts and other scripts needed to produce the AlmaLinux Live DVDs. Two ways to create/build this project. Using `docker` containers or `AlmaLinux` system.

## Using Live media

Live media ISO files are available at https://repo.almalinux.org/almalinux/8/live/x86_64/ and https://repo.almalinux.org/almalinux/9/live/x86_64/, or use mirrors https://mirrors.almalinux.org find a close one. Refer to project wiki https://wiki.almalinux.org/LiveMedia.html#about-live-media for detailed installation steps.

## Build using AlmaLinux System

`AlmaLinux` system installed on a physical or vitual system is required use these steps to live-media ISO files. This proces takes `20-50 minutes` depends on number of CPU cores and internet speed. Minimum `15GB` work space for temporary files. Resulting ISO size ranges from `1.4GB` to `2.4GB` depends on build type. Execute following commands from root folder of sources.


### Build Environments

This project contains number of `KickStart` files to build live media for AlmaLiux. It uses `anaconda` and `livecd-tools` or `lorax` packages for ISO file build process. Use following command to install necessary softwares to build this project. Make sure to reboot the system prior to run the build commands.

```sh
sudo dnf -y install epel-release
sudo dnf -y --enablerepo="epel" install anaconda-tui \
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

Run following commands to build GNOME live media.

```sh
sudo livecd-creator --config kickstarts/almalinux-8-live-gnome.ks \
               --fslabel AlmaLinux-8_8-x86_64-Live-GNOME \
               --title="AlmaLinux Live 8.8" \
               --product="AlmaLinux Live 8.8" \
               --cache=$PWD/pkg-cache-alma \
               --releasever=8.8
```

Run following commands to build GNOME Mini live media.

```sh
sudo livecd-creator --config kickstarts/almalinux-8-live-gnome-mini.ks \
               --fslabel AlmaLinux-8_8-x86_64-Live-Mini \
               --title="AlmaLinux Live 8.8" \
               --product="AlmaLinux Live 8.8" \
               --cache=$PWD/pkg-cache-alma \
               --releasever=8.8
```

Run following commands to build KDE live media.

```sh
sudo livecd-creator --config kickstarts/almalinux-8-live-kde.ks \
               --fslabel AlmaLinux-8_8-x86_64-Live-KDE \
               --title="AlmaLinux Live 8.8" \
               --product="AlmaLinux Live 8.8" \
               --cache=$PWD/pkg-cache-alma \
               --releasever=8.8
```

Run following commands to build XFCE live media.

```sh
sudo livecd-creator --config kickstarts/almalinux-8-live-xfce.ks \
               --fslabel AlmaLinux-8_8-x86_64-Live-XFCE \
               --title="AlmaLinux Live 8.8" \
               --product="AlmaLinux Live 8.8" \
               --cache=$PWD/pkg-cache-alma \
               --releasever=8.8
```

Run following commands to build MATE live media.

```sh
sudo livecd-creator --config kickstarts/almalinux-8-live-mate.ks \
               --fslabel AlmaLinux-8_8-x86_64-Live-MATE \
               --title="AlmaLinux Live 8.8" \
               --product="AlmaLinux Live 8.8" \
               --cache=$PWD/pkg-cache-alma \
               --releasever=8.8
```


### Build using `lorax`

Run following commands to build GNOME live media.

```sh
sudo livemedia-creator \
    --ks=kickstarts/almalinux-8-live-gnome.ks \
    --no-virt --resultdir  ./iso-gnome \
    --project "AlmaLinux Live" \
    --make-iso \
    --iso-only \
    --iso-name AlmaLinux-8.8-x86_64-Live-GNOME.iso \
    --releasever 8.8 \
    --volid "AlmaLinux-8_8-x86_64-Live-GNOME" \
    --nomacboot
```

Run following commands to build GNOME Mini live media.

```sh
sudo livemedia-creator \
    --ks=kickstarts/almalinux-8-live-gnome-mini.ks \
    --no-virt --resultdir ./iso-gnome-mini \
    --project "AlmaLinux Live" \
    --make-iso \
    --iso-only \
    --iso-name AlmaLinux-8.8-x86_64-Live-GNOME-Mini.iso \
    --releasever 8.8 \
    --volid "AlmaLinux-8_8-x86_64-Live-Mini" \
    --nomacboot
```

Run following commands to build KDE live media.

```sh
sudo livemedia-creator \
    --ks=kickstarts/almalinux-8-live-kde.ks \
    --no-virt --resultdir  ./iso-kde \
    --project "AlmaLinux Live" \
    --make-iso \
    --iso-only \
    --iso-name AlmaLinux-8.8-x86_64-Live-KDE.iso \
    --releasever 8.8 \
    --volid "AlmaLinux-8_8-x86_64-Live-KDE" \
    --nomacboot
```

Run following commands to build XFCE live media.

```sh
sudo livemedia-creator \
    --ks=kickstarts/almalinux-8-live-xfce.ks \
    --no-virt --resultdir  ./iso-xfce \
    --project "AlmaLinux Live" \
    --make-iso \
    --iso-only \
    --iso-name AlmaLinux-8.8-x86_64-Live-XFCE.iso \
    --releasever 8.8 \
    --volid "AlmaLinux-8_8-x86_64-Live-XFCE" \
    --nomacboot
```

### Additional notes

* Current build scripts uses the AlmaLinux mirror closer to `US/East` zone. Use https://mirrors.almalinux.org to find and change different mirror.
* Use following commnd to generate package list to install `rpm -qa --qf "%{n}\n" | grep -v pubkey | sort > packages-name.txt`
* Make sure to use `--cache` for build process, it will help for faster build and less network traffic.'
