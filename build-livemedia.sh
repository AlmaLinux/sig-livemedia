#!/bin/bash

# AlmaLinux Live Media Builder Script
# Usage: ./build-livemedia.sh <version_major> <desktop_environment>
# Example: ./build-livemedia.sh 9 GNOME

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULT_DIR="${RESULT_DIR:-$(pwd)/results}"
LOG_FILE="${RESULT_DIR}/livemedia-build.log"

# Ensure results directory exists for logging
mkdir -p "${RESULT_DIR}"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "${LOG_FILE}"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "${LOG_FILE}" >&2
    exit 1
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "${LOG_FILE}"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "${LOG_FILE}"
}

# Help function
show_help() {
    cat << EOF
AlmaLinux Live Media Builder

Usage: $0 <version_major> <desktop_environment> [--with-nvidia]

Arguments:
  version_major         AlmaLinux major version (8, 9, 10, 10-kitten)
  desktop_environment   Desktop environment (GNOME, GNOME-Mini, KDE, XFCE, MATE)
  --with-nvidia         Optional: Include NVIDIA GPU drivers (AlmaLinux 9, 10, 10-kitten only)

Examples:
  $0 9 GNOME              # Build AlmaLinux 9.8 GNOME Live Media
  $0 10 KDE               # Build AlmaLinux 10.2 KDE Live Media
  $0 10 GNOME --with-nvidia # Build AlmaLinux 10.2 GNOME with NVIDIA drivers
  $0 10-kitten GNOME-Mini # Build AlmaLinux Kitten GNOME-Mini Live Media
  $0 8 MATE               # Build AlmaLinux 8.10 MATE Live Media

Supported desktop environments:
  - GNOME       Full-featured desktop environment
  - GNOME-Mini  Minimal GNOME variant
  - KDE         Modern Plasma desktop
  - XFCE        Lightweight desktop environment
  - MATE        Traditional desktop experience

Architecture support:
  - AlmaLinux 8: x86_64
  - AlmaLinux 9: x86_64, aarch64
  - AlmaLinux 10: x86_64, aarch64, x86_64_v2
  - AlmaLinux 10-kitten: x86_64, aarch64, x86_64_v2

Environment variables:
  RESULT_DIR          Override default results directory (default: \$(pwd)/results)
  BUILD_X86_64_V2=1   Build with x86_64_v2 packages (10/10-kitten only)
  DATE_STAMP=YYYYMMDD   Override default date stamp for Kitten build
  ITERATION=N           Override default build iteration for Kitten build (default: 0)

Requirements:
  - AlmaLinux system (8, 9, or 10)
  - Root or sudo access
  - Minimum 15GB free disk space
  - Internet connection for package downloads
EOF
}

if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
    show_help
    exit 0
fi

# Validate arguments
if [[ $# -ne 2 ]] && [[ $# -ne 3 ]]; then
    show_help
    exit 1
fi

VERSION_MAJOR="$1"
DESKTOP_ENV="$2"
WITH_NVIDIA=false

# Check for optional --with-nvidia flag
if [[ $# -eq 3 ]]; then
    if [[ "$3" == "--with-nvidia" ]]; then
        WITH_NVIDIA=true
    else
        error "Invalid option: $3. Only --with-nvidia is supported."
    fi
fi

# NVIDIA is only available for AlmaLinux 9, 10 and 10-kitten
if [[ "${WITH_NVIDIA}" == true ]]; then
    if [[ ! "${VERSION_MAJOR}" =~ ^(9|10) ]]; then
        error "NVIDIA drivers are only available for AlmaLinux 9, 10 and 10-kitten"
    fi
fi

# Validate version
case "${VERSION_MAJOR}" in
    8|9|10|10-kitten)
        ;;
    *)
        error "Invalid version major: ${VERSION_MAJOR}. Supported: 8, 9, 10, 10-kitten"
        ;;
esac

# Validate and normalize desktop environment name
case "$(echo "${DESKTOP_ENV}" | tr '[:lower:]' '[:upper:]')" in
    GNOME)      DESKTOP_ENV="GNOME" ;;
    GNOME-MINI) DESKTOP_ENV="GNOME-Mini" ;;
    KDE)        DESKTOP_ENV="KDE" ;;
    XFCE)       DESKTOP_ENV="XFCE" ;;
    MATE)       DESKTOP_ENV="MATE" ;;
    *)
        error "Invalid desktop environment: ${DESKTOP_ENV}. Supported: GNOME, GNOME-Mini, KDE, XFCE, MATE"
        ;;
esac

