#!/usr/bin/env sh

version="0.0.1"

# verbose by default(unless non-tty)
if [ -t 1 ]; then
    verbose=1
else
    verbose=
fi

while [[ "$1" =~ ^- && ! "$1" = "--" ]]; do
    case $1 in
    -v | --version)
      echo $version
      exit
      ;;
    -q | --quite)
      verbose=
      ;;
    -h | --help)
      usage
      exit
      ;;
    esac
    shift
done
if [ "$1" = "--" ]; then shift; fi

# merge args for SSIDs with spaces
args="$@"

if [ "$verbose" ]; then
  echo "args: $args" >&2
fi

# how to use

usage() {
  cat <<EOF
  Usage: wifi-pwd [options] [ssid]
  Options:
    -q, --quiet       Only output the password
    -v, --version     Output version
    -h, --help        This message
    --                End of options
EOF
}

linux() {
    if [ "" != "$args" ]; then
        ssid="$args"
        exists="$(nmcli -f NAME connection | grep -E "${ssid}")"
        if [ "$verbose" ]; then
          echo "ssid: $ssid, exists: $exists" >&2
        fi
        if [ "$exists" = "" ]; then
            echo "Error: could not find SSID \"$ssid\"" >&2
            exit 1
        fi
    else
      ssid="$(nmcli -t -f in-use,ssid dev wifi | grep -E '^\*' | cut -d: -f2)"
      if [ "$verbose" ]; then
        echo "ssid: $ssid" >&2
      fi
      if [ "$ssid" = "" ]; then
          echo "Error: could not retrieve current SSID. Are you connected?" >&2
          exit 1
      fi
    fi

    password=$(sudo sed -e '/^psk=/!d' -e 's/psk=//' "/etc/NetworkManager/system-connections/${ssid}")
    
    if [ "$verbose" ]; then
      echo "password: $password" >&2 >&2
    fi
    
    if [ "" = "$password" ]; then
        echo "Error: could not get password. Did you enter your credentials?" >&2
        exit 1
    fi
    if [ "$verbose" ]; then
      echo "WIFI:T:WPA;S:${ssid};P:${password};;" >&2
    fi
    echo "WIFI:T:WPA;S:${ssid};P:${password};;" | qrencode -t UTF8
}

mac() {
  airport="/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport"
  if [ "$verbose" ]; then
    echo "airport: $airport" >&2
  fi
  if [ ! -f $airport ]; then
      echo "Error: could not find \`airport\` CLI program at \"$airport\"."
      exit 1
  fi
  if [ "" != "$args" ]; then
      ssid="$args"
      if [ "$verbose" ]; then
        echo "ssid: $ssid" >&2
      fi
  else
    ssid="$($airport -I | awk '/ SSID/ {print substr($0, index($0, $2))}')"
    if [ "$verbose" ]; then
        echo "ssid: $ssid" >&2
    fi
    if [ "" = "$ssid" ]; then
        echo "Error: could not retrieve current SSID. Are you connected?" >&2
        exit 1
    fi
  fi

  sleep 2
  password="$(security find-generic-password -ga \"$ssid\" 2>&1 >/dev/null)"
  if [ "$verbose" ]; then
    echo "password: $password" >&2
  fi
  if [ "$password" = "could" ]; then
      echo "Error: could not find SSID \"$ssid\"" >&2
      exit 1
  fi

  password=$(echo "$password" | sed -e "s/^.*\"\(.*\)\".*$/\1/")
  if [ "$verbose" ]; then
    echo "password: $password" >&2
  fi
  if [ "" = "$password" ]; then
      echo "Error: could not get password. Did you enter your keychain credentials?" >&2
      exit 1
  fi
  if [ "$verbose" ]; then
    echo "WIFI:T:WPA;S:${ssid};P:${password};;" >&2
  fi
  echo "WIFI:T:WPA;S:${ssid};P:${password};;" | qrencode -t UTF8
}

if [ "$verbose" ]; then
  echo "OSType: $OSTYPE" >&2
fi

if [ "$OSTYPE" = "linux-gnu" ]; then
    linux
    exit 0
elif [[ "$OSTYPE" = *"darwin"* ]]; then
    mac
    exit 0
fi

echo "Error: unsupported OS" >&2
exit 1

