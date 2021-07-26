# SIG - AlmaLinux Live Media

This git repository contains Kickstarts and other scripts
needed to produce the AlmaLinux LiveCD/DVD. 

Build requries AlmaLinux installed on a physical system `anaconda` and `lorax` packages installed

### Build ISO

Building ISO using `livemedia-creator` command, fewer options. The build output will be available at `/var/tmp/lmc-XXXX`, check build output for folder name. 

```sh
sudo livemedia-creator --project AlmaLinux --releasever 8 --make-iso --ks=kickstarts/almalinux-8-live-gnome.ks --no-virt
```

Build with extended options, building `gnome live media`

```sh
sudo livemedia-creator \
    --ks=kickstarts/almalinux-8-live-gnome.ks \
    --no-virt --resultdir  ./iso \
    --project "AlmaLinux 8 live" \
    --make-iso \
    --iso-only \
    --iso-name almalinux-8-live-gnome.iso \
    --releasever 8 \
    --volid AlmaLinux-8-live \
    --title "AlmaLinux 8 live"
```

Building `mini live media`

```sh
sudo livemedia-creator \
    --ks=kickstarts/almalinux-8-live-mini.ks \
    --no-virt --resultdir  ./iso \
    --project "AlmaLinux 8 mini live" \
    --make-iso \
    --iso-only \
    --iso-name almalinux-8-live-mini.iso \
    --releasever 8 \
    --volid AlmaLinux-8-live-mini \
    --title "AlmaLinux 8 live"
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

