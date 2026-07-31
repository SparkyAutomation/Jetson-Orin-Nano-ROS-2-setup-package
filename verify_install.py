#!/usr/bin/env python3
"""Verify ROS 2, OpenCV, PyTorch CUDA, and Ultralytics on a Jetson."""

from __future__ import annotations

import importlib
import platform
import sys
from dataclasses import dataclass


@dataclass
class Check:
    name: str
    passed: bool
    detail: str


def package_version(module_name: str) -> str:
    module = importlib.import_module(module_name)
    return str(getattr(module, "__version__", "unknown"))


def main() -> int:
    checks: list[Check] = []

    try:
        import numpy as np

        checks.append(Check("NumPy", True, np.__version__))
    except Exception as exc:  # noqa: BLE001
        checks.append(Check("NumPy", False, repr(exc)))

    try:
        import cv2

        build_info = cv2.getBuildInformation()
        gstreamer_line = next(
            (line.strip() for line in build_info.splitlines() if line.strip().startswith("GStreamer:")),
            "GStreamer: unknown",
        )
        gstreamer = gstreamer_line.split(":", maxsplit=1)[1].strip()
        checks.append(Check("OpenCV", True, f"{cv2.__version__}; GStreamer={gstreamer}"))
    except Exception as exc:  # noqa: BLE001
        checks.append(Check("OpenCV", False, repr(exc)))

    try:
        import torch

        cuda_ok = torch.cuda.is_available()
        device = torch.cuda.get_device_name(0) if cuda_ok else "none"
        if cuda_ok:
            a = torch.rand((512, 512), device="cuda")
            b = torch.rand((512, 512), device="cuda")
            _ = a @ b
            torch.cuda.synchronize()
        checks.append(
            Check(
                "PyTorch CUDA",
                cuda_ok,
                f"torch={torch.__version__}; CUDA={torch.version.cuda}; device={device}",
            )
        )
    except Exception as exc:  # noqa: BLE001
        checks.append(Check("PyTorch CUDA", False, repr(exc)))

    try:
        checks.append(Check("TorchVision", True, package_version("torchvision")))
    except Exception as exc:  # noqa: BLE001
        checks.append(Check("TorchVision", False, repr(exc)))

    try:
        checks.append(Check("Ultralytics", True, package_version("ultralytics")))
    except Exception as exc:  # noqa: BLE001
        checks.append(Check("Ultralytics", False, repr(exc)))

    try:
        import rclpy

        rclpy.init(args=None)
        node = rclpy.create_node("jetson_install_verification")
        node.destroy_node()
        rclpy.shutdown()
        checks.append(Check("ROS 2 rclpy", True, "node initialization succeeded"))
    except Exception as exc:  # noqa: BLE001
        checks.append(Check("ROS 2 rclpy", False, repr(exc)))

    print("Jetson robotics stack verification")
    print(f"Python: {sys.version.split()[0]}")
    print(f"System: {platform.platform()}")
    print("-" * 78)

    for check in checks:
        status = "PASS" if check.passed else "FAIL"
        print(f"[{status:4}] {check.name:16} {check.detail}")

    failed = [check for check in checks if not check.passed]
    if failed:
        print(f"\n{len(failed)} check(s) failed.")
        return 1

    print("\nAll checks passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
