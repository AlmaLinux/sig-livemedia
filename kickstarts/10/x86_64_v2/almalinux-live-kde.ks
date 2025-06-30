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
url --url=https://aws.repo.almalinux.org/10/BaseOS/x86_64_v2/os/
repo --name="appstream" --baseurl=https://aws.repo.almalinux.org/10/AppStream/x86_64_v2/os/
repo --name="extras" --baseurl=https://aws.repo.almalinux.org/10/extras/x86_64_v2/os/
repo --name="crb" --baseurl=https://aws.repo.almalinux.org/10/CRB/x86_64_v2/os/
repo --name="epel" --baseurl=https://epel.repo.almalinux.org/10z/x86_64_v2/

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

# Theme wallpapers
rm -f /usr/share/wallpapers/Fedora
ln -s Alma-default /usr/share/wallpapers/Fedora

# Login screen theme and wallpapers
cat <<'EOF'>/etc/sddm.conf.d/kde_settings.conf
[Theme]
Current=breeze
EOF
sed -i 's#background=.*$#background=/usr/share/backgrounds/almalinux-day.jpg#g' \
  /usr/share/sddm/themes/breeze/theme.conf

# TODO: revise I and II once installer icon is on the separate package
# like Fedora does at https://src.fedoraproject.org/rpms/kf6-breeze-icons/c/728493c525b4e4e7be5caccba41f66e8d816ee38

# I. Fix org.fedoraproject.AnacondaInstaller.svg broken symlinks
cp -a /usr/share/icons/hicolor/scalable/apps/org.fedoraproject.AnacondaInstaller.svg \
  /usr/share/icons/hicolor/48x48/apps/
# II. Replace live installer icon for the application and welcome center
cp -a /usr/share/icons/hicolor/scalable/apps/org.fedoraproject.AnacondaInstaller.svg \
  /usr/share/icons/hicolor/48x48/apps/org.almalinux.AnacondaInstaller.svg
sed -i 's#Icon=.*$#Icon=org.almalinux.AnacondaInstaller#g' \
  /usr/share/applications/liveinst.desktop

# Show liveinst.desktop on desktop and in menu
sed -i 's/NoDisplay=true/NoDisplay=false/' /usr/share/applications/liveinst.desktop
mkdir /home/liveuser/Desktop
cp -a /usr/share/applications/liveinst.desktop /home/liveuser/Desktop/liveinst.desktop
chmod +x /home/liveuser/Desktop/liveinst.desktop

# Disable network service here, as doing it in the services line
# fails due to RHBZ #1369794
systemctl disable network

# Remove machine-id on pre generated images
rm -f /etc/machine-id
touch /etc/machine-id

# set livesys session type
sed -i 's/^livesys_session=.*/livesys_session="kde"/' /etc/sysconfig/livesys

# enable CRB repo
dnf config-manager --enable crb

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

# Mandatory to build media with livemedia-creator
memtest86+

# libreoffice group
#@office-suite

# internet-browser group
firefox

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

# EPEL repo
epel-release

# OpenVPN
openvpn
NetworkManager-openvpn

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
