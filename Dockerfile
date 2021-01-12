# Create a builder image with the compilers, etc. needed
FROM ubuntu:20.04 AS build-env

# Install all the required packages for building. This list is probably
# longer than necessary.
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install --no-install-recommends -y \
    autopoint \
    autoconf \
    build-essential \
    clang \
    cmake \
    gettext \
    git \
    libcairo2-dev \
    libcap-dev \
    libcolord-dev \
    libdbus-glib-1-dev \
    libdrm-dev \
    libffi-dev \
    libgbm-dev \
    libgles2-mesa-dev \
    libgstreamer-plugins-base1.0-dev \
    libgstreamer1.0-dev \
    libinput-dev \
    libjpeg-dev \
    liblcms2-dev \
    libltdl-dev \
    libpam-dev \
    libpango1.0-dev \
    libpixman-1-dev \
    libsndfile1 \
    libsndfile-dev \
    libssl-dev \
    libsystemd-dev \
    libtool \
    libudev-dev \
    libudev-dev \
    libusb-1.0-0-dev \
    libva-dev \
    libwayland-dev \
    libwebp-dev \
    libx11-dev \
    libx11-xcb-dev \
    libxcb-composite0-dev \
    libxcb-xkb-dev \
    libxcursor-dev \
    libxdamage-dev \
    libxext-dev \
    libxfixes-dev \
    libxi-dev \
    libxinerama-dev \
    libxkbcommon-dev \
    libxkbfile-dev \
    libxml2-dev \
    libxml-parser-perl \
    libxrandr-dev \
    libxrender-dev \
    libxtst-dev \
    libxv-dev \
    lsb-release \
    meson \
    ninja-build \
    pkg-config \
    software-properties-common \
    uuid-dev \
    wayland-protocols \
    wget

# Create an image with builds of FreeRDP and Weston
FROM build-env AS dev

ARG WSLG_VERSION="<current>"
ARG WSLG_ARCH="x86_64"

WORKDIR /work
RUN echo "WSLG (" ${WSLG_ARCH} "):" ${WSLG_VERSION} > /work/versions.txt

ENV DESTDIR=/work/build
ENV PREFIX=/usr
ENV PKG_CONFIG_PATH=${DESTDIR}${PREFIX}/lib/pkgconfig:${DESTDIR}${PREFIX}/lib/${WSLG_ARCH}-linux-gnu/pkgconfig:${DESTDIR}${PREFIX}/share/pkgconfig
ENV C_INCLUDE_PATH=${DESTDIR}${PREFIX}/include/freerdp2:${DESTDIR}${PREFIX}/include/winpr2
ENV LIBRARY_PATH=${DESTDIR}${PREFIX}/lib

# Build wayland
COPY vendor/wayland /work/vendor/wayland
WORKDIR /work/vendor/wayland
RUN ./autogen.sh --prefix=${PREFIX} --disable-documentation && \
    make -j8 && make install
RUN echo 'wayland:' `git --git-dir=/work/vendor/wayland/.git rev-parse --verify HEAD` >> /work/versions.txt

# Build FreeRDP
COPY vendor/FreeRDP /work/vendor/FreeRDP
WORKDIR /work/vendor/FreeRDP
RUN cmake -G Ninja \
        -B build \
        -DCMAKE_INSTALL_PREFIX=${PREFIX} \
        -DCMAKE_INSTALL_LIBDIR=${PREFIX}/lib \
        -DCMAKE_BUILD_TYPE=RelWithDebInfo \
        -DWITH_SERVER=ON \
        -DWITH_CLIENT=OFF \
        -DWITH_CLIENT_COMMON=OFF \
        -DWITH_CLIENT_CHANNELS=OFF \
        -DWITH_CLIENT_INTERFACE=OFF \
        -DWITH_PROXY=OFF \
        -DWITH_SHADOW=OFF \
        -DWITH_SAMPLE=OFF && \
    ninja -C build -j8 install
RUN echo 'FreeRDP:' `git --git-dir=/work/vendor/FreeRDP/.git rev-parse --verify HEAD` >> /work/versions.txt

