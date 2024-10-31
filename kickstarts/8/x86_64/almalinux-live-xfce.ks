# AlmaLinux Live Media (Beta - experimental), with optional install option.
# Build: sudo livecd-creator --cache=~/livecd-creator/package-cache -c almalinux-8-live-xfce.ks -f AlmaLinux-8-Live-XFCE
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
url --url=https://atl.mirrors.knownhost.com/almalinux/8/BaseOS/$basearch/os/
repo --name="appstream" --baseurl=https://atl.mirrors.knownhost.com/almalinux/8/AppStream/$basearch/os/
repo --name="extras" --baseurl=https://atl.mirrors.knownhost.com/almalinux/8/extras/$basearch/os/
repo --name="powertools" --baseurl=https://atl.mirrors.knownhost.com/almalinux/8/PowerTools/$basearch/os/
repo --name="epel" --baseurl=https://dl.fedoraproject.org/pub/epel/8/Everything/$basearch/

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

# remove random seed, the newly installed instance should make it's own
rm -f /var/lib/systemd/random-seed

# convince readahead not to collect
# FIXME: for systemd

echo 'File created by kickstart. See systemd-update-done.service(8).' \
    | tee /etc/.updated >/var/.updated

# Drop the rescue kernel and initramfs, we don't need them on the live media itself.
# See bug 1317709
rm -f /boot/*-rescue*

# Disable network service here, as doing it in the services line
# fails due to RHBZ #1369794
systemctl disable network

# Remove machine-id on pre generated images
rm -f /etc/machine-id
touch /etc/machine-id

# xfce configuration

# create /etc/sysconfig/desktop (needed for installation)

cat > /etc/sysconfig/desktop <<EOF
PREFERRED=/usr/bin/startxfce4
DISPLAYMANAGER=/usr/sbin/lightdm
EOF

# add bookmarks for popular folders on Thunar’s Places
cat > /var/lib/livesys/livesys-session-late-extra <<EOF
#!/bin/bash

gtk_user_path=/home/liveuser/.config/gtk-3.0
mkdir -p -m 0755 \$gtk_user_path
chown liveuser:liveuser \$gtk_user_path
for favorite in Documents Downloads Music Pictures Videos; do
  # That's good idea to check whether /home/liveuser/\$favorite exists,
  # but it does not at the time livesys-session-late-extra runs
  grep \$favorite \$gtk_user_path/bookmarks >/dev/null 2>&1 || echo "file:///home/liveuser/\$favorite" >> \$gtk_user_path/bookmarks
done
chown liveuser:liveuser \$gtk_user_path/bookmarks
EOF
chmod +x /var/lib/livesys/livesys-session-late-extra

# set livesys session type
sed -i 's/^livesys_session=.*/livesys_session="xfce"/' /etc/sysconfig/livesys

# enable PowerTools repo
dnf config-manager --enable powertools

%end

%post --nochroot
# cp $INSTALL_ROOT/usr/share/licenses/*-release/* $LIVE_ROOT/

# only works on x86, x86_64
if [ "$(uname -m)" = "i386" -o "$(uname -m)" = "x86_64" ]; then
  if [ ! -d $LIVE_ROOT/LiveOS ]; then mkdir -p $LIVE_ROOT/LiveOS ; fi
  cp /usr/bin/livecd-iso-to-disk $LIVE_ROOT/LiveOS
fi

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

# We don't provide any XFCE environment group, so mandatory groups are
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

# XFCE specific
@xfce-desktop
-gdm
lightdm
lightdm-gobject
lightdm-gtk
xfce4-about
xfce4-notifyd
xfce4-screenshooter
xfce4-taskmanager
xdg-user-dirs-gtk

# @xfce-apps packages
geany
gparted
mousepad
pidgin
ristretto
seahorse
transmission
xfce4-clipman-plugin
xfce4-dict-plugin

# @xfce-extra-plugins packages
xfce4-cpugraph-plugin
xfce4-eyes-plugin
xfce4-fsguard-plugin
xfce4-genmon-plugin
xfce4-mailwatch-plugin
xfce4-mount-plugin
xfce4-netload-plugin
xfce4-panel-profiles
xfce4-sensors-plugin
xfce4-systemload-plugin
xfce4-time-out-plugin
xfce4-verve-plugin
xfce4-weather-plugin
xfce4-whiskermenu-plugin
xfce4-xkb-plugin

# @xfce-media packages
parole

# save some space
-autofs
-acpid
-gimp-help
-desktop-backgrounds-basic
-aspell-*                   # dictionaries are big
-xfce4-sensors-plugin
-xfce4-eyes-plugin

# OpenVPN
openvpn
NetworkManager-openvpn

# minimization
-hplip

# Add alsa-sof-firmware to all images PR #51
alsa-sof-firmware
%end
