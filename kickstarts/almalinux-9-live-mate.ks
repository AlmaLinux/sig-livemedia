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
if [ -f /etc/lightdm/slick-greeter.conf ]; then
  mv /etc/lightdm/slick-greeter.conf  /etc/lightdm/slick-greeter.conf_saved
fi
cat > /etc/lightdm/slick-greeter.conf << SLK_EOF
[Greeter]
logo=
SLK_EOF

systemctl enable --force lightdm.service

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
if [ -f /etc/lightdm/slick-greeter.conf ]; then
  mv /etc/lightdm/slick-greeter.conf  /etc/lightdm/slick-greeter.conf_saved
fi
cat > /etc/lightdm/slick-greeter.conf << SLK_EOF
[Greeter]
logo=
SLK_EOF

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
  # and mark it as executable (new Xfce security feature)
  chmod +x /usr/share/applications/liveinst.desktop
  # copy to desktop
  mkdir -p /home/liveuser/Desktop
  cp -a /usr/share/applications/liveinst.desktop /home/liveuser/Desktop/

  # need to move it to anaconda.desktop to make shell happy
  mv /usr/share/applications/liveinst.desktop /usr/share/applications/anaconda.desktop

  cat >> /usr/share/glib-2.0/schemas/org.gnome.shell.gschema.override << FOE
[org.gnome.shell]
favorite-apps=['firefox.desktop', 'evolution.desktop', 'rhythmbox.desktop', 'shotwell.desktop', 'org.gnome.Nautilus.desktop', 'anaconda.desktop']
FOE

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

# rebuild schema cache with any overrides we installed
glib-compile-schemas /usr/share/glib-2.0/schemas

# set up auto-login
## gdm auto login
# set up autologin for user liveuser
if [ -f /etc/lightdm/lightdm.conf ]; then
  mv /etc/lightdm/lightdm.conf  /etc/lightdm/lightdm.conf_saved
fi
cat > /etc/lightdm/lightdm.conf << LDM_EOF
[LightDM]

[Seat:*]
user-session=mate
autologin-user=liveuser
autologin-user-timeout=0
autologin-session=mate

[XDMCPServer]

[VNCServer]

LDM_EOF

if [ -f /etc/lightdm/lightdm-gtk-greeter.conf ]; then
  mv /etc/lightdm/lightdm-gtk-greeter.conf /etc/lightdm/lightdm-gtk-greeter.conf_saved
fi
cat > /etc/lightdm/lightdm-gtk-greeter.conf << SLG_EOF
[Greeter]
background=/usr/share/backgrounds/default.png
background-color=#729fcf
stretch-background-across-monitors=true

SLG_EOF

# Turn off PackageKit-command-not-found while uninstalled
if [ -f /etc/PackageKit/CommandNotFound.conf ]; then
  sed -i -e 's/^SoftwareSourceSearch=true/SoftwareSourceSearch=false/' /etc/PackageKit/CommandNotFound.conf
fi

# make sure to set the right permissions and selinux contexts
chown -R liveuser:liveuser /home/liveuser/
restorecon -R /home/liveuser/
restorecon -R /

EOF

# enable CRB repo
dnf config-manager --enable crb

%end

