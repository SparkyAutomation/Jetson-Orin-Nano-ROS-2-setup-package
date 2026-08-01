#!/usr/bin/env bash
# Jetson Orin Nano robotics workstation installer
# Target: NVIDIA JetPack 7.2 / Ubuntu 24.04 / ROS 2 Jazzy / Python 3.12

# This installer requires Bash. Do not run it with:
#   sh install_jetson_ros2.sh
#
# Run it with:
#   bash install_jetson_ros2.sh
# or:
#   chmod +x install_jetson_ros2.sh
#   ./install_jetson_ros2.sh

if [[ -z "${BASH_VERSION:-}" ]]; then
  printf '%s\n' "Error: this installer must be run with Bash." >&2
  printf '%s\n' "Run: bash $0 $*" >&2
  exit 2
fi

set -Eeuo pipefail
IFS=$'\n\t'

ROS_DISTRO="jazzy"
WORKSPACE="${HOME}/ros2_ws"
VENV_DIR="${HOME}/.venvs/jetson-ros2"

INSTALL_NAV2=1
INSTALL_SLAM=1
SYSTEM_UPGRADE=0
MAX_PERFORMANCE=0
SKIP_HARDWARE_CHECK=0

PYTORCH_INDEX_URL="https://download.pytorch.org/whl/cu130"
TORCH_VERSION="2.13.0+cu130"
TORCHVISION_VERSION="0.28.0+cu130"
ULTRALYTICS_VERSION="8.4.112"
NUMPY_VERSION="1.26.4"
ONNXRUNTIME_VERSION="1.18.0"

log() {
  printf '\n\033[1;34m[jetson-setup]\033[0m %s\n' "$*"
}

warn() {
  printf '\n\033[1;33m[warning]\033[0m %s\n' "$*" >&2
}

fail() {
  printf '\n\033[1;31m[error]\033[0m %s\n' "$*" >&2
  exit 1
}

on_error() {
  local exit_code=$?
  local failed_line="${BASH_LINENO[0]:-${LINENO}}"
  local failed_command="${BASH_COMMAND:-unknown command}"

  trap - ERR

  printf '\n\033[1;31m[error]\033[0m Installation failed.\n' >&2
  printf '\033[1;31m[error]\033[0m Line: %s\n' "$failed_line" >&2
  printf '\033[1;31m[error]\033[0m Command: %s\n' "$failed_command" >&2
  printf '\033[1;31m[error]\033[0m Exit code: %s\n' "$exit_code" >&2

  exit "$exit_code"
}

trap on_error ERR

usage() {
  cat <<'USAGE'
Usage: ./install_jetson_ros2.sh [options]

Options:
  --workspace PATH          ROS 2 workspace path
                            Default: ~/ros2_ws

  --venv PATH               Python virtual environment path
                            Default: ~/.venvs/jetson-ros2

  --no-nav2                 Do not install Navigation2 packages

  --no-slam                 Do not install SLAM Toolbox

  --system-upgrade          Run apt full-upgrade before installing packages

  --max-performance         Enable nvpmodel mode 0 and jetson_clocks

  --skip-hardware-check     Allow execution on non-Jetson ARM64 systems

  -h, --help                Show this help message

Run this script as a normal user with sudo access.
Do not run it as root.
Do not run it with sh.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --workspace)
      [[ $# -ge 2 ]] || fail "--workspace requires a path."
      WORKSPACE="$2"
      shift 2
      ;;

    --venv)
      [[ $# -ge 2 ]] || fail "--venv requires a path."
      VENV_DIR="$2"
      shift 2
      ;;

    --no-nav2)
      INSTALL_NAV2=0
      shift
      ;;

    --no-slam)
      INSTALL_SLAM=0
      shift
      ;;

    --system-upgrade)
      SYSTEM_UPGRADE=1
      shift
      ;;

    --max-performance)
      MAX_PERFORMANCE=1
      shift
      ;;

    --skip-hardware-check)
      SKIP_HARDWARE_CHECK=1
      shift
      ;;

    -h|--help)
      usage
      exit 0
      ;;

    *)
      fail "Unknown option: $1"
      ;;
  esac
done

