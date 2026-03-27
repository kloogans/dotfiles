#!/bin/bash
DATA=$(nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total,temperature.gpu --format=csv,noheader,nounits 2>/dev/null)
IFS=', ' read -r UTIL VRAM_USED VRAM_TOTAL TEMP <<< "$DATA"
printf '{"text": "<span color=\u0027#b4befe\u0027>󰢮</span>  %s%%", "tooltip": "VRAM: %s/%s MiB · %s°C"}\n' "$UTIL" "$VRAM_USED" "$VRAM_TOTAL" "$TEMP"
