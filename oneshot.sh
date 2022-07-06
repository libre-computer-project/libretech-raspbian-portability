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
