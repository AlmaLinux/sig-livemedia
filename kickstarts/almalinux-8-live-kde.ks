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

# TODO: remove next when epel is updated
# repo --name="epel-next" --baseurl=https://dl.fedoraproject.org/pub/epel/next/8/Everything/$basearch/ --cost=1000 --install

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
zerombr
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

# Enable sddm since EPEL packages it disabled by default
systemctl enable sddm.service

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

# TODO: almalinux-backgrounds-extras package looks good, remove inline method
# on next build
generateKDEWallpapers() {
  # Declare an array for background types
  declare -a bgtypes=("dark" "light" "abstract-dark" "abstract-light")
  # Declare an array for background sizes
  declare -a sizes=("1800x1440.jpg" "2048x1536.jpg" "2560x1080.jpg" "2560x1440.jpg" "2560x1600.jpg" "3440x1440.jpg")
  ## Loop through the above array(s) types and sizes to create links and metadata
  for bg in "${bgtypes[@]}"
  do
    echo "Processing 'Alma-"$bg"' background"
    # Remove any old folders and create new structure
    rm -rf /usr/share/wallpapers/Alma-$bg*
    mkdir -p /usr/share/wallpapers/Alma-$bg/contents/images/
    # creae sym link for all sizes
    for size in "${sizes[@]}"
    do
    ln -s /usr/share/backgrounds/Alma-$bg-$size /usr/share/wallpapers/Alma-$bg/contents/images/$size
    done
    # Create metadata file to make Desktop Wallpaper application happy
    # Move this to pre-created files in repo to give support to other languages
    # This is quick hack for time being.
    cat > /usr/share/wallpapers/Alma-$bg/metadata.desktop <<FOE
[Desktop Entry]
Name=AlmaLinux $bg

X-KDE-PluginInfo-Author=Bala Raman
X-KDE-PluginInfo-Email=srbala@gmail.com
X-KDE-PluginInfo-Name=Alma-$bg
X-KDE-PluginInfo-Version=0.1.0
X-KDE-PluginInfo-Website=https://almalinux.org
X-KDE-PluginInfo-Category=
X-KDE-PluginInfo-Depends=
X-KDE-PluginInfo-License=CC-BY-SA
X-KDE-PluginInfo-EnabledByDefault=true
X-Plasma-API=5.0

FOE
  done
}
# call function to create wallpapers
# generateKDEWallpapers
# Very ODD fix to get Alma background, find alternative
rm -rf /usr/share/wallpapers/Fedora
ln -s Alma-dark /usr/share/wallpapers/Fedora
# background end

# Update default theme - this has to stay KS
# Hack KDE Fedora package starts. TODO: need almalinux-kde-fix package
sed -i 's/defaultWallpaperTheme=Fedora/defaultWallpaperTheme=Alma-dark/' /usr/share/plasma/desktoptheme/default/metadata.desktop
sed -i 's/defaultFileSuffix=.png/defaultFileSuffix=.jpg/' /usr/share/plasma/desktoptheme/default/metadata.desktop
sed -i 's/defaultWidth=1920/defaultWidth=2048/' /usr/share/plasma/desktoptheme/default/metadata.desktop
sed -i 's/defaultHeight=1080/defaultHeight=1536/' /usr/share/plasma/desktoptheme/default/metadata.desktop
# Update KInfocenter
sed -i 's/pixmaps\/system-logo-white.png/icons\/hicolor\/256x256\/apps\/fedora-logo-icon.png/' /etc/xdg/kcm-about-distrorc
sed -i 's/http:\/\/fedoraproject.org/https:\/\/almalinux.org/' /etc/xdg/kcm-about-distrorc
# Hack KDE Fedora package ends

# Disable network service here, as doing it in the services line
# fails due to RHBZ #1369794
sbin/chkconfig network off  #fails

# Remove machine-id on pre generated images
rm -f /etc/machine-id
touch /etc/machine-id

# set default GTK+ theme for root (see #683855, #689070, #808062)
cat > /root/.gtkrc-2.0 << EOF
include "/usr/share/themes/Adwaita/gtk-2.0/gtkrc"
include "/etc/gtk-2.0/gtkrc"
gtk-theme-name="Adwaita"
EOF
mkdir -p /root/.config/gtk-3.0
cat > /root/.config/gtk-3.0/settings.ini << EOF
[Settings]
gtk-theme-name = Adwaita
EOF

# add initscript
cat >> /etc/rc.d/init.d/livesys << EOF

