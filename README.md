# NVIDIA Jetson Orin Nano ROS 2 Robotics Setup

A reproducible, native installation guide for turning a new NVIDIA Jetson Orin Nano Developer Kit into a ROS 2 robotics and edge-AI development computer.

The included installer configures:

- NVIDIA JetPack development components
- ROS 2 Jazzy Jalisco
- A standard `colcon` workspace
- NumPy and common scientific Python packages
- CUDA-enabled PyTorch and TorchVision
- OpenCV (`cv2`)
- Ultralytics YOLO
- ROS computer-vision packages, Navigation2, robot localization, and SLAM Toolbox
- Common serial, camera, I2C, and GPU device-group permissions
- A reusable shell environment and verification utility

> **Target stack:** JetPack 7.2, Jetson Linux 39.2, Ubuntu 24.04 ARM64, ROS 2 Jazzy, and Python 3.12. The package versions in this repository were selected on July 30, 2026. Run the included verifier on the target board before deploying to a physical robot.

## Why this stack

JetPack 7.2 is the current Jetson release supporting the Orin family. It uses Ubuntu 24.04, which is the native binary platform for ROS 2 Jazzy. JetPack 7.2 also moves Orin onto the newer ARM64 software ecosystem, making official CUDA-enabled PyTorch ARM64 wheels practical.

This repository deliberately does **not** use generic x86 CUDA packages, Conda, or an unverified community PyTorch wheel. Jetson package compatibility is strict: the operating system, CUDA runtime, Python ABI, PyTorch wheel, and ROS distribution must agree.

## Repository layout

```text
.
├── README.md
├── install_jetson_ros2.sh
├── verify_install.py
└── LICENSE
```

## 1. Hardware preparation

Recommended minimum hardware:

- NVIDIA Jetson Orin Nano Developer Kit or Orin Nano Super Developer Kit
- Official or equivalent power supply appropriate for the developer kit
- Active cooling
- Ethernet or reliable Wi-Fi connection
- USB keyboard and display for initial setup, or a supported headless setup
- A USB flash drive for the JetPack installer
- NVMe SSD recommended for robotics development; microSD works but is slower and has lower write endurance

For a ROS workspace, model files, Docker images, logs, and datasets, a 256 GB or larger NVMe SSD is a practical starting point.

## 2. Install JetPack 7.2

JetPack 7.2 uses NVIDIA's unified ISO installation workflow. For the Orin Nano Developer Kit, NVIDIA no longer provides the older downloadable SD-card image for this release.

1. Download the **JetPack 7.2 ISO** from NVIDIA.
2. Write the ISO to a USB flash drive with a trusted imaging tool.
3. Boot the Jetson from the USB installer.
4. Install Jetson Linux to the NVMe SSD or microSD card.
5. Complete the Ubuntu first-boot wizard.
6. Connect the Jetson to the network.

Official references:

