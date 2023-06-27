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
# Enable sddm since it is disabled by the packager by default
systemctl enable --force sddm.service

# FIXME: it'd be better to get this installed from a package
cat > /etc/rc.d/init.d/livesys << EOF
#!/bin/bash
#
# live: Init script for live image
#
# chkconfig: 345 00 99
# description: Init script for live image.
### BEGIN INIT INFO
# X-Start-Before: display-manager chronyd
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
    continue
  fi
  if [ "\${arg##live_dir=}" != "\${arg}" ]; then
    livedir=\${arg##live_dir=}
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

# add liveuser user with no passwd
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

# turn off abrtd on a live image
systemctl --no-reload disable abrtd.service 2> /dev/null || :
systemctl stop abrtd.service 2> /dev/null || :

# Don't sync the system clock when running live (RHBZ #1018162)
sed -i 's/rtcsync//' /etc/chrony.conf

# Mark things as configured
touch /.liveimg-configured

# add static hostname to work around xauth bug
# https://bugzilla.redhat.com/show_bug.cgi?id=679486
# the hostname must be something else than 'localhost'
# https://bugzilla.redhat.com/show_bug.cgi?id=1370222
echo "localhost-live" > /etc/hostname

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
# rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-fedora-$releasever-$basearch
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
/sbin/chkconfig network off

# Remove machine-id on pre generated images
rm -f /etc/machine-id
touch /etc/machine-id

# xfce configuration

# create /etc/sysconfig/desktop (needed for installation)

cat > /etc/sysconfig/desktop <<EOF
PREFERRED=/usr/bin/startxfce4
DISPLAYMANAGER=/usr/bin/sddm
EOF

cat >> /etc/rc.d/init.d/livesys << EOF

mkdir -p /home/liveuser/.config/xfce4
## uglyfix, replace with almalinux-backgrounds-extras package
#mkdir -p /usr/share/backgrounds/images
#ln -s /usr/share/backgrounds/Alma-dark-2048x1536.jpg /usr/share/backgrounds/images/default.png

cat > /home/liveuser/.config/xfce4/helpers.rc << FOE
MailReader=sylpheed-claws
FileManager=Thunar
WebBrowser=firefox
FOE

# disable screensaver locking (#674410)
cat >> /home/liveuser/.xscreensaver << FOE
mode:           off
lock:           False
dpmsEnabled:    False
FOE

# deactivate xfconf-migration (#683161)
rm -f /etc/xdg/autostart/xfconf-migration-4.6.desktop || :

# deactivate xfce4-panel first-run dialog (#693569)
mkdir -p /home/liveuser/.config/xfce4/xfconf/xfce-perchannel-xml
cp /etc/xdg/xfce4/panel/default.xml /home/liveuser/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml

# set up autologin for user liveuser
if [ -f /etc/sddm.conf ]; then
sed -i 's/^#User=.*/User=liveuser/' /etc/sddm.conf
sed -i 's/^#Session=.*/Session=xfce.desktop/' /etc/sddm.conf
else
cat > /etc/sddm.conf << SDDM_EOF
[Autologin]
User=liveuser
Session=xfce.desktop
SDDM_EOF
fi

mkdir -p /home/liveuser/Desktop
# make the installer show up, when exits
if [ -f /usr/share/applications/liveinst.desktop ]; then
  # Show harddisk install in shell dash
  sed -i -e 's/NoDisplay=true/NoDisplay=false/' /usr/share/applications/liveinst.desktop ""
  # copy to desktop
  cp -a /usr/share/applications/liveinst.desktop /home/liveuser/Desktop/
  # and mark it as executable (new Xfce security feature)
  chmod +x /home/liveuser/Desktop/liveinst.desktop

  # need to move it to anaconda.desktop to make shell happy TODO: Is reuired for XFCE?
  mv /usr/share/applications/liveinst.desktop /usr/share/applications/anaconda.desktop

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

# no updater applet in live environment
rm -f /etc/xdg/autostart/org.mageia.dnfdragora-updater.desktop

# this goes at the end after all other changes.
chown -R liveuser:liveuser /home/liveuser
restorecon -R /home/liveuser

EOF

%end

%post --nochroot
# cp $INSTALL_ROOT/usr/share/licenses/*-release/* $LIVE_ROOT/

# only works on x86, x86_64
if [ "$(uname -i)" = "i386" -o "$(uname -i)" = "x86_64" ]; then
  if [ ! -d $LIVE_ROOT/LiveOS ]; then mkdir -p $LIVE_ROOT/LiveOS ; fi
  cp /usr/bin/livecd-iso-to-disk $LIVE_ROOT/LiveOS
fi

%end

abattis-cantarell-fonts
accountsservice
accountsservice-libs
acl
adwaita-cursor-theme
adwaita-gtk2-theme
adwaita-icon-theme
almalinux-backgrounds
almalinux-backgrounds-extras
almalinux-indexhtml
almalinux-logos
almalinux-release
alsa-lib
anaconda
anaconda-install-env-deps
anaconda-live
@anaconda-tools
aspell
atk
atkmm
at-spi2-atk
at-spi2-core
audit
audit-libs
authselect
authselect-libs
autocorr-en
avahi-glib
avahi-libs
basesystem
bash
bind-export-libs
biosdevname
bluez
bluez-libs
bluez-obexd
bolt
boost-chrono
boost-date-time
boost-filesystem
boost-iostreams
boost-locale
boost-system
boost-thread
brotli
bubblewrap
bzip2-libs
ca-certificates
cairo
cairo-gobject
cairomm
c-ares
checkpolicy
cheese-libs
chkconfig
chrony
clucene-contribs-lib
clucene-core
clutter
clutter-gst3
clutter-gtk
cogl
colord
colord-gtk
colord-libs
color-filesystem
copy-jdk-configs
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
cyrus-sasl-lib
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
device-mapper-persistent-data
dhcp-client
dhcp-common
dhcp-libs
diffutils
dmidecode
dnf
dnf-data
dnf-plugins-core
dosfstools
dracut
dracut-config-generic
dracut-config-rescue
dracut-live
dracut-network
dracut-squash
e2fsprogs
e2fsprogs-libs
efibootmgr
efi-filesystem
efi-srpm-macros
efivar-libs
elfutils-debuginfod-client
elfutils-default-yama-scope
elfutils-libelf
elfutils-libs
emacs-filesystem
enchant2
epel-release
ethtool
evolution-data-server
evolution-data-server-langpacks
exo
expat
file
file-libs
filesystem
findutils
firefox
firewalld
firewalld-filesystem
flac-libs
flatpak
flatpak-selinux
flatpak-session-helper
fontconfig
fontpackages-filesystem
freetype
fribidi
fuse
fuse-common
fuse-libs
fwupd
garcon
gawk
GConf2
gcr
gdbm
gdbm-libs
gdisk
gdk-pixbuf2
gdk-pixbuf2-modules
gdm
geany
geany-libgeany
geoclue2
geoclue2-libs
geocode-glib
geolite2-city
geolite2-country
gettext
gettext-libs
gjs
glib2
glibc
glibc-all-langpacks
glibc-common
glibmm24
glib-networking
glx-utils
gmp
gnome-bluetooth
gnome-bluetooth-libs
gnome-control-center
gnome-control-center-filesystem
gnome-desktop3
gnome-keyring
gnome-keyring-pam
gnome-menus
gnome-online-accounts
gnome-session
gnome-session-wayland-session
gnome-session-xsession
gnome-settings-daemon
gnome-shell
gnome-themes-standard
gnupg2
gnupg2-smime
gnutls
gobject-introspection
google-crosextra-caladea-fonts
google-crosextra-carlito-fonts
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
gpgmepp
graphite2
grep
grilo
groff-base
grub2-common
grub2-efi-*64
grub2-efi-*64-cdboot
grub2-tools
grub2-tools-efi
grub2-tools-extra
grub2-tools-minimal
grubby
gsettings-desktop-schemas
gsm
gstreamer1
gstreamer1-plugins-base
gstreamer1-plugins-good
gstreamer1-plugins-good-gtk
gtk2
gtk3
gtkmm30
gtksourceview3
gtk-update-icon-cache
gzip
hardlink
harfbuzz
harfbuzz-icu
hdparm
hicolor-icon-theme
hostname
hunspell
hunspell-en-US
hwdata
hyphen
hyphen-en
ibus
ibus-gtk2
ibus-gtk3
ibus-libs
ibus-setup
iio-sensor-proxy
ima-evm-utils0
info
initscripts
ipcalc
iproute
iprutils
ipset
ipset-libs
iptables
iptables-ebtables
iptables-libs
iputils
irqbalance
iso-codes
isomd5sum
iw
iwl1000-firmware
iwl100-firmware
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
iwl6050-firmware
iwl7260-firmware
jansson
jasper-libs
java-1.8.0-openjdk-headless
javapackages-filesystem
jbigkit-libs
json-c
json-glib
kbd
kbd-legacy
kbd-misc
kernel
kernel-core
kernel-modules
kernel-tools
kernel-tools-libs
kexec-tools
keybinder3
keyutils-libs
kmod
kmod-libs
kpartx
krb5-libs
lame-libs
lcms2
less
libabw
libacl
libaio
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
libblockdev-fs
libblockdev-loop
libblockdev-mdraid
libblockdev-part
libblockdev-swap
libblockdev-utils
libbytesize
libcanberra
libcanberra-gtk3
libcap
libcap-ng
libcdr
libcmis
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
libdnf
libdrm
libdv
libedit
libepoxy
libepubgen
liberation-fonts-common
liberation-mono-fonts
liberation-sans-fonts
liberation-serif-fonts
libetonyek
libevdev
libevent
libexif
libexttextcat
libfdisk
libffi
libfontenc
libfreehand
libgcab1
libgcc
libgcrypt
libgdata
libglvnd
libglvnd-egl
libglvnd-gles
libglvnd-glx
libgnomekbd
libgomp
libgpg-error
libgtop2
libgudev
libgusb
libgweather
libibverbs
libical
libICE
libicu
libidn2
libiec61883
libimobiledevice
libini_config
libinput
libjpeg-turbo
libkcapi
libkcapi-hmaccalc
libksba
liblangtag
liblangtag-data
libldb
libmaxminddb
libmbim
libmcpp
libmetalink
libmnl
libmodman
libmodulemd
libmount
libmspack
libmspub
libmwaw
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
libnumbertext
liboauth
libodfgen
libogg
liborcus
libpagemaker
libpath_utils
libpcap
libpciaccess
libpipeline
libpkgconf
libplist
libpng
libproxy
libpsl
libpwquality
libqmi
libquvi
libquvi-scripts
libqxp
libraw1394
libref_array
libreoffice-base
libreoffice-calc
libreoffice-core
libreoffice-data
libreoffice-draw
libreoffice-graphicfilter
libreoffice-gtk3
libreoffice-help-en
libreoffice-impress
libreoffice-langpack-en
libreoffice-ogltrans
libreoffice-opensymbol-fonts
libreoffice-pdfimport
libreoffice-pyuno
libreoffice-ure
libreoffice-ure-common
libreoffice-writer
libreoffice-x11
librepo
libreport-filesystem
librevenge
librsvg2
libseccomp
libsecret
libselinux
libselinux-utils
libsemanage
libsepol
libshout
libsigc++20
libsigsegv
libSM
libsmartcols
libsmbclient
libsmbios
libsndfile
libsolv
libsoup
libss
libssh
libssh-config
libsss_autofs
libsss_certmap
libsss_idmap
libsss_nss_idmap
libsss_sudo
libstaroffice
libstdc++
libstemmer
libsysfs
libtalloc
libtasn1
libtdb
libteam
libtevent
libthai
libtheora
libtiff
libtirpc
libtool-ltdl
libudisks2
libunistring
libusbmuxd
libusbx
libuser
libutempter
libuuid
libv4l
libverto
libvisio
libvisual
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
libwnck3
libwpd
libwpg
libwps
libX11
libX11-common
libX11-xcb
libXau
libxcb
libXcomposite
libxcrypt
libXcursor
libXdamage
libXdmcp
libXext
libxfce4ui
libxfce4util
libXfixes
libXfont2
libXft
libXi
libXinerama
libxkbcommon
libxkbcommon-x11
libxkbfile
libxklavier
libxml2
libxmlb
libXmu
libXrandr
libXrender
libXres
libXScrnSaver
libxshmfence
libxslt
libXt
libXtst
libXv
libXxf86misc
libXxf86vm
libyaml
libzmf
libzstd
linux-firmware
lksctp-tools
llvm-libs
lmdb-libs
logrotate
lpsolve
lshw
lsscsi
lua
lua-expat
lua-json
lua-libs
lua-lpeg
lua-socket
lvm2
lvm2-libs
lz4-libs
lzo
man-db
mariadb-connector-c
mariadb-connector-c-config
mcpp
mdadm
memstrack
memtest86+
mesa-dri-drivers
mesa-filesystem
mesa-libEGL
mesa-libgbm
mesa-libGL
mesa-libglapi
microcode_ctl
mobile-broadband-provider-info
ModemManager
ModemManager-glib
mokutil
mousepad
mozilla-filesystem
mozjs60
mpfr
mpg123-libs
mtdev
mutter
mythes
mythes-en
nano
ncurses
ncurses-base
ncurses-libs
neon
nettle
NetworkManager
NetworkManager-libnm
NetworkManager-team
NetworkManager-tui
NetworkManager-wifi
newt
nftables
nm-connection-editor
npth
nspr
nss
nss-softokn
nss-softokn-freebl
nss-sysinit
nss-util
numactl-libs
openjpeg2
openldap
openssh
openssh-askpass
openssh-clients
openssh-server
openssl
openssl-libs
openssl-pkcs11
open-vm-tools
open-vm-tools-desktop
opus
orc
os-prober
ostree-libs
p11-kit
p11-kit-server
p11-kit-trust
pakchois
pam
pango
pangomm
parted
passwd
pavucontrol
pciutils
pciutils-libs
pcre
pcre2
pcre2-utf16
perl-Carp
perl-constant
perl-Data-Dumper
perl-Digest
perl-Digest-MD5
perl-Encode
perl-Errno
perl-Exporter
perl-File-Path
perl-File-Temp
perl-Getopt-Long
perl-HTTP-Tiny
perl-interpreter
perl-IO
perl-IO-Socket-IP
perl-IO-Socket-SSL
perl-libnet
perl-libs
perl-macros
perl-MIME-Base64
perl-Mozilla-CA
perl-Net-SSLeay
perl-parent
perl-PathTools
perl-Pod-Escapes
perl-podlators
perl-Pod-Perldoc
perl-Pod-Simple
perl-Pod-Usage
perl-Scalar-List-Utils
perl-Socket
perl-Storable
perl-Term-ANSIColor
perl-Term-Cap
perl-Text-ParseWords
perl-Text-Tabs+Wrap
perl-threads
perl-threads-shared
perl-Time-Local
perl-Unicode-Normalize
perl-URI
pigz
pinentry
pinentry-gtk
pipewire
pipewire0.2-libs
pipewire-libs
pixman
pkgconf
pkgconf-m4
pkgconf-pkg-config
platform-python
platform-python-pip
platform-python-setuptools
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
python36
python3-audit
python3-cairo
python3-chardet
python3-configobj
python3-cups
python3-dateutil
python3-dbus
python3-decorator
python3-dnf
python3-dnf-plugins-core
python3-firewall
python3-gobject
python3-gobject-base
python3-gpg
python3-hawkey
python3-idna
python3-libcomps
python3-libdnf
python3-libs
python3-libselinux
python3-libsemanage
python3-linux-procfs
python3-nftables
python3-perf
python3-pip
python3-pip-wheel
python3-policycoreutils
python3-pycurl
python3-pysocks
python3-pyudev
python3-requests
python3-rpm
python3-schedutils
python3-setools
python3-setuptools
python3-setuptools-wheel
python3-six
python3-slip
python3-slip-dbus
python3-syspurpose
python3-unbound
python3-urllib3
qt5-qtbase
qt5-qtbase-common
qt5-qtbase-gui
qt5-qtdeclarative
raptor2
rasqal
rdma-core
readline
redland
rest
rng-tools
rootfiles
rpm
rpm-build-libs
rpm-libs
rpm-plugin-selinux
rpm-plugin-systemd-inhibit
rsync
rtkit
samba-client-libs
samba-common
samba-common-libs
sbc
sddm
sed
selinux-policy
selinux-policy-targeted
setup
sg3_utils
sg3_utils-libs
shadow-utils
shared-mime-info
shim-*64
slang
snappy
sound-theme-freedesktop
speex
speexdsp
sqlite-libs
squashfs-tools
sssd-client
sssd-common
sssd-kcm
sssd-nfs-idmap
startup-notification
sudo
switcheroo-control
syslinux
system-config-printer-libs
systemd
systemd-libs
systemd-pam
systemd-udev
taglib
tar
teamd
Thunar
thunar-volman
thunderbird
timedatex
totem-pl-parser
trousers
trousers-lib
tumbler
tuned
twolame-libs
tzdata
tzdata-java
udisks2
unbound-libs
unzip
upower
util-linux
vim-minimal
vino
virt-what
volume_key-libs
vte291
vte-profile
wavpack
webkit2gtk3
webkit2gtk3-jsc
webrtc-audio-processing
which
woff2
wpa_supplicant
xcb-util
xcb-util-image
xcb-util-keysyms
xcb-util-renderutil
xcb-util-wm
xdg-desktop-portal
xdg-desktop-portal-gtk
xdg-user-dirs-gtk
xdg-utils
xfce4-about
xfce4-appfinder
xfce4-panel
xfce4-power-manager
xfce4-pulseaudio-plugin
xfce4-screensaver
xfce4-screenshooter
xfce4-session
xfce4-settings
xfce4-taskmanager
xfce4-terminal
xfce-polkit
xfconf
xfdesktop
xfsprogs
xfwm4
xkeyboard-config
xml-common
xmlsec1
xmlsec1-nss
xmlsec1-openssl
xorg-x11-drv-fbdev
xorg-x11-drv-libinput
xorg-x11-drv-vesa
xorg-x11-server-common
xorg-x11-server-utils
xorg-x11-server-Xorg
xorg-x11-server-Xwayland
xorg-x11-xauth
xorg-x11-xinit
xorg-x11-xkb-utils
xz
xz-libs
yum
zenity
zlib

%end