# set up autologin for user liveuser
if [ -f /etc/sddm.conf ]; then
sed -i 's/^#User=.*/User=liveuser/' /etc/sddm.conf
sed -i 's/^#Session=.*/Session=plasma.desktop/' /etc/sddm.conf
else
cat > /etc/sddm.conf << SDDM_EOF
[Autologin]
User=liveuser
Session=plasma.desktop
SDDM_EOF
fi

# add liveinst.desktop to favorites menu
mkdir -p /home/liveuser/.config/
cat > /home/liveuser/.config/kickoffrc << MENU_EOF
[Favorites]
FavoriteURLs=/usr/share/applications/firefox.desktop,/usr/share/applications/org.kde.dolphin.desktop,/usr/share/applications/systemsettings.desktop,/usr/share/applications/org.kde.konsole.desktop,/usr/share/applications/liveinst.desktop
MENU_EOF

# show liveinst.desktop on desktop and in menu
sed -i 's/NoDisplay=true/NoDisplay=false/' /usr/share/applications/liveinst.desktop
# set executable bit disable KDE security warning
chmod +x /usr/share/applications/liveinst.desktop
mkdir /home/liveuser/Desktop
cp -a /usr/share/applications/liveinst.desktop /home/liveuser/Desktop/

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

# Set akonadi backend
mkdir -p /home/liveuser/.config/akonadi
cat > /home/liveuser/.config/akonadi/akonadiserverrc << AKONADI_EOF
[%General]
Driver=QSQLITE3
AKONADI_EOF

# Disable plasma-pk-updates (bz #1436873 and 1206760)
echo "Removing plasma-pk-updates package."
rpm -e plasma-pk-updates

# Disable baloo
cat > /home/liveuser/.config/baloofilerc << BALOO_EOF
[Basic Settings]
Indexing-Enabled=false
BALOO_EOF

# Disable kres-migrator
cat > /home/liveuser/.kde/share/config/kres-migratorrc << KRES_EOF
[Migration]
Enabled=false
KRES_EOF

# Disable kwallet migrator
cat > /home/liveuser/.config/kwalletrc << KWALLET_EOL
[Migration]
alreadyMigrated=true
KWALLET_EOL

# make sure to set the right permissions and selinux contexts
chown -R liveuser:liveuser /home/liveuser/
restorecon -R /home/liveuser/

EOF

%end