%packages
Box2D
ImageMagick-libs
LibRaw
ModemManager
ModemManager-glib
NetworkManager
NetworkManager-adsl
NetworkManager-bluetooth
NetworkManager-l2tp
NetworkManager-l2tp-gnome
NetworkManager-libnm
NetworkManager-libreswan
NetworkManager-libreswan-gnome
NetworkManager-openconnect
NetworkManager-openconnect-gnome
NetworkManager-openvpn
NetworkManager-openvpn-gnome
NetworkManager-ovs
NetworkManager-ppp
NetworkManager-pptp
NetworkManager-pptp-gnome
NetworkManager-team
NetworkManager-tui
NetworkManager-wifi
NetworkManager-wwan
PackageKit
PackageKit-glib
PackageKit-gstreamer-plugin
SDL2
aajohan-comfortaa-fonts
abattis-cantarell-fonts
accountsservice
accountsservice-libs
acl
adcli
adobe-mappings-cmap
adobe-mappings-cmap-deprecated
adobe-mappings-pdf
adobe-source-code-pro-fonts
adwaita-cursor-theme
adwaita-gtk2-theme
adwaita-icon-theme
almalinux-backgrounds
almalinux-backgrounds-extras
almalinux-gpg-keys
almalinux-indexhtml
almalinux-logos
almalinux-release
almalinux-repos
alsa-lib
alsa-sof-firmware
alsa-ucm
alsa-utils
alternatives
anaconda
anaconda-core
anaconda-gui
anaconda-install-env-deps
anaconda-live
anaconda-tui
anaconda-user-help
anaconda-widgets
at
at-spi2-atk
at-spi2-core
atk
atkmm
atril
atril-caja
atril-libs
atril-thumbnailer
attr
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
bash-completion
bc
beesu
bind-libs
bind-license
bind-utils
binutils
binutils-gold
blivet-data
blktrace
bluez
bluez-libs
bolt
boost-chrono
boost-date-time
boost-filesystem
boost-iostreams
boost-locale
boost-regex
boost-system
boost-thread
bpftool
brlapi
brltty
bubblewrap
bzip2
bzip2-libs
c-ares
ca-certificates
cairo
cairo-gobject
cairomm
caja
caja-actions
caja-actions-doc
caja-core-extensions
caja-schemas
checkpolicy
chkconfig
chrony
clevis
clevis-luks
clucene-contribs-lib
clucene-core
cockpit
cockpit-bridge
cockpit-packagekit
cockpit-storaged
cockpit-system
cockpit-ws
colord-libs
copy-jdk-configs
coreutils
coreutils-common
cpio
cpp
cracklib
cracklib-dicts
createrepo_c
createrepo_c-libs
cronie
cronie-anacron
crontabs
crypto-policies
crypto-policies-scripts
cryptsetup
cryptsetup-libs
cups-libs
curl
cyrus-sasl-gssapi
cyrus-sasl-lib
cyrus-sasl-plain
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
dconf-editor
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
djvulibre-libs
dmidecode
dnf
dnf-data
dnf-plugins-core
dos2unix
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
ed
efi-filesystem
efibootmgr
efivar-libs
elfutils-debuginfod-client
elfutils-default-yama-scope
elfutils-libelf
elfutils-libs
emacs-filesystem
enchant
enchant2
engrampa
eom
epel-release
espeak-ng
ethtool
exempi
exiv2
exiv2-libs
expat
f36-backgrounds-base
f36-backgrounds-extras-base
f36-backgrounds-extras-mate
f36-backgrounds-mate
fcoe-utils
fdk-aac-free
file
file-libs
filesystem
filezilla
findutils
firefox
firewall-applet
firewall-config
firewalld
firewalld-filesystem
flac-libs
flashrom
flatpak
flatpak-libs
flatpak-selinux
flatpak-session-helper
fontconfig
fonts-filesystem
fortune-mod
fprintd
fprintd-pam
freetype
fribidi
fstrm
fuse
fuse-common
fuse-libs
fuse3
fuse3-libs
fwupd
fwupd-plugin-flashrom
gawk
gawk-all-langpacks
gcr
gcr-base
gd
gdb
gdb-headless
gdbm-libs
gdisk
gdk-pixbuf2
gdk-pixbuf2-modules
geany
geany-libgeany
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
gnome-disk-utility
gnome-epub-thumbnailer
gnome-keyring
gnome-keyring-pam
gnome-menus
gnome-themes-extra
gnupg2
gnutls
gobject-introspection
google-carlito-fonts
google-droid-sans-fonts
google-noto-cjk-fonts-common
google-noto-emoji-color-fonts
google-noto-fonts-common
google-noto-sans-cjk-ttc-fonts
google-noto-sans-fonts
google-noto-sans-gurmukhi-fonts
google-noto-sans-sinhala-vf-fonts
google-noto-serif-cjk-ttc-fonts
gparted
gpgme
gpgmepp
gpm-libs
graphene
graphite2
graphviz
grep
groff-base
group-service
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
gstreamer1
gstreamer1-plugins-bad-free
gstreamer1-plugins-base
gstreamer1-plugins-good
gstreamer1-plugins-good-gtk
gstreamer1-plugins-ugly-free
gtk-layer-shell
gtk-murrine-engine
gtk-update-icon-cache
gtk2
gtk2-engines
gtk3
gtkmm30
gtksourceview3
gtksourceview4
gucharmap
gucharmap-libs
@guest-desktop-agents
gvfs
gvfs-client
gvfs-fuse
gvfs-gphoto2
gvfs-mtp
gvfs-smb
gzip
harfbuzz
harfbuzz-icu
hddtemp
hdparm
hexchat
hicolor-icon-theme
highcontrast-icon-theme
hostname
ht-caladea-fonts
hunspell
hunspell-en
hunspell-en-GB
hunspell-en-US
hunspell-filesystem
hwdata
hyperv-daemons
hyperv-daemons-license
hypervfcopyd
hypervkvpd
hypervvssd
hyphen
hyphen-en
ima-evm-utils
imath
info
inih
initial-setup
initial-setup-gui
initscripts
initscripts-rename-device
initscripts-service
iproute
iproute-tc
iprutils
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
iwl6000g2b-firmware
iwl6050-firmware
iwl7260-firmware
jansson
jasper-libs
java-11-openjdk-headless
javapackages-filesystem
jbig2dec-libs
jbigkit-libs
jomolhari-fonts
jose
jq
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
kmod-kvdo
kmod-libs
kpartx
kpatch
kpatch-dnf
krb5-libs
lame-libs
langpacks-core-en
langpacks-core-font-en
langpacks-en
langtable
lcms2
ldns
ledmon
less
libICE
libSM
libX11
libX11-common
libX11-xcb
libXNVCtrl
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
libXpresent
libXrandr
libXrender
libXres
libXt
libXtst
libXv
libXxf86dga
libXxf86vm
liba52
libabw
libacl
libaio
libao
libappindicator-gtk3
libappstream-glib
libarchive
libassuan
libasyncns
libatasmart
libattr
libbabeltrace
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
libcryptui
libcurl
libdaemon
libdatrie
libdb
libdbusmenu
libdbusmenu-gtk3
libdecor
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
liberation-fonts-common
liberation-mono-fonts
liberation-sans-fonts
liberation-serif-fonts
libertas-sd8787-firmware
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
libfilezilla
libfontenc
libfprint
libfreehand
libgcab1
libgcc
libgcrypt
libgexiv2
libglvnd
libglvnd-egl
libglvnd-gles
libglvnd-glx
libglvnd-opengl
libgnomekbd
libgomp
libgpg-error
libgphoto2
libgs
libgsf
libgtop2
libgudev
libgusb
libgxps
libhandy
libibverbs
libicu
libidn2
libijs
libindicator-gtk3
libini_config
libinput
libipa_hbac
libipt
libiptcdata
libjcat
libjose
libjpeg-turbo
libkcapi
libkcapi-hmaccalc
libksba
liblangtag
liblangtag-data
libldac
libldb
liblouis
liblqr-1
libluksmeta
libmatekbd
libmatemixer
libmateweather
libmateweather-data
libmaxminddb
libmbim
libmbim-utils
libmnl
libmodulemd
libmount
libmpc
libmpeg2
libmspack
libmspub
libmtp
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
libnvme
libodfgen
libogg
liborcus
libosinfo
libpagemaker
libpaper
libpath_utils
libpcap
libpciaccess
libpeas
libpeas-gtk
libpeas-loader-python3
libpipeline
libpkgconf
libpng
libproxy
libproxy-webkitgtk4
libpskc
libpsl
libpwquality
libqmi
libqmi-utils
libqrtr-glib
libqxp
libraqm
libref_array
librelp
libreoffice-calc
libreoffice-core
libreoffice-data
libreoffice-draw
libreoffice-emailmerge
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
libreswan
librevenge
librsvg2
librsvg2-tools
libsamplerate
libsbc
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
libsss_certmap
libsss_idmap
libsss_nss_idmap
libsss_sudo
libstaroffice
libstdc++
libstemmer
libstoragemgmt
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
libusbx
libuser
libutempter
libuuid
libuv
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
libwmf-lite
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
lightdm
lightdm-gobject
lightdm-settings
linux-firmware
linux-firmware-whence
lksctp-tools
lldpad
llvm-libs
lm_sensors
lm_sensors-libs
lmdb-libs
lockdev
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
luksmeta
lvm2
lvm2-libs
lz4-libs
lzo
mailcap
man-db
man-pages
man-pages-overrides
marco
marco-libs
mariadb-connector-c
mariadb-connector-c-config
mate-applets
mate-backgrounds
mate-calc
mate-control-center
mate-control-center-filesystem
mate-desktop
mate-desktop-configs
mate-desktop-libs
mate-dictionary
mate-disk-usage-analyzer
mate-icon-theme
mate-media
mate-menu
mate-menus
mate-menus-libs
mate-menus-preferences-category-menu
mate-notification-daemon
mate-panel
mate-panel-libs
mate-polkit
mate-power-manager
mate-screensaver
mate-screenshot
mate-search-tool
mate-sensors-applet
mate-session-manager
mate-settings-daemon
mate-system-log
mate-system-monitor
mate-terminal
mate-themes
mate-user-admin
mate-user-guide
mate-utils
mate-utils-common
mathjax
mathjax-ams-fonts
mathjax-caligraphic-fonts
mathjax-fraktur-fonts
mathjax-main-fonts
mathjax-math-fonts
mathjax-sansserif-fonts
mathjax-script-fonts
mathjax-size1-fonts
mathjax-size2-fonts
mathjax-size3-fonts
mathjax-size4-fonts
mathjax-stixweb-fonts
mathjax-typewriter-fonts
mathjax-vector-fonts
mathjax-winchrome-fonts
mathjax-winie6-fonts
mcelog
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
mlocate
mobile-broadband-provider-info
mokutil
mozilla-filesystem
mozo
mpfr
mpg123-libs
mtdev
mtools
mtr
mythes
mythes-en
nano
ncurses
ncurses-base
ncurses-libs
ndctl
ndctl-libs
neon
net-tools
netronome-firmware
nettle
network-manager-applet
newt
nftables
nm-connection-editor
nmap-ncat
npth
nspr
nss
nss-softokn
nss-softokn-freebl
nss-sysinit
nss-tools
nss-util
numactl-libs
nvme-cli
oddjob
oddjob-mkhomedir
oniguruma
open-vm-tools
open-vm-tools-desktop
openconnect
openexr-libs
openjpeg2
openldap
openldap-compat
openssh
openssh-clients
openssh-server
openssl
openssl-libs
openssl-pkcs11
openvpn
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
p7zip
p7zip-plugins
paktype-naskh-basic-fonts
pam
pango
pangomm
parole
parted
passwd
pavucontrol
pcaudiolib
pciutils
pciutils-libs
pcre
pcre2
pcre2-syntax
pcre2-utf16
pcre2-utf32
pcsc-lite-libs
perl-AutoLoader
perl-B
perl-Carp
perl-Class-Struct
perl-Data-Dumper
perl-Digest
perl-Digest-MD5
perl-Encode
perl-Errno
perl-Exporter
perl-Fcntl
perl-File-Basename
perl-File-Path
perl-File-Temp
perl-File-stat
perl-FileHandle
perl-Getopt-Long
perl-Getopt-Std
perl-HTTP-Tiny
perl-IO
perl-IO-Socket-IP
perl-IO-Socket-SSL
perl-IPC-Open3
perl-MIME-Base64
perl-Mozilla-CA
perl-NDBM_File
perl-Net-SSLeay
perl-POSIX
perl-PathTools
perl-Pod-Escapes
perl-Pod-Perldoc
perl-Pod-Simple
perl-Pod-Usage
perl-Scalar-List-Utils
perl-SelectSaver
perl-Socket
perl-Storable
perl-Symbol
perl-Term-ANSIColor
perl-Term-Cap
perl-Text-ParseWords
perl-Text-Tabs+Wrap
perl-Time-Local
perl-URI
perl-base
perl-constant
perl-if
perl-interpreter
perl-libnet
perl-libs
perl-mro
perl-overload
perl-overloading
perl-parent
perl-podlators
perl-subs
perl-vars
pigz
pinentry
pinentry-gnome3
pinfo
pipewire
pipewire-alsa
pipewire-gstreamer
pipewire-jack-audio-connection-kit
pipewire-libs
pipewire-pulseaudio
pipewire-utils
pixman
pkcs11-helper
pkgconf
pkgconf-m4
pkgconf-pkg-config
pluma
pluma-data
pluma-plugins
pluma-plugins-data
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
ppp
pptp
prefixdevname
procps-ng
protobuf-c
psacct
psmisc
pt-sans-fonts
publicsuffix-list-dafsa
pugixml
pulseaudio-libs
pulseaudio-libs-glib2
pulseaudio-utils
python-qt5-rpm-macros
python-unversioned-command
python3
python3-audit
python3-blivet
python3-blockdev
python3-brlapi
python3-bytesize
python3-cairo
python3-cffi
python3-chardet
python3-configobj
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
python3-libstoragemgmt
python3-libxml2
python3-linux-procfs
python3-louis
python3-lxml
python3-meh
python3-meh-gui
python3-nftables
python3-perf
python3-pexpect
python3-pid
python3-pip-wheel
python3-ply
python3-policycoreutils
python3-productmd
python3-psutil
python3-ptyprocess
python3-pwquality
python3-pyatspi
python3-pycparser
python3-pyparted
python3-pyqt5-sip
python3-pysocks
python3-pytz
python3-pyudev
python3-pyxdg
python3-qt5-base
python3-requests
python3-requests-file
python3-requests-ftp
python3-rpm
python3-setools
python3-setproctitle
python3-setuptools
python3-setuptools-wheel
python3-simpleline
python3-six
python3-speechd
python3-systemd
python3-tracer
python3-unidecode
python3-urllib3
python3-xapp
python3-xlib
qemu-guest-agent
qt5-qtbase
qt5-qtbase-common
qt5-qtbase-gui
qt5-qtdeclarative
quota
quota-nls
raptor2
rasqal
readline
realmd
recode
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
rsyslog-gnutls
rsyslog-gssapi
rsyslog-logrotate
rsyslog-relp
rtkit
samba-client-libs
samba-common
samba-common-libs
satyr
seahorse
seahorse-caja
sed
selinux-policy
selinux-policy-targeted
setroubleshoot
setroubleshoot-plugins
setroubleshoot-server
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
slick-greeter
slick-greeter-mate
smartmontools
smc-meera-fonts
snappy
sos
sound-theme-freedesktop
soundtouch
source-highlight
speech-dispatcher
speech-dispatcher-espeak-ng
speex
spice-vdagent
sqlite-libs
squashfs-tools
sscg
sssd
sssd-ad
sssd-client
sssd-common
sssd-common-pac
sssd-ipa
sssd-kcm
sssd-krb5
sssd-krb5-common
sssd-ldap
sssd-proxy
startup-notification
stix-fonts
stoken-libs
strace
sudo
symlinks
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
tcl
tcpdump
teamd
texlive-lib
thai-scalable-fonts-common
thai-scalable-waree-fonts
tigervnc-license
tigervnc-server-minimal
time
tmux
totem-pl-parser
tpm2-tools
tpm2-tss
tracer-common
tracker
tracker-miners
tree
trousers-lib
tuned
twolame-libs
tzdata
tzdata-java
udisks2
udisks2-iscsi
udisks2-lvm2
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
usbutils
usermode
usermode-gtk
userspace-rcu
util-linux
util-linux-core
util-linux-user
vdo
vim-common
vim-enhanced
vim-filesystem
vim-minimal
virt-what
volume_key-libs
vpnc-script
vte-profile
vte291
vulkan-loader
wavpack
web-assets-filesystem
webkit2gtk3
webkit2gtk3-jsc
webrtc-audio-processing
wget
which
wireless-regdb
wireplumber
wireplumber-libs
woff2
words
wpa_supplicant
wpebackend-fdo
wxBase3
wxGTK3
wxGTK3-i18n
xcb-util
xcb-util-image
xcb-util-keysyms
xcb-util-renderutil
xcb-util-wm
xdg-dbus-proxy
xdg-desktop-portal
xdg-desktop-portal-gtk
xdg-user-dirs
xdg-user-dirs-gtk
xdg-utils
xfconf
xfsdump
xfsprogs
xkbcomp
xkeyboard-config
xl2tpd
xml-common
xmlrpc-c
xmlrpc-c-client
xmlsec1
xmlsec1-nss
xmlsec1-openssl
xorg-x11-drv-evdev
xorg-x11-drv-fbdev
xorg-x11-drv-libinput
xorg-x11-drv-vmware
xorg-x11-drv-wacom
xorg-x11-drv-wacom-serial-support
xorg-x11-fonts-ISO8859-1-100dpi
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
zip
zlib
zstd


%end
