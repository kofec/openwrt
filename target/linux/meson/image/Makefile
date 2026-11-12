# SPDX-License-Identifier: GPL-2.0-only

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/image.mk

FAT32_BLOCK_SIZE=1024
FAT32_BLOCKS=$(shell echo $$(($(CONFIG_TARGET_KERNEL_PARTSIZE)*1024*1024/$(FAT32_BLOCK_SIZE))))

# Vendorski U-Boot (w SPI NOR) szuka na pierwszej partycji FAT karty pliku
# kernel.img i ładuje go pod 0x82000000: uImage z doklejonym DTB.
define Build/meson-sdcard
	rm -f $@.boot
	mkfs.fat $@.boot -C $(FAT32_BLOCKS)
	mcopy -i $@.boot $(IMAGE_KERNEL) ::kernel.img
	./gen_meson_sdcard_img.sh $@ \
		$@.boot \
		$(IMAGE_ROOTFS) \
		$(CONFIG_TARGET_KERNEL_PARTSIZE) \
		$(CONFIG_TARGET_ROOTFS_PARTSIZE)
	rm -f $@.boot
endef

define Device/Default
	PROFILES := Default
	DTS_DIR := $(DTS_DIR)/amlogic
	KERNEL_DEPENDS = $$(wildcard $(DTS_DIR)/$$(DEVICE_DTS).dts)
	KERNEL_LOADADDR := 0x80008000
	KERNEL_NAME := zImage
	KERNEL := kernel-bin | append-dtb | uImage none
	IMAGES := sdcard.img.gz
	IMAGE/sdcard.img.gz := meson-sdcard | gzip
endef

define Device/wetek_play
	DEVICE_VENDOR := WeTek
	DEVICE_MODEL := Play
	DEVICE_DTS := meson6-wetek-play
	DEVICE_PACKAGES := kmod-brcmfmac cypress-firmware-43362-sdio \
		wpad-basic-mbedtls iw
endef
TARGET_DEVICES += wetek_play

$(eval $(call BuildImage))
