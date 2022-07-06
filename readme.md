# Libre Computer Raspbian Portability
## Objective
This repository contains scripts that allows Libre Computer boards to run existing Raspbian images.
It uses an upstream bootloader and kernel configured to support armhf executables. The resulting
image should boot both on the original board and the Libre Computer board.

## Current Status
This is at the proof of concept stage and is tested against Raspbian Lite and Desktop based on
the Debian 10 Buster release. The code base needs to be refined and modularized over time to
support all of the Raspbian variations that exist. We highly recommend that you back up your data!

It supports the following Libre Computer boards:
1. AML-S905X-CC Le Potato
2. AML-S805X-AC La Frite
3. ROC-RK3399-PC (with firmware)

Support can easily be added for all Libre Computer boards.

## Limitations
- This does not use Raspbian's kernels.
- This does not support Raspberry Pi:registered: device tree overlays.
- This does not support Raspberry Pi:registered: specific hardware acceleration.
- There is no warranty implied or otherwise.
- As a POC, the code is very ad-hoc and not representative of our normal coding standards.

## How to Use
On your Raspberry Pi, run:
```bash
git clone https://github.com/libre-computer-project/libretech-raspbian-portability.git
cd libretech-raspbian-portability
sudo ./oneshot.sh
```
Follow the instructions. Move MicroSD card to one of the Libre Computer board.

## Help
[Libera Chat IRC #librecomputer](https://web.libera.chat/#librecomputer)

## Roadmap
Our core work is on upstream Linux and u-boot so scripts such as this are not a high priority.
- Raspbian 11 bullseye 64-bit and 32-bit support
- ALL-H3-CC H2+/H3/H5 support
- Refactor to robust coding standards

If you need commercial support for 32-bit Raspbian or any distro, [please let us know](https://libre.computer/#contact).
