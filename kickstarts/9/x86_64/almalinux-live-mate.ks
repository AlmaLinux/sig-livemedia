#version=DEVEL
# X Window System configuration information
xconfig  --startxonboot
# Keyboard layouts
keyboard 'us'
# Root password
rootpw --plaintext rootme
# System language
lang en_US.UTF-8
# Shutdown after installation
shutdown
# System timezone
timezone US/Eastern
# Network information
network  --bootproto=dhcp --device=link --activate

# Repos
url --url=https://atl.mirrors.knownhost.com/almalinux/9/BaseOS/$basearch/os/
repo --name="appstream" --baseurl=https://atl.mirrors.knownhost.com/almalinux/9/AppStream/$basearch/os/
repo --name="extras" --baseurl=https://atl.mirrors.knownhost.com/almalinux/9/extras/$basearch/os/
repo --name="crb" --baseurl=https://atl.mirrors.knownhost.com/almalinux/9/CRB/$basearch/os/
repo --name="epel" --baseurl=https://dl.fedoraproject.org/pub/epel/9/Everything/$basearch/

# Firewall configuration
firewall --enabled --service=mdns
# SELinux configuration
selinux --enforcing

# System services
services --disabled="sshd" --enabled="NetworkManager,ModemManager"
# System bootloader configuration
bootloader --location=none
# Partition clearing information
clearpart --all --initlabel
# Disk partitioning information
part / --size=10238

%post

systemctl enable --force lightdm.service

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
sed -i 's/^livesys_session=.*/livesys_session="mate"/' /etc/sysconfig/livesys

if [ -f /etc/lightdm/slick-greeter.conf ]; then
  mv /etc/lightdm/slick-greeter.conf  /etc/lightdm/slick-greeter.conf_saved
fi
cat > /etc/lightdm/slick-greeter.conf << SLK_EOF
[Greeter]
logo=
SLK_EOF

# enable CRB repo
dnf config-manager --enable crb

# Workaround to add openvpn user and group in case they didn't added during
# openvpn package installation
getent group openvpn &>/dev/null || groupadd -r openvpn
getent passwd openvpn &>/dev/null || \
    /usr/sbin/useradd -r -g openvpn -s /sbin/nologin -c OpenVPN \
        -d /etc/openvpn openvpn

%end

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
aajohan-comfortaa-fonts

# Without this, initramfs generation during live image creation fails: #1242586
dracut-live

# anaconda needs the locales available to run for different locales
glibc-all-langpacks

# provide the livesys scripts
livesys-scripts

# Mandatory to build media with livemedia-creator
memtest86+

# libreoffice group
@office-suite
# firefox
@internet-browser

# We don't provide any MATE environment group, so mandatory groups are
@networkmanager-submodules
@dial-up
@fonts
@guest-desktop-agents
@hardware-support
@input-methods
@multimedia
@print-client
@standard
@base-x

# MATE specific
ccsm
simple-ccsm
emerald-themes
emerald

# blacklist applications which breaks mate-desktop
-audacious

# FIXME; apparently the glibc maintainers dislike this, but it got put into the
# desktop image at some point.  We won't touch this one for now.
nss-mdns

# Drop things for size
-@3d-printing
-@admin-tools
-brasero
-gnome-icon-theme
-gnome-icon-theme-symbolic
-gnome-logs
-gnome-software
-gnome-user-docs

# Help and art can be big, too
-gnome-user-docs
-evolution-help

# Legacy cmdline things we don't want
-telnet

# @mate-desktop
NetworkManager-l2tp-gnome
NetworkManager-libreswan-gnome
NetworkManager-openconnect-gnome
NetworkManager-ovs
NetworkManager-ppp
NetworkManager-pptp-gnome
atril
atril-caja
atril-thumbnailer
caja
caja-actions
caja-image-converter
caja-open-terminal
caja-sendto
caja-wallpaper
caja-xattr-tags
dconf-editor
engrampa
eom
filezilla
firewall-config
gnome-disk-utility
gnome-epub-thumbnailer
gnome-logs
gnome-themes-extra
gparted
gtk2-engines
gucharmap
gvfs-fuse
gvfs-gphoto2
gvfs-mtp
gvfs-smb
hexchat
initial-setup-gui
libmatekbd
libmatemixer
libmateweather
libsecret
lightdm
lm_sensors
marco
mate-applets
mate-backgrounds
mate-calc
mate-control-center
mate-desktop
mate-dictionary
mate-disk-usage-analyzer
mate-icon-theme
mate-media
mate-menus
mate-menus-preferences-category-menu
mate-notification-daemon
mate-panel
mate-polkit
mate-power-manager
mate-screensaver
mate-screenshot
mate-search-tool
mate-session-manager
mate-settings-daemon
mate-system-log
mate-system-monitor
mate-terminal
mate-themes
mate-user-admin
mate-user-guide
mozo
network-manager-applet
nm-connection-editor
orca
p7zip
p7zip-plugins
parole
pluma
seahorse
seahorse-caja
setroubleshoot
simple-scan
slick-greeter-mate
system-config-printer
system-config-printer-applet
thunderbird
transmission-gtk
usermode-gtk
wireplumber
xdg-user-dirs-gtk
xmodmap
xrdb
yelp

# @mate-applications
caja-beesu
caja-share
firewall-applet
mate-menu
mate-sensors-applet
mate-utils
pidgin
pluma-plugins
tigervnc

# minimization
-hplip

# OpenVPN
openvpn
NetworkManager-openvpn

# Add alsa-sof-firmware to all images PR #51
alsa-sof-firmware
%end
