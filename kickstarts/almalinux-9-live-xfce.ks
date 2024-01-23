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

# set livesys session type
sed -i 's/^livesys_session=.*/livesys_session="xfce"/' /etc/sysconfig/livesys

# xfce configuration

# create /etc/sysconfig/desktop (needed for installation)

cat > /etc/sysconfig/desktop <<EOF
PREFERRED=/usr/bin/startxfce4
DISPLAYMANAGER=/usr/sbin/lightdm
EOF

# enable CRB repo
dnf config-manager --enable crb

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
alsa-ucm
alsa-utils
alternatives
anaconda
anaconda-install-env-deps
anaconda-live
appstream
appstream-data
at-spi2-atk
at-spi2-core
atk
atkmm
atril
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
bash-color-prompt
bash-completion
blivet-data
bluez
bluez-libs
boost-chrono
boost-date-time
boost-filesystem
boost-iostreams
boost-locale
boost-system
boost-thread
bubblewrap
bzip2
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
firewall-config
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
gparted
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
lightdm
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
ntfs-3g
ntfs-3g-system-compression
ntfsprogs
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
pipewire-utils
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
ristretto
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
