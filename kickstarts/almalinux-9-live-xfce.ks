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
rpm --rebuilddb
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
  # Add Desktop dir to XDG_DATA_DIRS (Xfce 4.18 security feature)
cat > ~liveuser/.profile << PROFILE_EOF
export XDG_DATA_DIRS="\\\${XDG_DATA_DIRS}:\\\${HOME}/Desktop"
PROFILE_EOF
  # need to move it to anaconda.desktop to make shell happy TODO: Is reuired for XFCE?
  mv /usr/share/applications/liveinst.desktop /usr/share/applications/anaconda.desktop

# Make the welcome screen show up
if [ -f /usr/share/anaconda/gnome/fedora-welcome.desktop ]; then
  mkdir -p ~liveuser/.config/autostart
  cp /usr/share/anaconda/gnome/fedora-welcome.desktop /usr/share/applications/
  cp /usr/share/anaconda/gnome/fedora-welcome.desktop ~liveuser/.config/autostart/
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

%packages
Box2D
ModemManager
ModemManager-glib
NetworkManager
NetworkManager-libnm
NetworkManager-team
NetworkManager-tui
NetworkManager-wifi
PackageKit
PackageKit-glib
Thunar
aajohan-comfortaa-fonts
abattis-cantarell-fonts
acl
adobe-source-code-pro-fonts
adwaita-cursor-theme
adwaita-icon-theme
almalinux-backgrounds
almalinux-gpg-keys
almalinux-indexhtml
almalinux-logos
almalinux-release
almalinux-repos
alsa-lib
alsa-sof-firmware
alternatives
anaconda
anaconda-install-env-deps
anaconda-live
@anaconda-tools
appstream
appstream-data
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
autocorr-en
avahi-glib
avahi-libs
basesystem
bash
blivet-data
bluez-libs
boost-chrono
boost-date-time
boost-filesystem
boost-iostreams
boost-locale
boost-system
boost-thread
bubblewrap
bzip2-libs
c-ares
ca-certificates
cairo
cairo-gobject
cairomm
checkpolicy
chkconfig
chrony
clucene-contribs-lib
clucene-core
colord-libs
copy-jdk-configs
coreutils
coreutils-common
cpio
cpp
cracklib
cracklib-dicts
cronie
cronie-anacron
crontabs
crypto-policies
crypto-policies-scripts
cryptsetup
cryptsetup-libs
cups-libs
curl
cyrus-sasl-lib
daxctl-libs
dbus
dbus-broker
dbus-common
dbus-daemon
dbus-glib
dbus-libs
dbus-tools
dbus-x11
dconf
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
efi-filesystem
efibootmgr
efivar-libs
elfutils-default-yama-scope
elfutils-libelf
elfutils-libs
emacs-filesystem
enchant2
epel-release
ethtool
exempi
exiv2
exiv2-libs
exo
expat
fcoe-utils
fdk-aac-free
file
file-libs
filesystem
findutils
firefox
firewalld
firewalld-filesystem
flac-libs
flashrom
flatpak
flatpak-libs
flatpak-selinux
flatpak-session-helper
flute
fontconfig
fonts-filesystem
freetype
fribidi
fuse
fuse-common
fuse-libs
fwupd
fwupd-plugin-flashrom
garcon
gawk
gawk-all-langpacks
gcr-base
gdbm-libs
gdisk
gdk-pixbuf2
gdk-pixbuf2-modules
geany
geany-libgeany
gedit
genisoimage
geoclue2
gettext
gettext-libs
giflib
gjs
glib-networking
glib2
glibc
glibc-all-langpacks
glibc-common
glibc-gconv-extra
glibc-langpack-en
glibmm24
glx-utils
gmp
gnome-menus
gnome-software
gnupg2
gnutls
gobject-introspection
google-carlito-fonts
google-noto-cjk-fonts-common
google-noto-emoji-color-fonts
google-noto-fonts-common
google-noto-sans-cjk-ttc-fonts
google-noto-sans-gurmukhi-fonts
google-noto-sans-sinhala-vf-fonts
google-noto-serif-cjk-ttc-fonts
gpgme
gpgmepp
graphene
graphite2
grep
groff-base
grub2-common
grub2-efi-x64
grub2-efi-x64-cdboot
grub2-pc
grub2-pc-modules
grub2-tools
grub2-tools-efi
grub2-tools-extra
grub2-tools-minimal
grubby
gsettings-desktop-schemas
gsm
gspell
gstreamer1
gstreamer1-plugins-bad-free
gstreamer1-plugins-base
gstreamer1-plugins-good
gstreamer1-plugins-good-gtk
gtk-update-icon-cache
gtk2
gtk3
gtkmm30
gtksourceview4
@guest-desktop-agents
gvfs
gvfs-client
gzip
harfbuzz
harfbuzz-icu
hicolor-icon-theme
hostname
ht-caladea-fonts
hunspell
hunspell-en
hunspell-en-GB
hunspell-en-US
hunspell-filesystem
hwdata
hyphen
hyphen-en
iceauth
ima-evm-utils
inih
initscripts
initscripts-rename-device
initscripts-service
iproute
iproute-tc
ipset
ipset-libs
iptables-libs
iptables-nft
iputils
irqbalance
iscsi-initiator-utils
iscsi-initiator-utils-iscsiuio
isns-utils-libs
iso-codes
isomd5sum
iw
iwl100-firmware
iwl1000-firmware
iwl105-firmware
iwl135-firmware
iwl2000-firmware
iwl2030-firmware
iwl3160-firmware
iwl5000-firmware
iwl5150-firmware
iwl6000g2a-firmware
iwl6050-firmware
iwl7260-firmware
jansson
java-11-openjdk-headless
javapackages-filesystem
javapackages-tools
jbigkit-libs
jomolhari-fonts
json-c
json-glib
julietaula-montserrat-fonts
kbd
kbd-misc
kdump-anaconda-addon
kernel
kernel-core
kernel-modules
kernel-modules-extra
kernel-tools
kernel-tools-libs
kexec-tools
keybinder3
keyutils-libs
khmer-os-system-fonts
kmod
kmod-libs
kpartx
krb5-libs
lame-libs
langpacks-core-en
langpacks-core-font-en
langpacks-en
langtable
lcms2
less
libICE
libSM
libX11
libX11-common
libX11-xcb
libXScrnSaver
libXau
libXaw
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
libXxf86dga
libXxf86vm
libabw
libacl
libaio
libappstream-glib
libarchive
libassuan
libasyncns
libatasmart
libattr
libbase
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
libblockdev-plugins-all
libblockdev-swap
libblockdev-utils
libbpf
libbrotli
libbytesize
libcanberra
libcanberra-gtk2
libcanberra-gtk3
libcap
libcap-ng
libcap-ng-python3
libcbor
libcdio
libcdio-paranoia
libcdr
libcmis
libcollection
libcom_err
libcomps
libconfig
libcurl
libdaemon
libdatrie
libdb
libdhash
libdmx
libdnf
libdrm
libdvdnav
libdvdread
libeconf
libedit
libepoxy
libepubgen
liberation-fonts
liberation-fonts-common
liberation-mono-fonts
liberation-sans-fonts
liberation-serif-fonts
libestr
libetonyek
libevdev
libevent
libexif
libexttextcat
libfastjson
libfdisk
libffi
libfido2
libfontenc
libfonts
libformula
libfreehand
libgcab1
libgcc
libgcrypt
libgexiv2
libglvnd
libglvnd-egl
libglvnd-glx
libglvnd-opengl
libgnomekbd
libgomp
libgpg-error
libgsf
libgudev
libgusb
libgxps
libhandy
libibverbs
libicu
libidn2
libini_config
libinput
libiptcdata
libjcat
libjpeg-turbo
libkcapi
libkcapi-hmaccalc
libksba
liblangtag
liblangtag-data
liblayout
libldac
libldb
libloader
libmnl
libmodulemd
libmount
libmpc
libmspub
libmwaw
libndp
libnetfilter_conntrack
libnfnetlink
libnftnl
libnghttp2
libnl3
libnl3-cli
libnma
libnotify
libnumbertext
libodfgen
libogg
liborcus
libosinfo
libpagemaker
libpath_utils
libpcap
libpciaccess
libpeas
libpeas-gtk
libpeas-loader-python3
libpipeline
libpng
libproxy
libproxy-webkitgtk4
libpsl
libpwquality
libqxp
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
libreport
libreport-anaconda
libreport-cli
libreport-filesystem
libreport-gtk
libreport-plugin-bugzilla
libreport-plugin-reportuploader
libreport-web
librepository
librevenge
librsvg2
libsbc
libseccomp
libsecret
libselinux
libselinux-utils
libsemanage
libsepol
libserializer
libshout
libsigc++20
libsigsegv
libsmartcols
libsmbios
libsndfile
libsolv
libsoup
libsrtp
libss
libssh
libssh-config
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
libtimezonemap
libtirpc
libtool-ltdl
libtracker-sparql
libudisks2
libunistring
libusal
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
libwebp
libwnck3
libwpd
libwpe
libwpg
libwps
libxcb
libxcrypt
libxcrypt-compat
libxfce4ui
libxfce4util
libxkbcommon
libxkbcommon-x11
libxkbfile
libxklavier
libxml2
libxmlb
libxshmfence
libxslt
libyaml
libzmf
libzstd
linux-firmware
linux-firmware-whence
lksctp-tools
lldpad
llvm-libs
lmdb-libs
logrotate
lohit-assamese-fonts
lohit-bengali-fonts
lohit-devanagari-fonts
lohit-gujarati-fonts
lohit-kannada-fonts
lohit-odia-fonts
lohit-tamil-fonts
lohit-telugu-fonts
low-memory-monitor
lpsolve
lshw
lsof
lsscsi
lua
lua-libs
lua-posix
lvm2
lvm2-libs
lz4-libs
lzo
man-db
mariadb-connector-c
mariadb-connector-c-config
mdadm
memtest86+
mesa-dri-drivers
mesa-filesystem
mesa-libEGL
mesa-libGL
mesa-libgbm
mesa-libglapi
mesa-libxatracker
mesa-vulkan-drivers
microcode_ctl
mkfontscale
mobile-broadband-provider-info
mokutil
mozilla-filesystem
mpfr
mpg123-libs
mtdev
mtools
mythes
mythes-en
nano
ncurses
ncurses-base
ncurses-libs
ndctl
ndctl-libs
neon
nettle
network-manager-applet
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
oddjob
oddjob-mkhomedir
ongres-scram
ongres-scram-client
openjpeg2
openldap
openldap-compat
openssh
openssh-askpass
openssh-clients
openssh-server
openssl
openssl-libs
openssl-pkcs11
opus
orc
os-prober
osinfo-db
osinfo-db-tools
ostree
ostree-libs
p11-kit
p11-kit-server
p11-kit-trust
paktype-naskh-basic-fonts
pam
pango
pangomm
parted
passwd
pavucontrol
pciutils-libs
pcre
pcre2
pcre2-syntax
pcre2-utf16
pentaho-libxml
pentaho-reporting-flow-engine
pigz
pipewire
pipewire-alsa
pipewire-jack-audio-connection-kit
pipewire-libs
pipewire-pulseaudio
pixman
plymouth
plymouth-core-libs
plymouth-graphics-libs
plymouth-plugin-label
plymouth-plugin-two-step
plymouth-scripts
plymouth-system-theme
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
postgresql-jdbc
prefixdevname
procps-ng
psmisc
pt-sans-fonts
publicsuffix-list-dafsa
pulseaudio-libs
pulseaudio-libs-glib2
pulseaudio-utils
python-unversioned-command
python3
python3-audit
python3-blivet
python3-blockdev
python3-bytesize
python3-cairo
python3-chardet
python3-dasbus
python3-dateutil
python3-dbus
python3-dnf
python3-dnf-plugins-core
python3-firewall
python3-gobject
python3-gobject-base
python3-gobject-base-noarch
python3-gpg
python3-hawkey
python3-idna
python3-kickstart
python3-langtable
python3-libcomps
python3-libdnf
python3-libreport
python3-libs
python3-libselinux
python3-libsemanage
python3-meh
python3-meh-gui
python3-nftables
python3-pid
python3-pip-wheel
python3-policycoreutils
python3-productmd
python3-pwquality
python3-pyparted
python3-pysocks
python3-pytz
python3-pyudev
python3-requests
python3-requests-file
python3-requests-ftp
python3-rpm
python3-setools
python3-setuptools
python3-setuptools-wheel
python3-simpleline
python3-six
python3-systemd
python3-urllib3
qt5-qtbase
qt5-qtbase-common
qt5-qtbase-gui
qt5-qtdeclarative
raptor2
rasqal
readline
realmd
redland
restore
rmt
rootfiles
rpm
rpm-build-libs
rpm-libs
rpm-plugin-audit
rpm-plugin-selinux
rpm-plugin-systemd-inhibit
rpm-sign-libs
rsync
rsyslog
rsyslog-logrotate
rtkit
sac
satyr
sddm
sddm-x11
sed
selinux-policy
selinux-policy-targeted
setup
sg3_utils
sg3_utils-libs
shadow-utils
shared-mime-info
shim-x64
sil-abyssinica-fonts
sil-nuosu-fonts
sil-padauk-fonts
slang
smc-meera-fonts
snappy
sound-theme-freedesktop
soundtouch
speex
sqlite-libs
squashfs-tools
sssd-client
sssd-common
sssd-kcm
startup-notification
stix-fonts
sudo
syslinux
syslinux-extlinux
syslinux-extlinux-nonlinux
syslinux-nonlinux
systemd
systemd-libs
systemd-pam
systemd-rpm-macros
systemd-udev
taglib
tar
teamd
thai-scalable-fonts-common
thai-scalable-waree-fonts
thunar-archive-plugin
thunar-volman
tigervnc-license
tigervnc-server-minimal
tmux
totem-pl-parser
tpm2-tss
tracker
tracker-miners
tumbler
twolame-libs
tzdata
tzdata-java
udisks2
unzip
upower
usermode
userspace-rcu
util-linux
util-linux-core
vim-minimal
volume_key-libs
vte-profile
vte291
vulkan-loader
wavpack
webkit2gtk3
webkit2gtk3-jsc
webrtc-audio-processing
which
wireless-regdb
wireplumber
wireplumber-libs
woff2
wpa_supplicant
wpebackend-fdo
xcb-util
xcb-util-image
xcb-util-keysyms
xcb-util-renderutil
xcb-util-wm
xdg-dbus-proxy
xdg-desktop-portal
xdg-desktop-portal-gtk
xdg-user-dirs-gtk
xdg-utils
xfce-polkit
xfce4-appfinder
xfce4-panel
xfce4-power-manager
xfce4-pulseaudio-plugin
xfce4-screensaver
xfce4-screenshooter
xfce4-session
xfce4-settings
xfce4-terminal
xfconf
xfdesktop
xfsprogs
xfwm4
xkbcomp
xkeyboard-config
xml-common
xmlrpc-c
xmlrpc-c-client
xmlsec1
xmlsec1-nss
xorg-x11-drv-evdev
xorg-x11-drv-fbdev
xorg-x11-drv-libinput
xorg-x11-drv-vmware
xorg-x11-drv-wacom
xorg-x11-drv-wacom-serial-support
xorg-x11-fonts-misc
xorg-x11-server-Xorg
xorg-x11-server-common
xorg-x11-server-utils
xorg-x11-utils
xorg-x11-xauth
xorg-x11-xinit
xorg-x11-xinit-session
xterm
xterm-resize
xz
xz-libs
yelp
yelp-libs
yelp-xsl
yum
zenity
zlib
zstd

%end
