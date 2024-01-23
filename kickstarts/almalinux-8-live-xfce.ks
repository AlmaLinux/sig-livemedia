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

# set livesys session type
sed -i 's/^livesys_session=.*/livesys_session="xfce"/' /etc/sysconfig/livesys

# enable PowerTools repo
dnf config-manager --enable powertools

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
# provide the livesys scripts
livesys-scripts

@anaconda-tools
@guest-desktop-agents
GConf2
ModemManager
ModemManager-glib
NetworkManager
NetworkManager-libnm
NetworkManager-team
NetworkManager-tui
NetworkManager-wifi
Thunar
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
alsa-sof-firmware
alsa-ucm
alsa-utils
anaconda
anaconda-install-env-deps
anaconda-live
aspell
at-spi2-atk
at-spi2-core
atk
atkmm
atril
audit
audit-libs
authselect
authselect-libs
autocorr-en
avahi-glib
avahi-libs
basesystem
bash
bash-color-prompt
bash-completion
bind-export-libs
biosdevname
bluez
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
bzip2
bzip2-libs
c-ares
ca-certificates
cairo
cairo-gobject
cairomm
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
color-filesystem
colord
colord-gtk
colord-libs
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
efi-filesystem
efi-srpm-macros
efibootmgr
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
firewall-config
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
gcr
gdbm
gdbm-libs
gdisk
gdk-pixbuf2
gdk-pixbuf2-modules
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
glib-networking
glib2
glibc
glibc-all-langpacks
glibc-common
glibmm24
glx-utils
gmp
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
google-noto-sans-khmer-fonts
google-noto-sans-lisu-fonts
google-noto-sans-mandaic-fonts
google-noto-sans-meetei-mayek-fonts
google-noto-sans-myanmar-fonts
google-noto-sans-oriya-fonts
google-noto-sans-sinhala-fonts
google-noto-sans-tagalog-fonts
google-noto-sans-tai-tham-fonts
google-noto-sans-tai-viet-fonts
google-noto-sans-tibetan-fonts
google-noto-serif-cjk-ttc-fonts
gparted
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
gtk-update-icon-cache
gtk2
gtk3
gtkmm30
gtksourceview3
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
iwl6050-firmware
iwl7260-firmware
jansson
jasper-libs
java-1.8.0-openjdk-headless
javapackages-filesystem
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
lcms2
less
libICE
libSM
libX11
libX11-common
libX11-xcb
libXScrnSaver
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
libXrandr
libXrender
libXres
libXt
libXtst
libXv
libXxf86misc
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
libxcb
libxcrypt
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
linux-firmware
lksctp-tools
llvm-libs
lmdb-libs
logrotate
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
mesa-libGL
mesa-libgbm
mesa-libglapi
microcode_ctl
mobile-broadband-provider-info
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
ntfs-3g
ntfs-3g-system-compression
ntfsprogs
numactl-libs
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
os-prober
ostree-libs
p11-kit
p11-kit-server
p11-kit-trust
p7zip
p7zip-plugins
pakchois
pam
pango
pangomm
parole
parted
passwd
pavucontrol
pciutils
pciutils-libs
pcre
pcre2
pcre2-utf16
perl-Carp
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
perl-IO
perl-IO-Socket-IP
perl-IO-Socket-SSL
perl-MIME-Base64
perl-Mozilla-CA
perl-Net-SSLeay
perl-PathTools
perl-Pod-Escapes
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
perl-Time-Local
perl-URI
perl-Unicode-Normalize
perl-constant
perl-interpreter
perl-libnet
perl-libs
perl-macros
perl-parent
perl-podlators
perl-threads
perl-threads-shared
pigz
pinentry
pinentry-gtk
pipewire
pipewire-libs
pipewire-utils
pipewire0.2-libs
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
python36
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
ristretto
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
unzip
upower
util-linux
vim-minimal
vino
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
xcb-util-image
xcb-util-keysyms
xcb-util-renderutil
xcb-util-wm
xdg-desktop-portal
xdg-desktop-portal-gtk
xdg-user-dirs-gtk
xdg-utils
xfce-polkit
xfce4-about
xfce4-about
xfce4-appfinder
xfce4-notifyd
xfce4-panel
xfce4-panel-profiles
xfce4-power-manager
xfce4-pulseaudio-plugin
xfce4-screensaver
xfce4-screenshooter
xfce4-session
xfce4-settings
xfce4-taskmanager
xfce4-taskmanager
xfce4-terminal
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
xorg-x11-server-Xorg
xorg-x11-server-Xwayland
xorg-x11-server-common
xorg-x11-server-utils
xorg-x11-xauth
xorg-x11-xinit
xorg-x11-xkb-utils
xz
xz-libs
yum
zenity
zlib

%end
