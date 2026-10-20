# Copyright (C) 2026 VLC authors and VideoLAN
# SPDX-License-Identifier: GPL-2.0-or-later
# Official Windows x86_64 image of extras/ci/gitlab-ci.yml, plus rsync for
# incremental source syncs in win64-docker.sh.
FROM registry.videolan.org/vlc-debian-win64-posix:20260611225331
USER root
RUN apt-get update \
    && apt-get install -y --no-install-recommends rsync \
    && rm -rf /var/lib/apt/lists/*
USER videolan
