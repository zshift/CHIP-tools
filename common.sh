#!/bin/bash

TIMEOUT=30

if [[ -z $(which $FEL) ]]; then
  echo "  Error: Unable to locate FEL utility."
  echo "  Install FEL with:"
  echo "  CHIP-SDK setup script      [github.com/NextThingCo/CHIP-SDK]"
  echo "     - or build from source  [github.com/NextThingCo/sunxi-tools]"
  exit 1
fi

#------------------------------------------------------------
onMac() {
  if [ "$(uname)" == "Darwin" ]; then
    return 0;
  else
    return 1;
  fi
}

#------------------------------------------------------------
filesize() {
  if onMac; then
    stat -f "%z" $1
  else
    stat --printf="%s" $1
  fi
}

#------------------------------------------------------------
wait_for_fastboot() {
  echo -n "waiting for fastboot...";
  for ((i=$TIMEOUT; i>0; i--)) {
    if [[ ! -z "$(fastboot -i 0x1f3a $@ devices)" ]]; then
      echo "OK";
      return 0;
    fi
    echo -n ".";
    sleep 1
  }

  echo "TIMEOUT";
  return 1
}

#------------------------------------------------------------
wait_for_fel() {
  echo -n "waiting for fel...";
  for ((i=$TIMEOUT; i>0; i--)) {
    if ${FEL} $@ ver 2>/dev/null >/dev/null; then
      echo "OK"
      return 0;
    fi
    echo -n ".";
    sleep 1
  }

  echo "TIMEOUT";
  return 1
}

#------------------------------------------------------------
wait_for_linuxboot() {
  local TIMEOUT=100
  echo -n "flashing...";
  for ((i=$TIMEOUT; i>0; i--)) {
    if lsusb |grep -q "0525:a4a7"; then
      echo "OK"
      return 0;
    fi
    echo -n ".";
    sleep 3
  }

  echo "TIMEOUT";
  return 1
}

