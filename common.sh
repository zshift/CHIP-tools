#!/bin/bash

TIMEOUT=30
FEL=fel

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
    if lsusb |grep -q "0525:a4a7" ||
       lsusb |grep -q "0525:a4aa"; then
      echo "OK"
      return 0;
    fi
    echo -n ".";
    sleep 3
  }

  echo "TIMEOUT";
  return 1
}

verify() {
  local SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
  local SCRIPT_NAME="$(basename $0)"
  local CHAT_SCRIPT="verify.chat"
  local CHAT_BIN="$(which chat)"
  local CHAT_BIN="${CHAT_BIN:-/usr/sbin/chat}"
  
  
  local UART_DEVICE=ttyACM0
  local GETTY_UART_SERVICE="serial-getty@${UART_DEVICE}.service"
  local GETTY_DISABLED=0
  
  local TIMEOUT=3
  
  #echo "DUT_UART_RUN=$DUT_UART_RUN"
  
  while getopts "t:" opt; do
          case $opt in
                  t)
                          TIMEOUT="${OPTARG}"
                          echo "timeout set to ${TIMEOUT}"
                          ;;
                  \?)
                          echo "Invalid option: -$OPTARG" >&2
                          return 1
                          ;;
          esac
  done
  shift $((OPTIND-1))
  local DUT_UART_PARAMETER="$@"
  
  
  if [[ "$(systemctl is-active $GETTY_UART_SERVICE)" == "active" ]]; then
    echo "stopping $GETTY_UART_SERVICE"
    systemctl stop $GETTY_UART_SERVICE
    GETTY_DISABLED=1
  fi
  
  [[ -r "${CHAT_SCRIPT}" ]] || (echo "ERROR: can not read ${CHAT_SCRIPT}" && exit 1)
  if [[ ! -r "${CHAT_BIN}" ]]; then
    echo -e "ERROR: ${CHAT_BIN} not found\n -- 'sudo apt-get install ppp'"
    return 1
  fi
  
  for i in `seq 1 3`;
  do
    echo -e "Waiting for serial gadget...Attempt(${i}/3)"
    /usr/sbin/chat -t $TIMEOUT -E -V -f "${CHAT_SCRIPT}" </dev/${UART_DEVICE} >/dev/${UART_DEVICE}\
    && break\
    || (echo -e "ERROR: failed to verify\n" && return 1)
  done
  echo "SUCCESS: CHIP is powering down"
  
  if [[ ${GETTY_DISABLED} == 1 ]]; then
    echo "starting $GETTY_UART_SERVICE"
    systemctl start $GETTY_UART_SERVICE
  fi
}

ready_to_roll() {

  echo -e "\n\nFLASH VERIFICATION COMPLETE.\n\n"

  echo "   #  #  #"
  echo "  #########"
  echo "###       ###"
  echo "  # {#}   #"
  echo "###  '\######"
  echo "  #       #"
  echo "###       ###"
  echo "  ########"
  echo "   #  #  #"

  echo -e "\n\nCHIP is ready to roll!\n\n"

  return 0
}
