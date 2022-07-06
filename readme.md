# Libre Computer Raspbian Portability
## Objective
This repository contains scripts that allows Libre Computer boards to run existing images targeted at the Raspberry Pi:registered: board family.
It uses an upstream bootloader and kernel configured to support armhf executables. 

## Supported Distributions
- [Raspbian 10 Buster Lite armhf](https://www.raspberrypi.com/software/operating-systems/#raspberry-pi-os-32-bit) - Dual Board Boot Capable
- [Raspbian 10 Buster Desktop armhf](https://www.raspberrypi.com/software/operating-systems/#raspberry-pi-os-32-bit) - Dual Board Boot Capable
- [Ubuntu 22.04 Jammy Preinstalled Desktop arm64](https://cdimage.ubuntu.com/releases/22.04/release/)

## Supported Boards
- AML-S905X-CC Le Potato
- AML-S805X-AC La Frite
- ROC-RK3399-PC (with firmware)
- Other Libre Computer boards will be supported soon

## Current Status
This is at the proof of concept stage and is tested against the distribution
The code base needs to be refined and modularized over time to support all of the Raspbian variations that exist. 
We highly recommend that you back up your data!

## Limitations
- This does not use Raspbian's kernels.
- This does not support Raspberry Pi:registered: device tree overlays.
- This does not support Raspberry Pi:registered: specific hardware acceleration.
- There is no warranty implied or otherwise.
- As a POC, the code is very ad-hoc and not representative of our normal coding standards.

## How to Use
On your Raspberry Pi:registered:, run:
```bash
git clone https://github.com/libre-computer-project/libretech-raspbian-portability.git
cd libretech-raspbian-portability
sudo ./oneshot.sh
```
Follow the instructions.

## Help
[Libera Chat IRC #librecomputer](https://web.libera.chat/#librecomputer)

## Roadmap
Our core work is on upstream Linux and u-boot so scripts such as this are not a high priority.
- Raspbian 11 bullseye 64-bit and 32-bit support
- ALL-H3-CC H2+/H3/H5 support
- ROC-RK3328-CC support
- Refactor to robust coding standards
- Device tree overlay translation support as another project

If you need commercial support for any distro, [please let us know](https://libre.computer/#contact).
