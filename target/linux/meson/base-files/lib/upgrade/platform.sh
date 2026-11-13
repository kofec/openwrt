# SPDX-License-Identifier: GPL-2.0-only
#
# Sysupgrade z karty SD (WeTek Play): obraz jest całą kartą (MBR, p1 FAT
# z kernel.img dla U-Boota, p2 squashfs + nakładka). Na wzór bcm27xx i x86.

. /lib/functions.sh

REQUIRE_IMAGE_METADATA=1

# Tylko obraz całej karty: MBR z dwiema partycjami. Bez tego get_partitions
# zwraca pustą mapę i zapis „partycja po partycji” nic by nie zapisał.
meson_check_image_layout() {
	local magic

	get_image "$1" | dd of=/tmp/image.bs count=1 bs=512 2>/dev/null
	magic="$(dd if=/tmp/image.bs bs=2 count=1 skip=255 2>/dev/null | hexdump -v -n 2 -e '1/1 "%02x"')"
	if [ "$magic" != "55aa" ]; then
		echo "Image is not a whole SD card image (no MBR)"
		return 1
	fi

	get_partitions /tmp/image.bs image
	if ! grep -q '^ 1 ' /tmp/partmap.image || ! grep -q '^ 2 ' /tmp/partmap.image; then
		echo "Image has no boot and rootfs partitions"
		return 1
	fi

	return 0
}

platform_check_image() {
	local diskdev diff

	[ "$#" -gt 1 ] && return 1

	export_bootdevice && export_partdevice diskdev 0 || {
		echo "Unable to determine upgrade device"
		return 1
	}

	meson_check_image_layout "$1" || {
		rm -f /tmp/image.bs /tmp/partmap.image
		return 74
	}

	get_partitions "/dev/$diskdev" bootdisk

	diff="$(grep -F -x -v -f /tmp/partmap.bootdisk /tmp/partmap.image)"

	rm -f /tmp/image.bs /tmp/partmap.bootdisk /tmp/partmap.image

	if [ -n "$diff" ]; then
		echo "Partition layout has changed. Full image will be written."
		ask_bool 0 "Abort" && exit 1
		return 0
	fi

	return 0
}

# fstools trzyma nakładkę za squashfs, na pierwszej granicy 64 KiB. Obraz kończy
# się na squashfs, więc stara nakładka (f2fs) zostaje na karcie; gdyby nowy
# squashfs wypadł na tej samej granicy, system wstałby ze starą nakładką.
# Zerujemy 2 MiB za nowym squashfs, wtedy mount_root formatuje ją od nowa.
meson_wipe_old_overlay() {
	local partdev size

	export_partdevice partdev 2 || return 0
	[ "$(dd if="/dev/$partdev" bs=4 count=1 2>/dev/null)" = "hsqs" ] || return 0

	set -- $(dd if="/dev/$partdev" bs=1 skip=40 count=4 2>/dev/null | hexdump -v -e '4/1 "%02x "')
	[ $# -eq 4 ] || return 0
	size=$((0x$4$3$2$1))
	size=$(( (size + 4095) / 4096 ))

	echo "Clearing old overlay on /dev/$partdev..."
	dd if=/dev/zero of="/dev/$partdev" bs=4096 seek="$size" count=512 conv=fsync 2>/dev/null
}

platform_do_upgrade() {
	local diskdev partdev diff

	export_bootdevice && export_partdevice diskdev 0 || {
		echo "Unable to determine upgrade device"
		return 1
	}

	sync

	if [ "$UPGRADE_OPT_SAVE_PARTITIONS" = "1" ]; then
		get_partitions "/dev/$diskdev" bootdisk

		get_image "$@" | dd of=/tmp/image.bs count=1 bs=512b

		get_partitions /tmp/image.bs image

		diff="$(grep -F -x -v -f /tmp/partmap.bootdisk /tmp/partmap.image)"
	else
		diff=1
	fi

	if [ -n "$diff" ]; then
		get_image "$@" | dd of="/dev/$diskdev" bs=2M conv=fsync

		# osobno usunięcie i dodanie, inaczej p1 zniknie, gdy nachodzi na starą p2
		partx -d - "/dev/$diskdev"
		partx -a - "/dev/$diskdev"

		meson_wipe_old_overlay
		return 0
	fi

	while read part start size; do
		if export_partdevice partdev $part; then
			echo "Writing image to /dev/$partdev..."
			get_image "$@" | dd of="/dev/$partdev" ibs="512" obs=1M skip="$start" count="$size" conv=fsync
		else
			echo "Unable to find partition $part device, skipped."
		fi
	done < /tmp/partmap.image

	echo "Writing new UUID to /dev/$diskdev..."
	get_image "$@" | dd of="/dev/$diskdev" bs=1 skip=440 count=4 seek=440 conv=fsync

	meson_wipe_old_overlay
}

# Kopia konfiguracji na partycję FAT; przy starcie zabiera ją 79_move_config.
platform_copy_config() {
	local partdev

	export_partdevice partdev 1 || return 0

	mkdir -p /tmp/meson_boot
	mount -t vfat -o rw,noatime "/dev/$partdev" /tmp/meson_boot || return 0
	cp -af "$UPGRADE_BACKUP" "/tmp/meson_boot/$BACKUP_FILE"
	sync
	umount /tmp/meson_boot
}
