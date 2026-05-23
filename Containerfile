FROM archlinux:latest

ARG ARCH_SNAPSHOT=2026/05/01

RUN printf 'Server = https://archive.archlinux.org/repos/%s/$repo/os/$arch\n' "$ARCH_SNAPSHOT" > /etc/pacman.d/mirrorlist \
    && pacman -Syyu --noconfirm \
    && pacman -S --noconfirm \
        arch-install-scripts \
        ca-certificates \
        cpio \
        dosfstools \
        e2fsprogs \
        gnupg \
        mkosi \
        mtools \
        python-pefile \
        qemu-img \
        squashfs-tools \
        systemd \
        xz \
    && pacman -Scc --noconfirm

WORKDIR /mkosi

VOLUME ["/mkosi", "/output"]

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["/output"]
