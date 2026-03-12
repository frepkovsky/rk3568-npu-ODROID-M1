#!/bin/bash
set -euo pipefail

INPUT="${1:-}"
OUTPUT="${2:-${INPUT%.*}-yolo11n-out.png}"
SSH_HOST="${SSH_HOST:-m1}"
REPO_URL="${REPO_URL:-https://github.com/airockchip/rknn_model_zoo.git}"
REMOTE_REPO="${REMOTE_REPO:-/tmp/project/rknn_model_zoo/yolo11n}"
INSTALL_DIR_REL="install/rk356x_linux_aarch64/rknn_yolo11_demo"
MODEL_REL="examples/yolo11/model/yolo11n_rk3568.rknn"
ONNX_REL="examples/yolo11/model/yolo11n.onnx"

if [ -z "$INPUT" ]; then
    echo "Usage: $0 <input-image> [output-image]"
    exit 1
fi

if [ ! -f "$INPUT" ]; then
    echo "ERROR: Input file not found: $INPUT"
    exit 1
fi

mkdir -p "$(dirname "$OUTPUT")"
rm -f "$OUTPUT"

INPUT_BASENAME="$(basename "$INPUT")"
REMOTE_INPUT="$REMOTE_REPO/$INPUT_BASENAME"
REMOTE_OUTPUT="$REMOTE_REPO/$INSTALL_DIR_REL/out.png"

echo "=== YOLO11n NPU Test ==="
echo "Input:  $INPUT"
echo "Output: $OUTPUT"
echo "Host:   $SSH_HOST"
echo ""

echo "[1/4] Preparing remote checkout..."
ssh "$SSH_HOST" "set -euo pipefail; mkdir -p '$(dirname "$REMOTE_REPO")'; if [ -d '$REMOTE_REPO/.git' ]; then git -C '$REMOTE_REPO' pull --ff-only; else rm -rf '$REMOTE_REPO'; git clone --depth 1 '$REPO_URL' '$REMOTE_REPO'; fi"

echo "[2/4] Uploading input image..."
scp "$INPUT" "$SSH_HOST:$REMOTE_INPUT"

echo "[3/4] Building and running C++ YOLO11n demo on M1..."
ssh "$SSH_HOST" "set -euo pipefail; \
    if ! lsmod | grep -q '^rknpu\\b'; then modprobe rknpu || true; fi; \
    if [ ! -e /dev/rknpu ]; then echo 'ERROR: /dev/rknpu not found' >&2; exit 2; fi; \
    cd '$REMOTE_REPO'; \
    MODEL_PATH='$REMOTE_REPO/$MODEL_REL'; \
    ONNX_PATH='$REMOTE_REPO/$ONNX_REL'; \
    if [ ! -f \"\$MODEL_PATH\" ]; then \
        cd '$REMOTE_REPO/examples/yolo11/model'; \
        bash ./download_model.sh; \
        cd '$REMOTE_REPO/examples/yolo11/python'; \
        python3 ./convert.py ../model/yolo11n.onnx rk3568 i8 ../model/yolo11n_rk3568.rknn; \
    fi; \
    cd '$REMOTE_REPO'; \
    bash ./build-linux.sh -t rk3568 -a aarch64 -d yolo11; \
    INSTALL_DIR='$REMOTE_REPO/$INSTALL_DIR_REL'; \
    if [ ! -x \"\$INSTALL_DIR/rknn_yolo11_demo\" ]; then echo 'ERROR: rknn_yolo11_demo not built' >&2; exit 3; fi; \
    if [ ! -f \"\$MODEL_PATH\" ]; then echo 'ERROR: yolo11n_rk3568.rknn not found in cloned repo' >&2; exit 4; fi; \
    rm -f '$REMOTE_OUTPUT'; \
    export LD_LIBRARY_PATH=\"\$INSTALL_DIR/lib:\${LD_LIBRARY_PATH:-}\"; \
    cd \"\$INSTALL_DIR\"; \
    ./rknn_yolo11_demo \"\$MODEL_PATH\" '$REMOTE_INPUT'; \
    if [ ! -f '$REMOTE_OUTPUT' ]; then echo 'ERROR: out.png not produced' >&2; exit 5; fi"

echo "[4/4] Fetching output image..."
scp "$SSH_HOST:$REMOTE_OUTPUT" "$OUTPUT"

echo ""
echo "=== DONE ==="
echo "Result saved: $OUTPUT"