# Set version-specific variables
case "${VERSION_MAJOR}" in
    8)
        VERSION_MINOR=".10"
        RELEASEVER="${VERSION_MAJOR}${VERSION_MINOR}"
        DNF_REPO="powertools"
        NEED_PKGS="lorax lorax-templates-almalinux anaconda unzip zstd"
        LIVEMEDIA_OPTS='--anaconda-arg="--product AlmaLinux"'
        CODE_NAME=""
        ;;
    9)
        VERSION_MINOR=".8"
        RELEASEVER="${VERSION_MAJOR}${VERSION_MINOR}"
        DNF_REPO="crb"
        NEED_PKGS="lorax lorax-templates-almalinux anaconda unzip zstd libblockdev-nvme"
        LIVEMEDIA_OPTS=""
        CODE_NAME=""
        ;;
    10)
        VERSION_MINOR=".2"
        RELEASEVER="${VERSION_MAJOR}${VERSION_MINOR}"
        DNF_REPO="crb"
        NEED_PKGS="lorax lorax-templates-almalinux anaconda unzip zstd libblockdev-nvme"
        LIVEMEDIA_OPTS=""
        CODE_NAME=""
        ;;
    10-kitten)
        VERSION_MINOR=""
        RELEASEVER="10"
        DNF_REPO="crb"
        NEED_PKGS="lorax lorax-templates-almalinux anaconda unzip zstd libblockdev-nvme"
        LIVEMEDIA_OPTS=""
        CODE_NAME=" Kitten"
        DATE_STAMP="${DATE_STAMP:-$(date -u '+%Y%m%d')}"
        ITERATION="${ITERATION:-0}"
        ;;
esac

# Determine architecture
ARCH=$(uname -m)

# Validate architecture support per version
case "${VERSION_MAJOR}" in
    8)
        if [[ "${ARCH}" != "x86_64" ]]; then
            error "AlmaLinux 8 only supports x86_64 architecture. Current: ${ARCH}"
        fi
        ;;
    9)
        case "${ARCH}" in
            x86_64|aarch64)
                ;;
            *)
                error "AlmaLinux 9 supports x86_64 and aarch64 architectures. Current: ${ARCH}"
                ;;
        esac
        ;;
    10|10-kitten)
        case "${ARCH}" in
            x86_64|aarch64)
                ;;
            *)
                error "AlmaLinux ${VERSION_MAJOR} supports x86_64 and aarch64 architectures. Current: ${ARCH}"
                ;;
        esac

        # For media with x86_64_v2 packages
        if [[ "${ARCH}" == "x86_64" ]] && [[ "${BUILD_X86_64_V2:-}" == "1" ]]; then
            ARCH="x86_64_v2"
            log "Using x86_64_v2 optimization (set BUILD_X86_64_V2=1)"
        fi
        ;;
esac

# Validate desktop environment and architecture combinations
if [[ "${ARCH}" == "x86_64_v2" ]]; then
    case "${DESKTOP_ENV}" in
        GNOME|GNOME-Mini|KDE)
            ;;
        *)
            error "x86_64_v2 architecture only supports GNOME, GNOME-Mini, and KDE desktop environments. Requested: ${DESKTOP_ENV}"
            ;;
    esac
fi

# Validate NVIDIA support on requested architecture
if [[ "${WITH_NVIDIA}" == true ]]; then
    if [[ "${ARCH}" != "x86_64" ]]; then
        error "NVIDIA drivers are only supported on x86_64 architecture"
    fi
fi

# Set file names and paths
if [[ "${WITH_NVIDIA}" == true ]]; then
    KICKSTART_FILE="almalinux-live-$(echo "${DESKTOP_ENV}" | tr '[:upper:]' '[:lower:]')-nvidia.ks"
else
    KICKSTART_FILE="almalinux-live-$(echo "${DESKTOP_ENV}" | tr '[:upper:]' '[:lower:]').ks"
fi
KICKSTART_PATH="./kickstarts/${VERSION_MAJOR}/${ARCH}/${KICKSTART_FILE}"

# Check if we're building Kitten with date stamp
NVIDIA_SUFFIX=""
if [[ "${WITH_NVIDIA}" == true ]]; then
    NVIDIA_SUFFIX="-NVIDIA"
fi

if [[ "${VERSION_MAJOR}" == "10-kitten" ]]; then
    ISO_NAME="AlmaLinux-Kitten-10-${DATE_STAMP}.${ITERATION}-${ARCH}-Live-${DESKTOP_ENV}${NVIDIA_SUFFIX}.iso"
    VOLID="AlmaLinux-10-${ARCH}"
elif [[ "${VERSION_MAJOR}" == "10" ]]; then
    ISO_NAME="AlmaLinux-${RELEASEVER}-${ARCH}-Live-${DESKTOP_ENV}${NVIDIA_SUFFIX}.iso"
    VOLID="AlmaLinux-${RELEASEVER//./_}-${ARCH}" # TODO 'Live' skipped to fit into 32 chars
else
    ISO_NAME="AlmaLinux-${RELEASEVER}-${ARCH}-Live-${DESKTOP_ENV}${NVIDIA_SUFFIX}.iso"
    VOLID="AlmaLinux-${RELEASEVER//./_}-${ARCH}-Live"
fi

# Define output directory path
if [[ "${WITH_NVIDIA}" == true ]]; then
    ISO_RESULT_DIR="${RESULT_DIR}/iso_${VERSION_MAJOR}_${ARCH}_${DESKTOP_ENV}-NVIDIA"
else
    ISO_RESULT_DIR="${RESULT_DIR}/iso_${DESKTOP_ENV}"
