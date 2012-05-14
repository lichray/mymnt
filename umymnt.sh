#!/bin/sh

# 
# umymnt.sh  a semi-auto unmount script
#
# Copyright (c) 1992-2011 Zhihao Yuan. All rights reserved.
# This file is distributed under the 2-clause BSD License.

: ${MNTBASE:="$HOME/mnt"}

ALL=0
DEBUG=0
NAME="$(basename "$0")"

usage () {
	echo "Usage: $NAME [OPTIONS] [LABEL | NODE]"
}

help () {
	usage
	echo -n "
LABEL:        volume or device name under /dev/
NODE:         alternative mount point under MNTBASE

OPTIONS:
  -p path     overwrite the default MNTBASE
  -a          unmount all devices
  -D          show unmount command only
  -l          list available mount points
  -h          show this help
"
}

error () {
	echo "$NAME: $1" >&2
	exit 1
}

issue () {
	if [ "$DEBUG" -ne 0 ]; then
		echo "$@"
	else
		"$@"
	fi
}

getdevice () {
	dev="$(echo "/dev/$1" | sed 's/"/\\"/g')"
 	# preserve that space
	name="$(echo " $MNTBASE/$1" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g')"
	echo "$(mount | awk "{if(\$1==\"$dev\"||index(\$0,\"$name\")){print\$1;exit}}")"
}

labelof () {
	echo "$(glabel status -s "$1" | awk '{sub(/[^\/]*\//,"");split($0,a,/[[:space:]]*N\/A[[:space:]]+/);print a[1]}')"
}

umount_target () {

device="$(getdevice "$1")"
if [ -z "$device" ]; then
	error "$device: No such mount point"
fi
issue umount "$device"
st=$?
if [ "$device" != "/dev/$1" -a -d "$MNTBASE/$1" ]; then
	node="$MNTBASE/$1"
else
	node="$MNTBASE/$(labelof $(basename "$device"))"
fi
issue rmdir "$node" 2> /dev/null
exit $st

}

# process options
while getopts 'p:aDlh' flag; do
	case "$flag" in
		p)
			MNTBASE="${OPTARG%%/}" ;;
		a)
			ALL=1 ;;
		D)
			DEBUG=1 ;;
		l)
			ls -d "$MNTBASE"/* 2> /dev/null | while read nd; do
				echo "${nd#"$MNTBASE/"}"
			done
			exit ;;
		h)
			help
			exit ;;
		*)
			usage
			echo "Try \`$NAME -h' for more information."
			exit 2
	esac
done

# if -a is specified, call itself recursively
if [ "$ALL" -eq 1 -a $# -eq $((OPTIND-1)) ]; then
	mount | while read -r ln; do
		ls -d "$MNTBASE"/* 2> /dev/null | while read -r nd; do
			if echo "$ln" | grep -wF "$nd" > /dev/null 2>&1; then
				"$0" "$@" "${nd#"$MNTBASE/"}"
				break
			fi
		done
	done
	exit
fi

shift $((OPTIND-1))

if [ $# -eq 0 ]; then
	usage
	exit 2
else
	umount_target "$@"
fi

