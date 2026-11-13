# OpenWrt 25.12 for the WeTek Play 1 (fork)

This is a personal fork of [OpenWrt](https://github.com/openwrt/openwrt).
This branch, `wetek-play-25.12`, is upstream `openwrt-25.12` plus a new
`meson` target for the first **WeTek Play** set-top box (Amlogic Meson6 /
AML8726-MX). The default branch of this repository,
[`openwrt-19.07`](https://github.com/kofec/openwrt/tree/openwrt-19.07),
is unrelated: it keeps OpenWrt 19.07 alive for 4/32 MB TP-Link routers.

The aim is to give the box a second life as a small headless home
server (Docker, Domoticz, NFS) instead of the Android it shipped
with. It is not an official OpenWrt target and has not been sent
upstream.

## Hardware

- SoC Amlogic AML8726-MX (Meson6): 2x Cortex-A9, up to 1.5 GHz
- 1 GB RAM, 4 GB NAND (not used), 4 MB SPI NOR with the vendor U-Boot
- 100 Mbit Ethernet (SMSC LAN8720 PHY)
- AP6210 module: BCM43362 Wi-Fi on SDIO, BCM20710 Bluetooth on UART
- SD card slot, two USB host ports (one behind an internal hub), IR
  receiver, three LEDs

## How it boots

The vendor U-Boot in the SPI NOR loads `kernel.img` (uImage with the DTB
appended) from the first FAT partition of the SD card. The image is
therefore an SD card image: FAT with the kernel, then the squashfs root
with an f2fs overlay. Nothing is written to the NAND or the SPI NOR;
remove the card and the box starts the original Android again.

## Status

Working on the hardware:

- serial console (`ttyAML0`), Ethernet, SD card
- Wi-Fi (`brcmfmac`)
- USB host on both ports, VBUS switched by GPIO
- both CPU cores, CPU frequency and core voltage scaling, SoC temperature
  with CPU cooling
- front LEDs (Wi-Fi, Ethernet) and the two-colour power LED
- IR receiver (`rc-core`, common protocols built in)
- efuse readable through nvmem
- sysupgrade (whole card or partition by partition, configuration kept)
- Docker, with its data on the overlay

Added, still being verified:

- Bluetooth on the AP6210 (`hci_bcm`)
- Ethernet MAC from the efuse instead of the U-Boot command line
- 1416 and 1512 MHz as boost frequencies

Not supported: HDMI output and video decoding, audio, NAND.

## What this branch adds

Kernel patches in `target/linux/meson/patches-6.12/` (Linux 6.12; the
Meson6 device tree is removed upstream from 6.13 on):

| Patch | What |
|---|---|
| `100-phy-meson8b-usb2-add-meson6.patch` | USB2 PHY: Meson6 needs its reference clock enabled |
| `101-ARM-meson-add-meson6-smp.patch` | SMP bring-up of the second core |
| `102-mmc-meson-mx-sdio-multiple-slots.patch` | one SDIO controller, two slots (SD card and Wi-Fi), plus a timeout race fix |
| `103-clk-meson-add-meson6-clkc.patch` | clock controller: gates, CPU clock, system PLL reprogramming, 32 kHz clock for Wi-Fi |
| `104-iio-adc-meson-saradc-add-meson6.patch` | SAR ADC with the SoC temperature sensor |
| `105-regulator-pwm-regulator-init-microvolt.patch` | defined start voltage for the PWM CPU regulator |

Target `target/linux/meson`:

- device tree `meson6-wetek-play.dts` (pin muxing via `pinctrl-single`,
  GPIO via `gpio-mmio`, regulators, LEDs, IR, efuse, thermal zone, OPPs)
- SD card image (`sdcard.img.gz`) and `sysupgrade.img.gz` with metadata,
  `platform.sh` for sysupgrade that keeps the configuration backup on the
  FAT partition
- network defaults for a box plugged into an existing LAN: `eth0` is a
  DHCP client, no DHCP server, no failsafe IP in preinit
- Ethernet MAC set in preinit, Wi-Fi NVRAM for the AP6210

## Build

```sh
git clone -b wetek-play-25.12 https://github.com/kofec/openwrt.git openwrt-wetek
cd openwrt-wetek
./scripts/feeds update -a && ./scripts/feeds install -a
cat > .config <<'EOF'
CONFIG_TARGET_meson=y
CONFIG_TARGET_meson_generic=y
CONFIG_TARGET_meson_generic_DEVICE_wetek_play=y
EOF
make defconfig
make -j"$(nproc)"
```

Images land in `bin/targets/meson/generic/`. Write
`openwrt-meson-generic-wetek_play-squashfs-sdcard.img.gz` to an SD card
(`gunzip -c ... | dd of=/dev/sdX bs=4M`), insert it and power the box on.
Later updates go through `sysupgrade` with the `sysupgrade.img.gz` image.

## Original OpenWrt README

![OpenWrt logo](include/logo.png)

OpenWrt Project is a Linux operating system targeting embedded devices. Instead
of trying to create a single, static firmware, OpenWrt provides a fully
writable filesystem with package management. This frees you from the
application selection and configuration provided by the vendor and allows you
to customize the device through the use of packages to suit any application.
For developers, OpenWrt is the framework to build an application without having
to build a complete firmware around it; for users this means the ability for
full customization, to use the device in ways never envisioned.

Sunshine!

## Download

Built firmware images are available for many architectures and come with a
package selection to be used as WiFi home router. To quickly find a factory
image usable to migrate from a vendor stock firmware to OpenWrt, try the
*Firmware Selector*.

* [OpenWrt Firmware Selector](https://firmware-selector.openwrt.org/)

If your device is supported, please follow the **Info** link to see install
instructions or consult the support resources listed below.

## 

An advanced user may require additional or specific package. (Toolchain, SDK, ...) For everything else than simple firmware download, try the wiki download page:

* [OpenWrt Wiki Download](https://openwrt.org/downloads)

## Development

To build your own firmware you need a GNU/Linux, BSD or macOS system (case
sensitive filesystem required). Cygwin is unsupported because of the lack of a
case sensitive file system.

### Requirements

You need the following tools to compile OpenWrt, the package names vary between
distributions. A complete list with distribution specific packages is found in
the [Build System Setup](https://openwrt.org/docs/guide-developer/build-system/install-buildsystem)
documentation.

```
binutils bzip2 diff find flex gawk gcc-6+ getopt grep install libc-dev libz-dev
make4.1+ perl python3.7+ rsync subversion unzip which
```

### Quickstart

1. Run `./scripts/feeds update -a` to obtain all the latest package definitions
   defined in feeds.conf / feeds.conf.default

2. Run `./scripts/feeds install -a` to install symlinks for all obtained
   packages into package/feeds/

3. Run `make menuconfig` to select your preferred configuration for the
   toolchain, target system & firmware packages.

4. Run `make` to build your firmware. This will download all sources, build the
   cross-compile toolchain and then cross-compile the GNU/Linux kernel & all chosen
   applications for your target system.

### Related Repositories

The main repository uses multiple sub-repositories to manage packages of
different categories. All packages are installed via the OpenWrt package
manager called `opkg`. If you're looking to develop the web interface or port
packages to OpenWrt, please find the fitting repository below.

* [LuCI Web Interface](https://github.com/openwrt/luci): Modern and modular
  interface to control the device via a web browser.

* [OpenWrt Packages](https://github.com/openwrt/packages): Community repository
  of ported packages.

* [OpenWrt Routing](https://github.com/openwrt/routing): Packages specifically
  focused on (mesh) routing.

* [OpenWrt Video](https://github.com/openwrt/video): Packages specifically
  focused on display servers and clients (Xorg and Wayland).

## Support Information

For a list of supported devices see the [OpenWrt Hardware Database](https://openwrt.org/supported_devices)

### Documentation

* [Quick Start Guide](https://openwrt.org/docs/guide-quick-start/start)
* [User Guide](https://openwrt.org/docs/guide-user/start)
* [Developer Documentation](https://openwrt.org/docs/guide-developer/start)
* [Technical Reference](https://openwrt.org/docs/techref/start)

### Support Community

* [Forum](https://forum.openwrt.org): For usage, projects, discussions and hardware advise.
* [Support Chat](https://webchat.oftc.net/#openwrt): Channel `#openwrt` on **oftc.net**.

### Developer Community

* [Bug Reports](https://bugs.openwrt.org): Report bugs in OpenWrt
* [Dev Mailing List](https://lists.openwrt.org/mailman/listinfo/openwrt-devel): Send patches
* [Dev Chat](https://webchat.oftc.net/#openwrt-devel): Channel `#openwrt-devel` on **oftc.net**.

## License

OpenWrt is licensed under GPL-2.0