fi

# Handle volume ID length (ISO9660 32-char limit)
# Apply Mini suffix for GNOME-Mini, then handle length
if [[ "${DESKTOP_ENV}" == "GNOME-Mini" ]]; then
    VOLID="${VOLID}-Mini"
else
    VOLID="${VOLID}-${DESKTOP_ENV}"
fi

# Truncate if over 32 characters
if [[ ${#VOLID} -gt 32 ]]; then
    case "${DESKTOP_ENV}" in
        GNOME-Mini)
            VOLID="${VOLID:0:27}-Mini"
            ;;
        GNOME)
            VOLID="${VOLID:0:27}-GNOME"
            ;;
        *)
            VOLID="${VOLID:0:28}-${DESKTOP_ENV}"
            ;;
    esac
fi

# Create results directory structure
# Note: Don't create ISO_RESULT_DIR - livemedia-creator expects to create it
mkdir -p "${RESULT_DIR}"
mkdir -p "${RESULT_DIR}/logs"

# Initialize log
echo "# AlmaLinux Live Media Build Log" > "${LOG_FILE}"
echo "# Started: $(date)" >> "${LOG_FILE}"
echo "# Version: ${RELEASEVER}${CODE_NAME}" >> "${LOG_FILE}"
echo "# Desktop: ${DESKTOP_ENV}" >> "${LOG_FILE}"
echo "# Architecture: ${ARCH}" >> "${LOG_FILE}"
echo "" >> "${LOG_FILE}"

log "Starting AlmaLinux ${RELEASEVER}${CODE_NAME} ${DESKTOP_ENV} Live Media build"
log "Architecture: ${ARCH}"
log "ISO Name: ${ISO_NAME}"
log "Volume ID: ${VOLID}"

# Check if kickstart file exists
if [[ ! -f "${KICKSTART_PATH}" ]]; then
    error "Kickstart file not found: ${KICKSTART_PATH}"
fi

log "Using kickstart: ${KICKSTART_PATH}"

# Check if result directory from previous build exists (livemedia-creator will fail if it does)
if [[ -d "${ISO_RESULT_DIR}" ]]; then
    warning "Result directory from previous build exists: ${ISO_RESULT_DIR}"
    log "Automatically removing old result directory to proceed..."
    rm -rf "${ISO_RESULT_DIR}"
fi

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root or with sudo"
fi

# Prepare build environment
log "Preparing build environment..."

# Update system
log "Updating system packages..."
dnf update -y 2>&1 | tee -a "${LOG_FILE}"

# Install required packages
log "Installing required packages: ${NEED_PKGS}"
dnf install -y --enablerepo="${DNF_REPO}" ${NEED_PKGS} 2>&1 | tee -a "${LOG_FILE}"

# Set SELinux to permissive for AlmaLinux 10
if [[ "${VERSION_MAJOR}" =~ ^10 ]]; then
    if command -v getenforce &>/dev/null && [[ "$(getenforce)" != "Disabled" ]]; then
        log "Setting SELinux to permissive mode for AlmaLinux 10..."
        setenforce 0
        warning "SELinux has been set to permissive mode"
    else
        log "SELinux is already disabled, skipping setenforce"
    fi
fi

# Create livemedia-creator command
LIVEMEDIA_CMD="livemedia-creator \
--ks=${KICKSTART_PATH} \
--no-virt \
--resultdir ${ISO_RESULT_DIR} \
--project \"Live AlmaLinux${CODE_NAME}\" \
--make-iso \
--iso-only \
--iso-name \"${ISO_NAME}\" \
--releasever \"${RELEASEVER}\" \
--volid \"${VOLID}\" \
--nomacboot \
--logfile ${RESULT_DIR}/logs/livemedia.log"

# Add optional arguments
if [[ -n "${LIVEMEDIA_OPTS}" ]]; then
    LIVEMEDIA_CMD="${LIVEMEDIA_CMD} ${LIVEMEDIA_OPTS}"
fi

log "Build command: ${LIVEMEDIA_CMD}"

# Start the build
log "Starting live media creation..."
log "This process may take 20-50 minutes depending on system performance..."

# Execute the build
if eval "${LIVEMEDIA_CMD}"; then
    success "Live media build completed successfully!"

    # Generate checksum
    log "Generating SHA256 checksum..."
    (
        cd "${ISO_RESULT_DIR}"
        sha256sum "${ISO_NAME}" > "${ISO_NAME}.CHECKSUM"
    )

    # Display results
    ISO_SIZE=$(du -h "${ISO_RESULT_DIR}/${ISO_NAME}" | cut -f1)
    success "ISO created: ${ISO_RESULT_DIR}/${ISO_NAME} (${ISO_SIZE})"
    success "Checksum: ${ISO_RESULT_DIR}/${ISO_NAME}.CHECKSUM"
    success "Logs: ${RESULT_DIR}/logs/"

    log "Build completed at: $(date)"

else
    error "Live media build failed! Check logs in ${RESULT_DIR}/logs/ for details"
fi
