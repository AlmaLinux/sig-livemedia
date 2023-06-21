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
url --url=https://rsync.repo.almalinux.org/almalinux/8/BaseOS/$basearch/os/
repo --name="appstream" --baseurl=https://rsync.repo.almalinux.org/almalinux/8/AppStream/$basearch/os/
repo --name="extras" --baseurl=https://rsync.repo.almalinux.org/almalinux/8/extras/$basearch/os/
repo --name="powertools" --baseurl=https://rsync.repo.almalinux.org/almalinux/8/PowerTools/$basearch/os/
repo --name="epel" --baseurl=https://dl.fedoraproject.org/pub/epel/8/Everything/$basearch/

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

# Uncomment line with logo
if [ -f /etc/lightdm/slick-greeter.conf ]; then
  mv /etc/lightdm/slick-greeter.conf  /etc/lightdm/slick-greeter.conf_saved
fi
cat > /etc/lightdm/lightdm-gtk-greeter.conf << SLK_EOF
[Greeter]
logo=

SLK_EOF

# Turn off PackageKit-command-not-found while uninstalled
if [ -f /etc/PackageKit/CommandNotFound.conf ]; then
  sed -i -e 's/^SoftwareSourceSearch=true/SoftwareSourceSearch=false/' /etc/PackageKit/CommandNotFound.conf
fi

# make sure to set the right permissions and selinux contexts
chown -R liveuser:liveuser /home/liveuser/
restorecon -R /home/liveuser/

EOF

%end

