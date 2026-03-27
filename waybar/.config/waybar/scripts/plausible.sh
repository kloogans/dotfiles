#!/bin/bash
source ~/.env

sites=("buildlineups.com" "dfshelp.com" "kloogans.com" "botfight.lol")
total=0
tooltip=""
details=""
yesterday=$(date -d 'yesterday' +%Y-%m-%d)
today=$(date +%Y-%m-%d)

for site in "${sites[@]}"; do
    response=$(curl -s -H "Authorization: Bearer $PLAUSIBLE_API_KEY" \
        "$PLAUSIBLE_URL/api/v1/stats/aggregate?site_id=$site&period=custom&date=$yesterday,$today&metrics=visitors,pageviews" 2>/dev/null)

    visitors=$(echo "$response" | jq -r '.results.visitors.value // 0')
    pageviews=$(echo "$response" | jq -r '.results.pageviews.value // 0')

    total=$((total + visitors))

    if [[ -n "$details" ]]; then
        details="$details\\n"
    fi
    details="${details}${site}: ${visitors} visitors / ${pageviews} views"
done

icon='󰄪'
text="<span color='#b4befe'>$icon</span>  ${total}"
tooltip="Last 24h\\n\\n${details}"

printf '{"text": "%s", "tooltip": "%s", "class": "analytics"}\n' "$text" "$tooltip"
