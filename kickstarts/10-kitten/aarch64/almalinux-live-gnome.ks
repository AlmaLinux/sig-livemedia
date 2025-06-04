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
url --url=https://kitten.repo.almalinux.org/10-kitten/BaseOS/$basearch/os/
repo --name="appstream" --baseurl=https://kitten.repo.almalinux.org/10-kitten/AppStream/$basearch/os/
repo --name="extras" --baseurl=https://kitten.repo.almalinux.org/10-kitten/extras-common/$basearch/os/
repo --name="crb" --baseurl=https://kitten.repo.almalinux.org/10-kitten/CRB/$basearch/os/
repo --name="epel" --baseurl=https://dl.fedoraproject.org/pub/epel/10/Everything/$basearch/

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

# TODO: To place Firefox into Task Manager
# This should be removed when upstream fixes the livesys-scripts package
sed -i  's/org.mozilla.firefox.desktop/firefox.desktop/g' /usr/libexec/livesys/sessions.d/livesys-gnome
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

# libreoffice group
#@office-suite

# internet-browser group
firefox

# Workstation environment group (mandatory)
@core
@standard
#@base-x
@fonts
@guest-desktop-agents
@hardware-support
@multimedia
@networkmanager-submodules
@print-client

# Workstation environment group (optional)
#@backup-client
@headless-management
# internet-applications group
#evolution
#evolution-ews
#evolution-help
#evolution-mapi
#hexchat
thunderbird
@remote-desktop-clients
@smart-card

# GNOME specific
@gnome-desktop
#@gnome-apps

# Exclude unwanted packages from @anaconda-tools group
-gfs2-utils
-reiserfs-utils

# Workstation specific
bash-color-prompt
exfatprogs
fpaste
iptstate
nss-mdns
#ntfs-3g
#ntfsprogs
policycoreutils-python-utils
psmisc
python3-dnf-plugin-system-upgrade
toolbox
#unoconv
uresourced
whois

# EPEL repo
epel-release

# OpenVPN
openvpn
NetworkManager-openvpn
NetworkManager-openvpn-gnome

# minimization
-hplip
%end
