#!/bin/bash

set -ex

if [ "$USER" != "root" ]; then
	echo "Please run this as root." >&2
	echo "sudo $0 $@" >&2
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
elif [ "$sfdisk_dev_p1_start" -lt "" ]; then
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

if [ "${TARGET_OS_RELEASE[ID]}" != "raspbian" ]; then
	echo "os-release: installed distro is not Raspbian!" >&2
	exit 1
elif [ "${TARGET_OS_RELEASE[VERSION_ID]}" != '"10"' ]; then
	echo "os-release: only Raspbian 10 is supported!" >&2
	exit 1
fi

DPKG_ARCH_TARGET=arm64
dpkg_arch=$(dpkg --print-architecture)
if [ -z "$dpkg_arch" ]; then
	echo "dpkg: failed to get architecture" >&2
	exit 1
elif [ "$dpkg_arch" != "armhf" ]; then
	echo "dpkg: architecture is not supported" >&2
	exit 1
fi

dpkg_arches_foreign=$(dpkg --print-foreign-architectures)
for dpkg_arch_foreign in $dpkg_arches_foreign; do
	if [ "$dpkg_arch_foreign" = "$DPKG_ARCH_TARGET" ]; then
		break
	fi
done
if [ "$dpkg_arch_foreign" != "$DPKG_ARCH_TARGET" ]; then
	dpkg --add-architecture arm64
fi

KERNEL_HEADER_URL='https://kernel.libre.computer/manual/linux-5.18/linux-header-5.18_arm64.deb'
KERNEL_IMAGE_URL='https://kernel.libre.computer/manual/linux-5.18/linux-image-5.18_arm64.deb'
kernel_dir=$(mktemp -d)
wget -O "$kernel_dir/${KERNEL_HEADER_URL##*/}" "$KERNEL_HEADER_URL"
wget -O "$kernel_dir/${KERNEL_IMAGE_URL##*/}" "$KERNEL_IMAGE_URL"

dpkg -i "$kernel_dir"/*.deb

apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 605C66F00D6C9793
apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 0E98404D386FA1D9
apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 648ACFD622F3D138

apt_sources=$(ls /etc/apt/sources.list /etc/apt/sources.list.d/*.list)
for apt_source in $apt_sources; do
	sed -Ei "s/^(deb)\\s+(http:\\/\\/)/\\1 [ arch=armhf ] \2/" "$apt_source"
done
echo 'deb [ arch=arm64 ] http://deb.debian.org/debian/ buster main' > /etc/apt/sources.list.d/debian-main.list

apt update
#apt -y dist-upgrade
apt -y install grub-efi-arm64
grub-install --directory=/usr/lib/grub/arm64-efi --efi-directory=/boot --force-extra-removable --no-nvram
sed -Ei "s/(GRUB_CMDLINE_LINUX_DEFAULT)=\"quiet/\1=\"noquiet/" /etc/default/grub
update-grub
mkdir -p /boot/EFI/debian
cp /boot/EFI/raspbian/grub.cfg /boot/EFI/debian/grub.cfg

BOOT_LOADER_URL='https://boot.libre.computer/manual/u-boot-latest-aml-s905x-cc'
boot_loader_file=$(mktemp)
wget -O "$boot_loader_file" "$BOOT_LOADER_URL"
dd if="$boot_loader_file" of=/dev/"$TARGET_DISK" bs=512 seek=1

