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
url --url=https://rsync.repo.almalinux.org/almalinux/8/BaseOS/$basearch/os/
repo --name="appstream" --baseurl=https://rsync.repo.almalinux.org/almalinux/8/AppStream/$basearch/os/
repo --name="extras" --baseurl=https://rsync.repo.almalinux.org/almalinux/8/extras/$basearch/os/
repo --name="powertools" --baseurl=https://rsync.repo.almalinux.org/almalinux/8/PowerTools/$basearch/os/
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
# FIXME: it'd be better to get this installed from a package
cat > /etc/rc.d/init.d/livesys << EOF
#!/bin/bash
#
# live: Init script for live image
#
# chkconfig: 345 00 99
# description: Init script for live image.
### BEGIN INIT INFO
# X-Start-Before: display-manager
### END INIT INFO

. /etc/init.d/functions

if ! strstr "\`cat /proc/cmdline\`" rd.live.image || [ "\$1" != "start" ]; then
    exit 0
fi

if [ -e /.liveimg-configured ] ; then
    configdone=1
fi

exists() {
    which \$1 >/dev/null 2>&1 || return
    \$*
}

livedir="LiveOS"
for arg in \`cat /proc/cmdline\` ; do
  if [ "\${arg##rd.live.dir=}" != "\${arg}" ]; then
    livedir=\${arg##rd.live.dir=}
    return
  fi
  if [ "\${arg##live_dir=}" != "\${arg}" ]; then
    livedir=\${arg##live_dir=}
    return
  fi
done

# enable swaps unless requested otherwise
swaps=\`blkid -t TYPE=swap -o device\`
if ! strstr "\`cat /proc/cmdline\`" noswap && [ -n "\$swaps" ] ; then
  for s in \$swaps ; do
    action "Enabling swap partition \$s" swapon \$s
  done
fi
if ! strstr "\`cat /proc/cmdline\`" noswap && [ -f /run/initramfs/live/\${livedir}/swap.img ] ; then
  action "Enabling swap file" swapon /run/initramfs/live/\${livedir}/swap.img
fi

mountPersistentHome() {
  # support label/uuid
  if [ "\${homedev##LABEL=}" != "\${homedev}" -o "\${homedev##UUID=}" != "\${homedev}" ]; then
    homedev=\`/sbin/blkid -o device -t "\$homedev"\`
  fi

  # if we're given a file rather than a blockdev, loopback it
  if [ "\${homedev##mtd}" != "\${homedev}" ]; then
    # mtd devs don't have a block device but get magic-mounted with -t jffs2
    mountopts="-t jffs2"
  elif [ ! -b "\$homedev" ]; then
    loopdev=\`losetup -f\`
    if [ "\${homedev##/run/initramfs/live}" != "\${homedev}" ]; then
      action "Remounting live store r/w" mount -o remount,rw /run/initramfs/live
    fi
    losetup \$loopdev \$homedev
    homedev=\$loopdev
  fi

  # if it's encrypted, we need to unlock it
  if [ "\$(/sbin/blkid -s TYPE -o value \$homedev 2>/dev/null)" = "crypto_LUKS" ]; then
    echo
    echo "Setting up encrypted /home device"
    plymouth ask-for-password --command="cryptsetup luksOpen \$homedev EncHome"
    homedev=/dev/mapper/EncHome
  fi

  # and finally do the mount
  mount \$mountopts \$homedev /home
  # if we have /home under what's passed for persistent home, then
  # we should make that the real /home.  useful for mtd device on olpc
  if [ -d /home/home ]; then mount --bind /home/home /home ; fi
  [ -x /sbin/restorecon ] && /sbin/restorecon /home
  if [ -d /home/liveuser ]; then USERADDARGS="-M" ; fi
}

findPersistentHome() {
  for arg in \`cat /proc/cmdline\` ; do
    if [ "\${arg##persistenthome=}" != "\${arg}" ]; then
      homedev=\${arg##persistenthome=}
      return
    fi
  done
}

if strstr "\`cat /proc/cmdline\`" persistenthome= ; then
  findPersistentHome
elif [ -e /run/initramfs/live/\${livedir}/home.img ]; then
  homedev=/run/initramfs/live/\${livedir}/home.img
fi

# if we have a persistent /home, then we want to go ahead and mount it
if ! strstr "\`cat /proc/cmdline\`" nopersistenthome && [ -n "\$homedev" ] ; then
  action "Mounting persistent /home" mountPersistentHome
fi

if [ -n "\$configdone" ]; then
  exit 0
fi

### TODO: Review and finalize the location of anaconda-live package, experimental - starts
# dnf install https://dfw.mirror.rackspace.com/almalinux/8/devel/x86_64/os/Packages/anaconda-live-33.16.4.15-1.el8.alma.x86_64.rpm
### TODO: ends

# add liveuser with no passwd
action "Adding live user" useradd \$USERADDARGS -c "Live System User" liveuser
passwd -d liveuser > /dev/null
usermod -aG wheel liveuser > /dev/null

# Remove root password lock
passwd -d root > /dev/null

# turn off firstboot for livecd boots
systemctl --no-reload disable firstboot-text.service 2> /dev/null || :
systemctl --no-reload disable firstboot-graphical.service 2> /dev/null || :
systemctl stop firstboot-text.service 2> /dev/null || :
systemctl stop firstboot-graphical.service 2> /dev/null || :

# don't use prelink on a running live image
sed -i 's/PRELINKING=yes/PRELINKING=no/' /etc/sysconfig/prelink &>/dev/null || :

# turn off mdmonitor by default
systemctl --no-reload disable mdmonitor.service 2> /dev/null || :
systemctl --no-reload disable mdmonitor-takeover.service 2> /dev/null || :
systemctl stop mdmonitor.service 2> /dev/null || :
systemctl stop mdmonitor-takeover.service 2> /dev/null || :

# don't enable the gnome-settings-daemon packagekit plugin
gsettings set org.gnome.software download-updates 'false' || :

# don't start cron/at as they tend to spawn things which are
# disk intensive that are painful on a live image
systemctl --no-reload disable crond.service 2> /dev/null || :
systemctl --no-reload disable atd.service 2> /dev/null || :
systemctl stop crond.service 2> /dev/null || :
systemctl stop atd.service 2> /dev/null || :

# Don't sync the system clock when running live (RHBZ #1018162)
sed -i 's/rtcsync//' /etc/chrony.conf

# Mark things as configured
touch /.liveimg-configured

# add static hostname to work around xauth bug
# https://bugzilla.redhat.com/show_bug.cgi?id=679486
echo "localhost" > /etc/hostname

EOF

# bah, hal starts way too late
cat > /etc/rc.d/init.d/livesys-late << EOF
#!/bin/bash
#
# live: Late init script for live image
#
# chkconfig: 345 99 01
# description: Late init script for live image.

. /etc/init.d/functions

if ! strstr "\`cat /proc/cmdline\`" rd.live.image || [ "\$1" != "start" ] || [ -e /.liveimg-late-configured ] ; then
    exit 0
fi

exists() {
    which \$1 >/dev/null 2>&1 || return
    \$*
}

touch /.liveimg-late-configured

# read some variables out of /proc/cmdline
for o in \`cat /proc/cmdline\` ; do
    case \$o in
    ks=*)
        ks="--kickstart=\${o#ks=}"
        ;;
    xdriver=*)
        xdriver="\${o#xdriver=}"
        ;;
    esac
done

# if liveinst or textinst is given, start anaconda
if strstr "\`cat /proc/cmdline\`" liveinst ; then
   plymouth --quit
   /usr/sbin/liveinst \$ks
fi
if strstr "\`cat /proc/cmdline\`" textinst ; then
   plymouth --quit
   /usr/sbin/liveinst --text \$ks
fi

# configure X, allowing user to override xdriver
if [ -n "\$xdriver" ]; then
   cat > /etc/X11/xorg.conf.d/00-xdriver.conf <<FOE
Section "Device"
	Identifier	"Videocard0"
	Driver	"\$xdriver"
EndSection
FOE
fi

EOF

chmod 755 /etc/rc.d/init.d/livesys
/sbin/restorecon /etc/rc.d/init.d/livesys
/sbin/chkconfig --add livesys

chmod 755 /etc/rc.d/init.d/livesys-late
/sbin/restorecon /etc/rc.d/init.d/livesys-late
/sbin/chkconfig --add livesys-late

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
releasever=$(rpm -q --qf '%{version}\n' --whatprovides system-release)
basearch=$(uname -i)
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

# Remove machine-id on pre generated images
rm -f /etc/machine-id
touch /etc/machine-id
%end

%post

cat >> /etc/rc.d/init.d/livesys << EOF

# disable gnome-software automatically downloading updates
cat >> /usr/share/glib-2.0/schemas/org.gnome.software.gschema.override << FOE
[org.gnome.software]
download-updates=false
FOE

# don't autostart gnome-software session service
rm -f /etc/xdg/autostart/gnome-software-service.desktop

# disable the gnome-software shell search provider
cat >> /usr/share/gnome-shell/search-providers/org.gnome.Software-search-provider.ini << FOE
DefaultDisabled=true
FOE

# don't run gnome-initial-setup
mkdir ~liveuser/.config
touch ~liveuser/.config/gnome-initial-setup-done

# suppress anaconda spokes redundant with gnome-initial-setup
cat >> /etc/sysconfig/anaconda << FOE
[NetworkSpoke]
visited=1

[PasswordSpoke]
visited=1

[UserSpoke]
visited=1
FOE

# make the installer show up
if [ -f /usr/share/applications/liveinst.desktop ]; then
  # Show harddisk install in shell dash
  sed -i -e 's/NoDisplay=true/NoDisplay=false/' /usr/share/applications/liveinst.desktop ""
  # need to move it to anaconda.desktop to make shell happy
  mv /usr/share/applications/liveinst.desktop /usr/share/applications/anaconda.desktop

  cat >> /usr/share/glib-2.0/schemas/org.gnome.shell.gschema.override << FOE
[org.gnome.shell]
favorite-apps=['firefox.desktop', 'evolution.desktop', 'rhythmbox.desktop', 'shotwell.desktop', 'org.gnome.Nautilus.desktop', 'anaconda.desktop']
FOE

  # Make the welcome screen show up
  if [ -f /usr/share/anaconda/gnome/rhel-welcome.desktop ]; then
    mkdir -p ~liveuser/.config/autostart
    cp /usr/share/anaconda/gnome/rhel-welcome.desktop /usr/share/applications/
    cp /usr/share/anaconda/gnome/rhel-welcome.desktop ~liveuser/.config/autostart/
  fi

  # Copy Anaconda branding in place
  if [ -d /usr/share/lorax/product/usr/share/anaconda ]; then
    cp -a /usr/share/lorax/product/* /
  fi
fi

# rebuild schema cache with any overrides we installed
glib-compile-schemas /usr/share/glib-2.0/schemas

# set up auto-login
cat > /etc/gdm/custom.conf << FOE
[daemon]
AutomaticLoginEnable=True
AutomaticLogin=liveuser
FOE

# Turn off PackageKit-command-not-found while uninstalled
if [ -f /etc/PackageKit/CommandNotFound.conf ]; then
  sed -i -e 's/^SoftwareSourceSearch=true/SoftwareSourceSearch=false/' /etc/PackageKit/CommandNotFound.conf
fi

# make sure to set the right permissions and selinux contexts
chown -R liveuser:liveuser /home/liveuser/
restorecon -R /home/liveuser/

EOF

%end

# Packages
%packages
GConf2
ModemManager
ModemManager-glib
NetworkManager
NetworkManager-adsl
NetworkManager-bluetooth
NetworkManager-libnm
NetworkManager-team
NetworkManager-tui
NetworkManager-wifi
NetworkManager-wwan
PackageKit
PackageKit-command-not-found
PackageKit-glib
PackageKit-gtk3-module
aajohan-comfortaa-fonts
abattis-cantarell-fonts
accountsservice
accountsservice-libs
acl
adobe-mappings-cmap
adobe-mappings-cmap-deprecated
adobe-mappings-pdf
adwaita-cursor-theme
adwaita-gtk2-theme
adwaita-icon-theme
almalinux-backgrounds
almalinux-indexhtml
almalinux-logos
almalinux-release
alsa-lib
alsa-sof-firmware
anaconda-core
anaconda-gui
anaconda-live
anaconda-tui
anaconda-user-help
anaconda-widgets
appstream-data
aspell
at-spi2-atk
at-spi2-core
atk
atkmm
audit
audit-libs
augeas-libs
authselect
authselect-compat
authselect-libs
avahi
avahi-glib
avahi-libs
baobab
basesystem
bash
bind-export-libs
binutils
biosdevname
blivet-data
bluez
bluez-libs
bluez-obexd
bolt
boost-atomic
boost-chrono
boost-date-time
boost-iostreams
boost-program-options
boost-random
boost-regex
boost-system
boost-thread
brlapi
brltty
brotli
bubblewrap
bzip2
bzip2-libs
c-ares
ca-certificates
cairo
cairo-gobject
cairomm
celt051
checkpolicy
cheese
cheese-libs
chkconfig
chrome-gnome-shell
chrony
clutter
clutter-gst3
clutter-gtk
cogl
color-filesystem
colord
colord-gtk
colord-libs
compat-exiv2-026
coreutils
coreutils-common
cpio
cracklib
cracklib-dicts
crda
cronie
cronie-anacron
crontabs
crypto-policies
crypto-policies-scripts
cryptsetup-libs
cups-libs
cups-pk-helper
curl
cyrus-sasl
cyrus-sasl-gssapi
cyrus-sasl-lib
daxctl-libs
dbus
dbus-common
dbus-daemon
dbus-glib
dbus-libs
dbus-tools
dbus-x11
dconf
dejavu-fonts-common
dejavu-sans-fonts
dejavu-sans-mono-fonts
dejavu-serif-fonts
desktop-file-utils
device-mapper
device-mapper-event
device-mapper-event-libs
device-mapper-libs
device-mapper-multipath
device-mapper-multipath-libs
device-mapper-persistent-data
dhcp-client
dhcp-common
dhcp-libs
diffutils
dleyna-connector-dbus
dleyna-core
dleyna-server
dmidecode
dnf
dnf-data
dnf-plugin-spacewalk
dnf-plugins-core
dnsmasq
dosfstools
dotconf
dracut
dracut-config-generic
dracut-config-rescue
dracut-live
dracut-network
dracut-squash
e2fsprogs
e2fsprogs-libs
edk2-ovmf
efi-filesystem
efibootmgr
efivar-libs
elfutils-debuginfod-client
elfutils-default-yama-scope
elfutils-libelf
elfutils-libs
emacs-filesystem
enchant2
eog
espeak-ng
ethtool
evince
evince-libs
evince-nautilus
evolution-data-server
evolution-data-server-langpacks
exempi
exiv2
exiv2-libs
expat
file
file-libs
file-roller
filesystem
findutils
firefox
firewalld
firewalld-filesystem
flac-libs
flatpak
flatpak-libs
flatpak-selinux
flatpak-session-helper
fontconfig
fontpackages-filesystem
fprintd
fprintd-pam
freerdp-libs
freetype
frei0r-plugins
fribidi
fuse
fuse-common
fuse-libs
fwupd
gavl
gawk
gcr
gd
gdbm
gdbm-libs
gdisk
gdk-pixbuf2
gdk-pixbuf2-modules
gdm
gedit
genisoimage
geoclue2
geoclue2-libs
geocode-glib
geolite2-city
geolite2-country
gettext
gettext-libs
giflib
gimp
gjs
glib-networking
glib2
glibc
glibc-all-langpacks
glibc-common
glibc-langpack-en
glibmm24
glusterfs
glusterfs-api
glusterfs-cli
glusterfs-client-xlators
glusterfs-libs
glx-utils
gmp
gnome-autoar
gnome-bluetooth
gnome-bluetooth-libs
gnome-boxes
gnome-calculator
gnome-characters
gnome-classic-session
gnome-color-manager
gnome-control-center
gnome-control-center-filesystem
gnome-desktop3
gnome-disk-utility
gnome-font-viewer
gnome-getting-started-docs
gnome-initial-setup
gnome-keyring
gnome-keyring-pam
gnome-logs
gnome-menus
gnome-online-accounts
gnome-remote-desktop
gnome-screenshot
gnome-session
gnome-session-wayland-session
gnome-session-xsession
gnome-settings-daemon
gnome-shell
gnome-shell-extension-apps-menu
gnome-shell-extension-common
gnome-shell-extension-desktop-icons
gnome-shell-extension-horizontal-workspaces
gnome-shell-extension-launch-new-instance
gnome-shell-extension-places-menu
gnome-shell-extension-window-list
gnome-software
gnome-system-monitor
gnome-terminal
gnome-terminal-nautilus
gnome-themes-standard
gnome-tweaks
gnome-user-docs
gnome-video-effects
gnu-free-fonts-common
gnu-free-mono-fonts
gnu-free-sans-fonts
gnu-free-serif-fonts
gnupg2
gnupg2-smime
gnutls
gobject-introspection
gom
google-droid-sans-fonts
google-noto-cjk-fonts-common
google-noto-fonts-common
google-noto-sans-cjk-ttc-fonts
google-noto-sans-lisu-fonts
google-noto-sans-mandaic-fonts
google-noto-sans-meetei-mayek-fonts
google-noto-sans-sinhala-fonts
google-noto-sans-tagalog-fonts
google-noto-sans-tai-tham-fonts
google-noto-sans-tai-viet-fonts
google-noto-serif-cjk-ttc-fonts
google-noto-sans-khmer-fonts
google-noto-sans-myanmar-fonts
google-noto-sans-oriya-fonts
google-noto-sans-tibetan-fonts
lohit-assamese-fonts
lohit-bengali-fonts
lohit-devanagari-fonts
lohit-gujarati-fonts
lohit-gurmukhi-fonts
lohit-kannada-fonts
lohit-malayalam-fonts
lohit-marathi-fonts
lohit-nepali-fonts
lohit-odia-fonts
lohit-tamil-fonts
lohit-telugu-fonts
gpgme
graphite2
grep
grilo
grilo-plugins
groff-base
grub2-common
grub2-efi-*64
grub2-efi-*64-cdboot
grub2-pc-modules
grub2-tools
grub2-tools-efi
grub2-tools-extra
grub2-tools-minimal
grubby
gsettings-desktop-schemas
gsm
gspell
gssdp
gssproxy
gstreamer1
gstreamer1-plugins-bad-free
gstreamer1-plugins-base
gstreamer1-plugins-good
gstreamer1-plugins-ugly-free
gtk-update-icon-cache
gtk-vnc2
gtk2
gtk3
gtkmm30
gtksourceview3
@guest-desktop-agents
gupnp
gupnp-av
gupnp-dlna
gvfs
gvfs-afc
gvfs-afp
gvfs-archive
gvfs-client
gvfs-fuse
gvfs-goa
gvfs-gphoto2
gvfs-mtp
gvfs-smb
gvnc
gzip
hardlink
harfbuzz
harfbuzz-icu
hdparm
hicolor-icon-theme
hostname
hplip-common
hplip-libs
hunspell
hunspell-en
hunspell-en-GB
hunspell-en-US
hwdata
hyperv-daemons
hyperv-daemons-license
hypervfcopyd
hypervkvpd
hypervvssd
hyphen
ibus
ibus-gtk2
ibus-gtk3
ibus-libs
ibus-setup
iio-sensor-proxy
ima-evm-utils
info
initial-setup
initial-setup-gui
initscripts
inkscape
ipcalc
iproute
iproute-tc
iprutils
ipset
ipset-libs
iptables
iptables-ebtables
iptables-libs
iputils
ipxe-roms-qemu
irqbalance
iscsi-initiator-utils
iscsi-initiator-utils-iscsiuio
isns-utils-libs
iso-codes
isomd5sum
itstool
iw
iwl100-firmware
iwl1000-firmware
iwl105-firmware
iwl135-firmware
iwl2000-firmware
iwl2030-firmware
iwl3160-firmware
iwl3945-firmware
iwl4965-firmware
iwl5000-firmware
iwl5150-firmware
iwl6000-firmware
iwl6000g2a-firmware
iwl6000g2b-firmware
iwl6050-firmware
iwl7260-firmware
jansson
jasper-libs
jbig2dec-libs
jbigkit-libs
jimtcl
jomolhari-fonts
jq
json-c
json-glib
julietaula-montserrat-fonts
kbd
kbd-legacy
kbd-misc
kernel
kernel-core
kernel-modules
kernel-modules-extra
kernel-tools
kernel-tools-libs
kexec-tools
keybinder3
keyutils
keyutils-libs
khmeros-base-fonts
khmeros-fonts-common
kmod
kmod-libs
kpartx
krb5-libs
lame-libs
langpacks-en
langtable
lcms2
less
libICE
libSM
libX11
libX11-common
libX11-xcb
libXau
libXcomposite
libXcursor
libXdamage
libXdmcp
libXext
libXfixes
libXfont2
libXft
libXi
libXinerama
libXmu
libXpm
libXrandr
libXrender
libXres
libXt
libXtst
libXv
libXvMC
libXxf86dga
libXxf86misc
libXxf86vm
liba52
libacl
libaio
libao
libappstream-glib
libarchive
libassuan
libasyncns
libatasmart
libattr
libavc1394
libbasicobjects
libblkid
libblockdev
libblockdev-crypto
libblockdev-dm
libblockdev-fs
libblockdev-kbd
libblockdev-loop
libblockdev-lvm
libblockdev-mdraid
libblockdev-mpath
libblockdev-nvdimm
libblockdev-part
libblockdev-swap
libblockdev-utils
libbpf
libbytesize
libcacard
libcanberra
libcanberra-gtk3
libcap
libcap-ng
libcdio
libcdio-paranoia
libcollection
libcom_err
libcomps
libcroco
libcurl
libdaemon
libdatrie
libdb
libdb-utils
libdhash
libdmapsharing
libdmx
libdnf
libdrm
libdv
libdvdnav
libdvdread
libedit
libepoxy
liberation-fonts
liberation-fonts-common
liberation-mono-fonts
liberation-sans-fonts
liberation-serif-fonts
libertas-usb8388-firmware
libestr
libevdev
libevent
libexif
libfastjson
libfdisk
libffi
libfontenc
libfprint
libgcab1
libgcc
libgcrypt
libgdata
libgdither
libgexiv2
libglvnd
libglvnd-egl
libglvnd-gles
libglvnd-glx
libgnomekbd
libgomp
libgpg-error
libgphoto2
libgs
libgsf
libgtop2
libgudev
libgusb
libgweather
libgxps
libibumad
libibverbs
libical
libicu
libidn
libidn2
libiec61883
libieee1284
libijs
libimobiledevice
libini_config
libinput
libiptcdata
libiscsi
libjpeg-turbo
libkcapi
libkcapi-hmaccalc
libksba
libldb
liblouis
libmaxminddb
libmbim
libmbim-utils
libmcpp
libmediaart
libmetalink
libmnl
libmodman
libmodulemd
libmount
libmpc
libmspack
libmtp
libmusicbrainz5
libndp
libnetfilter_conntrack
libnfnetlink
libnfsidmap
libnftnl
libnghttp2
libnl3
libnl3-cli
libnma
libnotify
libnsl2
liboauth
libogg
libosinfo
libpaper
libpath_utils
libpcap
libpciaccess
libpeas
libpeas-gtk
libpeas-loader-python3
libpipeline
libpkgconf
libplist
libpmem
libpng
libproxy
libpsl
libpwquality
libqmi
libqmi-utils
libquvi
libquvi-scripts
librados2
libraw1394
librbd1
librdmacm
libref_array
librelp
libreoffice-base
libreoffice-calc
libreoffice-core
libreoffice-data
libreoffice-draw
libreoffice-graphicfilter
libreoffice-impress
libreoffice-writer
librepo
libreport
libreport-anaconda
libreport-cli
libreport-filesystem
libreport-gtk
libreport-plugin-reportuploader
libreport-web
librsvg2
libsane-hpaio
libseccomp
libsecret
libselinux
libselinux-utils
libsemanage
libsepol
libshout
libsigc++20
libsigsegv
libsmartcols
libsmbclient
libsmbios
libsndfile
libsolv
libsoup
libspectre
libsrtp
libss
libssh
libssh-config
libsss_autofs
libsss_certmap
libsss_idmap
libsss_nss_idmap
libsss_sudo
libstdc++
libstemmer
libsysfs
libtalloc
libtar
libtasn1
libtdb
libteam
libtevent
libthai
libtheora
libtiff
libtimezonemap
libtirpc
libtool-ltdl
libudisks2
libunistring
libusal
libusbmuxd
libusbx
libuser
libutempter
libuuid
libv4l
libverto
libverto-libevent
libvirt-daemon
libvirt-daemon-config-network
libvirt-daemon-driver-interface
libvirt-daemon-driver-network
libvirt-daemon-driver-nodedev
libvirt-daemon-driver-nwfilter
libvirt-daemon-driver-qemu
libvirt-daemon-driver-secret
libvirt-daemon-driver-storage
libvirt-daemon-driver-storage-core
libvirt-daemon-driver-storage-disk
libvirt-daemon-driver-storage-gluster
libvirt-daemon-driver-storage-iscsi
libvirt-daemon-driver-storage-iscsi-direct
libvirt-daemon-driver-storage-logical
libvirt-daemon-driver-storage-mpath
libvirt-daemon-driver-storage-rbd
libvirt-daemon-driver-storage-scsi
libvirt-daemon-kvm
libvirt-gconfig
libvirt-glib
libvirt-gobject
libvirt-libs
libvisual
libvncserver
libvorbis
libvpx
libwacom
libwacom-data
libwayland-client
libwayland-cursor
libwayland-egl
libwayland-server
libwbclient
libwebp
libwinpr
libwnck3
libxcb
libxcrypt
libxkbcommon
libxkbcommon-x11
libxkbfile
libxklavier
libxml2
libxmlb
libxshmfence
libxslt
libyaml
libzstd
linux-firmware
llvm-libs
lmdb-libs
lockdev
logrotate
lohit-assamese-fonts
lohit-bengali-fonts
lohit-devanagari-fonts
lohit-gujarati-fonts
lohit-gurmukhi-fonts
lohit-kannada-fonts
lohit-odia-fonts
lohit-tamil-fonts
lohit-telugu-fonts
lshw
lsof
lsscsi
lua
lua-expat
lua-json
lua-libs
lua-lpeg
lua-socket
lvm2
lvm2-libs
lz4
lz4-libs
lzo
lzo-minilzo
lzop
mallard-rng
man-db
mcpp
mdadm
memstrack
memtest86+
mesa-dri-drivers
mesa-filesystem
mesa-libEGL
mesa-libGL
mesa-libgbm
mesa-libglapi
mesa-libxatracker
metacity
microcode_ctl
mobile-broadband-provider-info
mokutil
mousetweaks
mozilla-filesystem
mozjs60
mpfr
mpg123-libs
mtdev
mtools
mutter
nano
nautilus
nautilus-extensions
nautilus-sendto
ncompress
ncurses
ncurses-base
ncurses-libs
ndctl
ndctl-libs
neon
net-snmp-libs
netcf-libs
nettle
newt
nfs-utils
nftables
nm-connection-editor
nmap-ncat
npth
nspr
nss
nss-softokn
nss-softokn-freebl
nss-sysinit
nss-util
numactl-libs
numad
oddjob
oddjob-mkhomedir
open-vm-tools
open-vm-tools-desktop
openjpeg2
openldap
openssh
openssh-askpass
openssh-clients
openssh-server
openssl
openssl-libs
openssl-pkcs11
opus
orc
orca
os-prober
osinfo-db
osinfo-db-tools
ostree
ostree-libs
p11-kit
p11-kit-server
p11-kit-trust
pakchois
paktype-naskh-basic-fonts
pam
pango
pangomm
paratype-pt-sans-fonts
parted
passwd
pcaudiolib
pciutils
pciutils-libs
pcre
pcre2
pigz
pinentry
pinentry-gtk
pipewire
pipewire-libs
pipewire0.2-libs
pixman
pkgconf
pkgconf-m4
pkgconf-pkg-config
platform-python
platform-python-pip
platform-python-setuptools
plymouth
plymouth-core-libs
plymouth-graphics-libs
plymouth-plugin-label
plymouth-plugin-two-step
plymouth-scripts
plymouth-system-theme
plymouth-theme-charge
plymouth-theme-spinner
policycoreutils
policycoreutils-python-utils
polkit
polkit-libs
polkit-pkla-compat
poppler
poppler-data
poppler-glib
popt
prefixdevname
procps-ng
psmisc
publicsuffix-list-dafsa
pulseaudio
pulseaudio-libs
pulseaudio-libs-glib2
pulseaudio-module-bluetooth
python3-audit
python3-blivet
python3-blockdev
python3-brlapi
python3-bytesize
python3-cairo
python3-cffi
python3-chardet
python3-configobj
python3-cryptography
python3-cups
python3-dasbus
python3-dateutil
python3-dbus
python3-decorator
python3-dmidecode
python3-dnf
python3-dnf-plugin-spacewalk
python3-dnf-plugins-core
python3-firewall
python3-gobject
python3-gobject-base
python3-gpg
python3-hawkey
python3-hwdata
python3-idna
python3-kickstart
python3-langtable
python3-libcomps
python3-libdnf
python3-librepo
python3-libreport
python3-libs
python3-libselinux
python3-libsemanage
python3-libxml2
python3-linux-procfs
python3-louis
python3-meh
python3-meh-gui
python3-netifaces
python3-newt
python3-nftables
python3-ntplib
python3-ordered-set
python3-perf
python3-pid
python3-pip
python3-pip-wheel
python3-ply
python3-policycoreutils
python3-productmd
python3-pwquality
python3-pyOpenSSL
python3-pyatspi
python3-pycparser
python3-pycurl
python3-pyparted
python3-pysocks
python3-pytz
python3-pyudev
python3-pyxdg
python3-pyyaml
python3-requests
python3-requests-file
python3-requests-ftp
python3-rhn-check
python3-rhn-client-tools
python3-rhn-setup
python3-rhnlib
python3-rpm
python3-schedutils
python3-setools
python3-setuptools
python3-setuptools-wheel
python3-simpleline
python3-six
python3-slip
python3-slip-dbus
python3-speechd
python3-syspurpose
python3-systemd
python3-unbound
python3-urllib3
python36
qemu-guest-agent
qemu-img
qemu-kvm
qemu-kvm-block-curl
qemu-kvm-block-gluster
qemu-kvm-block-iscsi
qemu-kvm-block-rbd
qemu-kvm-block-ssh
qemu-kvm-common
qemu-kvm-core
quota
quota-nls
radvd
rdma-core
readline
rest
rhn-check
rhn-client-tools
rhn-setup
rhnlib
rhnsd
rng-tools
rootfiles
rpcbind
rpm
rpm-build-libs
rpm-libs
rpm-plugin-selinux
rpm-plugin-systemd-inhibit
rsync
rsyslog
rsyslog-gnutls
rsyslog-gssapi
rsyslog-relp
rtkit
samba-client-libs
samba-common
samba-common-libs
sane-backends
sane-backends-drivers-cameras
sane-backends-drivers-scanners
sane-backends-libs
satyr
sbc
seabios-bin
seavgabios-bin
sed
selinux-policy
selinux-policy-targeted
setup
sg3_utils
sg3_utils-libs
sgabios-bin
shadow-utils
shared-mime-info
shim-*64
sil-abyssinica-fonts
sil-nuosu-fonts
sil-padauk-fonts
slang
smc-fonts-common
smc-meera-fonts
snappy
sound-theme-freedesktop
soundtouch
speech-dispatcher
speech-dispatcher-espeak-ng
speex
speexdsp
spice-glib
spice-gtk3
spice-server
spice-vdagent
sqlite-libs
squashfs-tools
sssd-client
sssd-common
sssd-kcm
sssd-nfs-idmap
startup-notification
stix-fonts
sudo
sushi
switcheroo-control
syslinux
syslinux-nonlinux
system-config-printer-libs
systemd
systemd-container
systemd-libs
systemd-pam
systemd-udev
taglib
tar
teamd
thai-scalable-fonts-common
thai-scalable-waree-fonts
thunderbird
tigervnc-license
tigervnc-server-minimal
timedatex
tmux
totem
totem-nautilus
totem-pl-parser
tpm2-tss
tracker
tracker-miners
trousers
trousers-lib
tuned
twolame-libs
tzdata
udisks2
unbound-libs
unzip
upower
urw-base35-bookman-fonts
urw-base35-c059-fonts
urw-base35-d050000l-fonts
urw-base35-fonts
urw-base35-fonts-common
urw-base35-gothic-fonts
urw-base35-nimbus-mono-ps-fonts
urw-base35-nimbus-roman-fonts
urw-base35-nimbus-sans-fonts
urw-base35-p052-fonts
urw-base35-standard-symbols-ps-fonts
urw-base35-z003-fonts
usb_modeswitch
usb_modeswitch-data
usbmuxd
usbredir
usermode
userspace-rcu
util-linux
vim-X11
vim-minimal
vino
virt-manager
virt-what
volume_key-libs
vte-profile
vte291
wavpack
webkit2gtk3
webkit2gtk3-jsc
webrtc-audio-processing
which
woff2
wpa_supplicant
xcb-util
xdg-desktop-portal
xdg-desktop-portal-gtk
xdg-user-dirs
xdg-user-dirs-gtk
xfsprogs
xkeyboard-config
xml-common
xmlrpc-c
xmlrpc-c-client
xmlsec1
xmlsec1-openssl
xorg-x11-drv-ati
xorg-x11-drv-evdev
xorg-x11-drv-fbdev
xorg-x11-drv-intel
xorg-x11-drv-libinput
xorg-x11-drv-nouveau
xorg-x11-drv-qxl
xorg-x11-drv-vesa
xorg-x11-drv-vmware
xorg-x11-drv-wacom
xorg-x11-drv-wacom-serial-support
xorg-x11-font-utils
xorg-x11-server-Xorg
xorg-x11-server-Xwayland
xorg-x11-server-common
xorg-x11-server-utils
xorg-x11-utils
xorg-x11-xauth
xorg-x11-xinit
xorg-x11-xinit-session
xorg-x11-xkb-utils
xsane
xz
xz-libs
yajl
yelp
yelp-libs
yelp-tools
yelp-xsl
yum
zenity
zip
zlib


%end
