# AlmaLinux Live Media

This git repository contains Kickstarts and other scripts needed to produce the AlmaLinux Live DVDs. You can build live media using the automated `build-livemedia.sh` script (recommended) or manually with `livemedia-creator` commands on an AlmaLinux system.

## Using Live media

Live media ISO files are available for download from the official AlmaLinux repositories:

**AlmaLinux 8:**
- x86_64: https://repo.almalinux.org/almalinux/8/live/x86_64/

**AlmaLinux 9:**
- x86_64: https://repo.almalinux.org/almalinux/9/live/x86_64/
- aarch64: https://repo.almalinux.org/almalinux/9/live/aarch64/

**AlmaLinux 10:**
- x86_64: https://repo.almalinux.org/almalinux/10/live/x86_64/
- x86_64_v2: https://repo.almalinux.org/almalinux/10/live/x86_64_v2/
- aarch64: https://repo.almalinux.org/almalinux/10/live/aarch64/

**AlmaLinux Kitten (Development):**
- x86_64: https://kitten.repo.almalinux.org/10-kitten/live/x86_64/
- x86_64_v2: https://kitten.repo.almalinux.org/10-kitten/live/x86_64_v2/
- aarch64: https://kitten.repo.almalinux.org/10-kitten/live/aarch64/

For faster downloads, use mirrors at https://mirrors.almalinux.org to find a location closer to you. Refer to the project wiki https://wiki.almalinux.org/LiveMedia.html#about-live-media for detailed installation and usage instructions.

## Build Live Media

Building AlmaLinux Live media requires an AlmaLinux system (physical or virtual). The build process takes `20-50 minutes` depending on CPU cores and internet speed. You need minimum `15GB` workspace for temporary files. Resulting ISO size ranges from `1.4GB` to `2.4GB` depending on desktop environment.


### Build Environments

This project contains number of `KickStart` files to build live media for AlmaLinux. It uses `anaconda` and `lorax` packages for the ISO file build process. The recommended approach is to use `livemedia-creator` with the `lorax` backend.

#### Prerequisites

- AlmaLinux system (physical or virtual) with minimum 15GB workspace
- Build process takes 20-50 minutes depending on CPU cores and internet speed
- Root or sudo access required

#### Install Required Packages

**For AlmaLinux 8:**
```sh
sudo dnf update -y
sudo dnf install -y --enablerepo=powertools lorax lorax-templates-almalinux anaconda unzip zstd
```

**For AlmaLinux 9:**
```sh
sudo dnf update -y
sudo dnf install -y --enablerepo=crb lorax lorax-templates-almalinux anaconda unzip zstd libblockdev-nvme
```

**For AlmaLinux 10:**
```sh
sudo dnf update -y
sudo dnf install -y --enablerepo=crb lorax lorax-templates-almalinux anaconda unzip zstd libblockdev-nvme
```

**Note:** For AlmaLinux 10, you may need to temporarily set SELinux to permissive mode:
```sh
sudo setenforce 0
```

### Quick Start with Build Script

For a simplified build process, use the included `build-livemedia.sh` script that automates environment setup and media creation:

```sh
# Make the script executable
chmod +x build-livemedia.sh

# Build AlmaLinux 9.8 GNOME Live Media
sudo ./build-livemedia.sh 9 GNOME

# Build AlmaLinux 10.1 KDE Live Media
sudo ./build-livemedia.sh 10 KDE

# Build AlmaLinux Kitten GNOME-Mini Live Media
sudo ./build-livemedia.sh 10-kitten GNOME-Mini

# To build media with x86_64_v2 packages for AlmaLinux 10+ (optional)
BUILD_X86_64_V2=1 sudo ./build-livemedia.sh 10 KDE

# Show all available options
./build-livemedia.sh --help
```

**Features:**
- **Automated setup**: Installs required packages and prepares build environment
- **Smart versioning**: Automatically maps major versions to current releases (8→8.10, 9→9.8, 10→10.1)
- **Architecture detection**: Supports x86_64, aarch64, and x86_64_v2 automatically
- **Comprehensive logging**: Creates detailed logs in `./results/` directory
- **Error handling**: Validates inputs and provides helpful error messages
- **Checksum generation**: Automatically creates SHA256 checksums for built ISOs

