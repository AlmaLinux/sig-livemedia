# AlmaLinux Live Media (Beta - experimental), with optional install option.
# Build: sudo livecd-creator --cache=~/livecd-creator/package-cache -c almalinux-8-live-gnome.ks -f AlmaLinux-8-Live-gnome
# X Window System configuration information
xconfig  --startxonboot
# Keyboard layouts
keyboard 'us'

# System timezone
timezone US/Eastern
# System language
lang en_US.UTF-8
# Firewall configuration
firewall --enabled --service=mdns

# Repos
# url --url=https://repo.almalinux.org/almalinux/10/BaseOS/x86_64_v2/os/
url --url=https://vault.almalinux.org/10.0-beta/BaseOS/x86_64_v2/os/
# repo --name="appstream" --baseurl=https://repo.almalinux.org/almalinux/10/AppStream/x86_64_v2/os/
repo --name="appstream" --baseurl=https://vault.almalinux.org/10.0-beta/AppStream/x86_64_v2/os/
# repo --name="extras" --baseurl=https://repo.almalinux.org/almalinux/10/extras/x86_64_v2/os/
repo --name="extras" --baseurl=https://vault.almalinux.org/10.0-beta/extras/x86_64_v2/os/
# repo --name="crb" --baseurl=https://repo.almalinux.org/almalinux/10/CRB/x86_64_v2/os/
repo --name="crb" --baseurl=https://vault.almalinux.org/10.0-beta/CRB/x86_64_v2/os/
repo --name="livesys-scripts" --baseurl=https://build.almalinux.org/pulp/content/builds/AlmaLinux-Kitten-10-x86_64_v2-20702-br/

# Network information
network --activate --bootproto=dhcp --device=link --onboot=on

# SELinux configuration
selinux --enforcing

# System services
services --disabled="sshd" --enabled="NetworkManager,ModemManager"

# livemedia-creator modifications.
shutdown
# System bootloader configuration
bootloader --location=none
# Clear blank disks or all existing partitions
clearpart --all --initlabel
rootpw rootme
# Disk partitioning information
part / --size=10238

%post
# Enable livesys services
systemctl enable livesys.service
systemctl enable livesys-late.service

# enable tmpfs for /tmp
systemctl enable tmp.mount

# make it so that we don't do writing to the overlay for things which
# are just tmpdirs/caches
# note https://bugzilla.redhat.com/show_bug.cgi?id=1135475
cat >> /etc/fstab << EOF
vartmp   /var/tmp    tmpfs   defaults   0  0
EOF

# work around for poor key import UI in PackageKit
rm -f /var/lib/rpm/__db*
# import AlmaLinux PGP key
rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-AlmaLinux
echo "Packages within this LiveCD"
rpm -qa
# Note that running rpm recreates the rpm db files which aren't needed or wanted
rm -f /var/lib/rpm/__db*

# go ahead and pre-make the man -k cache (#455968)
/usr/bin/mandb

# make sure there aren't core files lying around
rm -f /core*

# convince readahead not to collect
# FIXME: for systemd

echo 'File created by kickstart. See systemd-update-done.service(8).' \
    | tee /etc/.updated >/var/.updated

# Remove random-seed
rm /var/lib/systemd/random-seed

# Remove the rescue kernel and image to save space
# Installation will recreate these on the target
rm -f /boot/*-rescue*

# Disable network service here, as doing it in the services line
# fails due to RHBZ #1369794
systemctl disable network

# Remove machine-id on pre generated images
rm -f /etc/machine-id
touch /etc/machine-id

# set livesys session type
sed -i 's/^livesys_session=.*/livesys_session="gnome"/' /etc/sysconfig/livesys

# Workaround to add openvpn user and group in case they didn't added during
# openvpn package installation
getent group openvpn &>/dev/null || groupadd -r openvpn
getent passwd openvpn &>/dev/null || \
    /usr/sbin/useradd -r -g openvpn -s /sbin/nologin -c OpenVPN \
        -d /etc/openvpn openvpn

%end

# Packages
%packages
# Explicitly specified mandatory packages
kernel
kernel-modules
kernel-modules-extra

# The point of a live image is to install
anaconda
anaconda-install-env-deps
# TODO: "Install to Hard Drive" temporary disabled because of https://github.com/rhinstaller/anaconda/discussions/5997
anaconda-live
@anaconda-tools
# Anaconda has a weak dep on this and we don't want it on livecds, see
# https://fedoraproject.org/wiki/Changes/RemoveDeviceMapperMultipathFromWorkstationLiveCD
-fcoe-utils
-sdubby

# Need aajohan-comfortaa-fonts for the SVG rnotes images
#aajohan-comfortaa-fonts

# Without this, initramfs generation during live image creation fails: #1242586
dracut-live

# anaconda needs the locales available to run for different locales
glibc-all-langpacks

# provide the livesys scripts
livesys-scripts

# Memtest boot option
memtest86+

# firefox
#@internet-browser
firefox

# Workstation environment group
@^workstation-product-environment

# Workstation specific
-@workstation-product

# GNOME specific
@gnome-desktop

# OpenVPN
#openvpn
#NetworkManager-openvpn
#NetworkManager-openvpn-gnome

# Exclude unwanted packages from @anaconda-tools group
-gfs2-utils
-reiserfs-utils

# minimization
-hplip
%end