# Build Weston
COPY vendor/weston /work/vendor/weston
WORKDIR /work/vendor/weston
RUN meson --prefix=${PREFIX} build \
         -Dbackend-default=rdp \
         -Dbackend-drm=false \
         -Dbackend-drm-screencast-vaapi=false \
         -Dbackend-headless=false \
         -Dbackend-wayland=false \
         -Dbackend-x11=false \
         -Dbackend-fbdev=false \
         -Dscreenshare=false \
         -Dremoting=false \
         -Dpipewire=false \
         -Dshell-desktop=false \
         -Dshell-fullscreen=false \
         -Dshell-ivi=false \
         -Dshell-kiosk=false \
         -Ddemo-clients=false \
         -Dsimple-clients=[] \
         -Dtools=[] \
         -Dresize-pool=false \
         -Dwcap-decode=false \
         -Dtest-junit-xml=false && \
    ninja -C build -j8 install
RUN echo 'weston:' `git --git-dir=/work/vendor/weston/.git rev-parse --verify HEAD` >> /work/versions.txt

# Build PulseAudio
COPY vendor/pulseaudio /work/vendor/pulseaudio
WORKDIR /work/vendor/pulseaudio
RUN meson --prefix=${PREFIX} build -Ddatabase=simple -Dbluez5=false -Dtests=false
RUN ninja -C build -j8 install
RUN echo 'pulseaudio:' `git --git-dir=/work/vendor/pulseaudio/.git rev-parse --verify HEAD` >> /work/versions.txt

# Build sharedguestalloc
COPY vendor/sharedguestalloc /work/vendor/sharedguestalloc
WORKDIR /work/vendor/sharedguestalloc
RUN make -j8
RUN echo 'sharedguestalloc:' `git --git-dir=/work/vendor/sharedguestalloc/.git rev-parse --verify HEAD` >> /work/versions.txt

# Build WSLGd
COPY WSLGd /work/WSLGd
WORKDIR /work/WSLGd
RUN meson --prefix=${PREFIX} build
RUN ninja -C build -j8 install

# Create the distro image with just what's needed at runtime.
FROM ubuntu:20.04 as runtime

ARG WSLG_ARCH="x86_64"

# Install the packages needed to run weston, freerdp, and xwayland.
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install --no-install-recommends -y \
    check \
    dbus \
    dbus-x11 \
    libcairo2 \
    libcap-dev \
    libdbus-1-3 \
    libegl1 \
    libinput10 \
    libjpeg8 \
    liborc-0.4-0 \
    libpango-1.0.0 \
    libpangocairo-1.0.0 \
    libsndfile1 \
    libsndfile-dev \
    libssl1.1 \
    libtdb-dev \
    libwayland-client0 \
    libwayland-cursor0 \
    libwayland-server0 \
    libwebp6 \
    libxcb-composite0-dev \
    libxcursor1 \
    libxkbcommon0 \
    tzdata \
    xinit \
    xcursor-themes \
    xwayland

# Install packages to aid in development.
# TODO: these should not be included when building the retail image.
RUN apt-get update && apt-get install --no-install-recommends -y \
    gdb \
    nano \
    vim

# Create wslg user.
RUN useradd -u 1000 --create-home wslg && \
    mkdir /home/wslg/.config && \
    chown wslg /home/wslg/.config

# Copy config files.
COPY config/wsl.conf /etc/wsl.conf
COPY config/${WSLG_ARCH}-system-distro.conf /etc/ld.so.conf.d/${WSLG_ARCH}-system-distro.conf
COPY config/weston.ini /home/wslg/.config/weston.ini

# Copy default icon file.
COPY resources/linux.png /usr/share/icons/wsl/linux.png

# Copy the built artifacts from the build stage.
COPY --from=dev /work/build /
COPY --from=dev /work/versions.txt /etc/versions.txt

COPY --from=dev /work/vendor/sharedguestalloc/libsharedguestalloc.so /usr/lib/libsharedguestalloc.so

# start weston with RDP.
#
# --backend=rdp-backend.so : this enables RDP server in weston.
# --port=3391 : port to listen RDP connection (default is 3389)
# --xwayland : enable X11 app support in weston.
#
EXPOSE 3391/tcp

CMD /usr/bin/WSLGd
