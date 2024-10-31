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
url --url=https://kitten.repo.almalinux.org/10-kitten/BaseOS/$basearch/os/
repo --name="appstream" --baseurl=https://kitten.repo.almalinux.org/10-kitten/AppStream/$basearch/os/
repo --name="extras" --baseurl=https://kitten.repo.almalinux.org/10-kitten/extras-common/$basearch/os/
repo --name="crb" --baseurl=https://kitten.repo.almalinux.org/10-kitten/CRB/$basearch/os/
repo --name="epel" --baseurl=https://dl.fedoraproject.org/pub/epel/10/Everything/$basearch/

# Firewall configuration
firewall --enabled --service=mdns
# SELinux configuration
selinux --enforcing

# System services
services --disabled="sshd" --enabled="NetworkManager,ModemManager"
# System bootloader configuration
bootloader --location=none
# Clear the Master Boot Record
zerombr
# Partition clearing information
clearpart --all --initlabel
# Disk partitioning information
part / --size=10238

%post

# Enable livesys services
systemctl enable livesys.service
systemctl enable livesys-late.service

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
  declare -a bgtypes=("dark" "light" "abstract-dark" "abstract-light" "mountains-dark" "mountains-white" "waves-dark" "waves-light" "waves-sunset")
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
ln -s Alma-mountains-white /usr/share/wallpapers/Fedora
# background end

# Update default theme - this has to stay KS
# Hack KDE Fedora package starts. TODO: need almalinux-kde-fix package
sed -i 's/defaultWallpaperTheme=Fedora/defaultWallpaperTheme=Alma-mountains-white/' /usr/share/plasma/desktoptheme/default/metadata.desktop
sed -i 's/defaultFileSuffix=.png/defaultFileSuffix=.jpg/' /usr/share/plasma/desktoptheme/default/metadata.desktop
sed -i 's/defaultWidth=1920/defaultWidth=2048/' /usr/share/plasma/desktoptheme/default/metadata.desktop
sed -i 's/defaultHeight=1080/defaultHeight=1536/' /usr/share/plasma/desktoptheme/default/metadata.desktop
# Update KInfocenter
sed -i 's/pixmaps\/system-logo-white.png/icons\/hicolor\/256x256\/apps\/fedora-logo-icon.png/' /etc/xdg/kcm-about-distrorc
sed -i 's/http:\/\/fedoraproject.org/https:\/\/almalinux.org/' /etc/xdg/kcm-about-distrorc
# Hack KDE Fedora package ends

# Disable network service here, as doing it in the services line
# fails due to RHBZ #1369794
systemctl disable network

# Remove machine-id on pre generated images
rm -f /etc/machine-id
touch /etc/machine-id

# set livesys session type
sed -i 's/^livesys_session=.*/livesys_session="kde"/' /etc/sysconfig/livesys

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

# enable CRB repo
dnf config-manager --enable crb

# Workaround to add openvpn user and group in case they didn't added during
# openvpn package installation
getent group openvpn &>/dev/null || groupadd -r openvpn
getent passwd openvpn &>/dev/null || \
    /usr/sbin/useradd -r -g openvpn -s /sbin/nologin -c OpenVPN \
        -d /etc/openvpn openvpn

%end

%post --nochroot
# cp $INSTALL_ROOT/usr/share/licenses/*-release/* $LIVE_ROOT/

# only works on x86_64
# if [ "$(uname -m)" = "x86_64" ]; then
#   if [ ! -d $LIVE_ROOT/LiveOS ]; then mkdir -p $LIVE_ROOT/LiveOS ; fi
#   cp /usr/bin/livecd-iso-to-disk $LIVE_ROOT/LiveOS
# fi

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
#aajohan-comfortaa-fonts

# Without this, initramfs generation during live image creation fails: #1242586
dracut-live

# anaconda needs the locales available to run for different locales
glibc-all-langpacks

# provide the livesys scripts
livesys-scripts

# libreoffice group
@office-suite
# firefox
@internet-browser

# KDE specific
@dial-up
@standard

# install env-group to resolve RhBug:1891500
@^kde-desktop-environment
-kde-connect
-kdeconnectd
-kde-connect-libs

@kde-apps
@kde-media

# drop tracker stuff pulled in by gtk3 (pagureio:fedora-kde/SIG#124)
-tracker-miners
-tracker

# Additional packages that are not default in kde-* groups, but useful
fuse

### space issues
-ktorrent			# kget has also basic torrent features (~3 megs)
-digikam			# digikam has duplicate functionality with gwenview (~28 megs)
-kipi-plugins			# ~8 megs + drags in Marble
-krusader			# ~4 megs
-k3b				# ~15 megs

# minimization
-hplip

# Add alsa-sof-firmware to all images PR #51
alsa-sof-firmware
%end