[[ "${EUID}" -ne 0 ]] || fail \
  "Run this script as a normal user, not as root."

command -v sudo >/dev/null 2>&1 || fail \
  "sudo is required."

command -v curl >/dev/null 2>&1 || fail \
  "curl is required."

command -v python3 >/dev/null 2>&1 || fail \
  "python3 is required."

[[ -r /etc/os-release ]] || fail \
  "/etc/os-release could not be read."

# shellcheck disable=SC1091
source /etc/os-release

[[ "${ID:-}" == "ubuntu" ]] || fail \
  "Ubuntu is required. Detected: ${ID:-unknown}."

[[ "${VERSION_ID:-}" == "24.04" ]] || fail \
  "This installer targets Ubuntu 24.04 / JetPack 7.2. Detected Ubuntu ${VERSION_ID:-unknown}."

[[ "$(uname -m)" == "aarch64" ]] || fail \
  "ARM64/aarch64 is required. Detected: $(uname -m)."

if [[ "${SKIP_HARDWARE_CHECK}" -eq 0 ]]; then
  if [[ ! -f /etc/nv_tegra_release ]] &&
     ! dpkg-query -W nvidia-l4t-core >/dev/null 2>&1; then
    fail \
      "NVIDIA Jetson Linux was not detected. Use --skip-hardware-check only for controlled testing."
  fi
fi

log "Configuration"

printf '  Ubuntu:       %s\n' "${PRETTY_NAME:-unknown}"
printf '  Architecture: %s\n' "$(uname -m)"
printf '  ROS distro:   %s\n' "${ROS_DISTRO}"
printf '  Workspace:    %s\n' "${WORKSPACE}"
printf '  Python venv:  %s\n' "${VENV_DIR}"
printf '  User:         %s\n' "${USER:-$(id -un)}"

log "Acquiring sudo credentials"

sudo -v

log "Configuring locale"

sudo apt-get update

sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
  locales \
  software-properties-common \
  curl \
  ca-certificates \
  gnupg \
  lsb-release

sudo locale-gen en_US en_US.UTF-8
sudo update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8

export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

sudo add-apt-repository -y universe

if [[ "${SYSTEM_UPGRADE}" -eq 1 ]]; then
  log "Applying full system upgrade"

  sudo apt-get update

  sudo DEBIAN_FRONTEND=noninteractive \
    apt-get full-upgrade -y
fi

log "Installing the JetPack development stack and system tools"

sudo apt-get update

sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
  nvidia-jetpack \
  build-essential \
  cmake \
  ninja-build \
  pkg-config \
  git \
  git-lfs \
  python3-pip \
  python3-venv \
  python3-dev \
  python3-opencv \
  python3-numpy \
  libopenblas-dev \
  libjpeg-dev \
  libpng-dev \
  libavcodec-dev \
  libavformat-dev \
  libswscale-dev \
  libgtk-3-dev \
  ffmpeg \
  v4l-utils \
  usbutils \
  can-utils \
  net-tools \
  tigervnc-standalone-server \
  tigervnc-viewer \
  htop \
  tmux \
  nano \
  vim

git lfs install --skip-repo >/dev/null 2>&1 || true

log "Adding the current user to common robotics device groups"

CURRENT_USER="${SUDO_USER:-${USER:-$(id -un)}}"

for device_group in dialout video render i2c gpio; do
  if getent group "${device_group}" >/dev/null 2>&1; then
    sudo usermod -aG "${device_group}" "${CURRENT_USER}"
  else
    warn "Group '${device_group}' does not exist; skipping it."
  fi
done

log "Configuring the official ROS 2 apt repository"

ROS_APT_SOURCE_VERSION="$(
  curl -fsSL \
    https://api.github.com/repos/ros-infrastructure/ros-apt-source/releases/latest |
    awk -F'"' '/"tag_name"/ {print $4; exit}'
)"

[[ -n "${ROS_APT_SOURCE_VERSION}" ]] || fail \
  "Could not determine the ros-apt-source release version."

[[ -n "${VERSION_CODENAME:-}" ]] || fail \
  "Ubuntu VERSION_CODENAME is unavailable."

ROS_APT_DEB="/tmp/ros2-apt-source.deb"

