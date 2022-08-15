# Libre Computer Raspbian Portability
## Objective
This script is designed to run on existing Raspbian images and enables them
to boot on Libre Computer boards. It uses upstream FOSS software stack
developed by the community and Libre Computer to support booting Raspbian.

It is a proof-of-concept and there are no warranties implied or otherwise.
We highly recommend backing up the image if it holds important data in case
something unexpected occurs. While the image should still boot on the original
device, this is not fully tested or guaranteed so continue at your own risk.

This script installs/configures/overwrites data on the device's MicroSD card.
It is designed to run on Raspberry Pi(R)s and requires internet access to 
download additional necessary components. Once the script finishes, the card
should still remain bootable on the original board.

## Supported Distributions
- [Raspbian 10 Buster Lite and Desktop armhf](https://www.raspberrypi.com/software/operating-systems/#raspberry-pi-os-legacy)
- [Raspbian 11 Bullseye Lite and Desktop armhf](https://www.raspberrypi.com/software/operating-systems/#raspberry-pi-os-32-bit)
- [Raspbian 11 Bullseye Lite and Desktop arm64](https://www.raspberrypi.com/software/operating-systems/#raspberry-pi-os-64-bit)
- If you want to use Ubuntu, you can use these [Ubuntu 22.04.1 images](http://distro.libre.computer/ci/ubuntu/22.04/).

## Supported Boards
- All Libre Computer Boards

## Current Status
- GPIOs, I2C, SPI, UART, PWM need to be translated via our [wiring tool](https://github.com/libre-computer-project/libretech-wiring-tool.git).
- Software designed specificially for Raspberry Pi&reg; hardware will not work.
- Camera, DPI screens, and DSI panels are not supported.
= This is not extensively tested for all scenarios. Please report bugs on [our hub thread](https://hub.libre.computer/t/feedback-for-raspbian-portability/32).

## How to Use
On your Raspberry Pi:registered:, run:
```bash
git clone https://github.com/libre-computer-project/libretech-raspbian-portability.git lrp
sudo lrp/oneshot.sh aml-s905x-cc
```
Replace aml-s905x-cc with the appropriate board you want the image to run on and follow the instructions.
For a list of boards, run sudo lrp/oneshot.sh

## Help and Support
- [Libre Computer Hub](https://hub.libre.computer/t/feedback-for-raspbian-portability/32)
- [Libera Chat IRC #librecomputer](https://web.libera.chat/#librecomputer)

## Roadmap
- Refactor to robust coding standards
- Device tree overlay translation via our [wiring tool](https://github.com/libre-computer-project/libretech-wiring-tool.git)
- Firmware for specific boards

We provide commercial support for porting specific distros or images, [please reach out to us](https://libre.computer/#contact).
