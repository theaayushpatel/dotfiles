#!/usr/bin/env bash
# Ultra-fast non-blocking network details collector for Quickshell NetworkPanel

read -r def_gw def_iface def_ip <<< $(ip -4 route show default 2>/dev/null | awk '{for(i=1;i<=NF;i++){if($i=="via")gw=$(i+1); if($i=="dev")dev=$(i+1); if($i=="src")src=$(i+1)}} END{print gw, dev, src}')

if [ -z "$def_iface" ]; then
  def_iface=$(nmcli -t -f DEVICE,TYPE,STATE device status 2>/dev/null | awk -F: '$3 == "connected" { print $1; exit }')
fi

if [ -n "$def_iface" ]; then
  ip="${def_ip:-$(ip -4 -o addr show "$def_iface" 2>/dev/null | awk '{print $4}' | cut -d/ -f1)}"
  gateway="${def_gw:-$(ip route show default 2>/dev/null | awk '{print $3; exit}')}"
  [ -d "/sys/class/net/$def_iface/wireless" ] && type="wifi" || type="ethernet"

  eval "$(nmcli -t -f GENERAL.CONNECTION,GENERAL.CON-PATH device show "$def_iface" 2>/dev/null | awk -F: '$1=="GENERAL.CONNECTION"{print "connection=\"" $2 "\""} $1=="GENERAL.CON-PATH"{print "conPath=\"" $2 "\""}')"

  if [ "$type" = "wifi" ]; then
    IFS=$'\t' read -r ssid security < <(nmcli -t -f ACTIVE,SSID,SECURITY dev wifi list --rescan no 2>/dev/null | awk -F: '($1=="yes"||$1=="*"){ sec=$NF; sub(/^[^:]+:/, ""); sub(/:[^:]*$/, ""); printf "%s\t%s\n", $0, sec; exit }')
  fi
  [ -z "$ssid" ] && ssid="$connection"

  rx=$(cat "/sys/class/net/$def_iface/statistics/rx_bytes" 2>/dev/null)
  tx=$(cat "/sys/class/net/$def_iface/statistics/tx_bytes" 2>/dev/null)

  # Run latency & packet loss tests in parallel
  if [ -n "$gateway" ]; then
    pf=$(mktemp)
    (ping -c 1 -W 1 "$gateway" 2>/dev/null | awk -F'[/ ]+' '/rtt|round-trip/ { print $7 " ms"; exit }' > "$pf") &
    P1=$!
  fi
  lf=$(mktemp)
  (ping -c 1 -W 1 1.1.1.1 2>/dev/null | awk -F', ' '/packet loss/ { print $3; exit }' > "$lf") &
  P2=$!

  [ -n "$P1" ] && wait "$P1" 2>/dev/null
  wait "$P2" 2>/dev/null

  [ -n "$pf" ] && { ping=$(cat "$pf" 2>/dev/null); rm -f "$pf"; }
  loss=$(cat "$lf" 2>/dev/null); rm -f "$lf"
fi

wifiEnabled=$(nmcli radio wifi 2>/dev/null)

printf 'iface\t%s\nip\t%s\ngateway\t%s\ntype\t%s\nssid\t%s\nconnection\t%s\nconPath\t%s\nsecurity\t%s\nrx\t%s\ntx\t%s\nping\t%s\nloss\t%s\nwifiEnabled\t%s\n' \
  "$def_iface" "$ip" "$gateway" "$type" "$ssid" "$connection" "$conPath" "$security" "$rx" "$tx" "$ping" "$loss" "$wifiEnabled"
