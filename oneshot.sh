#!/bin/bash
# SPDX-License-Identifier: CC BY-NC-ND 4.0
# Copyright (C) 2021 Da Xue <da@libre.computer>

set -e

if [ "$USER" != "root" ]; then
	echo "Please run this as root." >&2
	echo "sudo $0 $@" >&2
	exit 1
fi

if [ -z "$1" ]; then
	echo "No board selected. Supported boards:" >&2
	echo "all-h3-cc-h3" >&2
	echo "all-h3-cc-h5" >&2
	echo "aml-s805x-ac" >&2
	echo "aml-s905x-cc" >&2
	echo "roc-rk3328-cc" >&2
	echo "roc-rk3399-pc" >&2
	echo "sudo $0 BOARD" >&2
	exit 1
fi

case "$1" in
	all-h3-cc-h3)
		BOARD_name=all-h3-cc-h3
		BOARD_bootSector=16
		BOARD_console=S0,115200
		BOARD_bootLoader=1
		BOARD_arch=arm
		;;
	all-h3-cc-h5)
		BOARD_name=all-h3-cc-h5
		BOARD_bootSector=16
		BOARD_console=S0,115200
		BOARD_bootLoader=1
		BOARD_arch=arm64
		;;
	aml-s805x-ac)
		BOARD_name=aml-s805x-ac
		BOARD_bootSector=1
		BOARD_console=AML0
		BOARD_bootLoader=0
		BOARD_arch=arm64
		;;
	aml-s905x-cc)
		BOARD_name=aml-s905x-cc
		BOARD_bootSector=1
		BOARD_console=AML0
		BOARD_bootLoader=1
		BOARD_arch=arm64
		;;
	roc-rk3328-cc)
		BOARD_name=roc-rk3328-cc
		BOARD_bootSector=64
		BOARD_console=S2,1500000
		BOARD_bootLoader=1
		BOARD_arch=arm64
		;;
	roc-rk3399-pc)
		BOARD_name=roc-rk3399-pc
		BOARD_bootSector=64
		BOARD_console=S2,1500000
		BOARD_bootLoader=1
		BOARD_arch=arm64
		;;
	*)
		echo "Unsupported board $1" >&2
		exit 1
		;;
esac

cat <<EOF
This script is designed to run on existing Raspbian images and enabled them
them to boot on Libre Computer boards. It uses our extensive upstream u-boot
and Linux work and infrastructure to support Raspbian's legacy ARMv6 binaries.

It is a proof-of-concept and there are no warranties implied or otherwise.
We highly recommend backing up the images if they hold important data in case
something unexpected occurs. While they should still boot on your original
device, this is not fully tested or guaranteed so continue at your own risk.

This script installs/configures/overwrites data this device/MicroSD card.
It is designed to run on Raspberry Pi(R)s and requires internet access to 
download additional necessary components.

Once completed, move the MicroSD card to the selected Libre Computer Board.

Please type 'continue' without quotes to acknowledge and start the script.

EOF
read -p ":" input
if [ "${input,,}" != "continue" ]; then
	echo "Input ${input} does not match 'continue'. Exiting."
	exit 1
fi

SRC_DIR=$(readlink -f $(dirname ${BASH_SOURCE[0]}))

target_part=$(findmnt -no SOURCE /)
target_disk=$(lsblk --list -no type,name --inverse "$target_part" | grep ^disk | cut -d " " -f 2)

sfdisk_file=$(mktemp)
sfdisk -d "/dev/$target_disk" > "$sfdisk_file"
sfdisk_label=$(grep -Po "label:\\s+\\K.*" "$sfdisk_file")

if [ -z "$sfdisk_label" ]; then
	echo "disk: error disk no label" >&2
	exit 1
elif [ "$sfdisk_label" = "dos" ]; then
	:
elif [ "$sfdisk_label" = "gpt" ]; then
	echo "disk: gpt is not supported" >&2
	exit 1
else
	echo "disk: unknown partition table" >&2
	exit 1
fi

sfdisk_dev=$(grep -Po "device:\\s+\\K.*" "$sfdisk_file")
sfdisk_dev_p1_file=$(mktemp)
grep -Po "^${sfdisk_dev}p1\\s+:\\s+\\K.*" "$sfdisk_file" | sed "s/,/\\n/g" | sed "s/\\s//g" > "$sfdisk_dev_p1_file"
sfdisk_dev_p1_start=$(awk -F= "/^start/ {print \$2}" "$sfdisk_dev_p1_file")

if [ -z "$sfdisk_dev_p1_start" ]; then
	echo "disk: p1 start not found" >&2
	exit 1
