# Copyright (C) 2026 VLC authors and VideoLAN
# SPDX-License-Identifier: GPL-2.0-or-later
FROM ubuntu:24.04@sha256:534baea6a22c03a63003dbc8dbe78fe34bc0d7e595d9a9dc9834884ff530eb55

ENV DEBIAN_FRONTEND=noninteractive
RUN sed -i 's/^Types: deb$/Types: deb deb-src/' /etc/apt/sources.list.d/ubuntu.sources \
    && apt-get update \
    && apt-get build-dep -y --no-install-recommends vlc \
    && apt-get install -y --no-install-recommends \
       git curl ca-certificates autoconf automake libtool autopoint \
       build-essential pkg-config flex bison nasm meson ninja-build \
       python3 qt6-base-dev qt6-base-private-dev qt6-declarative-dev \
       qt6-declarative-private-dev qt6-svg-dev qt6-shadertools-dev \
       qt6-tools-dev-tools qt6-wayland qt6-wayland-dev \
       qml6-module-qtquick qml6-module-qtquick-controls \
       qml6-module-qtquick-layouts qml6-module-qtquick-templates \
       qml6-module-qtquick-window qml6-module-qtqml-workerscript \
       qml6-module-qttest libsqlite3-dev xvfb xauth xdotool \
       ffmpeg pulseaudio-utils imagemagick \
    && rm -rf /var/lib/apt/lists/*

RUN apt-get update \
    && apt-get install -y --no-install-recommends qml6-module-qtqml-models \
       libxcb-xkb-dev libxcb-damage0-dev libxkbcommon-x11-dev pulseaudio openbox \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /work
USER ubuntu
