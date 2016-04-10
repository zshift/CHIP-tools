#!/bin/bash

#set -x

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SCRIPT_NAME="$(basename $0)"
CHAT_SCRIPT="${SCRIPT_DIR}/${SCRIPT_NAME}.chat"

UART_DEVICE=ttyACM0
GETTY_UART_SERVICE="serial-getty@${UART_DEVICE}.service"

export TIMEOUT=3

#echo "DUT_UART_RUN=$DUT_UART_RUN"

while getopts "t:" opt; do
	case $opt in
		t)
			TIMEOUT="${OPTARG}"
			echo "timeout set to ${TIMEOUT}"
			;;
		\?)
			echo "Invalid option: -$OPTARG" >&2
			exit 1
			;;
	esac
done
shift $((OPTIND-1))
export DUT_UART_PARAMETER="$@"


if [[ "$(systemctl is-active $GETTY_UART_SERVICE)" == "active" ]]; then
  echo "stopping $GETTY_UART_SERVICE"
  systemctl stop $GETTY_UART_SERVICE
fi

[[ -r "${CHAT_SCRIPT}" ]] || (echo "ERROR: can not read ${CHAT_SCRIPT}" && exit 1)
/usr/sbin/chat -t $TIMEOUT -E -V -f "${CHAT_SCRIPT}" </dev/${UART_DEVICE} >/dev/${UART_DEVICE} || (echo "ERROR: failed to verify" && exit 1)

sleep 5s
clear
echo -e "\n\nFLASH VERIFICATION COMPLETE.\n\n"

echo "   #  #  #"
echo "  #########"
echo "###       ###"
echo "  # {#}   #"
echo "###   \######"
echo "  #       #"
echo "###       ###"
echo "  ########"
echo "   #  #  #"

echo -e "\n\nCHIP is ready to roll!\n\n"
