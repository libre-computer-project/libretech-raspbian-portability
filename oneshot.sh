#!/bin/bash

# Copyright 2022 Da Xue. All rights reserved.

set -e

if [ "$USER" != "root" ]; then
	echo "Please run this as root." >&2
	echo "sudo $0 $@" >&2
	exit 1
fi

cat <<EOF
THIS IS A PROOF OF CONCEPT AND SHOULD ONLY BE USED FOR TESTING!

There is no warranty implied and you are continuing at your own risk!
Please backup the contents of this device/MicroSD if there is important data!

This script installs/configures/overwrites data this device/MicroSD card to
support Libre Computer AML-S905X-CC and AML-S805X-AC. It is designed to run on 
a Raspberry Pi(R) and requires internet access to download components.

Only Raspbian 10 Buster 32-bit armhf lite and desktop and Ubuntu 22.04 Jammy
preinstalled desktop image are currently supported.
Once completed, move the MicroSD card to one of the Libre Computer boards.

Please type 'continue' without quotes to acknowledge and start the script.

EOF
read -p ":" input
if [ "${input,,}" != "continue" ]; then
	echo "Input ${input} does not match 'continue'. Exiting."
	exit 1
fi

#TODO find root
TARGET_PART=$(findmnt -no SOURCE /)
TARGET_DISK=$(lsblk --list -no type,name --inverse "$TARGET_PART" | grep ^disk | cut -d " " -f 2)

sfdisk_file=$(mktemp)
sfdisk -d "/dev/$TARGET_DISK" > "$sfdisk_file"
sfdisk_label=$(grep -Po "label:\\s+\\K.*" "$sfdisk_file")
if [ -z "$sfdisk_label" ]; then
	echo "disk: error" >&2
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

if [ "${TARGET_OS_RELEASE[ID]}" = "raspbian" -a "${TARGET_OS_RELEASE[VERSION_ID]}" = '"10"' ]; then
	DPKG_ARCH_TARGET=arm64
	grub_install_cmd="grub-install --directory=/usr/lib/grub/arm64-efi --efi-directory=/boot --force-extra-removable --no-nvram"
elif [ "${TARGET_OS_RELEASE[ID]}" = "ubuntu" -a "${TARGET_OS_RELEASE[VERSION_ID]}" = '"22.04"' ]; then
	grub_install_cmd="grub-install --directory=/usr/lib/grub/arm64-efi --efi-directory=/boot/firmware --no-nvram"
	#chmod -x /etc/kernel/postinst.d/zz-flash-kernel
else
	echo "os-release: only Raspbian 10 is supported!" >&2
	exit 1
fi

dpkg_arch=$(dpkg --print-architecture)
if [ -z "$dpkg_arch" ]; then
	echo "dpkg: failed to get architecture" >&2
	exit 1
elif [ "$dpkg_arch" = "armhf" ]; then
	dpkg_arches_foreign=$(dpkg --print-foreign-architectures)
	for dpkg_arch_foreign in $dpkg_arches_foreign; do
		if [ "$dpkg_arch_foreign" = "$DPKG_ARCH_TARGET" ]; then
			break
		fi
	done
	if [ "$dpkg_arch_foreign" != "$DPKG_ARCH_TARGET" ]; then
		dpkg --add-architecture arm64
	fi
	
	apt_sources=$(ls /etc/apt/sources.list /etc/apt/sources.list.d/*.list)
	for apt_source in $apt_sources; do
		sed -Ei "s/^(deb)\\s+(http:\\/\\/)/\\1 [ arch=armhf ] \2/" "$apt_source"
	done
	echo 'deb [ arch=arm64 ] http://deb.debian.org/debian/ buster main' > /etc/apt/sources.list.d/debian-main.list
	
	apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 605C66F00D6C9793
	apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 0E98404D386FA1D9
	apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 648ACFD622F3D138

elif [ "$dpkg_arch" = "arm64" ]; then
	:
else
	echo "dpkg: architecture is not supported" >&2
	exit 1
fi

if [ "${TARGET_OS_RELEASE[ID]}" = "ubuntu" -a "${TARGET_OS_RELEASE[VERSION_ID]}" = '"22.04"' ]; then
	apt -y remove flash-kernel
	if [ -f /boot/firmware/boot.scr ]; then
		rm /boot/firmware/boot.scr
	fi
	dtbs=$(ls /boot/dtb /boot/dtb-* /boot/dtbs)
	if [ ! -z "$dtbs" ]; then
		for dtb in $dtbs; do
			if [ -f "$dtb" -o -L "$dtb" ]; then
				rm "$dtb"
			elif [ -d "$dtb" ]; then
				rm -r "$dtb"
			fi
		done
	fi
fi

KERNEL_HEADER_URL='https://kernel.libre.computer/manual/linux-5.18/linux-header-5.18_arm64.deb'
KERNEL_IMAGE_URL='https://kernel.libre.computer/manual/linux-5.18/linux-image-5.18_arm64.deb'
kernel_dir=$(mktemp -d)
wget -O "$kernel_dir/${KERNEL_HEADER_URL##*/}" "$KERNEL_HEADER_URL"
wget -O "$kernel_dir/${KERNEL_IMAGE_URL##*/}" "$KERNEL_IMAGE_URL"

dpkg -i "$kernel_dir"/*.deb

apt update
#apt -y dist-upgrade
apt -y install grub-efi-arm64
$grub_install_cmd
sed -Ei "s/(GRUB_CMDLINE_LINUX_DEFAULT)=\"quiet/\1=\"noquiet/" /etc/default/grub
update-grub
if [ "${TARGET_OS_RELEASE[ID]}" = "raspbian" ]; then
	mkdir -p /boot/EFI/debian
	cp /boot/EFI/raspbian/grub.cfg /boot/EFI/debian/grub.cfg
fi

BOOT_LOADER_URL='https://boot.libre.computer/manual/u-boot-latest-aml-s905x-cc'
boot_loader_file=$(mktemp)
wget -O "$boot_loader_file" "$BOOT_LOADER_URL"
dd if="$boot_loader_file" of=/dev/"$TARGET_DISK" bs=512 seek=1

tee /etc/X11/xorg.conf <<EOF
Section "Device"
	Identifier "FBTurbo"
	Driver "fbturbo"
	Option "DRI2" "true"
	Option "AccelMethod" "CPU"
EndSection
EOF

read -n 1 -p "Modifications complete. Press any key to shutdown. Once the green LED stops blinking and turns off for 10 seconds, remove power and move the MicroSD card to the Libre Computer board."
shutdown -H now