%packages
abattis-cantarell-fonts
abrt
abrt-addon-ccpp
abrt-addon-coredump-helper
abrt-addon-kerneloops
abrt-addon-pstoreoops
abrt-addon-vmcore
abrt-addon-xorg
abrt-dbus
abrt-desktop
abrt-gui
abrt-gui-libs
abrt-java-connector
abrt-libs
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
almalinux-backgrounds-extras
almalinux-indexhtml
almalinux-logos
almalinux-release
alsa-lib
alsa-plugins-pulseaudio
alsa-utils
anaconda-core
anaconda-gui
anaconda-tui
anaconda-user-help
anaconda-widgets
aspell
atk
atkmm
atril
atril-caja
atril-libs
atril-thumbnailer
at-spi2-atk
at-spi2-core
audit
audit-libs
augeas-libs
authselect
authselect-libs
avahi-glib
avahi-libs
basesystem
bash
biosdevname
blivet-data
bluez
bluez-libs
brotli
bubblewrap
bzip2-libs
ca-certificates
cairo
cairo-gobject
cairomm
caja
caja-actions
caja-actions-doc
caja-core-extensions
caja-extensions-common
caja-image-converter
caja-open-terminal
caja-schemas
caja-sendto
caja-wallpaper
caja-xattr-tags
c-ares
chkconfig
chrony
colord-libs
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
curl
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
dconf-editor
dejavu-fonts-common
dejavu-sans-mono-fonts
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
dosfstools
dracut
dracut-config-rescue
dracut-network
dracut-squash
e2fsprogs
e2fsprogs-libs
efibootmgr
efi-filesystem
efivar-libs
elfutils
elfutils-debuginfod-client
elfutils-default-yama-scope
elfutils-libelf
elfutils-libs
emacs-filesystem
enchant2
engrampa
eom
epel-release
ethtool
exempi
expat
file
file-libs
filesystem
findutils
firefox
firewall-config
firewalld
firewalld-filesystem
flac-libs
flatpak-libs
fontconfig
fontpackages-filesystem
fortune-mod
freetype
fribidi
fuse
fuse-common
fuse-libs
fwupd
gamin
gawk
gc
GConf2
gcr
gd
gdb-headless
gdbm
gdbm-libs
gdisk
gdk-pixbuf2
gdk-pixbuf2-modules
geany
geany-libgeany
gedit
geoclue2
gettext
gettext-libs
glib2
glibc
glibc-all-langpacks
glibc-common
glibc-gconv-extra
glibc-langpack-en
glibmm24
glib-networking
glx-utils
gmp
gnome-abrt
gnome-disk-utility
gnome-keyring
gnome-keyring-pam
gnome-menus
gnome-themes-standard
gnupg2
gnutls
gobject-introspection
google-droid-sans-fonts
google-noto-fonts-common
google-noto-sans-fonts
gpgme
graphite2
graphviz
grep
groff-base
group-service
grub2-common
grub2-efi-x64
grub2-tools
grub2-tools-efi
grub2-tools-extra
grub2-tools-minimal
grubby
gsettings-desktop-schemas
gsm
gspell
gssdp
gstreamer1
gstreamer1-plugins-bad-free
gstreamer1-plugins-base
gstreamer1-plugins-good
gstreamer1-plugins-ugly-free
gtk2
gtk2-engines
gtk3
gtk-layer-shell
gtkmm30
gtksourceview3
gtk-update-icon-cache
gucharmap
gucharmap-libs
guile
gupnp
gvfs
gvfs-afc
gvfs-afp
gvfs-archive
gvfs-client
gvfs-fuse
gvfs-gphoto2
gvfs-mtp
gvfs-smb
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
ilmbase
ima-evm-utils
ImageMagick
ImageMagick-libs
info
initial-setup
initial-setup-gui
initscripts
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
iw
iwl1000-firmware
iwl100-firmware
iwl105-firmware
iwl135-firmware
iwl2000-firmware
iwl2030-firmware
iwl3160-firmware
iwl5000-firmware
iwl5150-firmware
iwl6000-firmware
iwl6000g2a-firmware
iwl6050-firmware
iwl7260-firmware
jansson
jasper-libs
jbig2dec-libs
jbigkit-libs
jq
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
langtable
lcms2
ldns
less
liba52
libacl
libaio
libappindicator-gtk3
libarchive
libassuan
libasyncns
libatasmart
libatomic_ops
libattr
libavc1394
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
libblockdev-swap
libblockdev-utils
libbpf
libbytesize
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
libdbusmenu
libdbusmenu-gtk3
libdb-utils
libdhash
libdmx
libdnf
libdrm
libdv
libdvdnav
libdvdread
libedit
libepoxy
liberation-fonts-common
liberation-sans-fonts
libevdev
libevent
libexif
libfdisk
libffi
libfontenc
libgcab1
libgcc
libgcrypt
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
libgtop2
libgudev
libgusb
libgxps
libibverbs
libICE
libicu
libidn
libidn2
libiec61883
libijs
libimobiledevice
libindicator-gtk3
libini_config
libinput
libipt
libjpeg-turbo
libkcapi
libkcapi-hmaccalc
libksba
libldb
libmatekbd
libmatemixer
libmateweather
libmateweather-data
libmbim
libmbim-utils
libmcpp
libmnl
libmodman
libmodulemd
libmount
libmspack
libmtp
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
libogg
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
libpng
libproxy
libpsl
libpwquality
libqmi
libqmi-utils
libraqm
LibRaw
libraw1394
libref_array
librepo
libreport
libreport-anaconda
libreport-cli
libreport-filesystem
libreport-gtk
libreport-plugin-reportuploader
libreport-plugin-ureport
libreport-web
libreswan
librsvg2
libsamplerate
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
libusbmuxd
libusbx
libuser
libutempter
libuuid
libv4l
libverto
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
libX11
libX11-common
libX11-xcb
libXau
libXaw
libxcb
libXcomposite
libxcrypt
libXcursor
libXdamage
libXdmcp
libXext
libXfixes
libXfont2
libXft
libXi
libXinerama
libxkbcommon
libxkbfile
libxklavier
libxml2
libxmlb
libXmu
libXpm
libXpresent
libXrandr
libXrender
libXres
libXScrnSaver
libxshmfence
libxslt
libXt
libXtst
libXv
libXvMC
libXxf86dga
libXxf86misc
libXxf86vm
libyaml
libzstd
lightdm
lightdm-gobject
lightdm-gtk
linux-firmware
llvm-libs
lmdb-libs
lm_sensors
lm_sensors-libs
lockdev
logrotate
lshw
lsof
lsscsi
lua-libs
lvm2
lvm2-libs
lz4
lz4-libs
lzo
man-db
marco
marco-libs
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
mate-session-manager
mate-settings-daemon
mate-system-log
mate-system-monitor
mate-terminal
mate-user-admin
mate-user-guide
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
mcpp
mdadm
memstrack
mesa-dri-drivers
mesa-filesystem
mesa-libEGL
mesa-libgbm
mesa-libGL
mesa-libglapi
mesa-libxatracker
microcode_ctl
mobile-broadband-provider-info
ModemManager
ModemManager-glib
mokutil
mozilla-filesystem
mozjs60
mozo
mpfr
mpg123-libs
mtdev
nano
ncurses
ncurses-base
ncurses-libs
ndctl
ndctl-libs
nettle
NetworkManager
NetworkManager-adsl
network-manager-applet
NetworkManager-bluetooth
NetworkManager-libnm
NetworkManager-libreswan
NetworkManager-libreswan-gnome
NetworkManager-openvpn
NetworkManager-openvpn-gnome
NetworkManager-ovs
NetworkManager-ppp
NetworkManager-team
NetworkManager-tui
NetworkManager-wifi
NetworkManager-wwan
newt
nftables
nm-connection-editor
npth
nspr
nss
nss-softokn
nss-softokn-freebl
nss-sysinit
nss-tools
nss-util
numactl-libs
oniguruma
OpenEXR-libs
openjpeg2
openldap
openssh
openssh-clients
openssh-server
openssl
openssl-libs
openssl-pkcs11
open-vm-tools
open-vm-tools-desktop
openvpn
opus
orc
os-prober
ostree
ostree-libs
p11-kit
p11-kit-trust
p7zip
p7zip-plugins
pam
pango
pangomm
parted
passwd
pciutils
pciutils-libs
pcre
pcre2
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
pinentry-gnome3
pixman
pkcs11-helper
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
polkit
polkit-libs
polkit-pkla-compat
poppler
poppler-data
poppler-glib
popt
ppp
prefixdevname
procps-ng
psmisc
publicsuffix-list-dafsa
pulseaudio
pulseaudio-libs
pulseaudio-libs-glib2
python36
python3-abrt
python3-abrt-addon
python3-augeas
python3-blivet
python3-blockdev
python3-bytesize
python3-cairo
python3-chardet
python3-dasbus
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
python3-humanize
python3-idna
python3-inotify
python3-kickstart
python3-langtable
python3-libcomps
python3-libdnf
python3-libreport
python3-libs
python3-libselinux
python3-linux-procfs
python3-meh
python3-meh-gui
python3-nftables
python3-ntplib
python3-ordered-set
python3-perf
python3-pid
python3-pip
python3-pip-wheel
python3-productmd
python3-psutil
python3-pwquality
python3-pyparted
python3-pysocks
python3-pytz
python3-pyudev
python3-requests
python3-requests-file
python3-requests-ftp
python3-rpm
python3-setproctitle
python3-setuptools
python3-setuptools-wheel
python3-simpleline
python3-six
python3-slip
python3-slip-dbus
python3-syspurpose
python3-systemd
python3-urllib3
# python3-xapp
readline
recode
rest
rootfiles
rpm
rpm-build-libs
rpm-libs
rpm-plugin-selinux
rtkit
samba-client-libs
samba-common
samba-common-libs
satyr
seahorse
sed
selinux-policy
selinux-policy-targeted
setup
sg3_utils
sg3_utils-libs
shadow-utils
shared-mime-info
shim-x64
slang
snappy
sound-theme-freedesktop
soundtouch
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
systemd
systemd-libs
systemd-pam
systemd-udev
taglib
tar
teamd
tigervnc-license
tigervnc-server-minimal
timedatex
tpm2-tss
trousers
trousers-lib
tuned
twolame-libs
tzdata
udisks2
unbound-libs
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
usbmuxd
usermode
userspace-rcu
util-linux
vim-minimal
virt-what
volume_key-libs
vte291
vte-profile
wavpack
web-assets-filesystem
webkit2gtk3
webkit2gtk3-jsc
webrtc-audio-processing
which
woff2
wpa_supplicant
xcb-util
xdg-user-dirs
xdg-user-dirs-gtk
xdg-utils
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
xorg-x11-fonts-ISO8859-1-100dpi
xorg-x11-font-utils
xorg-x11-server-common
xorg-x11-server-utils
xorg-x11-server-Xorg
xorg-x11-utils
xorg-x11-xauth
xorg-x11-xinit
xorg-x11-xinit-session
xorg-x11-xkb-utils
xz
xz-libs
yelp
yelp-libs
yelp-xsl
yum
zenity
zlib
@anaconda-tools
anaconda-live
chkconfig
dracut-config-generic
dracut-live
efibootmgr
-gdm
glibc-all-langpacks
grub2-efi
grub2-efi-x64-cdboot
grub2-pc-modules
initscripts
kernel
kernel-modules
kernel-modules-extra
memtest86+
nano
rsync
shim-x64
syslinux
-@dial-up
-@input-methods
-gfs2-utils
almalinux-backgrounds
almalinux-backgrounds-extras
-desktop-backgrounds-compat
aajohan-comfortaa-fonts
firefox
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
liberation-fonts
liberation-fonts-common
liberation-mono-fonts
liberation-sans-fonts
liberation-serif-fonts
# thunderbird
isomd5sum
file-roller
gnome-software
tar 
lightdm
lightdm-gobject
# lightdm-settings
# lightdm-gtk
# slick-greeter
slick-greeter-mate
gjs

%end