%post --nochroot
cp $INSTALL_ROOT/usr/share/licenses/*-release/* $LIVE_ROOT/

# only works on x86, x86_64
if [ "$(uname -i)" = "i386" -o "$(uname -i)" = "x86_64" ]; then
  if [ ! -d $LIVE_ROOT/LiveOS ]; then mkdir -p $LIVE_ROOT/LiveOS ; fi
  cp /usr/bin/livecd-iso-to-disk $LIVE_ROOT/LiveOS
fi

%end

# Packages
%packages
# KDE package list

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
abrt-libs
accounts-qml-module
accountsservice
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
at-spi2-atk
at-spi2-core
audit
audit-libs
augeas-libs
authselect
authselect-libs
avahi
avahi-glib
avahi-libs
baloo-widgets
basesystem
bash
bc
bind-export-libs
biosdevname
blivet-data
bluedevil
bluez
bluez-libs
breeze-cursor-theme
breeze-icon-theme
brotli
bubblewrap
bzip2-libs
ca-certificates
cairo
cairo-gobject
cairomm
c-ares
chkconfig
chrony
cmake-filesystem
colord
colord-kde
colord-libs
color-filesystem
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
cups
cups-client
cups-filesystem
cups-filters
cups-filters-libs
cups-ipptool
cups-libs
cups-pk-helper
curl
cyrus-sasl-lib
daxctl-libs
dbus
dbus-common
dbus-daemon
dbus-glib
dbus-libs
dbusmenu-qt5
dbus-tools
dbus-x11
dconf
dejavu-fonts-common
dejavu-sans-mono-fonts
desktop-backgrounds-compat
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
dmidecode
dnf
dnf-data
dnf-plugins-core
docbook-dtds
docbook-style-xsl
dolphin
dolphin-libs
dosfstools
dotconf
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
epel-release
espeak-ng
ethtool
exiv2
exiv2-libs
expat
f31-backgrounds-base
f32-backgrounds-base
f32-backgrounds-kde
file
file-libs
filesystem
findutils
firewall-config
firewalld
firewalld-filesystem
flac-libs
flatpak-libs
fontconfig
fontpackages-filesystem
freetype
fribidi
fuse
fuse-common
fuse-libs
fwupd
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
geoclue2
geolite2-city
geolite2-country
gettext
gettext-libs
ghostscript
giflib
gjs
glib2
glibc
glibc-all-langpacks
glibc-common
glibc-langpack-en
glibmm24
glib-networking
glx-utils
gmp
gnome-abrt
gnome-keyring
gnome-keyring-pam
gnome-menus
gnupg2
gnupg2-smime
gnutls
gobject-introspection
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
gpsd-libs
grantlee-qt5
graphite2
grep
groff-base
grub2-common
grub2-efi-*64
grub2-tools
grub2-tools-extra
grub2-tools-minimal
grubby
gsettings-desktop-schemas
gsm
gstreamer1
gstreamer1-plugins-bad-free
gstreamer1-plugins-base
gstreamer1-plugins-good
gtk2
gtk3
gtkmm30
gtk-update-icon-cache
@guest-desktop-agents
guile
gwenview
gwenview-libs
gzip
hardlink
harfbuzz
harfbuzz-icu
hdparm
hicolor-icon-theme
hostname
http-parser
hunspell
hunspell-en-US
hwdata
hyphen
ibus-libs
ilmbase
ima-evm-utils0
ima-evm-utils
info
initial-setup
initial-setup-gui
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
jbig2dec-libs
jbigkit-libs
json-c
json-glib
kaccounts-integration
kactivitymanagerd
kamera
kbd
kbd-legacy
kbd-misc
kcalc
kcharselect
kcm_systemd
kcolorchooser
kde-cli-tools
kdecoration
kde-filesystem
kdegraphics-thumbnailers
kde-gtk-config
kde-partitionmanager
kdeplasma-addons
kde-print-manager
kde-print-manager-libs
kde-settings
kde-settings-plasma
kde-settings-pulseaudio
kdesu
kdialog
kdnssd
keditbookmarks
keditbookmarks-libs
kernel
kernel-core
kernel-core
kernel-modules
kernel-modules
kernel-modules-extra
kernel-tools
kernel-tools-libs
kexec-tools
keybinder3
keyutils-libs
kf5-akonadi-contacts
kf5-akonadi-server
kf5-akonadi-server-mysql
kf5-attica
kf5-baloo
kf5-baloo-file
kf5-baloo-libs
kf5-bluez-qt
kf5-filesystem
kf5-frameworkintegration
kf5-frameworkintegration-libs
kf5-kactivities
kf5-kactivities-stats
kf5-karchive
kf5-kauth
kf5-kbookmarks
kf5-kcmutils
kf5-kcodecs
kf5-kcompletion
kf5-kconfig-core
kf5-kconfig-gui
kf5-kconfigwidgets
kf5-kcontacts
kf5-kcoreaddons
kf5-kcrash
kf5-kdbusaddons
kf5-kdeclarative
kf5-kded
kf5-kdelibs4support
kf5-kdelibs4support-libs
kf5-kdesu
kf5-kdewebkit
kf5-kdnssd
kf5-kdoctools
kf5-kemoticons
kf5-kfilemetadata
kf5-kglobalaccel
kf5-kglobalaccel-libs
kf5-kguiaddons
kf5-kholidays
kf5-khtml
kf5-ki18n
kf5-kiconthemes
kf5-kidletime
kf5-kimageformats
kf5-kinit
kf5-kio-core
kf5-kio-core-libs
kf5-kio-doc
kf5-kio-file-widgets
kf5-kio-gui
kf5-kio-ntlm
kf5-kio-widgets
kf5-kio-widgets-libs
kf5-kipi-plugins
kf5-kirigami2
kf5-kitemmodels
kf5-kitemviews
kf5-kjobwidgets
kf5-kjs
kf5-kmime
kf5-knewstuff
kf5-knotifications
kf5-knotifyconfig
kf5-kpackage
kf5-kparts
kf5-kpeople
kf5-kpty
kf5-kquickcharts
kf5-kross-core
kf5-kross-ui
kf5-krunner
kf5-kservice
kf5-ktexteditor
kf5-ktextwidgets
kf5-kunitconversion
kf5-kwallet
kf5-kwallet-libs
kf5-kwayland
kf5-kwidgetsaddons
kf5-kwindowsystem
kf5-kxmlgui
kf5-kxmlrpcclient
kf5-libkdcraw
kf5-libkexiv2
kf5-libkipi
kf5-modemmanager-qt
kf5-networkmanager-qt
kf5-plasma
kf5-prison
kf5-purpose
kf5-solid
kf5-sonnet-core
kf5-sonnet-ui
kf5-syntax-highlighting
kf5-threadweaver
kfind
kgpg
khelpcenter
khotkeys
kinfocenter
kio-extras
kmag
kmenuedit
kmod
kmod-libs
kmousetool
kmouth
konqueror
konqueror-libs
konsole5
konsole5-part
kpartx
kpmcore
krb5-libs
kruler
kscreen
kscreenlocker
ksshaskpass
ksysguard
ksysguardd
kwalletmanager5
kwebenginepart
kwebkitpart
kwin
kwin-common
kwin-libs
kwrite
kwrited
lame-libs
langtable
lcms2
ldns
less
libaccounts-glib
libaccounts-qt5
libacl
libaio
libao
libappstream-glib
libarchive
libassuan
libasyncns
libatasmart
libatomic
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
libbytesize
libcanberra
libcap
libcap-ng
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
libdmtx
libdmx
libdnf
libdrm
libdv
libdvdnav
libdvdread
libedit
libepoxy
liberation-fonts-common
liberation-mono-fonts
libevdev
libevent
libexif
libfdisk
libffi
libfontenc
libgcab1
libgcc
libgcrypt
libgit2
libglvnd
libglvnd-egl
libglvnd-gles
libglvnd-glx
libgnomekbd
libgomp
libgpg-error
libgphoto2
libgs
libgudev
libgusb
libibverbs
libICE
libicu
libidn
libidn2
libiec61883
libijs
libimobiledevice
libini_config
libinput
libipt
libjpeg-turbo
libkcapi
libkcapi-hmaccalc
libksba
libkscreen-qt5
libksysguard
libksysguard-common
libkworkspace5
libldb
libmaxminddb
libmbim
libmcpp
libmetalink
libmng
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
libpipeline
libpkgconf
libplist
libpng
libproxy
libpsl
libpwquality
libqalculate
libqmi
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
libxkbcommon-x11
libxkbfile
libxklavier
libxml2
libxmlb
libXmu
libXpm
libXrandr
libXrender
libXres
libXScrnSaver
libxshmfence
libxslt
libXt
libXtst
libXv
libXxf86dga
libXxf86misc
libXxf86vm
libyaml
libzstd
linux-firmware
llvm-libs
lmdb-libs
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
mariadb
mariadb-backup
mariadb-common
mariadb-connector-c
mariadb-connector-c-config
mariadb-errmsg
mariadb-gssapi-server
mariadb-server
mariadb-server-utils
mcpp
mdadm
media-player-info
memstrack
mesa-dri-drivers
mesa-filesystem
mesa-libEGL
mesa-libgbm
mesa-libGL
mesa-libglapi
mesa-libGLU
microcode_ctl
mobile-broadband-provider-info
ModemManager
ModemManager-glib
mokutil
mozjs60
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
NetworkManager-l2tp
NetworkManager-libnm
NetworkManager-libreswan
NetworkManager-openconnect
NetworkManager-openvpn
NetworkManager-pptp
NetworkManager-team
NetworkManager-tui
NetworkManager-wifi
newt
nftables
nm-connection-editor
npth
nspr
nss
nss-mdns
nss-softokn
nss-softokn-freebl
nss-sysinit
nss-tools
nss-util
numactl-libs
openal-soft
openconnect
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
oxygen-sound-theme
p11-kit
p11-kit-trust
PackageKit
PackageKit-glib
PackageKit-Qt5
pam
pam-kwallet
pango
pangomm
parted
passwd
pcaudiolib
pciutils
pciutils-libs
pcre
pcre2
pcre2-utf16
pcsc-lite-libs
perl-Carp
perl-constant
perl-Data-Dumper
perl-DBD-MySQL
perl-DBI
perl-Digest
perl-Digest-MD5
perl-Encode
perl-Errno
perl-Exporter
perl-File-pushd
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
perl-Math-BigInt
perl-Math-Complex
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
phonon-qt5
phonon-qt5-backend-gstreamer
pigz
pinentry
pinentry-gnome3
pixman
pkcs11-helper
pkgconf
pkgconf-m4
pkgconf-pkg-config
plasma-breeze
plasma-breeze-common
plasma-desktop
plasma-desktop-doc
plasma-discover
plasma-discover-flatpak
plasma-discover-libs
plasma-discover-notifier
plasma-discover-packagekit
plasma-drkonqi
plasma-integration
plasma-milou
plasma-nm
plasma-nm-l2tp
plasma-nm-openconnect
plasma-nm-openswan
plasma-nm-openvpn
plasma-nm-pptp
plasma-pa
plasma-pk-updates
plasma-systemsettings
plasma-user-manager
plasma-workspace
plasma-workspace-common
plasma-workspace-geolocation
plasma-workspace-geolocation-libs
plasma-workspace-libs
platform-python
platform-python-pip
platform-python-setuptools
policycoreutils
polkit
polkit-kde
polkit-libs
polkit-pkla-compat
polkit-qt5-1
poppler
poppler-data
poppler-utils
popt
powerdevil
ppp
pptp
prefixdevname
procps-ng
psmisc
publicsuffix-list-dafsa
pulseaudio
pulseaudio-libs
pulseaudio-libs-glib2
pulseaudio-module-bluetooth
pulseaudio-module-x11
pulseaudio-utils
python3-abrt
python3-abrt-addon
python3-augeas
python3-blivet
python3-blockdev
python3-bytesize
python3-cairo
python3-chardet
python3-configobj
python3-cups
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
python3-pip-wheel
python3-productmd
python3-pwquality
python3-pycurl
python3-pyparted
python3-pysocks
python3-pytz
python3-pyudev
python3-requests
python3-requests-file
python3-requests-ftp
python3-rpm
python3-schedutils
python3-setuptools-wheel
python3-simpleline
python3-six
python3-slip
python3-slip-dbus
python3-syspurpose
python3-systemd
python3-unbound
python3-urllib3
qca-qt5
qca-qt5-ossl
qpdf-libs
qqc2-desktop-style
qrencode-libs
qt5-qtbase
qt5-qtbase-common
qt5-qtbase-gui
qt5-qtbase-mysql
qt5-qtdeclarative
qt5-qtgraphicaleffects
qt5-qtimageformats
qt5-qtlocation
qt5-qtmultimedia
qt5-qtquickcontrols
qt5-qtquickcontrols2
qt5-qtscript
qt5-qtsensors
qt5-qtspeech
qt5-qtspeech-speechd
qt5-qtsvg
qt5-qttools
qt5-qttools-common
qt5-qttools-libs-designer
qt5-qtvirtualkeyboard
qt5-qtwebchannel
qt5-qtwebengine
qt5-qtwebkit
qt5-qtx11extras
qt5-qtxmlpatterns
rdma-core
re2
readline
rest
rng-tools
rootfiles
rpm
rpm-build-libs
rpm-libs
rpm-plugin-selinux
rpm-plugin-systemd-inhibit
rtkit
samba-client
samba-client-libs
samba-common
samba-common-libs
satyr
sbc
sddm
sddm-breeze
sddm-kcm
sed
selinux-policy
selinux-policy-targeted
setup
sg3_utils
sg3_utils-libs
sgml-common
shadow-utils
shared-mime-info
shim-*64
signon
signon-plugin-oauth2
slang
snappy
socat
sound-theme-freedesktop
soundtouch
spectacle
speech-dispatcher
speech-dispatcher-espeak-ng
speex
speexdsp
sqlite-libs
squashfs-tools
sssd-client
sssd-common
sssd-kcm
sssd-nfs-idmap
sudo
system-config-printer-libs
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
userspace-rcu
util-linux
vim-minimal
virt-what
volume_key-libs
vpnc-script
vte291
vte-profile
wavpack
webkit2gtk3
webkit2gtk3-jsc
webrtc-audio-processing
which
woff2
wpa_supplicant
xapian-core-libs
xcb-util
xcb-util-cursor
xcb-util-image
xcb-util-keysyms
xcb-util-renderutil
xcb-util-wm
xdg-user-dirs
xdg-utils
xfsprogs
xkeyboard-config
xl2tpd
xml-common
xmlrpc-c
xmlrpc-c-client
xmlsec1
xmlsec1-openssl
xorg-x11-apps
xorg-x11-drv-fbdev
xorg-x11-drv-libinput
xorg-x11-drv-vesa
xorg-x11-fonts-misc
xorg-x11-font-utils
xorg-x11-server-common
xorg-x11-server-utils
xorg-x11-server-Xorg
xorg-x11-utils
xorg-x11-xauth
xorg-x11-xbitmaps
xorg-x11-xinit
xorg-x11-xkb-utils
xz
xz-libs
yelp
yelp-libs
yelp-xsl
yum
zlib
anaconda
anaconda-install-env-deps
anaconda-live
@anaconda-tools
dracut-config-generic
dracut-live
glibc-all-langpacks
grub2-efi
grub2-pc-modules
grub2-efi-*64-cdboot
kernel
kernel-modules
kernel-modules-extra
memtest86+
syslinux
glibc-all-langpacks
initscripts
chkconfig
aajohan-comfortaa-fonts
firefox
libreoffice-base
libreoffice-calc
libreoffice-core
libreoffice-data
libreoffice-draw
libreoffice-graphicfilter
libreoffice-impress
libreoffice-writer
liberation-fonts
liberation-fonts-common
liberation-mono-fonts
liberation-sans-fonts
liberation-serif-fonts
nano
thunderbird

-desktop-backgrounds-compat

%end
