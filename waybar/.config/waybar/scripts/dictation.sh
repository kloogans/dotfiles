#!/bin/bash
if systemctl --user is-active hypr-dictate-server.service &>/dev/null; then
    echo '{"text": "󰍬", "tooltip": "Dictation server running", "class": "running"}'
else
    echo '{"text": "󰍭", "tooltip": "Dictation server stopped", "class": "stopped"}'
fi
