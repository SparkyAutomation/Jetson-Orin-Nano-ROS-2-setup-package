# SparkyBot hardware provisioning

This repository can provision a fresh Jetson Orin Nano for ROS 2 development and configure the Yahboom/SparkyBot controller that uses the QinHeng CH340/CH341 USB-UART device (`1a86:7523`).

## One-command setup

```bash
git clone https://github.com/SparkyAutomation/Jetson-Orin-Nano-ROS-2-setup-package.git
cd Jetson-Orin-Nano-ROS-2-setup-package
chmod +x install_all.sh install_jetson_ros2.sh install_sparkybot_hardware.sh
./install_all.sh
sudo reboot
```

After reboot, reconnect the controller if needed and verify:

```bash
python3 verify_sparkybot.py
ls -l /dev/sparkybot
```

Use `/dev/sparkybot` instead of `/dev/ttyUSB0` in robot code and ROS 2 parameters.

## What the hardware installer does

`install_sparkybot_hardware.sh`:

1. Detects the running Jetson kernel.
2. Uses existing CH341 kernel support when available.
3. If the CH341 module is absent, verifies that matching kernel headers exist.
4. Downloads the upstream stable Linux CH341 driver source matching the base kernel version.
5. Builds `ch341.ko` against `/lib/modules/$(uname -r)/build`.
6. Installs the module under the running kernel's module tree.
7. Runs `depmod`, loads `usbserial` and `ch341`, and configures CH341 to load at boot.
8. Adds the current user to `dialout`.
9. Installs a udev rule that creates `/dev/sparkybot` for USB VID/PID `1a86:7523`.

## Current Jetson 7.2 case

On the tested Jetson Orin Nano configuration, the controller is visible in `lsusb` as:

```text
1a86:7523 QinHeng Electronics CH340 serial converter
```

but the NVIDIA kernel may report:

```text
# CONFIG_USB_SERIAL_CH341 is not set
```

In that case the hardware installer builds and installs the missing CH341 module automatically.

## Verify the kernel module manually

```bash
modinfo ch341
lsmod | grep ch341
lsusb -d 1a86:7523
ls -l /dev/ttyUSB*
ls -l /dev/sparkybot
```

## Persistent serial naming

The installed udev rule is:

```text
SUBSYSTEM=="tty", ATTRS{idVendor}=="1a86", ATTRS{idProduct}=="7523", SYMLINK+="sparkybot", GROUP="dialout", MODE="0660"
```

This prevents robot code from depending on USB enumeration order such as `/dev/ttyUSB0` versus `/dev/ttyUSB1`.

### Multiple CH340 devices

`1a86:7523` is a common VID/PID. If the robot later has multiple CH340-based devices, refine the rule using a unique serial number or physical USB path. Inspect attributes with:

```bash
udevadm info --attribute-walk --name=/dev/ttyUSB0
```

Then create deterministic aliases such as `/dev/sparkybot`, `/dev/gps`, and `/dev/lidar`.

## Kernel updates

The module is installed for the currently running kernel. If NVIDIA installs a new kernel release, rerun:

```bash
./install_sparkybot_hardware.sh
```

A future improvement is packaging the CH341 driver with DKMS so it rebuilds automatically after compatible kernel updates.

## Troubleshooting

If the module build succeeds but `modprobe ch341` fails, do not force-load it. Inspect:

```bash
sudo dmesg | tail -40
modinfo ./ch341.ko
uname -r
```

A module-version or symbol mismatch means the driver should be rebuilt from source matching that specific NVIDIA kernel release.
