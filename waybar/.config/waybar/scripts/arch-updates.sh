#!/bin/bash
# Waybar module: Arch update checker (pacman + AUR)

official=$(checkupdates 2>/dev/null | wc -l)
aur=$(yay -Qua 2>/dev/null | wc -l)
total=$((official + aur))

if [ "$total" -eq 0 ]; then
    echo '{"text": "", "tooltip": "System is up to date", "class": "updated"}'
else
    tooltip="${official} official, ${aur} AUR"
    echo "{\"text\": \"󰏔  ${total}\", \"tooltip\": \"${tooltip}\", \"class\": \"pending\"}"
fi