**Supported combinations:**
- **Versions**: 8, 9, 10, 10-kitten
- **Desktop Environments**: GNOME, GNOME-Mini, KDE, XFCE, MATE
- **Architecture**: Version-specific support (see table below)

The script handles all the complexity shown in the manual examples below and follows the same build process used in the CI workflows.

### Manual Build using `livemedia-creator`

For advanced users or custom builds, you can use `livemedia-creator` directly. The following examples show manual commands for building AlmaLinux Live media. The kickstart files are organized by version and architecture in the `kickstarts/` directory.

**Note:** The build script above handles all these steps automatically. Use these manual commands only if you need custom configuration.

#### AlmaLinux 8.10 Examples

**GNOME Live Media:**
```sh
sudo livemedia-creator \
    --ks=./kickstarts/8/x86_64/almalinux-live-gnome.ks \
    --no-virt \
    --resultdir ./iso_GNOME \
    --project "Live AlmaLinux" \
    --make-iso \
    --iso-only \
    --iso-name "AlmaLinux-8.10-x86_64-Live-GNOME.iso" \
    --releasever "8.10" \
    --volid "AlmaLinux-8_10-x86_64-Live-GNOME" \
    --nomacboot \
    --logfile ./livemedia.log \
    --anaconda-arg="--product AlmaLinux"
```

**GNOME-Mini Live Media:**
```sh
sudo livemedia-creator \
    --ks=./kickstarts/8/x86_64/almalinux-live-gnome-mini.ks \
    --no-virt \
    --resultdir ./iso_GNOME-MINI \
    --project "Live AlmaLinux" \
    --make-iso \
    --iso-only \
    --iso-name "AlmaLinux-8.10-x86_64-Live-GNOME-Mini.iso" \
    --releasever "8.10" \
    --volid "AlmaLinux-8_10-x86_64-Live-Mini" \
    --nomacboot \
    --logfile ./livemedia.log \
    --anaconda-arg="--product AlmaLinux"
```

**KDE Live Media:**
```sh
sudo livemedia-creator \
    --ks=./kickstarts/8/x86_64/almalinux-live-kde.ks \
    --no-virt \
    --resultdir ./iso_KDE \
    --project "Live AlmaLinux" \
    --make-iso \
    --iso-only \
    --iso-name "AlmaLinux-8.10-x86_64-Live-KDE.iso" \
    --releasever "8.10" \
    --volid "AlmaLinux-8_10-x86_64-Live-KDE" \
    --nomacboot \
    --logfile ./livemedia.log \
    --anaconda-arg="--product AlmaLinux"
```

#### AlmaLinux 9.8 Examples

**GNOME Live Media:**
```sh
sudo livemedia-creator \
    --ks=./kickstarts/9/x86_64/almalinux-live-gnome.ks \
    --no-virt \
    --resultdir ./iso_GNOME \
    --project "Live AlmaLinux" \
    --make-iso \
    --iso-only \
    --iso-name "AlmaLinux-9.8-x86_64-Live-GNOME.iso" \
    --releasever "9.8" \
    --volid "AlmaLinux-9_8-x86_64-Live-GNOME" \
    --nomacboot \
    --logfile ./livemedia.log
```

**MATE Live Media:**
```sh
sudo livemedia-creator \
    --ks=./kickstarts/9/x86_64/almalinux-live-mate.ks \
    --no-virt \
    --resultdir ./iso_MATE \
    --project "Live AlmaLinux" \
    --make-iso \
    --iso-only \
    --iso-name "AlmaLinux-9.8-x86_64-Live-MATE.iso" \
    --releasever "9.8" \
    --volid "AlmaLinux-9_8-x86_64-Live-MATE" \
    --nomacboot \
    --logfile ./livemedia.log
```

#### AlmaLinux 10.1 Examples

**GNOME Live Media:**
```sh
sudo livemedia-creator \
    --ks=./kickstarts/10/x86_64/almalinux-live-gnome.ks \
    --no-virt \
    --resultdir ./iso_GNOME \
    --project "Live AlmaLinux" \
    --make-iso \
    --iso-only \
    --iso-name "AlmaLinux-10.1-x86_64-Live-GNOME.iso" \
    --releasever "10.1" \
    --volid "AlmaLinux-10_1-x86_64" \
    --nomacboot \
    --logfile ./livemedia.log
```

