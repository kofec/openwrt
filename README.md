# OpenWrt 25.12 for the WeTek Play 1 (fork)

This is a personal fork of [OpenWrt](https://github.com/openwrt/openwrt).
This branch, `wetek-play-25.12`, is upstream `openwrt-25.12` plus a new
`meson` target for the first **WeTek Play** set-top box (Amlogic Meson6 /
AML8726-MX). The default branch of this repository,
[`openwrt-19.07`](https://github.com/kofec/openwrt/tree/openwrt-19.07),
is unrelated: it keeps OpenWrt 19.07 alive for 4/32 MB TP-Link routers.

The aim is to give the box a second life as a small home server
(Docker, Domoticz, NFS) instead of the Android it shipped with; the HDMI
output, CEC, HDMI audio and the Mali GPU work as well. It is not an official OpenWrt target and has not been sent
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
- HDMI output: DRM/KMS (`meson-drm` with the TranSwitch HDMI transmitter),
  EDID, framebuffer console at 1080p60 (480p/576p, 720p/1080i and 1080p
  modes only, like the vendor kernel)
- HDMI CEC (`/dev/cec0`): tested with a Sony TV (power status, OSD name,
  Image View On, Standby — the TV only accepts Standby after Active Source)
- audio over HDMI (ALSA card `WETEK-PLAY`, PCM device 1)

Added, still being verified:

- Bluetooth on the AP6210 (`hci_bcm`)
- Ethernet MAC from the efuse instead of the U-Boot command line
- 1416 and 1512 MHz as boost frequencies
- analog audio (I2S to the external DAC, PCM device 0) and the optical
  S/PDIF output: play fine, not listened to yet

- Mali-400 MP2 GPU through `lima` and Mesa (`libmesa-lima` and `kmscube`
  from the `video` feed as packages): `kmscube` runs at ~60 fps with
  cpufreq active. The OSD plane has no
  XRGB8888, use `kmscube -f AR24 -D /dev/dri/card1` (lima is `card0`).

Not supported: video decoding, NAND.

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
| `110`–`121` | Meson8/8b/8m2 display support in drm/meson by Martin Blumenstingl (VPU, TranSwitch HDMI transmitter), from [xdarklight/linux](https://github.com/xdarklight/linux) `meson-mx-integration-6.13-20250112`, as they are (the 24 bpp framebuffer patch is already in 6.12, the Meson8b PHY limits are left out, `meson_vpu_init` is folded into `122`) |
| `122`–`124` | port of the above to 6.12 (VCLK in Hz, HDMI audio bridge hooks disabled), `TX_HDMI_PHY_CONFIG1` offset fix |
| `125-clk-meson-meson6-add-the-video-clocks.patch` | Meson6 video clock tree: video PLL (bit 30 is power-down), VCLK, VENC/HDMI gates, video divider resets |
| `126-drm-meson-add-Meson6-AML8726-MX-support.patch` | Meson6 VPU (registers in CBUS), 8-bit OSD alpha, HDMI PHY in the transmitter registers, inverted TMDS resets |
| `127-drm-meson-transwitch-hdmi-add-the-Meson6-CEC-control.patch` | CEC: the GX AO-CEC controller, but inside the HDMI TX register space |
| `128-clk-meson-meson6-add-the-audio-clocks.patch` | MPLL0/1/2 and the audio master clock |
| `129-ASoC-meson-aiu-support-Meson6.patch` | AIU without FIFO interrupts (polled), AIU HDMI clock for the transmitter |
| `130-drm-meson-transwitch-hdmi-HDMI-audio-through-hdmi-co.patch` | HDMI audio through `hdmi-codec`; on Meson6 only the S/PDIF input of the transmitter works |
| `131-clk-meson-meson6-add-the-Mali-clock.patch` | Mali clock (`HHI_MALI_CLK_CNTL`), 333 MHz from `fclk_div3` like the vendor kernel |
| `132-clk-meson-meson6-park-the-other-core-while-switching.patch` | the other core is parked while the CPU clock is switched, as the vendor kernel does; without it the box locks up when cpufreq changes the CPU rate while the GPU is busy |
| `133-drm-lima-run-the-Meson6-power-on-GP-job.patch` | the vendor power-on GP job (Mali-400 rev B); without it every GP job hangs |
| `134-drm-lima-poll-the-PP-MMUs-on-Meson6.patch` | the PP MMU interrupts do not reach the GIC on Meson6, poll them like the vendor driver |

Target `target/linux/meson`:

- device tree `meson6-wetek-play.dts` (pin muxing via `pinctrl-single`,
  GPIO via `gpio-mmio`, regulators, LEDs, IR, efuse, thermal zone, OPPs,
  VPU/HDMI/CEC, sound card with I2S, S/PDIF and HDMI, Mali GPU)
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
