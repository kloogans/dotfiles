#!/bin/bash
HOUR=$(date +%-H)
DAY=$(date +%A)
UPTIME=$(uptime -p | sed 's/up //')
CPU=$(awk '{printf "%.0f", $1 * 100 / '"$(nproc)"'}' /proc/loadavg)
MEM=$(free -m | awk '/Mem:/{printf "%.0f", $3/$2*100}')
WEATHER=$(cat /tmp/waybar-weather-raw 2>/dev/null || echo "unknown")

PROMPT="You are a tiny status bar personality living in a Linux desktop. Generate a SHORT witty status message (max 6 words). Be dry, sarcastic, or oddly philosophical. No quotes, no emoji, no hashtags.

Context: It's $DAY, ${HOUR}:00. System up $UPTIME. CPU ${CPU}%, RAM ${MEM}%. Weather: $WEATHER."

MSG=$(curl -sf http://127.0.0.1:11434/api/generate -d "{\"model\":\"qwen3:14b\",\"prompt\":$(echo "$PROMPT" | jq -Rs .),\"stream\":false}" 2>/dev/null | jq -r '.response // empty' | tr -d '\n' | head -c 50)

if [ -z "$MSG" ]; then
    MSG="ollama is napping"
fi

MSG=$(echo "$MSG" | sed 's/"/\\"/g')

printf '{"text": "%s", "tooltip": "%s · CPU %s%% · RAM %s%%", "class": "active"}\n' "$MSG" "$DAY" "$CPU" "$MEM"
