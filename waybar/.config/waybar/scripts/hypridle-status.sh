#!/bin/bash
hypridle_ok=false
failsafe_ok=false
watchdog_ok=false

pgrep -x hypridle &>/dev/null && hypridle_ok=true
systemctl --user is-active hypridle-failsafe &>/dev/null && failsafe_ok=true
systemctl --user is-active hypridle-watchdog.timer &>/dev/null && watchdog_ok=true

tooltip="hypridle: $hypridle_ok\nfailsafe: $failsafe_ok\nwatchdog: $watchdog_ok"

if $hypridle_ok && $failsafe_ok && $watchdog_ok; then
    echo "{\"text\": \"󰒲\", \"tooltip\": \"$tooltip\", \"class\": \"ok\"}"
else
    # Try to fix whatever is broken
    $hypridle_ok || systemctl --user restart hypridle 2>/dev/null
    $failsafe_ok || systemctl --user restart hypridle-failsafe 2>/dev/null
    $watchdog_ok || systemctl --user restart hypridle-watchdog.timer 2>/dev/null
    echo "{\"text\": \"󰒲\", \"tooltip\": \"RESTARTING — $tooltip\", \"class\": \"dead\"}"
fi