ROS_APT_URL="https://github.com/ros-infrastructure/ros-apt-source/releases/download/${ROS_APT_SOURCE_VERSION}/ros2-apt-source_${ROS_APT_SOURCE_VERSION}.${VERSION_CODENAME}_all.deb"

log "Downloading ROS apt-source package"

printf '  Version: %s\n' "${ROS_APT_SOURCE_VERSION}"
printf '  URL:     %s\n' "${ROS_APT_URL}"

curl -fL \
  --retry 3 \
  --retry-delay 2 \
  --connect-timeout 20 \
  -o "${ROS_APT_DEB}" \
  "${ROS_APT_URL}"

[[ -s "${ROS_APT_DEB}" ]] || fail \
  "The downloaded ROS apt-source package is empty."

sudo dpkg -i "${ROS_APT_DEB}"

rm -f "${ROS_APT_DEB}"

log "Installing ROS 2 Jazzy and robotics packages"

ROS_PACKAGES=(
  "ros-${ROS_DISTRO}-desktop"
  "ros-${ROS_DISTRO}-cv-bridge"
  "ros-${ROS_DISTRO}-image-transport"
  "ros-${ROS_DISTRO}-vision-opencv"
  "ros-${ROS_DISTRO}-robot-localization"
  "ros-${ROS_DISTRO}-xacro"
  "ros-${ROS_DISTRO}-joint-state-publisher-gui"
  "ros-${ROS_DISTRO}-rmw-cyclonedds-cpp"
  "ros-dev-tools"
)

if [[ "${INSTALL_NAV2}" -eq 1 ]]; then
  ROS_PACKAGES+=(
    "ros-${ROS_DISTRO}-navigation2"
    "ros-${ROS_DISTRO}-nav2-bringup"
  )
fi

if [[ "${INSTALL_SLAM}" -eq 1 ]]; then
  ROS_PACKAGES+=(
    "ros-${ROS_DISTRO}-slam-toolbox"
  )
fi

sudo apt-get update

sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
  "${ROS_PACKAGES[@]}"

log "Initializing rosdep"

if [[ ! -f /etc/ros/rosdep/sources.list.d/20-default.list ]]; then
  sudo rosdep init
else
  log "rosdep is already initialized"
fi

rosdep update

log "Creating ROS 2 workspace"

mkdir -p "${WORKSPACE}/src" || fail \
  "Could not create workspace directory: ${WORKSPACE}/src"

log "Creating Python virtual environment"

VENV_PARENT="$(dirname "${VENV_DIR}")"

mkdir -p "${VENV_PARENT}" || fail \
  "Could not create venv parent directory: ${VENV_PARENT}"

if [[ ! -x "${VENV_DIR}/bin/python" ]]; then
  python3 -m venv \
    --system-site-packages \
    "${VENV_DIR}"
else
  log "Existing Python virtual environment detected"
fi

"${VENV_DIR}/bin/python" -m pip install \
  --upgrade \
  pip \
  setuptools \
  wheel

log "Installing CUDA-enabled PyTorch for ARM64"

"${VENV_DIR}/bin/python" -m pip install \
  --no-cache-dir \
  --index-url "${PYTORCH_INDEX_URL}" \
  "torch==${TORCH_VERSION}" \
  "torchvision==${TORCHVISION_VERSION}"

log "Installing NumPy and robotics Python libraries"

"${VENV_DIR}/bin/python" -m pip install \
  --no-cache-dir \
  "numpy==${NUMPY_VERSION}" \
  "scipy>=1.13,<2" \
  "pyserial>=3.5,<4" \
  "pyyaml>=6,<7" \
  "filelock>=3.16,<4" \
  "matplotlib>=3.8,<4" \
  "pillow>=10,<13" \
  "requests>=2.31,<3" \
  "psutil>=5.9,<8" \
  "polars>=1,<2" \
  "nvidia-ml-py>=12,<14" \
  "ultralytics-thop>=2.1.2,<3" \
  "onnx>=1.18,<2" \
  "onnxslim>=0.1.82,<1" \
  "onnxruntime>=${ONNXRUNTIME_VERSION},<2"

