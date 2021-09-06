#!/usr/bin/env sh

version="0.0.1"
while [[ "$1" =~ ^- && ! "$1" = "--" ]]; do
    case $1 in
    -V | --version)
      echo $version
      exit
      ;;
    esac
    shift
done
if [ "$1" = "--" ]; then shift; fi

# merge args for SSIDs with spaces
args="$@"

linux() {
    if [ "" != "$args" ]; then
        ssid="$args"
        exists="$(nmcli -f NAME connection | grep -E "${ssid}")"

        if [ "$exists" = "" ]; then
            echo "Error: could not find SSID \"$ssid\"" >&2
            exit 1
        fi
    else
      ssid="$(nmcli -t -f in-use,ssid dev wifi | grep -E '^\*' | cut -d: -f2)"
      if [ "$ssid" = "" ]; then
          echo "Error: could not retieve current SSID. Are you connected?" >&2
          exit 1
      fi
    fi

    pwd=$(sudo sed -e '/^psk=/!d' -e 's/psk=//' "/etc/NetworkManager/system-connections/${ssid}")

    if [ "" = "$pwd" ]; then
        echo "Error: could not get password. Did you enter your credentials?" >&2
        exit 1
    fi
    echo "WIFI:T:WPA;S:${ssid};P:${pwd};;" | qrencode -t UTF8
}

mac() {
  airport="/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport"
  echo "airport: $airport" >&2
  if [ ! -f $airport ]; then
      echo "Error: could not find \`airport\` CLI program at \"$airport\"."
      exit 1
  fi
  if [ "" != "$args" ]; then
      ssid="$args"
  else
    ssid="$($airport -I | awk '/ SSID/ {print substr($0, index($0, $2))}')"
    if [ "" = "$ssid" ]; then
        echo "Error: could not retrieve current SSID. Are you connected?" >&2
        exit 1
    fi
  fi

  sleep 2
  pwd="$(security find-generic-password -ga \"$ssid\" 2>&1 >/dev/null)"
  if [ "$pwd" = "could" ]; then
      echo "Error: could not find SSID \"$ssid\"" >&2
      exit 1
  fi

  pwd=$(echo "$pwd" | sed -e "s/^.*\"\(.*\)\".*$/\1/")
  if [ "" = "$pwd" ]; then
      echo "Error: could not get password. Did you enter your keychain credentials?" >&2
      exit 1
  fi
  echo "WIFI:T:WPA;S:${ssid};P:${pwd};;" | qrencode -t UTF8
}

if [ "$OSTYPE" = "linux-gnu" ]; then
    linux
    exit 0
elif [[ "$OSTYPE" = *"darwin"* ]]; then
    mac
    exit 0
fi

echo "Error: unsupported OS" >&2
exit 1

