# ─────────────────────────────────────────────────────────────────────────────
# cdin — Docker image
#   builder: Ubuntu 22.04, SDL3 built from source, release build
#            (mirrors .github/workflows/release-linux.yml step for step)
#   runtime: Ubuntu 22.04 + shared libs only, cdin runs as a non-root user
#
# Notes:
#   * the version comes from `git describe` (mk/version.mk) — CI workflows
#     check out with fetch-depth: 0; .git is excluded from the build context,
#     so a plain `docker build` reports 0.0.0+unknown
#   * multi-arch friendly: builds for linux/amd64 and linux/arm64 (QEMU)
# ─────────────────────────────────────────────────────────────────────────────

FROM ubuntu:22.04 AS builder

ARG DEBIAN_FRONTEND=noninteractive
ARG SDL_VERSION=3.2.14

# ── Build dependencies — same list as release-linux.yml (plus build-essential
#    and git: needed to compile and to resolve the version via git describe) ─
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
      build-essential git \
      gcc make pkg-config python3 python3-pip \
      librsvg2-bin \
      liblua5.4-dev \
      cmake ninja-build \
      libwayland-dev libxkbcommon-dev \
      libgl1-mesa-dev libegl1-mesa-dev \
      libpulse-dev libasound2-dev \
      libdbus-1-dev libx11-dev libxext-dev \
      libxrandr-dev libxinerama-dev libxcursor-dev libxi-dev \
      wget ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# ── SDL3 from source — same version/URL/flags/prefix as release-linux.yml ──
RUN wget -q "https://github.com/libsdl-org/SDL/releases/download/release-${SDL_VERSION}/SDL3-${SDL_VERSION}.tar.gz" && \
    tar xf "SDL3-${SDL_VERSION}.tar.gz" && \
    cmake -S "SDL3-${SDL_VERSION}" -B /tmp/sdl3-build \
      -G Ninja \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_INSTALL_PREFIX=/opt/sdl3 \
      -DSDL_SHARED=ON -DSDL_STATIC=OFF \
      -DSDL_TEST=OFF -DSDL_TESTS=OFF && \
    cmake --build /tmp/sdl3-build --parallel $(nproc) && \
    cmake --install /tmp/sdl3-build && \
    rm -rf /tmp/sdl3-build "SDL3-${SDL_VERSION}" "SDL3-${SDL_VERSION}.tar.gz"

# ── Register SDL3 (ldconfig) — same as release-linux.yml ────────────────────
RUN echo "/opt/sdl3/lib" > /etc/ld.so.conf.d/sdl3.conf && \
    ldconfig && \
    PKG_CONFIG_PATH=/opt/sdl3/lib/pkgconfig pkg-config --modversion sdl3

WORKDIR /src

COPY . .

# ── Icon assets — same recipe as release-linux.yml (rsvg-convert + Pillow) ──
RUN pip3 install --quiet Pillow && \
    mkdir -p scripts/icons && \
    for sz in 16 22 24 32 48 64 128 256 512 1024; do \
      rsvg-convert -w "$sz" -h "$sz" scripts/icon.svg \
        -o "scripts/icons/cdin-${sz}.png"; \
    done && \
    python3 scripts/gen_icon.py \
      scripts/icon.svg \
      --out-inl        src/icon.inl \
      --out-dir scripts/icons && \
    PNG_COUNT=$(find scripts/icons -name 'cdin-*.png' | wc -l) && \
    [ "$PNG_COUNT" -gt 0 ]

# ── Build release binary — same make invocation as release-linux.yml ────────
RUN PKG_CONFIG_PATH=/opt/sdl3/lib/pkgconfig \
    make -j$(nproc) BUILD=release PLATFORM=linux SDL_VERSION=3

# ═══════════════════════════════════════════════════════════════════════════
# Runtime
# ═══════════════════════════════════════════════════════════════════════════

FROM ubuntu:22.04

ARG DEBIAN_FRONTEND=noninteractive

# ── Runtime dependencies — X11/wayland/audio/udev/GL shared libs SDL3 links
#    against, plus liblua5.4-0 (cdin links liblua5.4) ───────────────────────
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
      ca-certificates liblua5.4-0 \
      libx11-6 libxext6 libxrandr2 libxcursor1 libxi6 libxinerama1 \
      libxkbcommon0 libwayland-cursor0 libwayland-egl1 \
      libasound2 libpulse0 libdbus-1-3 libudev1 libgl1 && \
    rm -rf /var/lib/apt/lists/*

# ── SDL3 runtime — same /opt/sdl3 prefix as the builder ─────────────────────
COPY --from=builder /opt/sdl3/ /opt/sdl3/
RUN echo "/opt/sdl3/lib" > /etc/ld.so.conf.d/sdl3.conf && ldconfig

# ── cdin — the layout from mk/install.mk: the real binary and data/ live side
#    by side under /usr/local/lib/cdin, /usr/local/bin/cdin is a symlink.
#    cdin resolves data/ relative to the real executable (/proc/self/exe), so
#    the symlink and the data dir must keep pointing at the same prefix. ─────
RUN install -dm755 /usr/local/lib/cdin
COPY --from=builder /src/build/linux-release/cdin /usr/local/lib/cdin/cdin
COPY data/ /usr/local/lib/cdin/data/
RUN chmod 755 /usr/local/lib/cdin/cdin && \
    ln -sf /usr/local/lib/cdin/cdin /usr/local/bin/cdin

# ── Non-root user (uid 1000) ────────────────────────────────────────────────
RUN useradd -m -u 1000 cdin

ENV HOME=/home/cdin \
    DISPLAY=:0

USER cdin
WORKDIR /home/cdin

ENTRYPOINT ["/usr/local/bin/cdin"]
