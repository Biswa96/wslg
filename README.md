# Introduction

This repository contains a Dockerfile and supporting tools to build the WSL GUI system distro image.

## Quick start

0. Install and start Docker in a Linux or WSL2 environment.

1. Clone the FreeRDP ,Weston and PulseAudio side by side this repo repositories and checkout the "working" branch from each:

    ```bash
    git clone https://microsoft.visualstudio.com/DefaultCollection/DxgkLinux/_git/FreeRDP vendor/FreeRDP -b working

    git clone https://microsoft.visualstudio.com/DefaultCollection/DxgkLinux/_git/weston vendor/weston -b working

    git clone https://microsoft.visualstudio.com/DefaultCollection/DxgkLinux/_git/pulseaudio vendor/pulseaudio -b working
    ```

2. Build the image:

    ```bash
    docker build -t wsl-system-distro .
    ```

    This builds a container image called "wsl-system-distro" that will run weston when it starts.

3. Run the image, allowing port 3391 out and bind mounting the Unix sockets:

    ```bash
    docker run -it --rm -v /tmp/.X11-unix:/tmp/.X11-unix -v /tmp/xdg-runtime-dir:/mnt/wsl/system-distro/ -p 3391:3391 wsl-system-distro
    ```

4. Start mstsc:

    Get the IP address of your WSL instance:

    ```
    hostname -I
    ```

    From the Windows start mstsc.exe

    ```bash
    mstsc.exe /v:172.25.228.118:3391 rail-weston.rdp
    ```

5. In another terminal, set the environment appropraitely and run apps:

    ```bash
    export DISPLAY=:0
    export WAYLAND_DISPLAY=/tmp/xdg-runtime-dir/wayland-0
    sudo gimp
    ```

If you are running from docker right now due an issue they with the permissions of 
`/tmp/.X11-unix/X0` only root can launch gui applications.
Other users will fail to open the display, you may see a message like 

```
cannot open display: :0
```

6. Make changes to vendor/FreeRDP or vendor/weston and repeat steps 2 through 5.

## Advanced

By default, `docker build` only saves the runtime image. Internally, there is
also a build environment with all the packages needed to build Weston and
FreeRDP, and there is a development environment that has Weston and FreeRDP
built but also includes all the development packages. You can get access to
these via the `--target` option to `docker build`.

For example, to just get a build environment and to run it with the source mapped in instead of copied:

```
docker build --target build-env -t wsl-weston-build-env .
docker run -it --rm -v $PWD/vendor:/work/vendor wsl-weston-build-env

# inside the docker container
cd vendor/weston
meson --prefix=/usr/local/weston build -Dpipewire=false
ninja -C build
```

## Build system.vhd

To build the system distro vhd you need to use `docker export`
Docker export only works when the image is running:

Use docker export to create the tar with the contents of the image, and 
tar2ext4 to create the vhd file

```
docker export `docker create wsl-system-distro` > system.tar
git clone --branch v0.8.9 --single-branch https://github.com/microsoft/hcsshim.git
go run hcsshim/cmd/tar2ext4/tar2ext4.go -o system.vhd -i system.tar -vhd'
```

# Distro Image

* To get the SystemDistro image you can grab the latest from the [AzDO Pipeline](https://microsoft.visualstudio.com/DefaultCollection/DxgkLinux/_build?definitionId=55011)

* Go to the lastest build > Pipeline Artifacts > Download `system.vhd`

* Add an entry to your `%USERPROFILE%\.wslconfig`

```
[wsl2]
systemDistro=C:\\Users\\MyUser\\system.vhd
```


