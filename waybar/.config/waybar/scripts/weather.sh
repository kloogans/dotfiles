#!/bin/bash

CACHE="$HOME/.cache/waybar-weather.json"
CACHE_AGE=1800  # 30 minutes

mkdir -p "$(dirname "$CACHE")"

# Use cache if fresh enough
if [[ -f "$CACHE" ]]; then
  AGE=$(( $(date +%s) - $(stat -c %Y "$CACHE") ))
  if [[ "$AGE" -lt "$CACHE_AGE" ]]; then
    cat "$CACHE"
    exit 0
  fi
fi

DATA=$(curl -sf "https://wttr.in/33714?format=j1" 2>/dev/null)

if [[ -z "$DATA" ]]; then
  echo '{"text": "??°F", "tooltip": "Weather unavailable"}'
  exit 0
fi

TEMP_F=$(echo "$DATA" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['current_condition'][0]['temp_F'])" 2>/dev/null)
FEELS_F=$(echo "$DATA" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['current_condition'][0]['FeelsLikeF'])" 2>/dev/null)
DESC=$(echo "$DATA" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['current_condition'][0]['weatherDesc'][0]['value'])" 2>/dev/null)
HUMIDITY=$(echo "$DATA" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['current_condition'][0]['humidity'])" 2>/dev/null)
WIND=$(echo "$DATA" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['current_condition'][0]['windspeedMiles'])" 2>/dev/null)

# Nerd Font weather icons
case "${DESC,,}" in
  *sun*|*clear*)    ICON=$'\ue30d' ;;
  *partly*cloud*)   ICON=$'\ue302' ;;
  *cloud*)          ICON=$'\ue312' ;;
  *rain*|*drizzle*) ICON=$'\ue318' ;;
  *thunder*)        ICON=$'\ue31d' ;;
  *snow*)           ICON=$'\ue31a' ;;
  *fog*|*mist*)     ICON=$'\ue313' ;;
  *overcast*)       ICON=$'\ue312' ;;
  *)                ICON=$'\ue302' ;;
esac

OUTPUT=$(python3 -c "
import json, sys
icon = sys.argv[1]
print(json.dumps({
    'text': f'{icon} ${TEMP_F}°F',
    'tooltip': '${DESC}\nFeels like ${FEELS_F}°F\nHumidity ${HUMIDITY}%\nWind ${WIND} mph',
    'class': 'weather'
}))
" "$ICON")

echo "$OUTPUT" | tee "$CACHE"
