#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
MODEL_PATH="${1:-/root/work/npu2/rknn-toolkit2-v2.4.0/rknn-toolkit2-v2.4.0-2026-01-17/rknpu2/examples/rknn_yolov5_demo/model/RK3566_RK3568/yolov5s-640-640.rknn}"
NUM_RUNS="${2:-30}"
NPU_GOVERNOR="${RKNPU_BENCH_NPU_GOVERNOR:-performance}"
CPU_GOVERNOR="${RKNPU_BENCH_CPU_GOVERNOR:-performance}"
NPU_DEVFREQ="/sys/class/devfreq/fde40000.npu"
IDLE_WAIT_SECONDS="${RKNPU_BENCH_IDLE_WAIT_SECONDS:-60}"
IDLE_POLL_SECONDS="${RKNPU_BENCH_IDLE_POLL_SECONDS:-5}"
LOADAVG1_MAX="${RKNPU_BENCH_LOADAVG1_MAX:-1.50}"
TOP_LINES="${RKNPU_BENCH_TOP_LINES:-12}"

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

show_top()
{
    top -bn1 | sed -n "1,${TOP_LINES}p"
}

show_busy_processes()
{
    pgrep -af '^zfs snapshot ' || true
}

board_is_idle()
{
    local loadavg1

    loadavg1=$(awk '{print $1}' /proc/loadavg)
    if ! awk -v current="$loadavg1" -v max="$LOADAVG1_MAX" 'BEGIN { exit !(current <= max) }'; then
        return 1
    fi

    if pgrep -f '^zfs snapshot ' >/dev/null 2>&1; then
        return 1
    fi

    return 0
}

wait_for_idle()
{
    local waited=0

    while ! board_is_idle; do
        if [ "$waited" -ge "$IDLE_WAIT_SECONDS" ]; then
            echo "ERROR: board did not become idle within ${IDLE_WAIT_SECONDS}s"
            echo "Load average: $(cut -d' ' -f1-3 /proc/loadavg)"
            show_busy_processes
            show_top
            exit 1
        fi

        echo "== waiting for idle board state =="
        echo "Load average: $(cut -d' ' -f1-3 /proc/loadavg)"
        show_busy_processes
        show_top
        sleep "$IDLE_POLL_SECONDS"
        waited=$((waited + IDLE_POLL_SECONDS))
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
    echo "Load average: $(cut -d' ' -f1-3 /proc/loadavg)"
    show_busy_processes
    show_top
}

trap restore_governors EXIT

echo "$NPU_GOVERNOR" > "$NPU_DEVFREQ/governor"
for policy in "${CPU_POLICIES[@]}"; do
    echo "$CPU_GOVERNOR" > "$policy/scaling_governor"
done
sleep 1
wait_for_idle

echo "== pinned benchmark state before =="
show_state
python3 "$SCRIPT_DIR/bench_yolov5.py" "$MODEL_PATH" "$NUM_RUNS"
echo "== pinned benchmark state after =="
show_state
