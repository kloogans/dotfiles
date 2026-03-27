#!/bin/bash
# Post-cwal hook: copies generated colors to app config locations
CACHE="$HOME/.cache/cwal"

# Ghostty
cp "$CACHE/ghostty.conf" "$HOME/.config/ghostty/theme.conf" 2>/dev/null

# Waybar (catppuccin-compatible mapping)
cp "$CACHE/colors-waybar-catppuccin.css" "$HOME/.config/waybar/colors-cwal.css" 2>/dev/null

# Mako - read generated colors and update config
if [ -f "$CACHE/colors-mako" ]; then
    bg=$(grep 'background-color=' "$CACHE/colors-mako" | cut -d= -f2)
    fg=$(grep 'text-color=' "$CACHE/colors-mako" | cut -d= -f2)
    border=$(grep 'border-color=' "$CACHE/colors-mako" | cut -d= -f2)
    sed -i \
        -e "s/^text-color=.*/text-color=${fg}/" \
        -e "s/^border-color=.*/border-color=${border}/" \
        -e "s/^background-color=.*/background-color=${bg}ee/" \
        "$HOME/.config/mako/config" 2>/dev/null
fi

# Fuzzel - replace [colors] section with cwal-generated colors
if [ -f "$CACHE/colors-fuzzel.ini" ]; then
    sed -i '/^\[colors\]/,$d' "$HOME/.config/fuzzel/fuzzel.ini" 2>/dev/null
    cat "$CACHE/colors-fuzzel.ini" >> "$HOME/.config/fuzzel/fuzzel.ini" 2>/dev/null
fi

# Reload Hyprland to pick up new border colors from colors-hyprland.conf
hyprctl reload &>/dev/null

# Reload mako to apply notification color changes
makoctl reload 2>/dev/null || true

# Walker - restart to pick up new theme
systemctl --user restart app-walker@autostart.service 2>/dev/null

# Generate rofi color variables for wallpaper picker theme
if [ -f "$CACHE/colors.sh" ]; then
    source "$CACHE/colors.sh"
    cat > "$CACHE/colors-rofi-vars.rasi" << EOF
* {
    wp-bg:        ${background}F2;
    wp-bg-alt:    ${color1};
    wp-fg:        ${foreground};
    wp-accent:    ${color5};
    wp-accent-hi: ${color13};
    wp-border:    ${color2};
    wp-selected:  ${color2};
}
EOF
fi

# Recolor Discord SVG to match theme
if [ -f "$CACHE/colors.sh" ]; then
    source "$CACHE/colors.sh"
    sed -i "s/fill:[^\"']*/fill:${color5}/" "$HOME/.config/waybar/images/discord.svg" 2>/dev/null
fi
