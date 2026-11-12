# Build environment for the Lenovo Tab P12 Pro (q706f) Ubuntu Touch port.
# Ubuntu 22.04 is used on purpose: the 4.19 downstream kernel and the Halium
# build tools expect an older userland than the host distribution.
FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl wget git git-lfs openssh-client gnupg sudo \
      build-essential bc bison flex libssl-dev libelf-dev kmod cpio \
      python2 python3 python3-pip python-is-python3 \
      gcc-aarch64-linux-gnu binutils-aarch64-linux-gnu gcc-arm-linux-gnueabi \
      clang lld llvm ccache \
      device-tree-compiler abootimg \
      android-sdk-libsparse-utils \
      lz4 xz-utils zstd unzip zip p7zip-full rsync file \
      e2fsprogs erofs-utils dosfstools fakeroot kpartx \
      debootstrap qemu-user-static binfmt-support \
      repo adb fastboot \
    && rm -rf /var/lib/apt/lists/*
# The jammy mkbootimg package ships a broken unpack_bootimg; use AOSP's tools.
RUN git clone -q --depth 1 https://android.googlesource.com/platform/system/tools/mkbootimg /opt/mkbootimg \
    && git clone -q --depth 1 https://android.googlesource.com/platform/external/avb /opt/avb \
    && ln -s /opt/mkbootimg/mkbootimg.py /usr/local/bin/mkbootimg \
    && ln -s /opt/mkbootimg/unpack_bootimg.py /usr/local/bin/unpack_bootimg \
    && ln -s /opt/mkbootimg/unpack_bootimg.py /usr/local/bin/unpackbootimg \
    && ln -s /opt/avb/avbtool.py /usr/local/bin/avbtool
ARG UID=1000
ARG GID=1000
RUN groupadd -g ${GID} build && useradd -m -u ${UID} -g ${GID} -s /bin/bash build \
    && echo 'build ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/build
USER build
ENV CCACHE_DIR=/work/.ccache
WORKDIR /work
