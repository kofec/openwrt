# OpenWrt 19.07 for 4/32 MB devices (fork)

This is a personal fork of [OpenWrt](https://github.com/openwrt/openwrt).
Branches:

| Branch | Based on | What it is |
|---|---|---|
| `openwrt-19.07` (this one, default) | upstream `openwrt-19.07` | 19.07 kept buildable for old 4 MB flash / 32 MB RAM routers |
| [`wetek-play-25.12`](https://github.com/kofec/openwrt/tree/wetek-play-25.12) | upstream `openwrt-25.12` | new `meson` target for the WeTek Play 1 (Amlogic Meson6) |

OpenWrt 19.07 is end of life. Newer releases no longer fit the 4/32 MB
TP-Link boards (TL-WR740N, TL-WR741ND, TL-WR841N) that are still in use
here, so this branch keeps 19.07 alive for them with a few backports and
one tested package profile per model. It is not an official OpenWrt
release and gets no security support beyond what is listed below.

The starting point was [T-X/openwrt](https://github.com/T-X/openwrt)
(upstream `openwrt-19.07` plus a kernel bump to 4.14.327), which is why
GitHub shows that repository as the parent of this fork.

## Changes against upstream openwrt-19.07

Kernel and packages:

- Linux 4.14.336, the last 4.14 release (the generic and ath79 patches
  refreshed).
- WireGuard: `wireguard-linux-compat` 1.0.20220627.
- vxlan: updated `vxlan.sh` protocol handler.
- odhcpd: 2021-07-18 snapshot, used as the DHCP server instead of dnsmasq.
- hostapd: new option `CONFIG_WPA_WNM_AP` builds 802.11v (WNM) into the
  `basic` variant, so `wpad-basic` gets `bss_transition` and the ubus
  method `wnm_disassoc_imminent` for client steering (+8 KB squashfs).
- Build option "Use preinit IP configuration as default LAN IP",
  backported from 23.05, plus a fix so that 19.07 actually runs the
  generated `/etc/board.d/99-lan-ip`.
- Host tools: CMake 3.17.0.

Build setup:

- [BUILD-19.07.md](BUILD-19.07.md) - how to build, profile table, space
  saving tricks, how to check the remaining overlay.
- [Containerfile-alpine](Containerfile-alpine) - Alpine 3.12 build
  container, since current distributions no longer ship a host toolchain
  that builds 19.07.
- `diffconfig_<model>_1907[_vxlan|_bonding]` - one profile per model: LuCI
  with statistics, WireGuard, relayd, odhcpd, travelmate, Wake-on-LAN, no
  IPv6, no firewall, no opkg, default LAN 192.168.2.1. About 384 KiB of
  overlay is left (320 KiB with bonding).

Feeds ([feeds.conf.default](feeds.conf.default)):

| Feed | Repository | Changes against upstream |
|---|---|---|
| packages | [kofec/packages_1907](https://github.com/kofec/packages_1907) | newer watchcat (with its UCI migration), collectd without unused `libip4tc`/`libltdl`, travelmate without the captive portal loop when dnsmasq is missing, minimal Domoticz build |
| luci | [kofec/luci_1907](https://github.com/kofec/luci_1907) | vxlan, JavaScript watchcat and statistics |
| routing | upstream `openwrt-19.07` | none |

## Quick start

```sh
git clone -b openwrt-19.07 https://github.com/kofec/openwrt.git openwrt-19.07
cd openwrt-19.07
./scripts/feeds update -a && ./scripts/feeds install -a
docker build -t openwrt:alpine -f Containerfile-alpine .
docker run --rm --ulimit 'nofile=1024:262144' -v "$(pwd):/workdir" -w /workdir \
  openwrt:alpine sh -c 'cp diffconfig_wr741ndv1_1907 .config && make defconfig && make -j"$(nproc)"'
```

Details and the full profile list are in [BUILD-19.07.md](BUILD-19.07.md).

## Original OpenWrt README

```
  _______                     ________        __
 |       |.-----.-----.-----.|  |  |  |.----.|  |_
 |   -   ||  _  |  -__|     ||  |  |  ||   _||   _|
 |_______||   __|_____|__|__||________||__|  |____|
          |__| W I R E L E S S   F R E E D O M
 -----------------------------------------------------

This is the buildsystem for the OpenWrt Linux distribution.

To build your own firmware you need a Linux, BSD or MacOSX system (case
sensitive filesystem required). Cygwin is unsupported because of the lack
of a case sensitive file system.

You need gcc, binutils, bzip2, flex, python, perl, make, find, grep, diff,
unzip, gawk, getopt, subversion, libz-dev and libc headers installed.

1. Run "./scripts/feeds update -a" to obtain all the latest package definitions
defined in feeds.conf / feeds.conf.default

2. Run "./scripts/feeds install -a" to install symlinks for all obtained
packages into package/feeds/

3. Run "make menuconfig" to select your preferred configuration for the
toolchain, target system & firmware packages.

4. Run "make" to build your firmware. This will download all sources, build
the cross-compile toolchain and then cross-compile the Linux kernel & all
chosen applications for your target system.

Sunshine!
	Your OpenWrt Community
	http://www.openwrt.org
```
