#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
MODEL_PATH="${1:-/root/work/npu2/rknn-toolkit2-v2.4.0/rknn-toolkit2-v2.4.0-2026-01-17/rknpu2/examples/rknn_yolov5_demo/model/RK3566_RK3568/yolov5s-640-640.rknn}"
NUM_RUNS="${2:-30}"
NPU_GOVERNOR="${RKNPU_BENCH_NPU_GOVERNOR:-performance}"
CPU_GOVERNOR="${RKNPU_BENCH_CPU_GOVERNOR:-performance}"
NPU_DEVFREQ="/sys/class/devfreq/fde40000.npu"

if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: run as root"
    exit 1
fi

if [ ! -d "$NPU_DEVFREQ" ]; then
    echo "ERROR: missing $NPU_DEVFREQ"
    exit 1
fi

declare -a CPU_POLICIES=()
declare -a CPU_GOVERNORS=()
for policy in /sys/devices/system/cpu/cpufreq/policy*; do
    [ -d "$policy" ] || continue
    CPU_POLICIES+=("$policy")
    CPU_GOVERNORS+=("$(cat "$policy/scaling_governor")")
done

ORIG_NPU_GOVERNOR=$(cat "$NPU_DEVFREQ/governor")

restore_governors()
{
    echo "$ORIG_NPU_GOVERNOR" > "$NPU_DEVFREQ/governor" || true
    for i in "${!CPU_POLICIES[@]}"; do
        echo "${CPU_GOVERNORS[$i]}" > "${CPU_POLICIES[$i]}/scaling_governor" || true
    done
}

show_state()
{
    echo "NPU governor: $(cat "$NPU_DEVFREQ/governor")"
    echo "NPU cur_freq: $(cat "$NPU_DEVFREQ/cur_freq")"
    echo "NPU min_freq: $(cat "$NPU_DEVFREQ/min_freq")"
    echo "NPU max_freq: $(cat "$NPU_DEVFREQ/max_freq")"
    if [ -r /proc/rknpu/load ]; then
        echo "$(cat /proc/rknpu/load)"
    fi
    for policy in "${CPU_POLICIES[@]}"; do
        name=$(basename "$policy")
        echo "$name governor: $(cat "$policy/scaling_governor")"
        echo "$name cur_freq: $(cat "$policy/scaling_cur_freq")"
    done
    for zone in /sys/class/thermal/thermal_zone*; do
        [ -d "$zone" ] || continue
        echo "$(basename "$zone") $(cat "$zone/type") $(cat "$zone/temp")"
    done
}

trap restore_governors EXIT

echo "$NPU_GOVERNOR" > "$NPU_DEVFREQ/governor"
for policy in "${CPU_POLICIES[@]}"; do
    echo "$CPU_GOVERNOR" > "$policy/scaling_governor"
done
sleep 1

echo "== pinned benchmark state before =="
show_state
python3 "$SCRIPT_DIR/bench_yolov5.py" "$MODEL_PATH" "$NUM_RUNS"
echo "== pinned benchmark state after =="
show_state
