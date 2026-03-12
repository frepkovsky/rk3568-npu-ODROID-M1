# Rockchip RKNPU — DKMS Driver for ODROID-M1

DKMS kernel modules to enable the 0.8 TOPS RKNN NPU on the ODROID-M1 (RK3568) running Armbian mainline kernels.

## What's Included

| Component | Description |
|-----------|-------------|
| `drivers/rknpu/` | RKNPU kernel driver (DKMS) — DRM/GEM, devfreq, IOMMU, fence, debugfs, procfs |
| `dma32-heap/` | DMA32 heap module installed by `install.sh` |
| `dtb/` | Custom device tree blob with NPU, IOMMU, and OPP table nodes |
| `overlays/rknpu.dts` | Device tree overlay — enables NPU power domain, regulator, clocks, thermal |
| `install.sh` | One-shot installer |
| `uninstall.sh` | Uninstalls the DKMS modules and installed boot/runtime configuration |
| `test.sh` | Fresh-checkout YOLO11n smoke test that builds and runs the upstream C++ demo on the M1 |

## Requirements

- ODROID-M1 (Rockchip RK3568) with Armbian
- Kernel ≥ 6.18 with headers installed
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

The installer configures everything including `/boot/armbianEnv.txt` (backup saved as `.pre-npu`).

## Uninstall

```bash
sudo ./uninstall.sh
sudo reboot
```

The uninstaller removes the installed DKMS modules, DTB/overlay artifacts, udev rules, autoload files, and restores the relevant `/boot/armbianEnv.txt` settings.

## Verify

```bash
lsmod | grep rknpu           # rknpu module loaded
ls /dev/rknpu                # misc device
ls -la /dev/dma_heap/system  # symlink -> dma32
dmesg | grep RKNPU           # probe ok, no errors
```

## Tests

The repository currently ships a single end-to-end smoke test: `test.sh`.

Run it directly on the ODROID-M1 after installing the driver. It creates or updates a fresh local checkout of `airockchip/rknn_model_zoo` under `/tmp/project/rknn_model_zoo/src`, builds the upstream Linux C++ `yolo11` demo, runs YOLO11n inference on one image, and saves the generated `out.png` to the output path you pass in.

```bash
./test.sh input.jpg
./test.sh input.jpg output.png
MODEL_ZOO_DIR=/tmp/project/rknn_model_zoo/src ./test.sh input.jpg output.png
```

- The test expects the NPU driver to be installed and `/dev/rknpu` to exist on the target board.
- The inference path itself is C++ (`rknn_yolo11_demo`).
- The script is intended to be run locally on the M1, not from a separate host.
- A fresh upstream checkout does not currently ship `examples/yolo11/model/yolo11n_rk3568.rknn`. If that file is missing, `test.sh` performs a one-time upstream ONNX download plus RKNN conversion on the M1 before running the C++ demo.

## Armbian Support

- Supported Armbian release baseline: **v26.2.1** (**May 2026 release stream**) or newer.
- `v26.2.1` is an Armbian release version, not a Linux kernel version.
- Required Armbian-side update: `armbian/build#9403`.
- Repository kernel compatibility target: **Linux `6.18+`**.
- Validated baseline: `6.18.9-current-rockchip64`.

## Device Tree

The stock Armbian DTB does not include NPU hardware nodes. Two pieces are needed:

**Custom DTB** (`dtb/rk3568-odroid-m1-npu.dtb`) adds the base hardware nodes:
- NPU node (`npu@fde40000`) — compatible, reg, interrupts, clocks, resets
- IOMMU node (`iommu@fde4b000`) — NPU memory management unit
- OPP table (`npu-opp-table`) — DVFS frequency/voltage pairs (200–1000 MHz)

**Overlay** (`overlays/rknpu.dts`) enables power and wiring on top of the DTB:
- **PD6** (NPU power domain) — `status = "okay"`
- **vdd_npu regulator** — `regulator-always-on`, `regulator-boot-on`
- **Power domain wiring** — NPU and IOMMU linked to PD6
- **SCMI + CRU clocks** — full clock tree for DVFS up to 1000 MHz
- **Thermal throttling** — NPU bound to CPU and GPU thermal zones
- **SRAM** — 44 KB shared SRAM for NPU acceleration

Both are installed automatically by `install.sh`. Without them the NPU power domain stays off and the driver crashes on MMIO access.

## Features

| Feature | Status |
|---------|--------|
| DRM render node `/dev/dri/renderD129` | ✅ Present |
| IOMMU (translated mode) | ✅ |
| Devfreq (DVFS, simple_ondemand) | ✅ |
| Thermal throttling | ✅ |
| `/dev/rknpu` misc device | ✅ |
| Debugfs / Procfs | ✅ |
| Fence sync | ✅ |
| ODROID-M1 8 GB runtime | ✅ |
| SCMI clock (200–1000 MHz) | ✅ |
| SRAM acceleration (44 KB) | ✅ |

## Tested With

- **Board:** ODROID-M1 8 GB
- **Kernel:** 6.18.9-current-rockchip64 (Armbian)
- **RKNN SDK:** 2.4.0
- **Driver version:** 0.9.8
- **Inference:** YOLOv5s 42.4 ms avg @ 1000 MHz, YOLO11n working

## License

The RKNPU driver is derived from [Rockchip's kernel sources](https://github.com/rockchip-linux/kernel) and is licensed under GPL-2.0. See individual source files for details.
