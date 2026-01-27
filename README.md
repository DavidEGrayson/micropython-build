# MicroPython build scripts

This repository contains code and instructions for building [MicroPython]
firmware images for the 3pi+ 2040 Robot and the Zumo 2040 Robot.

## Building with Nix

To build a combined UF2 file that contains both MicroPython (compiled from source)
and a filesystem with Pololu example code, install [Nix] and [Git] on a Linux machine,
then navigate to this directory and run one of the following:
- `./build.sh -A pico`
- `./build.sh -A pololu-3pi-2040-robot`
- `./build.sh -A pololu-zumo-2040-robot`

You can also build MicroPython itself without a filesystem by running one of the
commands above with `.base` appended to the end (no spaces).

These builds are reproducible: if you build the firmware the same way on two
different machines or at two different times, you should get the exact same result.

## Manual build

To build your own updated version of MicroPython without using Nix, you
can follow these steps on a Linux machine:

```text
sudo apt install git cmake make gcc gcc-arm-none-eabi python3 # for Debian/Ubuntu

# Run one of these commands to define what board you are building for.
export BOARD=POLOLU_3PI_2040_ROBOT
export BOARD=POLOLU_ZUMO_2040_ROBOT

git clone https://github.com/pololu/micropython-build
git clone https://github.com/v923z/micropython-ulab ulab
git clone https://github.com/micropython/micropython
cd micropython

cat ../micropython-build/mpy*.patch | patch -p1
git submodule update --init lib/pico-sdk
cat ../micropython-build/pico-sdk*.patch | (cd lib/pico-sdk && patch -p1)

cd ports/rp2
make submodules
make clean
make USER_C_MODULES=../../../ulab/code/micropython.cmake
```

There will now be a `firmware.uf2` file in the `build-*` directory
for your robot that you can use.  It will not contain a file system
or example code for the robot.

## Acknowledgments

This project relies on the following third-party projects:

- [MicroPython](https://github.com/micropython/micropython)
- [Mbed TLS](https://github.com/ARMmbed/mbedtls)
- [micropython-lib](https://github.com/micropython/micropython-lib)
- [Raspberry Pi Pico SDK](https://github.com/raspberrypi/pico-sdk)
- [TinyUSB](https://github.com/hathach/tinyusb)
- [ulab](https://github.com/v923z/micropython-ulab)
- [Nixpkgs](https://github.com/nixos/nixpkgs) and [Nix]

It also incorporates example code written by Pololu:

- [3pi+ 2040 Robot Libraries and Example Code](https://github.com/pololu/pololu-3pi-2040-robot)
- [Zumo 2040 Robot Libraries and Example Code](https://github.com/pololu/zumo-2040-robot)

[Git]: https://git-scm.com/
[Nix]: https://github.com/nixos/nix
[MicroPython]: https://micropython.org/
