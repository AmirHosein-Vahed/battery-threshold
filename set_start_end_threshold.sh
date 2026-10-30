#!/usr/bin/env bash
set -euo pipefail

# Default thresholds (used if no arguments are passed)
DEFAULT_START=40
DEFAULT_END=80

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS] [START_THRESHOLD] [END_THRESHOLD]

Automatically detects batteries supporting charge thresholds and sets or displays them.

Arguments:
  START_THRESHOLD   Start charging below this % (default: $DEFAULT_START)
  END_THRESHOLD     Stop charging at this % (default: $DEFAULT_END)

Options:
  -s, --status      Display current battery thresholds without modifying them
  -h, --help        Show this help message

Examples:
  $(basename "$0")            # Sets thresholds to default ${DEFAULT_START}% and ${DEFAULT_END}%
  $(basename "$0") 50 85      # Sets start to 50% and end to 85%
  $(basename "$0") --status   # Shows current thresholds
EOF
}

STATUS_ONLY=false

# Parse flags
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
elif [[ "${1:-}" == "-s" || "${1:-}" == "--status" ]]; then
    STATUS_ONLY=true
fi

START_VAL="${1:-$DEFAULT_START}"
END_VAL="${2:-$DEFAULT_END}"

# Validate inputs if we are setting values
if [[ "$STATUS_ONLY" == false ]]; then
    if ! [[ "$START_VAL" =~ ^[0-9]+$ ]] || ! [[ "$END_VAL" =~ ^[0-9]+$ ]]; then
        echo "Error: Thresholds must be positive integers." >&2
        exit 1
    fi
    if (( START_VAL < 0 || END_VAL > 100 || START_VAL >= END_VAL )); then
        echo "Error: Must satisfy 0 <= START ($START_VAL) < END ($END_VAL) <= 100." >&2
        exit 1
    fi
fi

# Locate all batteries in /sys/class/power_supply/
shopt -s nullglob
BATTERIES=(/sys/class/power_supply/BAT*)
shopt -u nullglob

if [[ ${#BATTERIES[@]} -eq 0 ]]; then
    echo "Error: No battery detected in /sys/class/power_supply/BAT*" >&2
    exit 1
fi

FOUND_SUPPORTED=false

for bat in "${BATTERIES[@]}"; do
    bat_name=$(basename "$bat")
    start_file="$bat/charge_control_start_threshold"
    end_file="$bat/charge_control_end_threshold"

    # Check if this battery supports threshold control
    if [[ ! -f "$start_file" && ! -f "$end_file" ]]; then
        continue
    fi

    FOUND_SUPPORTED=true
    echo "=== Battery: $bat_name ==="

    if [[ "$STATUS_ONLY" == false ]]; then
        echo "Applying thresholds (Start: ${START_VAL}%, End: ${END_VAL}%)..."

        # Read current end threshold to avoid invalid state transitions
        # (The kernel rejects start_threshold > current end_threshold)
        cur_end=100
        [[ -f "$end_file" ]] && cur_end=$(cat "$end_file")

        if (( START_VAL > cur_end )); then
            [[ -f "$end_file" ]]   && echo "$END_VAL"   | sudo tee "$end_file" > /dev/null
            [[ -f "$start_file" ]] && echo "$START_VAL" | sudo tee "$start_file" > /dev/null
        else
            [[ -f "$start_file" ]] && echo "$START_VAL" | sudo tee "$start_file" > /dev/null
            [[ -f "$end_file" ]]   && echo "$END_VAL"   | sudo tee "$end_file" > /dev/null
        fi
    fi

    # Read and display active values
    [[ -f "$start_file" ]] && echo "  Start Threshold : $(cat "$start_file")%"
    [[ -f "$end_file" ]]   && echo "  End Threshold   : $(cat "$end_file")%"
done

if [[ "$FOUND_SUPPORTED" == false ]]; then
    echo "Error: Found battery (${BATTERIES[*]}), but charge threshold files are not supported by your kernel/hardware." >&2
    exit 1
fi
