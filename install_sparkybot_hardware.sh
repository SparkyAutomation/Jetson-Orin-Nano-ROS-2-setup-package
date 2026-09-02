#!/usr/bin/env bash
# Install SparkyBot/Yahboom CH340/CH341 serial support on Jetson Orin Nano.
# Designed for NVIDIA Jetson Linux kernels where CONFIG_USB_SERIAL_CH341 is disabled.

set -Eeuo pipefail
IFS=$'\n\t'

log() { printf '\n\033[1;34m[sparkybot-hw]\033[0m %s\n' "$*"; }
warn() { printf '\n\033[1;33m[warning]\033[0m %s\n' "$*" >&2; }
fail() { printf '\n\033[1;31m[error]\033[0m %s\n' "$*" >&2; exit 1; }

[[ ${EUID} -ne 0 ]] || fail "Run this script as a normal user, not as root."
command -v sudo >/dev/null 2>&1 || fail "sudo is required."
command -v curl >/dev/null 2>&1 || fail "curl is required."

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
KERNEL_RELEASE="$(uname -r)"
KERNEL_BASE="${KERNEL_RELEASE%%-*}"
KERNEL_BUILD="/lib/modules/${KERNEL_RELEASE}/build"
MODULE_DIR="/lib/modules/${KERNEL_RELEASE}/kernel/drivers/usb/serial"
BUILD_DIR="${HOME}/.cache/sparkybot/ch341-${KERNEL_RELEASE}"
CH341_SOURCE_URL="https://raw.githubusercontent.com/gregkh/linux/v${KERNEL_BASE}/drivers/usb/serial/ch341.c"
CURRENT_USER="${SUDO_USER:-${USER:-$(id -un)}}"

log "Kernel: ${KERNEL_RELEASE}"

sudo -v

log "Installing build prerequisites"
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
  build-essential bc flex bison libssl-dev zstd curl usbutils

if getent group dialout >/dev/null 2>&1; then
  sudo usermod -aG dialout "$CURRENT_USER"
else
  warn "dialout group does not exist."
fi

# First handle kernels that already provide CH341 support.
if zgrep -q '^CONFIG_USB_SERIAL_CH341=y' /proc/config.gz 2>/dev/null; then
  log "CH341 support is built into the running kernel; no external module is required."
elif modinfo ch341 >/dev/null 2>&1; then
  log "CH341 module is already installed."
  sudo modprobe ch341 || fail "The existing ch341 module could not be loaded."
else
  log "CH341 module is not available; building it for ${KERNEL_RELEASE}"

  [[ -d "$KERNEL_BUILD" ]] || fail "Matching kernel headers are missing at ${KERNEL_BUILD}. Install nvidia-l4t-kernel-headers first."
  [[ -f "${KERNEL_BUILD}/Makefile" ]] || fail "Kernel build directory is not usable: ${KERNEL_BUILD}"

  if [[ ! -f "${KERNEL_BUILD}/Module.symvers" ]]; then
    warn "${KERNEL_BUILD}/Module.symvers is missing. CONFIG_MODVERSIONS kernels may reject the module."
  fi

  mkdir -p "$BUILD_DIR"

  log "Downloading Linux ${KERNEL_BASE} CH341 driver source"
  curl -fL --retry 3 --connect-timeout 20 \
    "$CH341_SOURCE_URL" \
    -o "${BUILD_DIR}/ch341.c" \
    || fail "Could not download ${CH341_SOURCE_URL}. The Jetson kernel may require a different matching source revision."

  cat > "${BUILD_DIR}/Makefile" <<'MAKEFILE'
obj-m += ch341.o
KDIR ?= /lib/modules/$(shell uname -r)/build
PWD := $(shell pwd)

all:
	$(MAKE) -C $(KDIR) M=$(PWD) modules

clean:
	$(MAKE) -C $(KDIR) M=$(PWD) clean
MAKEFILE

  log "Building ch341.ko"
  make -C "$BUILD_DIR" clean >/dev/null 2>&1 || true
  make -C "$BUILD_DIR"
  [[ -f "${BUILD_DIR}/ch341.ko" ]] || fail "Build completed without producing ch341.ko."

  log "Checking module version compatibility"
  BUILT_VERMAGIC="$(modinfo -F vermagic "${BUILD_DIR}/ch341.ko" 2>/dev/null || true)"
  printf '  Built module vermagic: %s\n' "${BUILT_VERMAGIC:-unknown}"
  printf '  Running kernel:        %s\n' "$KERNEL_RELEASE"

  sudo mkdir -p "$MODULE_DIR"
  sudo install -m 0644 "${BUILD_DIR}/ch341.ko" "${MODULE_DIR}/ch341.ko"
  sudo depmod -a
  sudo modprobe usbserial

  if ! sudo modprobe ch341; then
    sudo dmesg | tail -40 || true
    fail "ch341.ko was installed but the kernel rejected it. Do not force-load it; rebuild from the exact NVIDIA kernel source for ${KERNEL_RELEASE}."
  fi

  echo ch341 | sudo tee /etc/modules-load.d/ch341.conf >/dev/null
  log "CH341 module installed and configured to load at boot."
fi

log "Installing persistent /dev/sparkybot udev rule"
[[ -f "${SCRIPT_DIR}/udev/99-sparkybot.rules" ]] || fail "Missing udev/99-sparkybot.rules in repository."
sudo install -m 0644 "${SCRIPT_DIR}/udev/99-sparkybot.rules" /etc/udev/rules.d/99-sparkybot.rules
sudo udevadm control --reload-rules
sudo udevadm trigger --subsystem-match=tty || true

log "Verification"
if lsmod | grep -q '^ch341 '; then
  printf '  [PASS] ch341 module is loaded\n'
elif zgrep -q '^CONFIG_USB_SERIAL_CH341=y' /proc/config.gz 2>/dev/null; then
  printf '  [PASS] CH341 support is built into the kernel\n'
else
  warn "CH341 support is installed but not currently shown as loaded."
fi

if lsusb -d 1a86:7523 >/dev/null 2>&1; then
  printf '  [PASS] CH340/CH341 USB device 1a86:7523 detected\n'
else
  printf '  [INFO] No 1a86:7523 controller is currently connected\n'
fi

if compgen -G '/dev/ttyUSB*' >/dev/null; then
  printf '  [PASS] USB serial device(s): %s\n' "$(printf '%s ' /dev/ttyUSB*)"
else
  printf '  [INFO] No /dev/ttyUSB* device is currently present\n'
fi

if [[ -e /dev/sparkybot ]]; then
  printf '  [PASS] Persistent robot alias: /dev/sparkybot -> %s\n' "$(readlink -f /dev/sparkybot)"
else
  printf '  [INFO] /dev/sparkybot will appear when the matching controller is connected/replugged\n'
fi

cat <<'SUMMARY'

SparkyBot hardware provisioning complete.

For a connected controller, verify with:
  lsusb -d 1a86:7523
  ls -l /dev/ttyUSB*
  ls -l /dev/sparkybot

A logout/login may be required before new dialout group membership takes effect.
Use /dev/sparkybot as the serial port in robot applications and ROS 2 configuration.
SUMMARY