- [NVIDIA JetPack overview](https://developer.nvidia.com/embedded/jetpack)
- [JetPack 7.2 downloads and release notes](https://developer.nvidia.com/embedded/jetpack/downloads/archive-7.2)
- [Jetson Linux Developer Guide](https://docs.nvidia.com/jetson/)

After the first login, open a terminal and run:

```bash
sudo apt update
sudo apt install -y nvidia-jetpack
sudo reboot
```

The `nvidia-jetpack` meta-package ensures that CUDA, cuDNN, TensorRT, VPI, development headers, and related JetPack components are present.

## 3. Confirm the base system

After rebooting:

```bash
uname -m
cat /etc/os-release
cat /etc/nv_tegra_release 2>/dev/null || true
dpkg-query -W nvidia-l4t-core nvidia-jetpack
```

Expected essentials:

```text
aarch64
Ubuntu 24.04
Jetson Linux / L4T 39.x
```

You can inspect CUDA and Jetson tools with:

```bash
nvcc --version
nvidia-smi || true
sudo nvpmodel -q
```

`nvidia-smi` on Jetson does not always expose the same information as a desktop GPU. `tegrastats` is usually more useful for embedded monitoring:

```bash
sudo tegrastats
```

Press `Ctrl+C` to stop it.

## 4. Download this repository

```bash
git clone https://github.com/SparkyAutomation/Jetson-Orin-Nano-ROS-2-setup-package.git
cd Jetson-Orin-Nano-ROS-2-setup-package
chmod +x install_jetson_ros2.sh verify_install.py
```

When using the files directly without a Git repository:

```bash
cd jetson-orin-nano-ros2-setup
chmod +x install_jetson_ros2.sh verify_install.py
```

## 5. Run the installer

Run the script as your normal Ubuntu user. Do **not** run the entire script with `sudo`.

```bash
./install_jetson_ros2.sh
```

The script requests sudo only for system-level operations.

### Installer options

```bash
./install_jetson_ros2.sh --help
```

Common examples:

```bash
# Default full robotics installation
./install_jetson_ros2.sh

# Use a custom workspace and virtual environment
./install_jetson_ros2.sh \
  --workspace "$HOME/robot_ws" \
  --venv "$HOME/.venvs/robot-ai"

# Skip Navigation2 and SLAM packages
./install_jetson_ros2.sh --no-nav2 --no-slam

# Upgrade all system packages first
./install_jetson_ros2.sh --system-upgrade

# Enable maximum clocks after installation
./install_jetson_ros2.sh --max-performance
```

The default installation creates:

```text
~/ros2_ws
~/.venvs/jetson-ros2
~/jetson_ros2_env.sh
```

It also adds the environment helper to `~/.bashrc` and adds the current user to available robotics device groups such as `dialout`, `video`, `render`, `i2c`, and `gpio`. Group changes take effect after logout or reboot.

## 6. Reboot and load the environment

A reboot is recommended after installation:

```bash
sudo reboot
```

Open a new terminal. The environment should load automatically. To load it manually:

```bash
source ~/jetson_ros2_env.sh
```

Confirm the active environment:

```bash
echo "$ROS_DISTRO"
which python
python --version
```

Expected output should identify ROS 2 Jazzy and the Python interpreter inside `~/.venvs/jetson-ros2`.

## 7. Verify the complete stack

From this repository:

```bash
source ~/jetson_ros2_env.sh
python verify_install.py
```

The verifier checks:

- NumPy import
- OpenCV import and build information
- PyTorch CUDA availability
- A CUDA matrix multiplication
- TorchVision
- Ultralytics
- ROS 2 Python node initialization

A healthy result resembles:

```text
[PASS] NumPy            1.26.4
[PASS] OpenCV           4.x.x; GStreamer=YES
[PASS] PyTorch CUDA     torch=2.13.0+cu130; CUDA=13.0; device=...
[PASS] TorchVision      0.28.0+cu130
[PASS] Ultralytics      8.4.112
[PASS] ROS 2 rclpy      node initialization succeeded
```

PyTorch must report:

```python
import torch
print(torch.cuda.is_available())
```

Expected:

```text
True
```

## 8. Test ROS 2 communication

Open terminal 1:

```bash
source ~/jetson_ros2_env.sh
ros2 run demo_nodes_cpp talker
```

Open terminal 2:

```bash
source ~/jetson_ros2_env.sh
ros2 run demo_nodes_py listener
```

The listener should receive messages from the talker.

Inspect the ROS graph:

```bash
ros2 node list
ros2 topic list
ros2 topic echo /chatter
```

## 9. Build a ROS 2 workspace

The installer creates an empty workspace at `~/ros2_ws`.

```bash
cd ~/ros2_ws
colcon build --symlink-install
source install/setup.bash
```

Create a Python package:

```bash
cd ~/ros2_ws/src
ros2 pkg create \
  --build-type ament_python \
  --license Apache-2.0 \
  --dependencies rclpy sensor_msgs geometry_msgs \
  robot_perception
```

Install dependencies and build:

```bash
cd ~/ros2_ws
rosdep install --from-paths src --ignore-src -r -y
colcon build --symlink-install
source install/setup.bash
```

During development, use:

```bash
colcon build --symlink-install --packages-select robot_perception
```

## 10. Test OpenCV

Run a basic image test:

```bash
python - <<'PY'
import cv2
import numpy as np

image = np.zeros((480, 640, 3), dtype=np.uint8)
cv2.putText(
    image,
    "Jetson Orin Nano + ROS 2",
    (45, 240),
    cv2.FONT_HERSHEY_SIMPLEX,
    1.0,
    (255, 255, 255),
    2,
)
cv2.imwrite("opencv_test.jpg", image)
print("Saved opencv_test.jpg")
print("OpenCV version:", cv2.__version__)
PY
```

List USB video devices:

```bash
v4l2-ctl --list-devices
ls -l /dev/video*
```

Test a USB camera:

```bash
python - <<'PY'
import cv2

camera = cv2.VideoCapture(0)
if not camera.isOpened():
    raise SystemExit("Could not open camera 0")

for _ in range(30):
    ok, frame = camera.read()
    if not ok:
        raise SystemExit("Camera opened but did not return a frame")

cv2.imwrite("camera_test.jpg", frame)
camera.release()
print("Saved camera_test.jpg")
PY
```

For CSI cameras, use the NVIDIA Argus/GStreamer pipeline recommended for the specific sensor and carrier board. A generic `/dev/video0` test is not sufficient for every CSI camera.

## 11. Test Ultralytics YOLO on the GPU

Ultralytics downloads pretrained weights during the first run, so the Jetson needs internet access.

```bash
source ~/jetson_ros2_env.sh
python - <<'PY'
import torch
from ultralytics import YOLO

assert torch.cuda.is_available(), "CUDA is not available to PyTorch"

model = YOLO("yolo26n.pt")
results = model.predict(
    source="https://ultralytics.com/images/bus.jpg",
    device=0,
    imgsz=640,
    save=True,
    verbose=True,
)
print("Saved results to:", results[0].save_dir)
PY
```

For a more conservative model path in a project already standardized on YOLO11, replace `yolo26n.pt` with `yolo11n.pt`.

### Export to TensorRT

TensorRT is normally the preferred deployment format for Jetson inference. The installer includes ONNX and ONNXSlim so Ultralytics does not need to modify the environment automatically during the export step.

```bash
python - <<'PY'
from ultralytics import YOLO

model = YOLO("yolo26n.pt")
model.export(format="engine", device=0, half=True, imgsz=640)
PY
```

Run the TensorRT engine:

```bash
python - <<'PY'
from ultralytics import YOLO

model = YOLO("yolo26n.engine")
model.predict(
    source="https://ultralytics.com/images/bus.jpg",
    device=0,
    save=True,
)
PY
```

Build TensorRT engines on the target Jetson, then validate them on that exact hardware and software stack. Do not assume an engine built on another GPU, TensorRT version, or Jetson SKU is portable.

## 12. ROS 2 computer-vision integration

The installer includes `cv_bridge`, `image_transport`, and `vision_opencv`.

Verify packages:

```bash
ros2 pkg prefix cv_bridge
ros2 pkg prefix image_transport
ros2 pkg prefix vision_opencv
```

Typical perception flow:

```text
Camera driver
    -> sensor_msgs/Image
    -> cv_bridge
    -> OpenCV/NumPy preprocessing
    -> PyTorch or TensorRT inference
    -> detections/segmentations
    -> ROS 2 messages
    -> tracking, planning, or actuation
```

For production robotics, keep the model callback non-blocking. Use a bounded queue, explicit QoS, timestamps, and a separate inference worker or composable-node architecture.

## 13. ROS 2 networking

ROS 2 uses DDS discovery. All machines should have synchronized clocks and compatible network settings.

Set the same domain on every machine that should communicate:

```bash
export ROS_DOMAIN_ID=30
```

Persist it by editing `~/jetson_ros2_env.sh`.

For multi-robot systems, use a separate domain ID per robot or deployment group. Avoid the default domain on shared institutional networks.

Cyclone DDS is installed but is not forced as the default. To test it:

```bash
export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
ros2 doctor --report
```

Persist this only after validating discovery, multicast, firewall, and Wi-Fi behavior for the robot network.

## 14. Performance and thermal management

Inspect the available power modes:

```bash
sudo nvpmodel -q --verbose
```

Enable the highest configured mode and fixed clocks only during controlled testing:

```bash
sudo nvpmodel -m 0
sudo jetson_clocks
```

Monitor the system:

```bash
sudo tegrastats
```

Maximum clocks increase power draw and heat. A robot should use a power mode selected for sustained performance, battery capacity, enclosure airflow, and worst-case ambient temperature—not merely the highest benchmark result.

To restore clocks after testing, reboot or use the appropriate `jetson_clocks` restore workflow for the installed JetPack release.

## 15. Useful development commands

```bash
# ROS diagnostics
ros2 doctor --report

# Package and topic inspection
ros2 pkg list
ros2 node list
ros2 topic list -t

# Workspace dependency installation
cd ~/ros2_ws
rosdep install --from-paths src --ignore-src -r -y

# Clean rebuild
cd ~/ros2_ws
rm -rf build install log
colcon build --symlink-install

# CUDA verification
python -c "import torch; print(torch.__version__, torch.cuda.is_available(), torch.cuda.get_device_name(0))"

# OpenCV verification
python -c "import cv2; print(cv2.__version__)"

# Jetson utilization
sudo tegrastats
```

## 16. Troubleshooting

### PyTorch imports but CUDA is `False`

Check:

```bash
source ~/jetson_ros2_env.sh
python -c "import torch; print(torch.__version__); print(torch.version.cuda); print(torch.cuda.is_available())"
dpkg-query -W nvidia-l4t-core nvidia-jetpack
nvcc --version
```

Then reboot once. If the issue remains, confirm that the system is actually JetPack 7.2/Ubuntu 24.04 and that PyTorch came from the CUDA 13.0 ARM64 index.

```bash
python -m pip show torch torchvision
```

Do not install a generic CPU-only `torch` wheel from the default PyPI index over the CUDA build.

### `ModuleNotFoundError: rclpy`

Load the environment:

```bash
source ~/jetson_ros2_env.sh
```

The virtual environment was created with `--system-site-packages` so it can access ROS 2 Python modules installed under `/opt/ros/jazzy`.

### `ModuleNotFoundError: cv2`

Check the system package:

```bash
dpkg-query -W python3-opencv
python3 -c "import cv2; print(cv2.__version__)"
```

Reinstall if necessary:

```bash
sudo apt update
sudo apt install --reinstall python3-opencv
```

Then recreate the virtual environment with `--system-site-packages` or rerun the installer.

### Ultralytics reports that `opencv-python` is missing

This setup intentionally installs Ultralytics with `--no-deps` and uses Ubuntu/JetPack's `cv2` module instead of replacing it with a generic pip OpenCV wheel. Confirm that this works:

```bash
python -c "import cv2; from ultralytics import YOLO; print(cv2.__version__)"
```

Do not run `pip install -U ultralytics` blindly on the Jetson; it may modify the tested PyTorch or OpenCV stack. Update package pins deliberately.

### ROS 2 machines cannot discover one another

Check:

- Same `ROS_DOMAIN_ID`
- Same or compatible ROS distribution and message definitions
- Multicast support on the network
- Host firewall rules
- Wi-Fi client isolation
- Correct time synchronization
- Correct DDS interface selection

Run:

```bash
ros2 doctor --report
```

### Build fails after adding packages

Install missing dependencies:

```bash
cd ~/ros2_ws
rosdep update
rosdep install --from-paths src --ignore-src -r -y
```

Then clean and rebuild:

```bash
rm -rf build install log
colcon build --symlink-install
```

### Out-of-memory failures

The Orin Nano shares system RAM between CPU and GPU workloads. Reduce model size, image resolution, batch size, queue depth, and the number of concurrent ROS nodes.

For inference, start with a nano model and batch size 1. Use TensorRT FP16 after validating accuracy.

## 17. JetPack 6 note

JetPack 6.2.2 uses Ubuntu 22.04 and normally pairs with ROS 2 Humble. Its PyTorch installation path is different from this repository because the Python version and Jetson CUDA packaging differ.

Do not run this JetPack 7.2 installer on JetPack 6. The script intentionally stops when it detects Ubuntu 22.04.

For a long-lived robot already validated on JetPack 6, keep that software stack frozen and maintain a separate installer branch. Do not perform an in-place major JetPack upgrade on a production robot without full sensor, driver, timing, inference, and hardware-in-the-loop regression testing.

## 18. Reproducibility and maintenance

The script pins the most failure-sensitive AI packages:

```text
PyTorch      2.13.0+cu130
TorchVision  0.28.0+cu130
NumPy        1.26.4
Ultralytics  8.4.112
```

Before changing these versions:

1. Confirm an ARM64 wheel exists.
2. Confirm the CUDA wheel matches the JetPack runtime.
3. Confirm the PyTorch/TorchVision version pair.
4. Test `torch.cuda.is_available()`.
5. Test `cv2`, `cv_bridge`, and image transport.
6. Re-export TensorRT engines.
7. Run robot-level regression tests.

For production deployments, record:

```bash
cat /etc/os-release
cat /etc/nv_tegra_release 2>/dev/null || true
dpkg-query -W nvidia-l4t-core nvidia-jetpack
python -m pip freeze
ros2 doctor --report
```

Store that output with the robot software release.

## 19. Security and licensing

- Review the license of every ROS package, model, dataset, and Python dependency used by the project.
- Ultralytics is distributed under AGPL-3.0 with commercial licensing options. Review the terms for closed-source or commercial deployment.
- Do not expose ROS 2 DDS traffic directly to an untrusted network.
- Use least-privilege device permissions instead of running robot software as root.
- Pin dependencies and review updates before deploying them to a physical robot.

## Official references

- [NVIDIA JetPack](https://developer.nvidia.com/embedded/jetpack)
- [JetPack 7.2 release information](https://developer.nvidia.com/embedded/jetpack/downloads/archive-7.2)
- [NVIDIA PyTorch for Jetson](https://docs.nvidia.com/deeplearning/frameworks/install-pytorch-jetson-platform/)
- [PyTorch installation](https://pytorch.org/get-started/locally/)
- [PyTorch CUDA 13.0 ARM64 wheel index](https://download.pytorch.org/whl/cu130/torch/)
- [ROS 2 Jazzy installation](https://docs.ros.org/en/jazzy/Installation/Ubuntu-Install-Debs.html)
- [ROS apt-source repository](https://github.com/ros-infrastructure/ros-apt-source)
- [Ultralytics installation](https://docs.ultralytics.com/quickstart/)
- [Ultralytics on NVIDIA Jetson](https://docs.ultralytics.com/guides/nvidia-jetson/)
- [TorchVision compatibility matrix](https://github.com/pytorch/vision#installation)

## Disclaimer

This installer is intended for a newly flashed development kit. Review every command before using it on a production robot. Back up calibration files, udev rules, network configuration, custom kernels, device-tree changes, and robot-specific services before modifying an existing system.
