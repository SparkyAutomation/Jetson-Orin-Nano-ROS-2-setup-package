#!/usr/bin/env python3
"""Verify SparkyBot-specific Jetson hardware provisioning."""

from __future__ import annotations

import grp
import os
import pathlib
import subprocess
import sys
from dataclasses import dataclass


@dataclass
class Check:
    name: str
    status: str
    detail: str


def run(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(args, capture_output=True, text=True, check=False)


def main() -> int:
    checks: list[Check] = []

    kernel = os.uname().release
    checks.append(Check("Kernel", "PASS", kernel))

    module_info = run("modinfo", "ch341")
    builtin = False
    config_path = pathlib.Path("/proc/config.gz")
    if config_path.exists():
        config = run("zgrep", "^CONFIG_USB_SERIAL_CH341=y", str(config_path))
        builtin = config.returncode == 0

    if module_info.returncode == 0:
        checks.append(Check("CH341 available", "PASS", "kernel module installed"))
    elif builtin:
        checks.append(Check("CH341 available", "PASS", "built into kernel"))
    else:
        checks.append(Check("CH341 available", "FAIL", "module not installed and not built in"))

    lsmod = run("lsmod")
    if builtin:
        checks.append(Check("CH341 active", "PASS", "built into kernel"))
    elif any(line.startswith("ch341 ") for line in lsmod.stdout.splitlines()):
        checks.append(Check("CH341 active", "PASS", "module loaded"))
    else:
        checks.append(Check("CH341 active", "FAIL", "module is not loaded"))

    usb = run("lsusb", "-d", "1a86:7523")
    if usb.returncode == 0 and usb.stdout.strip():
        checks.append(Check("Yahboom USB", "PASS", usb.stdout.strip()))
    else:
        checks.append(Check("Yahboom USB", "INFO", "1a86:7523 controller is not currently connected"))

    tty_devices = sorted(pathlib.Path("/dev").glob("ttyUSB*"))
    if tty_devices:
        checks.append(Check("USB serial", "PASS", ", ".join(map(str, tty_devices))))
    else:
        checks.append(Check("USB serial", "INFO", "no /dev/ttyUSB* device currently present"))

    alias = pathlib.Path("/dev/sparkybot")
    if alias.exists():
        try:
            target = alias.resolve(strict=True)
            checks.append(Check("/dev/sparkybot", "PASS", str(target)))
        except OSError as exc:
            checks.append(Check("/dev/sparkybot", "FAIL", repr(exc)))
    else:
        checks.append(Check("/dev/sparkybot", "INFO", "alias absent; reconnect controller if it is plugged in"))

    try:
        groups = {grp.getgrgid(gid).gr_name for gid in os.getgroups()}
    except KeyError:
        groups = set()
    if "dialout" in groups:
        checks.append(Check("dialout", "PASS", "current session has serial-port access"))
    else:
        checks.append(Check("dialout", "FAIL", "log out/in after installer adds the user to dialout"))

    rule = pathlib.Path("/etc/udev/rules.d/99-sparkybot.rules")
    checks.append(
        Check(
            "udev rule",
            "PASS" if rule.exists() else "FAIL",
            str(rule) if rule.exists() else "persistent /dev/sparkybot rule is missing",
        )
    )

    print("SparkyBot hardware verification")
    print("-" * 88)
    for check in checks:
        print(f"[{check.status:4}] {check.name:18} {check.detail}")

    failed = [check for check in checks if check.status == "FAIL"]
    if failed:
        print(f"\n{len(failed)} required check(s) failed.")
        return 1

    print("\nRequired hardware provisioning checks passed.")
    if any(check.status == "INFO" for check in checks):
        print("INFO entries are normally resolved by connecting/replugging the controller.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
