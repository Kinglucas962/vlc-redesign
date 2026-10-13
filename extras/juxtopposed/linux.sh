#!/bin/sh
# Isolated baseline build; run inside the image from linux.Dockerfile.
set -eu
cd /work
jobs=${M0_JOBS:-1}
mkdir -p build-m0/contrib build-m0/linux build-m0/logs

if ! pkg-config --atleast-version=0.13.0 medialibrary; then
    cd /work/build-m0/contrib
    ../../contrib/bootstrap --prefix=/work/build-m0/deps --disable-all --enable-medialibrary
    make -j"$jobs" .medialibrary > ../logs/medialibrary.log 2>&1
    cd /work
fi

./bootstrap > build-m0/logs/bootstrap.log 2>&1
cd build-m0/linux
export PKG_CONFIG_PATH="/work/build-m0/deps/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
export LD_LIBRARY_PATH="/work/build-m0/deps/lib:${LD_LIBRARY_PATH:-}"
/work/configure --disable-nls --disable-skins2 --disable-rust \
    --enable-qt --enable-medialibrary CFLAGS='-O0 -g0' CXXFLAGS='-O0 -g0' \
    > ../logs/configure.log 2>&1
make -j"$jobs" > ../logs/linux-build.log 2>&1