elif [ "$sfdisk_dev_p1_start" -lt 2048 ]; then
	echo "disk: p1 starts too early" >&2
	exit 1
fi

OS_RELEASE_FILE=/etc/os-release
if [ ! -f "$OS_RELEASE_FILE" ]; then
	echo "os-release: missing file" >&2
	exit 1
fi

readarray -t lines < "$OS_RELEASE_FILE"
declare -A TARGET_OS_RELEASE
for line in "${lines[@]}"; do
	key="${line%%=*}"
	value="${line#*=}"
	TARGET_OS_RELEASE["$key"]="$value"
done

if [ "${TARGET_OS_RELEASE[ID]}" = "raspbian" ]; then
	case  "${TARGET_OS_RELEASE[VERSION_ID]}" in
		'"10"')
			:
			;;
		'"11"')
			:
			;;
		*)
			echo "os-release-version: only Raspbian 10 and 11 are supported." >&2
			;;
	esac
	dpkg_arch_target=$BOARD_arch
	grub_install_cmd="grub-install --directory=/usr/lib/grub/${BOARD_arch}-efi --efi-directory=/boot --force-extra-removable --no-nvram"
else
	echo "os-release: only Raspbian is supported!" >&2
	exit 1
fi

if which rpi-eeprom-update > /dev/null; then
	systemctl disable rpi-eeprom-update || true
fi

dpkg_arch=$(dpkg --print-architecture)
if [ -z "$dpkg_arch" ]; then
	echo "dpkg: failed to get architecture" >&2
	exit 1
elif [ "$dpkg_arch" = "armhf" ]; then
	dpkg_arches_foreign=$(dpkg --print-foreign-architectures)
	for dpkg_arch_foreign in $dpkg_arches_foreign; do
		if [ "$dpkg_arch_foreign" = "$dpkg_arch_target" ]; then
			break
		fi
	done
	if [ "$dpkg_arch_foreign" != "$dpkg_arch_target" ]; then
		dpkg --add-architecture ${BOARD_arch}
	fi
	
	apt_sources=$(ls /etc/apt/sources.list /etc/apt/sources.list.d/*.list)
	for apt_source in $apt_sources; do
		sed -Ei "s/^(deb)\\s+(http:\\/\\/)/\\1 [ arch=armhf ] \2/" "$apt_source"
	done
	echo "deb [ arch=${BOARD_arch} ] http://deb.debian.org/debian/ ${TARGET_OS_RELEASE[VERSION_CODENAME]} main" > /etc/apt/sources.list.d/debian-main.list
	
	apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 605C66F00D6C9793
	apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 0E98404D386FA1D9
	apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 648ACFD622F3D138
else
	echo "dpkg: architecture is not supported" >&2
	exit 1
fi

wget -O "/usr/share/keyrings/libre-computer-deb.gpg" 'https://deb.libre.computer/repo/libre-computer-deb.gpg'
echo "deb [arch=${BOARD_arch} signed-by=/usr/share/keyrings/libre-computer-deb.gpg] https://deb.libre.computer/repo linux main non-free" > "$root_mount_dir/etc/apt/sources.list.d/libre-computer-deb.list"

apt update
#apt -y dist-upgrade
apt -y install grub-efi-$BOARD_arch linux-image-lc-stable-$BOARD_arch linux-headers-lc-stable-$BOARD_arch
$grub_install_cmd
sed -Ei "s/(GRUB_CMDLINE_LINUX_DEFAULT)=\"quiet/\1=\"noquiet/" /etc/default/grub
update-grub
if [ "${TARGET_OS_RELEASE[ID]}" = "raspbian" ]; then
	mkdir -p /boot/EFI/debian
	cp /boot/EFI/raspbian/grub.cfg /boot/EFI/debian/grub.cfg
fi

if [ "$BOARD_bootLoader" -eq 1 ]; then
	BOOT_LOADER_URL="http://boot.libre.computer/ci/$BOARD_name"
	boot_loader_file=$(mktemp)
	wget -O "$boot_loader_file" "$BOOT_LOADER_URL"
	dd if="$boot_loader_file" of=/dev/"$target_disk" bs=512 seek=$BOARD_bootSector
fi

cp $SRC_DIR/apps/xorg/10-*.conf /usr/share/X11/xorg.conf.d
if [ -f $SRC_DIR/apps/alsa/${BOARD_name}.state ]; then
	cp $SRC_DIR/apps/alsa/${BOARD_name}.state /var/lib/alsa/asound.state
fi

read -n 1 -p "Modifications complete. Press any key to shutdown. Once the green LED stops blinking and turns off for 10 seconds, remove power and move the MicroSD card to the Libre Computer Board."
shutdown -H now
