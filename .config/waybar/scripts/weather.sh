#!/usr/bin/env bash

DATA=$(curl -sf "https://wttr.in/Vijapur,Gujarat?format=j1") || exit 1

CITY=$(jq -r '.nearest_area[0].areaName[0].value' <<< "$DATA")
REGION=$(jq -r '.nearest_area[0].region[0].value' <<< "$DATA")

TEMP=$(jq -r '.current_condition[0].temp_C' <<< "$DATA")
FEELS=$(jq -r '.current_condition[0].FeelsLikeC' <<< "$DATA")
DESC=$(jq -r '.current_condition[0].weatherDesc[0].value' <<< "$DATA")

HUMIDITY=$(jq -r '.current_condition[0].humidity' <<< "$DATA")
UV=$(jq -r '.current_condition[0].uvIndex' <<< "$DATA")
PRESSURE=$(jq -r '.current_condition[0].pressure' <<< "$DATA")
VISIBILITY=$(jq -r '.current_condition[0].visibility' <<< "$DATA")

WIND=$(jq -r '.current_condition[0].windspeedKmph' <<< "$DATA")
WINDDIR=$(jq -r '.current_condition[0].winddir16Point' <<< "$DATA")

CLOUD=$(jq -r '.current_condition[0].cloudcover' <<< "$DATA")
PRECIP=$(jq -r '.current_condition[0].precipMM' <<< "$DATA")

SUNRISE=$(jq -r '.weather[0].astronomy[0].sunrise' <<< "$DATA")
SUNSET=$(jq -r '.weather[0].astronomy[0].sunset' <<< "$DATA")

MOON=$(jq -r '.weather[0].astronomy[0].moon_phase' <<< "$DATA")
MOONILLUM=$(jq -r '.weather[0].astronomy[0].moon_illumination' <<< "$DATA")

CODE=$(jq -r '.current_condition[0].weatherCode' <<< "$DATA")

case "$CODE" in
    113) ICON="󰖙" ;;
    116) ICON="󰖕" ;;
    119|122) ICON="󰖐" ;;
    143|248|260) ICON="󰖑" ;;
    176|263|266|281|293|296) ICON="󰖗" ;;
    299|302|305|308|311|314|353|356|359) ICON="󰖖" ;;
    179|182|185|227|230|323|326|329|332|335|338|368|371) ICON="󰖘" ;;
    200|386|389|392|395) ICON="󰖓" ;;
    *) ICON="󰖙" ;;
esac

FORECAST=$(jq -r '
.weather[] |
"\(.date[5:])  \(.maxtempC)°/\(.mintempC)°"
' <<< "$DATA")

TOOLTIP=$(cat <<EOF
󰍹 $CITY, $REGION

$ICON $DESC
󰔄 Temperature  $TEMP°C
󰸁 Feels Like   $FEELS°C

󰖎 Humidity     $HUMIDITY%
󰼫 UV Index     $UV
󰙃 Clouds       $CLOUD%
󰔏 Rain         $PRECIP mm

󰖝 Wind         $WIND km/h $WINDDIR
󰖑 Visibility   $VISIBILITY km
󰙾 Pressure     $PRESSURE hPa

󰖜 Sunrise      $SUNRISE
󰖛 Sunset       $SUNSET

󰽧 $MOON
󰽧 Illumination $MOONILLUM%

󰖐 Forecast
$FORECAST
EOF
)

jq -cn \
    --arg text "$ICON $TEMP°C" \
    --arg tooltip "$TOOLTIP" \
    '{text:$text,tooltip:$tooltip}'