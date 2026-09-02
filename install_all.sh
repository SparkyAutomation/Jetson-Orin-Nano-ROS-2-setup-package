#!/usr/bin/env bash
# One-command SparkyBot Jetson Orin Nano provisioning.
# Runs the existing Jetson/ROS 2 installer, then provisions robot USB hardware.

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

printf '\n=== SparkyBot Jetson + ROS 2 provisioning ===\n'

bash "${SCRIPT_DIR}/install_jetson_ros2.sh" "$@"
bash "${SCRIPT_DIR}/install_sparkybot_hardware.sh"

printf '\nProvisioning complete.\n'
printf 'Recommended next steps:\n'
printf '  1. Reboot: sudo reboot\n'
printf '  2. Reconnect the Sparkybot controller if needed\n'
printf '  3. Verify: python3 %s/verify_sparkybot.py\n' "$SCRIPT_DIR"
printf '  4. Use /dev/sparkybot for the robot serial port\n'
