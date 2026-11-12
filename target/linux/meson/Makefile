# SPDX-License-Identifier: GPL-2.0-only
#
# Amlogic Meson6 (AML8726-MX), 32-bit. Na razie jedno urządzenie: WeTek Play 1.

include $(TOPDIR)/rules.mk

ARCH:=arm
BOARD:=meson
BOARDNAME:=Amlogic Meson6 (AML8726-MX)
FEATURES:=fpu usb ext4 squashfs boot-part rootfs-part targz
CPU_TYPE:=cortex-a9
CPU_SUBTYPE:=vfpv3-d16
SUBTARGETS:=generic

KERNEL_PATCHVER:=6.12

define Target/Description
	Build firmware images for Amlogic Meson6 based boards.
endef

include $(INCLUDE_DIR)/target.mk

KERNELNAME:=zImage

DEFAULT_PACKAGES += mkf2fs e2fsprogs partx-utils \
	kmod-usb-dwc2 kmod-usb-storage kmod-fs-vfat

$(eval $(call BuildTarget))
