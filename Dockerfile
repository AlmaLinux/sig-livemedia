# ----------------------------------------------------------------------------
# Multi stage docker build for live cd tools in docker/container environment
# AlmaLinux Init + Live CD Tools + PyKickStart 
# ----------------------------------------------------------------------------
FROM almalinux:8 as builder

RUN dnf install -y epel-release elrepo-release && \
    dnf upgrade -y && \
    mkdir -p /mnt/system-root /mnt/system-root/build; \
    dnf install --enablerepo="powertools" --enablerepo="epel" --enablerepo="elrepo" --installroot /mnt/system-root  --releasever 8 --setopt=install_weak_deps=False --setopt=tsflags=nodocs -y \
    dnf \
    systemd \
    livecd-tools \
    pykickstart \
    hfsplus-tools \
    grub2-efi-x64 \
    grub2-efi-x64-cdboot \
    shim-x64 ; \
    rm -rf /mnt/system-root/var/cache/* ; \
    dnf clean all; \
    cp /etc/yum.repos.d/* /mnt/system-root/etc/yum.repos.d/ ; \
    rm -rf /var/cache/yum; 

# Create Final image from scratch for ks2rootfs
FROM scratch

COPY --from=builder /mnt/system-root/ /

CMD ["/bin/bash"]
