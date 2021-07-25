# SIG - AlmaLinux Live Media

This git repository contains Kickstarts and other scripts
needed to produce the AlmaLinux LiveCD/DVD. 

Build requries AlmaLinux installed on a physical system `anaconda` and `lorax` packages installed

### Build ISO

Building ISO using `livemedia-creator` command, fewer options.
```sh
sudo livemedia-creator --project AlmaLinux --releasever 8 --make-iso --ks=kickstarts/almalinux-8-live-gnome.ks --no-virt
```

Build with more options

```sh 
sudo livemedia-creator \
    --ks almalinux-8-live-minimal.ks \
    --no-virt --resultdir  ./iso1 \
    --project AlmaLinux-8-live \
    --make-iso \
    --iso-only \
    --iso-name almalinux-8-minimal.iso \
    --releasever 8 \
    --volid AlmaLinux-8-live \
    --title AlmaLinux-live
```

### Full live media

![image](https://user-images.githubusercontent.com/1273137/126790113-42c76349-cb33-4e21-a55a-fe59ff49459f.png)


### Minimal live media

![image](https://user-images.githubusercontent.com/1273137/126832606-52fc45c6-7bf2-4df0-b9c5-408e0b38af95.png)

### Live Media installer
![image](https://user-images.githubusercontent.com/1273137/126913694-e0f4ad15-e405-4764-a24c-8c63f5d5799c.png)