# Install Ultralytics without dependencies so pip does not replace the
# JetPack/Ubuntu OpenCV build with a generic opencv-python wheel.
log "Installing Ultralytics YOLO while preserving system OpenCV"

"${VENV_DIR}/bin/python" -m pip install \
  --no-cache-dir \
  --no-deps \
  "ultralytics==${ULTRALYTICS_VERSION}"

ENV_SCRIPT="${HOME}/jetson_ros2_env.sh"

log "Writing environment helper: ${ENV_SCRIPT}"

cat > "${ENV_SCRIPT}" <<ENVEOF
#!/usr/bin/env bash
# Source this file before developing or running the robot stack.

source "/opt/ros/${ROS_DISTRO}/setup.bash"
source "${VENV_DIR}/bin/activate"

if [[ -f "${WORKSPACE}/install/setup.bash" ]]; then
  source "${WORKSPACE}/install/setup.bash"
fi

export ROS_DOMAIN_ID=0
export RCUTILS_COLORIZED_OUTPUT=1
export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
ENVEOF

chmod +x "${ENV_SCRIPT}"

BASHRC_MARKER="# Jetson ROS 2 environment"

if ! grep -Fq "${BASHRC_MARKER}" "${HOME}/.bashrc"; then
  cat >> "${HOME}/.bashrc" <<BASHRCEOF

${BASHRC_MARKER}
if [[ -f "${ENV_SCRIPT}" ]]; then
  source "${ENV_SCRIPT}"
fi
BASHRCEOF
fi

log "Building the initial workspace"

# shellcheck disable=SC1091
source "/opt/ros/${ROS_DISTRO}/setup.bash"

# shellcheck disable=SC1090
source "${VENV_DIR}/bin/activate"

cd "${WORKSPACE}" || fail \
  "Could not change directory to ${WORKSPACE}"

colcon build --symlink-install

if [[ "${MAX_PERFORMANCE}" -eq 1 ]]; then
  log "Enabling maximum performance mode"

  warn \
    "Maximum clocks increase power draw and heat. Use adequate active cooling."

  if command -v nvpmodel >/dev/null 2>&1; then
    sudo nvpmodel -m 0
  else
    warn "nvpmodel was not found."
  fi

  if command -v jetson_clocks >/dev/null 2>&1; then
    sudo jetson_clocks
  else
    warn "jetson_clocks was not found."
  fi
fi

log "Running installation checks"

"${VENV_DIR}/bin/python" - <<'PY'
import cv2
import numpy as np
import onnx
import onnxruntime as ort
import torch
import torchvision
import ultralytics
from ultralytics import YOLO

print(f"NumPy:                 {np.__version__}")
print(f"OpenCV:                {cv2.__version__}")
print(f"PyTorch:               {torch.__version__}")
print(f"TorchVision:           {torchvision.__version__}")
print(f"ONNX:                   {onnx.__version__}")
print(f"ONNX Runtime:           {ort.__version__}")
print(f"Ultralytics:            {ultralytics.__version__}")
print(f"CUDA usable:            {torch.cuda.is_available()}")
print(f"ONNX Runtime providers: {ort.get_available_providers()}")

if torch.cuda.is_available():
    print(f"CUDA device:            {torch.cuda.get_device_name(0)}")

_ = YOLO
PY

if ! "${VENV_DIR}/bin/python" -c \
  'import torch; raise SystemExit(0 if torch.cuda.is_available() else 1)'
then
  warn \
    "PyTorch imported, but CUDA was not available. Reboot once and run the verification again."
fi

cat <<SUMMARY

Installation complete.

Open a new terminal, or run:

  source "${ENV_SCRIPT}"

Verify Python and CUDA:

  "${VENV_DIR}/bin/python" -c \
    "import torch; print(torch.__version__); print(torch.cuda.is_available())"

Test ROS 2 in terminal 1:

  ros2 run demo_nodes_cpp talker

Test ROS 2 in terminal 2:

  ros2 run demo_nodes_py listener

Workspace:

  ${WORKSPACE}

Python environment:

  ${VENV_DIR}

Your user was added to available robotics device groups.
A reboot is recommended before using serial, camera, GPIO, or GPU resources:

  sudo reboot

SUMMARY