**KDE Live Media:**
```sh
sudo livemedia-creator \
    --ks=./kickstarts/10/x86_64/almalinux-live-kde.ks \
    --no-virt \
    --resultdir ./iso_KDE \
    --project "Live AlmaLinux" \
    --make-iso \
    --iso-only \
    --iso-name "AlmaLinux-10.1-x86_64-Live-KDE.iso" \
    --releasever "10.1" \
    --volid "AlmaLinux-10_1-x86_64" \
    --nomacboot \
    --logfile ./livemedia.log
```

#### Architecture Support

For different architectures, adjust the kickstart path and output names accordingly:

**For aarch64 (ARM64):**
```sh
sudo livemedia-creator \
    --ks=./kickstarts/9/aarch64/almalinux-live-gnome.ks \
    --no-virt \
    --resultdir ./iso_GNOME \
    --project "Live AlmaLinux" \
    --make-iso \
    --iso-only \
    --iso-name "AlmaLinux-9.8-aarch64-Live-GNOME.iso" \
    --releasever "9.8" \
    --volid "AlmaLinux-9_8-aarch64-Live-GNOME" \
    --nomacboot \
    --logfile ./livemedia.log
```

**For x86_64_v2**

x86-64 v2 microarchitecture, to support older hardware with features match the 2008 Intel Nehalem architecture and newer.

```sh
sudo livemedia-creator \
    --ks=./kickstarts/10/x86_64_v2/almalinux-live-kde.ks \
    --no-virt \
    --resultdir ./iso_KDE \
    --project "Live AlmaLinux" \
    --make-iso \
    --iso-only \
    --iso-name "AlmaLinux-10.1-x86_64_v2-Live-KDE.iso" \
    --releasever "10.1" \
    --volid "AlmaLinux-10_1-x86_64_v2-KDE" \
    --nomacboot \
    --logfile ./livemedia.log
```

## Customizing Live Media

AlmaLinux Live Media can be customized by editing the corresponding kickstart (`.ks`) files located in the `kickstarts/` directory. The specific file to edit depends on your target AlmaLinux version, architecture, and desktop environment.

### Kickstart File Structure

Kickstart files are organized as:
```
kickstarts/{version}/{architecture}/almalinux-live-{desktop}.ks
```

**Examples:**
- `kickstarts/9/x86_64/almalinux-live-gnome.ks` - AlmaLinux 9 GNOME for x86_64
- `kickstarts/10/aarch64/almalinux-live-kde.ks` - AlmaLinux 10 KDE for aarch64
- `kickstarts/8/x86_64/almalinux-live-mate.ks` - AlmaLinux 8 MATE for x86_64

### Kickstart Documentation

For complete kickstart syntax and options, refer to the official Red Hat documentation:
**[Kickstart Syntax Reference](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/9/html/performing_an_advanced_rhel_9_installation/kickstart-commands-and-options-reference_installing-rhel-as-an-experienced-user)**

### Common Customizations

#### 1. Package Selection (`%packages` section)

Add or remove packages in the `%packages` section:

```bash
%packages
# Add packages
git
htop
vim-enhanced

# Remove packages (prefix with -)
-libreoffice-calc
-evolution

# Package groups
@core
@base-x
@fonts
%end
```

#### 2. Additional Repositories (`repo` instruction)

Enable additional repositories for more packages:

```bash
# Enable EPEL repository
repo --name="epel" --baseurl=https://dl.fedoraproject.org/pub/epel/$releasever/Everything/$basearch/

# Enable RPM Fusion
repo --name="rpmfusion-free" --baseurl=https://download1.rpmfusion.org/free/el/$releasever/Everything/$basearch/os/

# Local repository
repo --name="local-repo" --baseurl=file:///path/to/local/repo
```

#### 3. System Configuration

**Keyboard and Language:**
```bash
# Keyboard layout
keyboard us

# System language and locale
lang en_US.UTF-8

# Timezone
timezone America/New_York --isUtc
```

**Network Configuration:**
```bash
# Enable NetworkManager
network --onboot=yes --device=link --bootproto=dhcp --hostname=almalinux-live
```

**Services Management:**
```bash
# Enable services
services --enabled=NetworkManager,sshd,chronyd

# Disable services
services --disabled=postfix,sendmail
```

#### 4. Disk Partitioning

Customize the filesystem layout:

