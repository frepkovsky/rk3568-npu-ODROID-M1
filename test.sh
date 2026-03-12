#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
INPUT="${1:-}"
OUTPUT="${2:-${INPUT%.*}-yolo11n-out.png}"
REPO_URL="${REPO_URL:-https://github.com/airockchip/rknn_model_zoo.git}"
MODEL_ZOO_DIR="${MODEL_ZOO_DIR:-$SCRIPT_DIR/project/rknn_model_zoo/src}"
INSTALL_DIR_REL="install/rk356x_linux_aarch64/rknn_yolo11_demo"
MODEL_REL="examples/yolo11/model/yolo11n_rk3568.rknn"

fail() {
    echo "ERROR: $*" >&2
    exit 1
}

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || fail "Required command not found: $1"
}

if [ -z "$INPUT" ]; then
    echo "Usage: $0 <input-image> [output-image]"
    exit 1
fi

if [ ! -f "$INPUT" ]; then
    echo "ERROR: Input file not found: $INPUT"
    exit 1
fi

if [ "$(uname -m)" != "aarch64" ]; then
    fail "This test must run on the ODROID-M1 itself (expected aarch64)"
fi

require_cmd git
require_cmd python3
require_cmd wget
require_cmd cmake
require_cmd make
require_cmd aarch64-linux-gnu-gcc
require_cmd aarch64-linux-gnu-g++

if [ ! -e /dev/rknpu ]; then
    fail "/dev/rknpu not found; install the NPU driver first"
fi

if ! grep -q '^rknpu\b' /proc/modules; then
    fail "rknpu module is not loaded; install and activate the NPU driver first"
fi

INPUT="$(cd "$(dirname "$INPUT")" && pwd)/$(basename "$INPUT")"
mkdir -p "$(dirname "$OUTPUT")"
OUTPUT="$(cd "$(dirname "$OUTPUT")" && pwd)/$(basename "$OUTPUT")"
rm -f "$OUTPUT"

MODEL_PATH="$MODEL_ZOO_DIR/$MODEL_REL"
INSTALL_DIR="$MODEL_ZOO_DIR/$INSTALL_DIR_REL"
LOCAL_OUTPUT="$INSTALL_DIR/out.png"

echo "=== YOLO11n NPU Test ==="
echo "Input:  $INPUT"
echo "Output: $OUTPUT"
echo "Model zoo: $MODEL_ZOO_DIR"
echo ""

echo "[1/4] Checking local prerequisites..."
echo "NPU driver and required tools are present."

echo "[2/4] Preparing local checkout..."
mkdir -p "$(dirname "$MODEL_ZOO_DIR")"
if [ -d "$MODEL_ZOO_DIR/.git" ]; then
    git -C "$MODEL_ZOO_DIR" pull --ff-only
else
    rm -rf "$MODEL_ZOO_DIR"
    git clone --depth 1 "$REPO_URL" "$MODEL_ZOO_DIR"
fi

if [ ! -f "$MODEL_ZOO_DIR/build-linux.sh" ]; then
    fail "Upstream checkout is missing build-linux.sh"
fi

if [ ! -f "$MODEL_ZOO_DIR/examples/yolo11/model/download_model.sh" ]; then
    fail "Upstream checkout is missing examples/yolo11/model/download_model.sh"
fi

if [ ! -f "$MODEL_ZOO_DIR/examples/yolo11/python/convert.py" ]; then
    fail "Upstream checkout is missing examples/yolo11/python/convert.py"
fi

echo "[3/4] Building and running C++ YOLO11n demo on M1..."
cd "$MODEL_ZOO_DIR"
if [ ! -f "$MODEL_PATH" ]; then
    cd "$MODEL_ZOO_DIR/examples/yolo11/model"
    bash ./download_model.sh
    if [ ! -f "$MODEL_ZOO_DIR/examples/yolo11/model/yolo11n.onnx" ]; then
        fail "yolo11n.onnx download failed"
    fi
    cd "$MODEL_ZOO_DIR/examples/yolo11/python"
    python3 ./convert.py ../model/yolo11n.onnx rk3568 i8 ../model/yolo11n_rk3568.rknn
fi

cd "$MODEL_ZOO_DIR"
bash ./build-linux.sh -t rk3568 -a aarch64 -d yolo11

if [ ! -x "$INSTALL_DIR/rknn_yolo11_demo" ]; then
    fail "rknn_yolo11_demo not built"
fi

if [ ! -f "$MODEL_PATH" ]; then
    fail "yolo11n_rk3568.rknn not found in cloned repo"
fi

rm -f "$LOCAL_OUTPUT"
export LD_LIBRARY_PATH="$INSTALL_DIR/lib:${LD_LIBRARY_PATH:-}"
cd "$INSTALL_DIR"
./rknn_yolo11_demo "$MODEL_PATH" "$INPUT"

if [ ! -f "$LOCAL_OUTPUT" ]; then
    fail "out.png not produced"
fi

echo "[4/4] Saving output image..."
cp "$LOCAL_OUTPUT" "$OUTPUT"

echo ""
echo "=== DONE ==="
echo "Result saved: $OUTPUT"
