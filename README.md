# Rockchip RKNPU — DKMS Driver for ODROID-M1

DKMS kernel modules and boot configuration for enabling the RK3568 RKNN NPU on the ODROID-M1 under Armbian mainline kernels.

## Supported Platform

- **Board:** ODROID-M1
- **SoC:** Rockchip RK3568
- **Armbian baseline:** `v26.2.1` or newer
- **Kernel target:** Linux `6.18+`
- **Validated baseline:** `6.18.9-current-rockchip64`
- **RKNN SDK/runtime tested:** `2.4.0`
- **NPU frequency range:** SCMI-managed `200–1000 MHz`

## What the Repository Contains

| Component | Description |
|-----------|-------------|
| `drivers/rknpu/` | RKNPU DKMS driver with DRM/GEM, misc device, devfreq, IOMMU, fence, debugfs, procfs, and SRAM support |
| `dma32-heap/` | DMA heap DKMS module used by the installed runtime setup |
| `dtb/` | Custom ODROID-M1 DTB source with NPU, IOMMU, and OPP nodes |
| `overlays/rknpu.dts` | Overlay enabling power, clocks, regulator, thermal bindings, and SRAM wiring |
| `install.sh` | Installer for DKMS modules, DTB, overlay, udev rules, and boot configuration |
| `uninstall.sh` | Uninstaller that removes installed artifacts and restores boot configuration |
| `test.sh` | End-to-end YOLO11n smoke test on the target board |
| `tests/` | Direct-allocation, DRM GEM, thermal, and benchmark utilities |

## Requirements

- ODROID-M1 running Armbian
- Linux kernel headers for the running `rockchip64` kernel
- Packages: `dkms`, `build-essential`, `device-tree-compiler`

```bash
apt install dkms build-essential device-tree-compiler linux-headers-current-rockchip64
```

## Install

```bash
git clone https://github.com/vitalijborissow/rk3568-npu-ODROID-M1.git
cd rk3568-npu-ODROID-M1
sudo ./install.sh
sudo reboot
```

`install.sh` performs the full supported setup:

- installs `rknpu` DKMS package version `1.0`
- installs `dma32-heap` DKMS package version `1.0`
- compiles and installs `dtb/rk3568-odroid-m1-npu.dts`
- installs `/boot/overlay-user/rknpu.dtbo`
- creates module autoload entries for `rknpu`, `dma32_heap`, and devfreq governors
- installs the `/dev/dma_heap/system -> /dev/dma_heap/dma32` udev rule
- updates `/boot/armbianEnv.txt` and saves a one-time backup as `/boot/armbianEnv.txt.pre-npu`

## Boot Configuration

The supported runtime uses both a custom DTB and the checked-in overlay.

`install.sh` configures `/boot/armbianEnv.txt` with:

```text
fdtfile=rockchip/rk3568-odroid-m1-npu.dtb
user_overlays=rknpu
```

This is required because the stock Armbian DTB does not provide the complete NPU, IOMMU, OPP, and power-domain wiring used by this repository.

## Uninstall

```bash
sudo ./uninstall.sh
sudo reboot
```

The uninstaller removes the DKMS modules, DTB and overlay artifacts, autoload files, udev rules, and restores the relevant `/boot/armbianEnv.txt` settings from the saved backup when present.

## Verify

After reboot, the expected runtime state is:

```bash
lsmod | grep -E '^(rknpu|dma32_heap)\b'
ls -l /dev/rknpu /dev/dri/by-path/platform-fde40000.npu-render /dev/dma_heap/system /dev/dma_heap/dma32
cat /sys/class/devfreq/fde40000.npu/governor
dmesg | grep -i rknpu
```

Key expectations:

- `/dev/rknpu` exists
- `/dev/dri/by-path/platform-fde40000.npu-render` exists and points to the active render node
- `/dev/dma_heap/system` is a symlink to `/dev/dma_heap/dma32`
- `/sys/class/devfreq/fde40000.npu` exists

## Runtime Features

| Feature | Status |
|---------|--------|
| Misc device `/dev/rknpu` | ✅ Working |
| DRM render node | ✅ Working |
| IOMMU translated mode | ✅ Working |
| Devfreq / DVFS | ✅ Working |
| Thermal throttling | ✅ Working |
| Debugfs and procfs | ✅ Working |
| Fence sync | ✅ Working |
| SRAM support | ✅ Working |
| DMA heap integration | ✅ Working |

## Tests and Benchmarks

### End-to-End Smoke Test

`test.sh` runs a local YOLO11n inference smoke test on the M1 using the upstream RKNN model zoo C++ demo.

```bash
./test.sh input.jpg
./test.sh input.jpg output.png
MODEL_ZOO_DIR=/tmp/project/rknn_model_zoo/src ./test.sh input.jpg output.png
```

### Targeted Runtime Checks

- `tests/test_direct_alloc.c` verifies the misc-device direct-allocation and DMA-BUF import path
- `tests/test_drm_gem.c` verifies DRM GEM create/map on the NPU render node

### Benchmarks

- `tests/bench_yolov5.py` measures RKNNLite YOLOv5 inference latency
- `tests/bench_yolov5_pinned.sh` pins CPU and NPU governors and waits for an idle board state before measuring

The current validated performance reference includes:

- YOLOv5s 640×640 via C API: `42.4 ms` average at `1000 MHz`
- YOLOv5s 640×640 via Python RKNNLite and idle-aware pinned benchmark: about `85–86 ms` average, about `11.7 FPS`
- YOLO11n smoke test: working on the target board

## Device Tree Layout

The supported boot configuration is split into two layers:

- `dtb/rk3568-odroid-m1-npu.dts` provides the base NPU, IOMMU, and OPP nodes
- `overlays/rknpu.dts` enables PD6, regulator wiring, clocks, thermal bindings, and SRAM-related settings

Without this DTB and overlay combination the NPU power domain does not come up in the required runtime state.

## Known Limitations

- The RKNN userspace library hardcodes the `system` DMA heap name, so the installer provides a udev symlink to `dma32`
- `vdd_npu` must remain `regulator-always-on`; disabling it causes a PD6 power-domain crash
- SCMI reports approximate low-end frequencies such as `198/297/396 MHz`
- Frequencies above `1000 MHz` are not supported on this board and firmware combination

## Tested With

- **Board:** ODROID-M1 8 GB
- **Kernel:** `6.18.9-current-rockchip64`
- **RKNN SDK/runtime:** `2.4.0`
- **DKMS package version:** `1.0`
- **Runtime driver string:** `0.9.8`

## License

The RKNPU driver is derived from [Rockchip's kernel sources](https://github.com/rockchip-linux/kernel) and is licensed under GPL-2.0. See individual source files for details.