```bash
# Clear existing partitions
clearpart --drives=sda --all --initlabel

# Create partitions
part /boot/efi --fstype="efi" --size=512 --fsoptions="umask=0077,shortname=winnt"
part /boot --fstype="xfs" --size=1024
part / --fstype="ext4" --size=8192 --grow
part swap --fstype="swap" --size=2048
```

#### 5. Post-Installation Scripts (`%post` section)

Add custom post-installation scripts:

```bash
%post --log=/var/log/ks-post.log

# Configure custom settings
echo "Welcome to Custom AlmaLinux Live" > /etc/motd

# Create custom user
useradd -m -G wheel customuser

# Configure firewall
firewall-cmd --permanent --add-service=ssh
firewall-cmd --reload

# Custom systemd service
systemctl enable custom-service

%end
```

#### 6. Pre-Installation Scripts (`%pre` section)

Execute scripts before installation:

```bash
%pre --log=/tmp/ks-pre.log

# Detect hardware and set variables
MEMORY=$(free -m | awk 'NR==2{printf "%.0f", $2/1024}')
if [ "$MEMORY" -lt 2 ]; then
    echo "Insufficient memory for installation"
    exit 1
fi

%end
```

### Testing Your Customizations

1. **Edit the appropriate kickstart file** for your target version/architecture/desktop
2. **Build with your modifications** using the build script:
   ```bash
   sudo ./build-livemedia.sh 9 GNOME
   ```
3. **Test the resulting ISO** in a virtual machine before deployment
4. **Check logs** in `./results/logs/` if the build fails

### Best Practices

- **Backup original files** before making changes
- **Test incrementally** - make small changes and test frequently
- **Use package groups** (@core, @base, etc.) when possible for easier maintenance
- **Document your changes** in comments within the kickstart file
- **Validate syntax** using `ksvalidator` if available:
  ```bash
  ksvalidator kickstarts/9/x86_64/almalinux-live-gnome.ks
  ```

### Additional Notes

#### Build Tips
* **Recommended approach:** Use the `build-livemedia.sh` script for automated, error-free builds
* **Performance:** The build process benefits from multiple CPU cores and faster storage (SSD recommended)
* **Network:** Builds require downloading packages; a stable internet connection is essential
* **Storage:** Ensure at least 15GB free space for temporary files and output ISOs
* **Logs:** The build script automatically creates comprehensive logs; manual builds should use `--logfile` parameter

#### Available Desktop Environments
The following desktop environments are supported:
- **GNOME** - Full-featured desktop environment
- **GNOME-Mini** - Minimal GNOME variant
- **KDE** - Modern Plasma desktop
- **XFCE** - Lightweight desktop environment
- **MATE** - Traditional desktop experience

#### Architecture and Desktop Environment Support Matrix

| Version | Architecture | GNOME | GNOME-Mini | KDE | XFCE | MATE |
|---------|-------------|-------|------------|-----|------|------|
| 8       | x86_64      | ✅    | ✅         | ✅  | ✅   | ✅   |
| 9       | x86_64      | ✅    | ✅         | ✅  | ✅   | ✅   |
| 9       | aarch64     | ✅    | ✅         | ✅  | ✅   | ✅   |
| 10      | x86_64      | ✅    | ✅         | ✅  | ✅   | ✅   |
| 10      | aarch64     | ✅    | ✅         | ✅  | ✅   | ✅   |
| 10      | x86_64_v2   | ✅    | ✅         | ✅  | ❌   | ❌   |
| 10-kitten | x86_64    | ✅    | ✅         | ✅  | ✅   | ✅   |
| 10-kitten | aarch64   | ✅    | ✅         | ✅  | ✅   | ✅   |
| 10-kitten | x86_64_v2 | ✅    | ✅         | ✅  | ❌   | ❌   |

#### Troubleshooting
* For AlmaLinux 10, SELinux may need to be set to permissive: `sudo setenforce 0`
* Volume IDs are limited to 32 characters due to ISO9660 specification
* Repository mirrors: Use https://mirrors.almalinux.org to find optimal mirrors

#### CI/CD Integration
This repository includes GitHub Actions workflows that automatically build live media images. The workflows support:
- Multiple AlmaLinux versions (8, 9, 10, 10-kitten)
- Multiple architectures and desktop environments
- GitHub Actions artifact publishing
- S3 upload and Mattermost notifications
