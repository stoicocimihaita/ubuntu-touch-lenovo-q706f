# Qualcomm EDL (emergency download) tooling for the q706f port: bkerler/edl + qdl (distribution package).
# Runs as root with USB passthrough, so no udev rules are needed on the host.
FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates git python3 python3-pip python3-venv python3-dev build-essential \
      libusb-1.0-0 libusb-1.0-0-dev libxml2-dev pkg-config usbutils xz-utils liblzma-dev qdl \
    && rm -rf /var/lib/apt/lists/*
RUN python3 -m venv /opt/edl-venv \
    && git clone -q --depth 1 --recurse-submodules https://github.com/bkerler/edl /opt/edl \
    && /opt/edl-venv/bin/pip install -q /opt/edl \
    && ln -s /opt/edl-venv/bin/edl /usr/local/bin/edl
WORKDIR /work
