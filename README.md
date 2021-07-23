# SIG - AlmaLinux Live Media

This git repository contains Kickstarts and other scripts
needed to produce the AlmaLinux LiveCD/DVD. 

Build requries AlmaLinux installed on a physical system `anaconda` and `lorax` packages installed

```sh
sudo livemedia-creator --project AlmaLinux --releasever 8 --make-iso --ks=kickstarts/almalinux-8-livecd.ks --no-virt
```

![image](https://user-images.githubusercontent.com/1273137/126790113-42c76349-cb33-4e21-a55a-fe59ff49459f.png)
