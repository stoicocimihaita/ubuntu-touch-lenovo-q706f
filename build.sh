#!/bin/bash
# Build boot.img and the device tarball for the Lenovo Tab P12 Pro (q706f).
# Run it through scripts/build.sh, which provides the build container.
set -e

[ -d build ] || git clone https://gitlab.com/ubports/porting/community-ports/halium-generic-adaptation-build-tools build

LIBDIR=overlay/system/opt/halium-overlay/vendor
for f in q706f-stock.dtb "$LIBDIR/lib/eglSubDriverAndroid.so" "$LIBDIR/lib64/eglSubDriverAndroid.so"; do
    if [ ! -s "$f" ]; then
        echo "ERROR: $f is missing." >&2
        echo "Run scripts/extract-stock.sh <stock firmware zip> first (see README.md)." >&2
        exit 1
    fi
done

# Fetch toolchains, the kernel and the Halium ramdisk without building yet.
./build/build.sh -c "$@"

# The slot-aware wrapper in ramdisk-overlay/ calls the original Halium tool under a
# different name; take that binary from the ramdisk that was just downloaded.
REAL=ramdisk-overlay/sbin/parse-android-dynparts.real
if [ ! -s "$REAL" ]; then
    tmp=$(mktemp -d)
    gzip -dc workdir/downloads/halium-boot-ramdisk.img | (cd "$tmp" && cpio -id --quiet --no-absolute-filenames 'sbin/parse-android-dynparts' './sbin/parse-android-dynparts' 2>/dev/null || true)
    if [ ! -s "$tmp/sbin/parse-android-dynparts" ]; then
        echo "ERROR: parse-android-dynparts not found in the Halium ramdisk" >&2
        exit 1
    fi
    install -m755 "$tmp/sbin/parse-android-dynparts" "$REAL"
    rm -rf "$tmp"
fi

./build/build.sh "$@"
